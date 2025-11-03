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
  // Service tự bọc FirebaseAuth (giả định): cung cấp currentUser (uid, email, ...)
  final AuthService _auth = AuthService();
  // Tham chiếu gốc tới Firebase Realtime Database
  final fb.DatabaseReference _db = fb.FirebaseDatabase.instance.ref();

  // ----------- Form state -----------
  // Key để điều khiển & validate toàn bộ Form
  final _formKey = GlobalKey<FormState>();
  // Controller cho 2 input (tên + số điện thoại)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Cờ trạng thái UI
  bool _loading = true; // đang tải dữ liệu ban đầu từ DB
  bool _saving = false; // đang lưu, dùng để disable nút Lưu, chống double-tap

  @override
  void initState() {
    super.initState();
    _loadProfile(); // Khi mở màn hình -> tải thông tin hiện có để fill vào form
  }

  @override
  void dispose() {
    // Giải phóng controller để tránh memory leak
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD: Lấy thông tin từ /users/{uid}
  // Ý tưởng:
  //  - Lấy uid từ _auth.currentUser
  //  - Đọc 1 lần node 'users/{uid}' trong Realtime DB
  //  - Nếu có dữ liệu -> ép mọi giá trị về String để không lỗi kiểu (VD: int -> toString)
  //  - Hiển thị lỗi nếu đọc thất bại
  //  - Sau cùng: bỏ trạng thái _loading để render form
  // ---------------------------------------------------------------------------
  Future<void> _loadProfile() async {
    final user = _auth.currentUser; // lấy user đang đăng nhập
    if (user == null) {
      // Nếu chưa đăng nhập -> báo và pop màn hình
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chỉnh sửa.')),
      );
      Navigator.of(context).pop(false);
      return;
    }

    try {
      // Đọc node theo uid
      final snap = await _db.child('users/${user.uid}').get();
      if (snap.exists && snap.value is Map) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);

        // Gán vào controller (ép kiểu an toàn: null -> '', int/bool -> string)
        _nameCtrl.text = (data['name'] ?? '').toString();
        _phoneCtrl.text = (data['phone'] ?? '').toString();
      }
    } catch (e) {
      // Có lỗi mạng/quyền truy cập -> hiển thị SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
    } finally {
      // Dù thành công hay lỗi, cũng tắt loading để show UI
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // SAVE: Ghi lại /users/{uid} với name + phone
  // Flow:
  //  - Validate form; nếu không pass -> dừng
  //  - Lấy uid; nếu null (chưa login) -> dừng
  //  - Đặt _saving = true để vô hiệu hoá nút Lưu & show loading nhỏ trong nút
  //  - Gọi update() lên DB với name/phone đã trim
  //  - Thành công: báo SnackBar + pop(true) để màn trước biết là đã lưu
  //  - Thất bại: báo lỗi
  //  - Cuối cùng: _saving = false
  // ---------------------------------------------------------------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; // chạy validator của form
    final user = _auth.currentUser;
    if (user == null) return; // an toàn (hiếm khi xảy ra nếu tới được đây)

    setState(() => _saving = true);
    try {
      // Ghi đè những field cần cập nhật; giữ nguyên field khác
      await _db.child('users/${user.uid}').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        // Có thể thêm 'updatedAt': ServerValue.timestamp nếu muốn lưu thời gian
      });

      if (!mounted) return;
      // Báo thành công + đóng màn với kết quả true
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      // Ghi thất bại -> báo lỗi cụ thể
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu thông tin: $e')));
    } finally {
      // Luôn trả UI về trạng thái bình thường
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------- Validator đơn giản -----------
  // Kiểm tra tên: không rỗng, >= 2 ký tự
  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (v.trim().length < 2) {
      return 'Tên quá ngắn';
    }
    return null;
  }

  // Kiểm tra số điện thoại: cho phép rỗng, nếu nhập thì phải 9–11 chữ số
  String? _phoneValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // cho phép bỏ trống
    // Regex đơn giản; có thể thay bằng validator chuẩn nhà mạng nếu cần
    final reg = RegExp(r'^\d{9,11}$');
    if (!reg.hasMatch(s)) return 'Số điện thoại không hợp lệ';
    return null;
  }

  // ----------- UI -----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F), // nền tối đồng bộ app
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text('Cài đặt tài khoản'),
        elevation: 0,
      ),
      body: _loading
          // Khi đang tải profile từ DB -> hiện spinner trung tâm
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            )
          // Khi đã tải xong -> hiển thị form
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey, // gắn key để validate toàn form
                child: Column(
                  children: [
                    // --- Input: Họ và tên ---
                    TextFormField(
                      controller: _nameCtrl, // dữ liệu nhập tên
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Họ và tên'), // style thống nhất
                      textInputAction:
                          TextInputAction.next, // Next -> nhảy sang ô sau
                      validator: _nameValidator, // ràng buộc tên
                    ),
                    const SizedBox(height: 12),

                    // --- Input: Số điện thoại ---
                    TextFormField(
                      controller: _phoneCtrl, // dữ liệu nhập số điện thoại
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Số điện thoại'),
                      keyboardType: TextInputType.phone, // mở bàn phím số
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // chỉ cho số
                        LengthLimitingTextInputFormatter(11), // tối đa 11
                      ],
                      validator: _phoneValidator, // ràng buộc hợp lệ
                    ),
                    const SizedBox(height: 20),

                    // --- Nút Lưu ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : _save, // disable khi đang lưu
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E9B),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // Hiển thị spinner nhỏ trong nút khi _saving = true
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
  // - Màu nền input, bo góc, không viền, label màu dịu
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
