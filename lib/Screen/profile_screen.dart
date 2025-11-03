import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' as fb;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// 🆕 Import thêm màn hình quản lý vé
import 'ticket_manager_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Tham chiếu gốc tới Realtime Database
  final fb.DatabaseReference _database = fb.FirebaseDatabase.instance.ref();
  // Dịch vụ xác thực gói lại FirebaseAuth (đăng nhập/đăng xuất/Google...)
  final AuthService _authService = AuthService();

  // Model hồ sơ người dùng (name/phone/points)
  UserProfile? userProfile;
  // Danh sách giao dịch gần đây
  List<Transaction> recentTransactions = [];
  // Trạng thái đang tải (loading skeleton)
  bool isLoading = true;
  // FirebaseAuth.User hiện tại (null nếu chưa đăng nhập)
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeFirebase(); // Khởi tạo Firebase Core (an toàn trước khi dùng DB/Auth)

    // Lắng nghe trạng thái đăng nhập thay đổi (login/logout)
    _authService.authStateChanges().listen((u) {
      setState(() {
        _currentUser = u; // cập nhật user hiện tại
        isLoading = false; // tắt loading UI
      });

      // Nếu đã đăng nhập -> tải profile + giao dịch
      if (u != null) {
        _fetchProfileData();
        _fetchTransactions();
      } else {
        // Nếu đăng xuất -> clear dữ liệu UI
        setState(() {
          userProfile = null;
          recentTransactions = [];
        });
      }
    });
  }

  // Đảm bảo Firebase.initializeApp() đã chạy (tránh lỗi trên 1 số platform)
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // ====================== DATA: /users/{uid} ======================
  // Lấy thông tin hồ sơ người dùng từ Realtime Database
  Future<void> _fetchProfileData() async {
    if (_currentUser == null) return; // chưa đăng nhập -> bỏ

    try {
      final snapshot = await _database
          .child('users')
          .child(_currentUser!.uid)
          .get(); // GET 1 lần

      if (snapshot.exists) {
        // snapshot.value là Map<dynamic, dynamic> (từ JSON)
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          userProfile = UserProfile(
            name: data['name'] as String? ?? 'Unknown', // fallback an toàn
            phone: data['phone'] as String? ?? 'Unknown',
            points: (data['points'] ?? 0).toString(), // ép sang String
          );
        });
      } else {
        // Nếu chưa có node users/{uid} -> hiển thị mặc định
        setState(() {
          userProfile = UserProfile(
            name: 'Unknown',
            phone: 'Unknown',
            points: '0',
          );
        });
      }
    } catch (e) {
      _showSnack('Lỗi tải profile: $e'); // báo lỗi mềm
    }
  }

  // ================= DATA: /users/{uid}/transactions =================
  // Lấy danh sách giao dịch gần đây (Map -> List<Transaction>)
  Future<void> _fetchTransactions() async {
    if (_currentUser == null) return;

    try {
      final snapshot = await _database
          .child('users')
          .child(_currentUser!.uid)
          .child('transactions')
          .get();

      if (snapshot.exists) {
        // Có thể rỗng -> dùng {} để tránh null
        final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
        // Map entries -> Transaction model
        final transactions = data.entries.map((entry) {
          final t = entry.value as Map<dynamic, dynamic>;
          return Transaction(
            title: t['title'] as String? ?? 'Unknown',
            date: t['date'] as String? ?? 'Unknown',
            amount: t['amount'] as String? ?? '0 VNĐ',
            status: t['status'] as String? ?? 'Unknown',
          );
        }).toList();

        setState(() => recentTransactions = transactions);
      }
    } catch (e) {
      _showSnack('Lỗi tải giao dịch: $e');
    }
  }

  // Helper hiển thị SnackBar nhanh
  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    // Hiển thị loading toàn màn khi còn isLoading
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
        ),
      );
    }

    // Khi đã xong loading, render nội dung
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: Text(
          'Tài khoản',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFEDEDED),
          ),
        ),
        actions: [
          // Icon thông báo (chưa gắn chức năng)
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFFEDEDED)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            _buildProfileHeader(), // Header: avatar + tên/sđt + điểm
            const SizedBox(height: 20),
            _buildMenuSection(), // Menu hành động (lịch sử, quản lý vé, cài đặt, đăng xuất/đăng nhập)
            const SizedBox(height: 20),
            _buildTransactionSection(), // Liệt kê giao dịch gần đây
          ],
        ),
      ),
    );
  }

  // ====================== UI: HEADER PROFILE ======================
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        border: const Border(bottom: BorderSide(color: Color(0xFF222230))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar tròn (tạm dùng icon)
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF8B1E9B),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Tên người dùng
          Text(
            userProfile?.name ?? 'Unknown',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // Số điện thoại
          Text(
            userProfile?.phone ?? 'Unknown',
            style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 12),
          // Huy hiệu điểm thưởng (MoMo Points) — chỉ là ví dụ hiển thị
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B1E9B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFF8B1E9B), size: 18),
                const SizedBox(width: 4),
                Text(
                  '${userProfile?.points ?? '0'} MoMo Points',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================== UI: MENU ACTIONS ========================
  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 1) Lịch sử giao dịch (placeholder)
          _menuItem(Icons.history, 'Lịch sử giao dịch', () {}),

          // 2) 🆕 Quản lý vé: điều hướng tới TicketManagerScreen
          _menuItem(Icons.confirmation_number, 'Quản lý vé', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TicketManagerScreen()),
            );
          }),

          // 3) Ưu đãi cá nhân (placeholder)
          _menuItem(Icons.local_offer, 'Ưu đãi cá nhân', () {}),

          // 4) Cài đặt: mở màn chỉnh profile; nếu quay về có kết quả true -> reload profile
          _menuItem(Icons.settings, 'Cài đặt', () async {
            final res = await Navigator.pushNamed(context, '/edit-profile');
            if (res == true) _fetchProfileData();
          }),

          // 5) Nếu đã đăng nhập -> nút Đăng xuất; ngược lại -> Đăng nhập/Đăng ký
          _currentUser != null
              ? _menuItem(Icons.logout, 'Đăng xuất', () async {
                  await _authService.signOut(); // gọi AuthService để signOut
                  _showSnack('Đã đăng xuất');
                  if (mounted) {
                    // Điều hướng về màn Login và xóa stack route
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                })
              : _menuItem(Icons.login, 'Đăng nhập / Đăng ký', () {
                  // Chưa đăng nhập -> mở màn Login (truyền authService)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(authService: _authService),
                    ),
                  );
                }),
        ],
      ),
    );
  }

  // =================== UI: RECENT TRANSACTIONS ===================
  Widget _buildTransactionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề block
          Text(
            'Giao dịch gần đây',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Nếu rỗng -> hiển thị nhắc
          if (recentTransactions.isEmpty)
            const Text(
              'Không có giao dịch nào',
              style: TextStyle(color: Colors.white70),
            )
          else
            // Duyệt danh sách transactions -> tạo item
            ...recentTransactions.map(_transactionItem).toList(),
        ],
      ),
    );
  }

  // ========================= WIDGET PHỤ =========================
  // 1 item trong menu cài đặt (icon + title + chevron)
  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF8B1E9B)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white38,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  // 1 item giao dịch: trái là tiêu đề/ngày, phải là số tiền/trạng thái
  Widget _transactionItem(Transaction t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cột trái: title + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                t.date,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          // Cột phải: amount + status (màu theo trạng thái)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                t.status,
                style: TextStyle(
                  color: t.status == 'Đã thanh toán'
                      ? const Color(0xFF6DD17A) // xanh: đã trả
                      : const Color(0xFFFFC861), // vàng: chờ xử lý / khác
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
