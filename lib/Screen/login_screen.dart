import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'dart:async';

import '../services/auth_service.dart';
import 'register_screen.dart';

/// Màn hình đăng nhập
class LoginScreen extends StatefulWidget {
  final AuthService
  authService; // Service bọc các thao tác đăng nhập (email/pass, Google, ...)
  const LoginScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // -------------------- Controllers & State --------------------
  final _formKey = GlobalKey<FormState>(); // key để validate Form
  final _usernameCtrl =
      TextEditingController(); // dùng username (không phải email trực tiếp)
  final _passwordCtrl = TextEditingController(); // mật khẩu

  bool _isLoading = false; // cờ đang xử lý để khóa UI/nút
  bool _obscurePw = true; // cờ ẩn/hiện mật khẩu

  // Realtime Database root (tạo sẵn để tái sử dụng)
  // -> Sử dụng để map username -> uid, và lấy email từ uid
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    // Giải phóng controller khi widget bị huỷ
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // -------------------- Helpers UI --------------------
  void _toggleLoading(bool v) {
    // Helper bật/tắt trạng thái loading an toàn (kiểm tra mounted)
    if (mounted) setState(() => _isLoading = v);
  }

  void _showSnack(String msg) {
    // Helper hiển thị SnackBar thông báo
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------- Core: Đăng nhập bằng username + password --------------------
  /// Luồng đăng nhập:
  /// 1) Validate form (username không rỗng, password >= 6)
  /// 2) Chuẩn hoá username (trim + lowercase) -> tránh trùng khác hoa/thường
  /// 3) Truy vấn /usernames/{username} -> lấy uid
  /// 4) Truy vấn /users/{uid}/email -> lấy email
  /// 5) Gọi FirebaseAuth đăng nhập bằng email + mật khẩu
  /// 6) Điều hướng về /home nếu thành công, hiển thị thông báo nếu lỗi
  Future<void> _loginWithUsernamePassword() async {
    // 1) Validate form
    if (!_formKey.currentState!.validate()) return;

    _toggleLoading(true);
    try {
      // 2) Chuẩn hoá username (lowercase, trim)
      final uname = _usernameCtrl.text.trim().toLowerCase();

      // 3) Tìm uid theo username: /usernames/{username} -> uid (String)
      final unameSnap = await _db
          .child('usernames/$uname') // node map username -> uid
          .get()
          .timeout(const Duration(seconds: 5)); // tránh treo request

      // Kiểm tra tồn tại & kiểu dữ liệu
      if (!unameSnap.exists ||
          (unameSnap.value as String?)?.isNotEmpty != true) {
        _showSnack('Không tìm thấy tên đăng nhập.');
        return; // dừng luôn nếu không có mapping
      }
      final uid = unameSnap.value as String;

      // 4) Lấy email theo uid: /users/{uid}/email -> email (String)
      final emailSnap = await _db
          .child('users/$uid/email')
          .get()
          .timeout(const Duration(seconds: 5));
      final email = (emailSnap.value as String?)?.trim();
      if (email == null || email.isEmpty) {
        _showSnack('Tài khoản không có email hợp lệ.');
        return; // không thể đăng nhập FirebaseAuth nếu thiếu email
      }

      // 5) Firebase Auth: đăng nhập bằng email vừa resolve được
      await widget.authService.login(
        email: email,
        password: _passwordCtrl.text.trim(),
      );

      // 6) Nếu thành công -> điều hướng về Home (xoá stack)
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      // Mapping mã lỗi FirebaseAuth -> thông điệp tiếng Việt thân thiện
      final msg = switch (e.code) {
        'wrong-password' => 'Mật khẩu không chính xác.',
        'user-not-found' => 'Không tìm thấy tài khoản.',
        'user-disabled' => 'Tài khoản đã bị vô hiệu hoá.',
        'too-many-requests' => 'Thử lại sau ít phút (quá nhiều yêu cầu).',
        _ => e.message ?? 'Lỗi khi đăng nhập.',
      };
      _showSnack(msg);
    } on TimeoutException {
      // Hết thời gian chờ
      _showSnack('Mạng chậm, vui lòng thử lại.');
    } catch (e) {
      // Các lỗi khác (parse, null, network...)
      _showSnack('Lỗi khi đăng nhập: $e');
    } finally {
      // Luôn tắt loading để trả UI về trạng thái bình thường
      _toggleLoading(false);
    }
  }

  // -------------------- Google Sign-In (nhẹ máy, tránh double tap) --------------------
  /// Đăng nhập qua Google bằng AuthService
  /// - Khoá nút khi đang _isLoading để tránh double-tap
  /// - Nếu nhận được user != null -> điều hướng về Home
  Future<void> _loginWithGoogle() async {
    if (_isLoading) return; // chặn double tap
    _toggleLoading(true);
    try {
      final user = await widget.authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      _showSnack('Lỗi đăng nhập Google: $e');
    } finally {
      _toggleLoading(false);
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F), // Nền tối đồng bộ app
      body: SafeArea(
        child: SingleChildScrollView(
          // Cho phép cuộn khi bàn phím mở/thiết bị nhỏ
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo + tiêu đề
              const Icon(
                Icons.movie_creation_outlined,
                color: Color(0xFF8B1E9B),
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chào mừng trở lại!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng nhập để tiếp tục trải nghiệm',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 36),

              // -------------------- Form đăng nhập --------------------
              Form(
                key: _formKey, // gắn key để validate
                child: Column(
                  children: [
                    // ====== Ô nhập Username ======
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction:
                          TextInputAction.next, // Next -> chuyển xuống mật khẩu
                      autocorrect: false, // tắt gợi ý/sửa tự động
                      enableSuggestions: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1C1C28), // nền input
                        labelText: 'Tên đăng nhập',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.white60,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      // Validation: không rỗng
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Tên đăng nhập không được để trống'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ====== Ô nhập Password ======
                    TextFormField(
                      controller: _passwordCtrl,
                      textInputAction:
                          TextInputAction.done, // Done -> gọi submit
                      obscureText: _obscurePw, // bật/tắt ẩn mật khẩu
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1C1C28),
                        labelText: 'Mật khẩu',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white60,
                        ),
                        // Nút con mắt để ẩn/hiện mật khẩu
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePw
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white60,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePw = !_obscurePw),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      // Validation: >= 6 ký tự
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu ít nhất 6 ký tự'
                          : null,
                      // Nhấn enter trên bàn phím -> trigger đăng nhập
                      onFieldSubmitted: (_) => _loginWithUsernamePassword(),
                    ),
                    const SizedBox(height: 24),

                    // ====== Nút Đăng nhập ======
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null // Khi loading -> disable nút (tránh double tap)
                            : _loginWithUsernamePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E9B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ====== Nút Google Sign-In ======
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: SignInButton(
                        Buttons.google,
                        text: 'Đăng nhập bằng Google',
                        // Một số version không chấp nhận null → dùng no-op khi _isLoading
                        onPressed: _isLoading ? () {} : _loginWithGoogle,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ====== Điều hướng sang màn đăng ký ======
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Điều hướng sang RegisterScreen, truyền cùng AuthService
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  authService: widget.authService,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              color: Color(0xFF8B1E9B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
