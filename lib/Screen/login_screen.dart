import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'dart:async';

import '../services/auth_service.dart';
import 'register_screen.dart';

/// Màn hình đăng nhập
class LoginScreen extends StatefulWidget {
  final AuthService authService;
  const LoginScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // -------------------- Controllers & State --------------------
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl =
      TextEditingController(); // dùng username, không phải email
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePw = true;

  // Realtime Database root (tạo sẵn để tái sử dụng)
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // -------------------- Helpers UI --------------------
  void _toggleLoading(bool v) {
    if (mounted) setState(() => _isLoading = v);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------- Core: Đăng nhập bằng username + password --------------------
  Future<void> _loginWithUsernamePassword() async {
    // 1) Validate form
    if (!_formKey.currentState!.validate()) return;

    _toggleLoading(true);
    try {
      // 2) Chuẩn hoá username (lowercase, trim)
      final uname = _usernameCtrl.text.trim().toLowerCase();

      // 3) Tìm uid theo username: /usernames/{username} -> uid
      final unameSnap = await _db
          .child('usernames/$uname')
          .get()
          .timeout(const Duration(seconds: 5));
      if (!unameSnap.exists ||
          (unameSnap.value as String?)?.isNotEmpty != true) {
        _showSnack('Không tìm thấy tên đăng nhập.');
        return;
      }
      final uid = unameSnap.value as String;

      // 4) Lấy email theo uid: /users/{uid}/email -> email
      final emailSnap = await _db
          .child('users/$uid/email')
          .get()
          .timeout(const Duration(seconds: 5));
      final email = (emailSnap.value as String?)?.trim();
      if (email == null || email.isEmpty) {
        _showSnack('Tài khoản không có email hợp lệ.');
        return;
      }

      // 5) Firebase Auth: đăng nhập bằng email vừa resolve được
      await widget.authService.login(
        email: email,
        password: _passwordCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      // Thông điệp ngắn gọn, dễ hiểu
      final msg = switch (e.code) {
        'wrong-password' => 'Mật khẩu không chính xác.',
        'user-not-found' => 'Không tìm thấy tài khoản.',
        'user-disabled' => 'Tài khoản đã bị vô hiệu hoá.',
        'too-many-requests' => 'Thử lại sau ít phút (quá nhiều yêu cầu).',
        _ => e.message ?? 'Lỗi khi đăng nhập.',
      };
      _showSnack(msg);
    } on TimeoutException {
      _showSnack('Mạng chậm, vui lòng thử lại.');
    } catch (e) {
      _showSnack('Lỗi khi đăng nhập: $e');
    } finally {
      _toggleLoading(false);
    }
  }

  // -------------------- Google Sign-In (nhẹ máy, tránh double tap) --------------------
  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
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
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: SingleChildScrollView(
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

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1C1C28),
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Tên đăng nhập không được để trống'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      textInputAction: TextInputAction.done,
                      obscureText: _obscurePw,
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
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu ít nhất 6 ký tự'
                          : null,
                      onFieldSubmitted: (_) => _loginWithUsernamePassword(),
                    ),
                    const SizedBox(height: 24),

                    // Nút đăng nhập
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
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

                    // Google Sign-In
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

                    // Điều hướng sang đăng ký
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
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
