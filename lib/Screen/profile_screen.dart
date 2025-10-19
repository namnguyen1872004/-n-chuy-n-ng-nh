import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' as fb;
import '../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final fb.DatabaseReference _database = fb.FirebaseDatabase.instance.ref();
  UserProfile? userProfile;
  List<Transaction> recentTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _fetchProfileData();
    _fetchTransactions();
  }

  // Khởi tạo Firebase
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // Lưu dữ liệu mẫu lên Firebase (chạy một lần) - Comment nếu đã có dữ liệu
  /*
  Future<void> _uploadSampleData() async {
    try {
      await _database.child('users/user1/profile').set({
        'name': 'Nguyễn Hoài Nam',
        'phone': '0941969269',
        'points': '1500',
      });

      await _database.child('users/user1/transactions').set({
        'transaction1': {
          'title': 'Vé CGV - Mưa đỏ',
          'date': '07/10/2025',
          'amount': '150.000 VNĐ',
          'status': 'Đã thanh toán',
        },
        'transaction2': {
          'title': 'Combo bắp nước Lotte',
          'date': '05/10/2025',
          'amount': '80.000 VNĐ',
          'status': 'Hoàn thành',
        },
        'transaction3': {
          'title': 'Vé BHD - F1',
          'date': '03/10/2025',
          'amount': '120.000 VNĐ',
          'status': 'Đã hủy',
        },
      });
      print('Sample data uploaded successfully!');
    } catch (e) {
      print('Error uploading sample data: $e');
    }
  }
  */

  // Lấy dữ liệu profile từ Firebase
  Future<void> _fetchProfileData() async {
    try {
      final snapshot = await _database.child('users/user1/profile').get();
      print("Profile snapshot exists: ${snapshot.exists}"); // Debug
      print("Profile snapshot value: ${snapshot.value}"); // Debug
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          userProfile = UserProfile(
            name: data['name'] as String? ?? 'Unknown',
            phone: data['phone'] as String? ?? 'Unknown',
            points: data['points'] as String? ?? '0',
          );
          isLoading = false;
        });
      } else {
        setState(() {
          userProfile = UserProfile(
            name: 'Unknown',
            phone: 'Unknown',
            points: '0',
          );
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy dữ liệu profile, tạo mặc định'),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải profile: $e')));
    }
  }

  // Lấy danh sách giao dịch từ Firebase
  Future<void> _fetchTransactions() async {
    try {
      final snapshot = await _database.child('users/user1/transactions').get();
      print("Transactions snapshot exists: ${snapshot.exists}"); // Debug
      print("Transactions snapshot value: ${snapshot.value}"); // Debug
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
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy giao dịch')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải giao dịch: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "userProfile: $userProfile, recentTransactions: $recentTransactions",
    ); // Debug
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Tài khoản',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
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
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userProfile?.phone ?? 'Unknown',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.grey[600],
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
                      color: const Color(0xFFF5F5F5),
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
                            color: const Color(0xFF8B1E9B),
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
                      // TODO: Mở lịch sử giao dịch
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở lịch sử giao dịch')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.confirmation_number,
                    title: 'Quản lý vé',
                    onTap: () {
                      // TODO: Mở quản lý vé
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở quản lý vé')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.local_offer,
                    title: 'Ưu đãi cá nhân',
                    onTap: () {
                      // TODO: Mở ưu đãi
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở ưu đãi cá nhân')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Cài đặt',
                    onTap: () {
                      // TODO: Mở cài đặt
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở cài đặt')),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Đăng xuất',
                    onTap: () {
                      // TODO: Đăng xuất
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đăng xuất')),
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
                      color: Colors.black,
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
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF8B1E9B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B1E9B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
                    color: Colors.black,
                  ),
                ),
                Text(
                  transaction.date,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey[600],
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
                  color: Colors.black,
                ),
              ),
              Text(
                transaction.status,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: transaction.status == 'Đã thanh toán'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
