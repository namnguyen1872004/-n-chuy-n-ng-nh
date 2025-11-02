// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart' as fb;

import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ----------- Services / DB -----------
  final AuthService _auth = AuthService();
  final fb.DatabaseReference _db = fb.FirebaseDatabase.instance.ref();

  // ----------- Form state -----------
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true; // đang tải dữ liệu ban đầu
  bool _saving = false; // đang lưu, khoá nút để tránh double-tap

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD: Lấy thông tin từ /users/{uid}
  // - Mọi giá trị đều chuyển về String để tránh lỗi kiểu dữ liệu (int/bool/null)
  // ---------------------------------------------------------------------------
  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa.')),
      );
      Navigator.of(context).pop(false);
      return;
    }

    try {
      final snap = await _db.child('users/${user.uid}').get();
      if (snap.exists && snap.value is Map) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);

        // ép kiểu an toàn
        _nameCtrl.text = (data['name'] ?? '').toString();
        _phoneCtrl.text = (data['phone'] ?? '').toString();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // SAVE: Ghi lại /users/{uid} với name + phone
  // - Có validator cơ bản cho name/phone
  // - Khoá nút khi đang lưu để tránh double-submit
  // ---------------------------------------------------------------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await _db.child('users/${user.uid}').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        // có thể thêm 'updatedAt': ServerValue.timestamp nếu cần
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin.')));
      Navigator.of(context).pop(true); // quay lại và báo thành công
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu thông tin: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------- Validator đơn giản -----------
  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (v.trim().length < 2) {
      return 'Tên quá ngắn';
    }
    return null;
  }

  String? _phoneValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // cho phép bỏ trống
    // Regex đơn giản cho số VN: 9–11 chữ số
    final reg = RegExp(r'^\d{9,11}$');
    if (!reg.hasMatch(s)) return 'Số điện thoại không hợp lệ';
    return null;
  }

  // ----------- UI -----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text('Cài đặt tài khoản'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Họ và tên
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Họ và tên'),
                      textInputAction: TextInputAction.next,
                      validator: _nameValidator,
                    ),
                    const SizedBox(height: 12),

                    // Số điện thoại (chỉ số)
                    TextFormField(
                      controller: _phoneCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Số điện thoại'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: _phoneValidator,
                    ),
                    const SizedBox(height: 20),

                    // Nút lưu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E9B),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Lưu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // InputDecoration thống nhất cho dark theme
  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF151521),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFFB9B9C3)),
    );
  }
}
