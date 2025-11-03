import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService; // Service gói các thao tác đăng ký/đăng nhập
  const RegisterScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form key để validate toàn bộ form 1 lượt
  final _formKey = GlobalKey<FormState>();

  // Controllers cho từng ô nhập liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Trạng thái đang submit (để disable nút & hiện spinner)
  bool _isLoading = false;

  @override
  void dispose() {
    // Giải phóng controller để tránh memory leak
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================ ĐĂNG KÝ ============================
  Future<void> _submit() async {
    // 1) Validate form: nếu có field invalid -> dừng
    if (!_formKey.currentState!.validate()) return;

    // 2) Bật loading để khóa nút & hiển thị progress
    setState(() => _isLoading = true);

    try {
      // 3) Gọi AuthService.register để:
      //    - Tạo tài khoản Firebase Auth (email/password)
      //    - Ghi dữ liệu user vào Realtime Database (tùy phần cài trong AuthService)
      await widget.authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
      );

      // 4) Điều hướng sang /home và xóa history (không cho quay lại màn Register)
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on Exception catch (e) {
      // 5) Xử lý lỗi: hiển thị thông báo thân thiện
      String message = 'Lỗi khi đăng ký';

      // Lỗi tùy chỉnh từ AuthService: username đã tồn tại
      if (e.toString().contains('username-taken')) {
        message = 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.';
      }
      // Lỗi chuẩn của FirebaseAuth (ví dụ email không hợp lệ)
      else if (e is FirebaseAuthException) {
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
            message = e.message ?? e.toString(); // fallback thông điệp gốc
        }
      } else {
        // Các lỗi khác (mạng, parsing...)
        message = e.toString();
      }

      // Hiển thị thông báo lỗi qua SnackBar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      // 6) Tắt trạng thái loading nếu widget còn mounted
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================ UI ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
        backgroundColor: const Color(0xFF0B0B0F), // nền tối đồng bộ app
      ),
      backgroundColor: const Color(0xFF0B0B0F),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // gắn key để validate form
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // nút full width
              children: [
                // ====== Họ và tên ======
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  // Validator: không được bỏ trống
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 12),

                // ====== Tên đăng nhập ======
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  // Validator: không để trống; (logic kiểm tra trùng nằm ở AuthService.register)
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
                ),
                const SizedBox(height: 12),

                // ====== Số điện thoại ======
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  // Validator: bắt buộc nhập (có thể thêm regex tuỳ ý)
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng nhập số điện thoại'
                      : null,
                ),
                const SizedBox(height: 12),

                // ====== Email ======
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  // Validator: check có @ (đơn giản). Lỗi sâu hơn Firebase sẽ báo
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email không hợp lệ'
                      : null,
                ),
                const SizedBox(height: 12),

                // ====== Mật khẩu ======
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // ẩn ký tự
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  // Validator: tối thiểu 6 ký tự (quy tắc của Firebase)
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mật khẩu ít nhất 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 20),

                // ====== Nút Đăng ký ======
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit, // disable khi loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B), // màu chủ đạo
                  ),
                  child: _isLoading
                      // Khi submit -> hiển thị vòng tròn loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      // Khi bình thường -> hiện chữ
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
