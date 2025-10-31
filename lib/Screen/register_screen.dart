import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  const RegisterScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
      );
      // Navigate to Home and remove all previous routes so user can't go back to Register
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on Exception catch (e) {
      String message = 'Lỗi khi đăng ký';
      if (e.toString().contains('username-taken')) {
        message = 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.';
      } else if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'invalid-email':
            message = 'Email không hợp lệ.';
            break;
          case 'email-already-in-use':
            message = 'Email đã được sử dụng.';
            break;
          case 'weak-password':
            message = 'Mật khẩu quá yếu.';
            break;
          case 'operation-not-allowed':
            message =
                'Đăng ký bằng email/password chưa được bật trên Firebase. Vào Firebase Console → Authentication → Sign-in method và bật Email/Password.';
            break;
          default:
            message = e.message ?? e.toString();
        }
      } else {
        message = e.toString();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
        backgroundColor: const Color(0xFF0B0B0F),
      ),
      backgroundColor: const Color(0xFF0B0B0F),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng nhập số điện thoại'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email không hợp lệ'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mật khẩu ít nhất 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Đăng ký'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
