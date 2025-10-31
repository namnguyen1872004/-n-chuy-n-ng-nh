import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sign_in_button/sign_in_button.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  const LoginScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Đăng nhập bằng email & password
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Login by username: read /usernames/{username} to get uid, then read email
      final username = _emailController.text.trim();
      final uname = username.toLowerCase();
      final unameSnap = await FirebaseDatabase.instance
          .ref('usernames/$uname')
          .get();
      if (!unameSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy tên đăng nhập.')),
          );
        }
        return;
      }

      final uid = unameSnap.value as String?;
      if (uid == null || uid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tài khoản không tồn tại.')),
          );
        }
        return;
      }

      final emailSnap = await FirebaseDatabase.instance
          .ref('users/$uid/email')
          .get();
      final email = emailSnap.value as String?;
      if (email == null || email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tài khoản không có email hợp lệ.')),
          );
        }
        return;
      }

      await widget.authService.login(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      String message = 'Lỗi khi đăng nhập';
      switch (e.code) {
        case 'wrong-password':
          message = 'Mật khẩu không chính xác.';
          break;
        case 'user-not-found':
          message = 'Không tìm thấy tài khoản.';
          break;
        case 'user-disabled':
          message = 'Tài khoản đã bị vô hiệu hóa.';
          break;
        case 'too-many-requests':
          message = 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
          break;
        default:
          message = e.message ?? e.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi đăng nhập: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm đăng nhập Google riêng (tránh lỗi Future)
  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await widget.authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đăng nhập Google: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              // === Logo + Tiêu đề ===
              const Icon(
                Icons.movie_creation_outlined,
                color: Color(0xFF8B1E9B),
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                "Chào mừng trở lại!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Đăng nhập để tiếp tục trải nghiệm",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 36),

              // === Form đăng nhập ===
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Tên đăng nhập (username)
                    TextFormField(
                      controller: _emailController,
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

                    // Mật khẩu
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
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
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white60,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu ít nhất 6 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // === Nút Đăng nhập ===
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E9B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
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

                    // === Nút Google Sign-In ===
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: SignInButton(
                        Buttons.google,
                        text: "Đăng nhập bằng Google",
                        // SignInButton's callback expects a non-null function on some versions
                        // so provide a no-op when disabled instead of null to avoid runtime TypeError
                        onPressed: _isLoading
                            ? () {}
                            : () {
                                _handleGoogleLogin();
                              },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === Đăng ký ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Chưa có tài khoản? ",
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
                            "Đăng ký ngay",
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
