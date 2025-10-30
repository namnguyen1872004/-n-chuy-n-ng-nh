import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  // NOTE: we avoid depending on the google_sign_in client here and use
  // FirebaseAuth's `signInWithProvider` / `signInWithPopup` flow which works
  // across platforms and avoids constructor mismatches between package versions.

  // Register using email & password, then write profile data to Realtime Database
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        // create user record in realtime DB and update firebase profile
        await _ensureUserRecordExists(
          user,
          name: name,
          phone: phone,
          photoUrl: null,
        );
        try {
          await user.updateDisplayName(name);
          await user.reload();
        } catch (_) {}
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Forward the FirebaseAuthException so the UI can show a friendly message
      throw e;
    }
  }

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

  Future<void> signOut() async {
    // Sign out from Firebase and Google (if used)
    try {
      await _auth.signOut();
    } catch (_) {
      // ignore errors on sign out
    }
  }

  /// Update current user's profile (name, phone, photoUrl) in Realtime DB
  /// and optionally update the Firebase Auth displayName/photoURL.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _db.child('users').child(user.uid).update(updates);
    }

    // update Firebase Auth profile where applicable
    try {
      if (name != null) await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
      await user.reload();
    } catch (_) {
      // ignore failures to update the Auth profile
    }
  }

  /// Sign in using Google account. Returns the Firebase [User] or null if cancelled.
  Future<User?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();

      // Web uses popup flow
      if (kIsWeb) {
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

      // Mobile/desktop: use signInWithProvider which delegates to platform SDKs
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
      throw e;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Ensure there is a user record in Realtime Database. If missing, create it.
  /// If existing and optional fields provided, update them.
  Future<void> _ensureUserRecordExists(
    User user, {
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final ref = _db.child('users').child(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: name ?? user.displayName ?? '',
        phone: phone,
        points: 0,
        photoUrl: photoUrl ?? user.photoURL,
        createdAt: DateTime.now().toIso8601String(),
      );
      await ref.set(userModel.toMap());
    } else {
      // update provided fields only
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (updates.isNotEmpty) await ref.update(updates);
    }
  }
}
