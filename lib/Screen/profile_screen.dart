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
    // listen to auth changes and load profile when signed in
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

  // Khởi tạo Firebase
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // Lấy dữ liệu profile từ Firebase
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải profile: $e')));
    }
  }

  // Lấy danh sách giao dịch từ Firebase
  Future<void> _fetchTransactions() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _database
          .child('users')
          .child(_currentUser!.uid)
          .child('transactions')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final transactions = data.entries.map((entry) {
            final transactionData = entry.value as Map<dynamic, dynamic>;
            return Transaction(
              title: transactionData['title'] as String? ?? 'Unknown',
              date: transactionData['date'] as String? ?? 'Unknown',
              amount: transactionData['amount'] as String? ?? '0 VNĐ',
              status: transactionData['status'] as String? ?? 'Unknown',
            );
          }).toList();
          setState(() {
            recentTransactions = transactions;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải giao dịch: $e')));
    }
  }

  // Hiển thị bottom sheet cho Đăng nhập / Đăng ký
  // (Moved to dedicated screens) Previously we showed a bottom sheet here; we now navigate to Login/Register screens.

  @override
  Widget build(BuildContext context) {
    print("userProfile: $userProfile, recentTransactions: $recentTransactions");
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        body: const Center(
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
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFFEDEDED)),
            onPressed: () {
              // TODO: Mở thông báo
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Phần đầu: Thông tin cá nhân
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151521),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF222230)),
                ),
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
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF8B1E9B),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF8B1E9B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tên và số điện thoại
                  Text(
                    userProfile?.name ?? 'Unknown',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEDEDED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userProfile?.phone ?? 'Unknown',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: const Color(0xFFB9B9C3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Điểm MoMo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF8B1E9B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFF8B1E9B),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${userProfile?.points ?? '0'} MoMo Points',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEDEDED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu chính: Các tùy chọn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Lịch sử giao dịch',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở lịch sử giao dịch')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.confirmation_number,
                    title: 'Quản lý vé',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở quản lý vé')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.local_offer,
                    title: 'Ưu đãi cá nhân',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở ưu đãi cá nhân')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Cài đặt',
                    onTap: () async {
                      // Navigate to Edit Profile screen; refresh profile on successful save
                      final res = await Navigator.pushNamed(
                        context,
                        '/edit-profile',
                      );
                      if (res == true) {
                        await _fetchProfileData();
                      }
                    },
                  ),
                  // If user is signed in show logout, otherwise show login/register entry
                  _currentUser != null
                      ? _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Đăng xuất',
                          onTap: () async {
                            await _authService.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã đăng xuất')),
                            );
                            // After sign out navigate to Login and clear history
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          },
                        )
                      : _buildMenuItem(
                          icon: Icons.login,
                          title: 'Đăng nhập / Đăng ký',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoginScreen(authService: _authService),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Phần dưới: Giao dịch gần đây
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giao dịch gần đây',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEDEDED),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recentTransactions.map(
                    (transaction) => _buildTransactionItem(transaction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget cho menu item
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222230)),
                  ),
                  child: const Icon(Icons.history, color: Color(0xFF8B1E9B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFEDEDED),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFFB9B9C3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget cho giao dịch gần đây
  Widget _buildTransactionItem(Transaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF222230)),
            ),
            child: const Icon(
              Icons.confirmation_number,
              color: Color(0xFF8B1E9B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFEDEDED),
                  ),
                ),
                Text(
                  transaction.date,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: const Color(0xFFB9B9C3),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.amount,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEDEDED),
                ),
              ),
              Text(
                transaction.status,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: transaction.status == 'Đã thanh toán'
                      ? const Color(0xFF6DD17A)
                      : const Color(0xFFFFC861),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Small widget that contains Login / Register forms used in the bottom sheet
class _AuthForms extends StatefulWidget {
  final VoidCallback onCompleted;
  final AuthService authService;

  const _AuthForms({
    required this.onCompleted,
    required this.authService,
    Key? key,
  }) : super(key: key);

  @override
  State<_AuthForms> createState() => _AuthFormsState();
}

class _AuthFormsState extends State<_AuthForms> {
  bool _isRegister = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isRegister) {
        await widget.authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đăng ký thành công')));
      } else {
        await widget.authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công')));
      }
      widget.onCompleted();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isRegister ? 'Đăng ký' : 'Đăng nhập',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Đã có tài khoản? Đăng nhập'
                    : 'Chưa có tài khoản? Đăng ký',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_isRegister)
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
              if (_isRegister) const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'Mật khẩu ít nhất 6 ký tự'
                    : null,
              ),
              if (_isRegister) const SizedBox(height: 8),
              if (_isRegister)
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isRegister ? 'Đăng ký' : 'Đăng nhập'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
