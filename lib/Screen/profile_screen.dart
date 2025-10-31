import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' as fb;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final fb.DatabaseReference _database = fb.FirebaseDatabase.instance.ref();
  final AuthService _authService = AuthService();
  UserProfile? userProfile;
  List<Transaction> recentTransactions = [];
  bool isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _authService.authStateChanges().listen((u) {
      setState(() {
        _currentUser = u;
        isLoading = false;
      });
      if (u != null) {
        _fetchProfileData();
        _fetchTransactions();
      } else {
        setState(() {
          userProfile = null;
          recentTransactions = [];
        });
      }
    });
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // --- Lấy dữ liệu người dùng từ Firebase ---
  Future<void> _fetchProfileData() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _database
          .child('users')
          .child(_currentUser!.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          userProfile = UserProfile(
            name: data['name'] as String? ?? 'Unknown',
            phone: data['phone'] as String? ?? 'Unknown',
            points: (data['points'] ?? 0).toString(),
          );
        });
      } else {
        setState(() {
          userProfile = UserProfile(
            name: 'Unknown',
            phone: 'Unknown',
            points: '0',
          );
        });
      }
    } catch (e) {
      _showSnack('Lỗi tải profile: $e');
    }
  }

  // --- Lấy danh sách giao dịch ---
  Future<void> _fetchTransactions() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _database
          .child('users')
          .child(_currentUser!.uid)
          .child('transactions')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
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

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
        ),
      );
    }

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
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildMenuSection(),
            const SizedBox(height: 20),
            _buildTransactionSection(),
          ],
        ),
      ),
    );
  }

  // --- Header thông tin người dùng ---
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
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF8B1E9B),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            userProfile?.name ?? 'Unknown',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userProfile?.phone ?? 'Unknown',
            style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 12),
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

  // --- Menu ---
  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _menuItem(Icons.history, 'Lịch sử giao dịch', () {}),
          _menuItem(Icons.confirmation_number, 'Quản lý vé', () {}),
          _menuItem(Icons.local_offer, 'Ưu đãi cá nhân', () {}),
          _menuItem(Icons.settings, 'Cài đặt', () async {
            final res = await Navigator.pushNamed(context, '/edit-profile');
            if (res == true) _fetchProfileData();
          }),
          _currentUser != null
              ? _menuItem(Icons.logout, 'Đăng xuất', () async {
                  await _authService.signOut();
                  _showSnack('Đã đăng xuất');
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                })
              : _menuItem(Icons.login, 'Đăng nhập / Đăng ký', () {
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

  // --- Giao dịch gần đây ---
  Widget _buildTransactionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giao dịch gần đây',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (recentTransactions.isEmpty)
            const Text(
              'Không có giao dịch nào',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...recentTransactions.map(_transactionItem).toList(),
        ],
      ),
    );
  }

  // --- Widget con ---
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
                      ? const Color(0xFF6DD17A)
                      : const Color(0xFFFFC861),
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
