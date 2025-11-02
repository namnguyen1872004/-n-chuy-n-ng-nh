import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/user_model.dart';

/// ===================================================================
/// AuthService
/// - Đăng ký / đăng nhập / đăng xuất với Firebase Auth
/// - Đồng bộ hồ sơ người dùng vào Realtime Database tại nhánh `users/{uid}`
/// - Hỗ trợ đăng nhập Google bằng API provider của FirebaseAuth
/// - Có ánh xạ username -> uid tại `usernames/{username}`
/// ===================================================================
class AuthService {
  /// Firebase Auth (xác thực)
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firebase Realtime Database (lưu hồ sơ, username map, v.v.)
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // -------------------------------------------------------------------
  // ĐĂNG KÝ TÀI KHOẢN (Email/Password)
  // - Tạo user trên Firebase Auth
  // - Tạo hồ sơ trong Realtime DB: users/{uid}
  // - Ghi map username -> uid tại usernames/{username}
  // -------------------------------------------------------------------
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String username,
  }) async {
    try {
      // Chuẩn hoá username (chữ thường, bỏ khoảng trắng đầu/cuối)
      final uname = username.trim().toLowerCase();

      // 1) Kiểm tra username đã tồn tại chưa
      final usernameSnap = await _db.child('usernames').child(uname).get();
      if (usernameSnap.exists) {
        // Ném lỗi tuỳ chỉnh để UI hiển thị "username-taken"
        throw Exception('username-taken');
      }

      // 2) Tạo tài khoản Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        // 3) Đảm bảo có hồ sơ trong DB (nếu chưa có thì tạo)
        await _ensureUserRecordExists(
          user,
          name: name,
          phone: phone,
          photoUrl: null,
        );

        // 4) Ghi map username -> uid để đăng nhập theo username về sau
        if (uname.isNotEmpty) {
          await _db.child('usernames').child(uname).set(user.uid);
        }

        // 5) Đồng bộ displayName trên Firebase Auth (không bắt buộc)
        try {
          await user.updateDisplayName(name);
          await user.reload();
        } catch (_) {
          // Bỏ qua lỗi không quan trọng
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      // Đẩy lỗi Auth ra ngoài để UI xử lý và hiện thông báo thân thiện
      throw e;
    }
  }

  // -------------------------------------------------------------------
  // ĐĂNG NHẬP (Email/Password)
  // -------------------------------------------------------------------
  Future<User?> login({required String email, required String password}) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  // -------------------------------------------------------------------
  // ĐĂNG XUẤT
  // -------------------------------------------------------------------
  Future<void> signOut() async {
    try {
      await _auth.signOut(); // nếu có Google, SDK sẽ tự gỡ token
    } catch (_) {
      // Bỏ qua lỗi khi sign out
    }
  }

  // -------------------------------------------------------------------
  // CẬP NHẬT HỒ SƠ NGƯỜI DÙNG (trên DB và/hoặc Auth profile)
  // - Chỉ update field được truyền (không ghi đè toàn bộ)
  // -------------------------------------------------------------------
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // 1) Cập nhật Realtime DB
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _db.child('users').child(user.uid).update(updates);
    }

    // 2) Cập nhật hồ sơ hiển thị trong Firebase Auth (tuỳ chọn)
    try {
      if (name != null) await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
      await user.reload();
    } catch (_) {
      // Không quan trọng -> bỏ qua
    }
  }

  // -------------------------------------------------------------------
  // ĐĂNG NHẬP GOOGLE
  // - Web: dùng signInWithPopup(provider)
  // - Mobile/Desktop: dùng signInWithProvider(provider)
  // - Sau khi đăng nhập: đảm bảo có hồ sơ ở DB (users/{uid})
  // -------------------------------------------------------------------
  Future<User?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();

      if (kIsWeb) {
        // Web: popup flow
        final userCred = await _auth.signInWithPopup(provider);
        final user = userCred.user;
        if (user != null) {
          await _ensureUserRecordExists(
            user,
            name: user.displayName,
            phone: user.phoneNumber,
            photoUrl: user.photoURL,
          );
        }
        return user;
      }

      // Mobile/Desktop: provider flow
      final userCred = await _auth.signInWithProvider(provider);
      final user = userCred.user;
      if (user != null) {
        await _ensureUserRecordExists(
          user,
          name: user.displayName,
          phone: user.phoneNumber,
          photoUrl: user.photoURL,
        );
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e; // để UI hiển thị tuỳ trường hợp (user-cancelled, network, …)
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  // -------------------------------------------------------------------
  // TIỆN ÍCH TRUY CẬP TRẠNG THÁI AUTH
  // -------------------------------------------------------------------
  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // -------------------------------------------------------------------
  // _ensureUserRecordExists
  // - Đảm bảo có hồ sơ trong DB tại `users/{uid}`
  // - Nếu chưa có -> tạo mới từ thông tin hiện có
  // - Nếu đã có -> chỉ cập nhật những field được truyền vào
  // -------------------------------------------------------------------
  Future<void> _ensureUserRecordExists(
    User user, {
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final ref = _db.child('users').child(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // Tạo record mới
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: name ?? user.displayName ?? '',
        phone: phone,
        points: 0, // điểm khởi tạo
        photoUrl: photoUrl ?? user.photoURL,
        createdAt: DateTime.now().toIso8601String(),
      );
      await ref.set(userModel.toMap());
    } else {
      // Cập nhật những field được truyền (không ghi đè toàn bộ object)
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (updates.isNotEmpty) await ref.update(updates);
    }
  }
}
