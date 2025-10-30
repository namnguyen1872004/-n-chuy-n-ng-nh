import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as fb;
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final fb.DatabaseReference _db = fb.FirebaseDatabase.instance.ref();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _photoCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa.')),
        );
        Navigator.of(context).pop(false);
      }
      return;
    }
    try {
      final snap = await _db.child('users').child(user.uid).get();
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        _nameCtrl.text = (data['name'] ?? '') as String;
        _phoneCtrl.text = (data['phone'] ?? '') as String;
        _photoCtrl.text = (data['photoUrl'] ?? '') as String;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _authService.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _db.child('users').child(user.uid).update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'photoUrl': _photoCtrl.text.trim().isEmpty
            ? null
            : _photoCtrl.text.trim(),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lưu thông tin thành công')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu thông tin: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
        backgroundColor: const Color(0xFF0B0B0F),
      ),
      backgroundColor: const Color(0xFF0B0B0F),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
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
                      controller: _phoneCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        labelStyle: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _photoCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'URL ảnh đại diện (tùy chọn)',
                        labelStyle: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E9B),
                        ),
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
