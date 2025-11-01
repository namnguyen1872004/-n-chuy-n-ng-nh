import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import './movie_selection_screen.dart';
import '../models/cinema_model.dart';

/// Màn hình chọn rạp
class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  /// Tham chiếu gốc vào Realtime Database
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Danh sách rạp lấy từ Firebase
  List<Cinema> cinemas = [];

  /// Trạng thái UI
  String searchQuery = '';
  bool isLoading = true;
  String? selectedBrandKey; // null = không lọc
  String city = 'TP.HN';

  /// Danh sách brand (chỉ dùng để hiển thị filter trên UI)
  /// 3 brand phổ biến: CGV, Lotte, BHD
  final List<Map<String, String>> _brands = const [
    {
      'key': 'cgv',
      'name': 'CGV',
      'icon':
          'https://tenpack.com.vn/wp-content/uploads/2020/05/cgv-cinema-logo.jpg',
    },
    {
      'key': 'lotte',
      'name': 'Lotte',
      'icon':
          'https://doanhnghiepfdi.vn/public/upload/company/lote_400x400_669331188.webp',
    },
    {
      'key': 'bhd',
      'name': 'BHD',
      'icon':
          'https://upload.wikimedia.org/wikipedia/commons/5/57/Logo_BHD_Star_Cineplex.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCinemas(); // tải dữ liệu rạp khi mở màn hình
  }

  // ---------------------------------------------------------------------------
  // 1) DATA: Lấy danh sách rạp từ Firebase (/cinemas)
  // ---------------------------------------------------------------------------
  Future<void> _fetchCinemas() async {
    try {
      final snapshot = await _database.child('cinemas').get();
      if (!mounted) return;

      if (!snapshot.exists) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy dữ liệu rạp')),
        );
        return;
      }

      // snapshot.value có thể là Map<dynamic,dynamic>
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Cinema> loaded = data.values
          .map((v) => Cinema.fromMap(Map<String, dynamic>.from(v)))
          .toList();

      setState(() {
        cinemas = loaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // 2) ACTION: Mở Google Maps “Tìm đường” đến địa chỉ rạp
  // ---------------------------------------------------------------------------
  Future<void> _openDirections(String address) async {
    if (address.trim().isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}&travelmode=driving',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps')));
    }
  }

  // ---------------------------------------------------------------------------
  // 3) HELPER: Suy ra brand từ tên rạp (để dùng khi lọc theo brand)
  // ---------------------------------------------------------------------------
  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('cgv')) return 'cgv';
    if (n.contains('lotte')) return 'lotte';
    if (n.contains('bhd')) return 'bhd';
    return 'other';
  }

  // ---------------------------------------------------------------------------
  // 4) UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Lọc danh sách rạp theo từ khóa & brand
    final filtered = cinemas.where((c) {
      final q = searchQuery.toLowerCase();
      final matchSearch =
          c.name.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
      final matchBrand = selectedBrandKey == null
          ? true
          : _detectBrand(c.name) == selectedBrandKey;
      return matchSearch && matchBrand;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _headerSection(context),
              const SizedBox(height: 8),
              // Tiêu đề + chip thành phố
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Rạp đề xuất (${filtered.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEDEDED),
                      ),
                    ),
                    const Spacer(),
                    _cityPill(),
                  ],
                ),
              ),
              // Danh sách rạp
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _cinemaCard(
                    cinema: filtered[i],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MovieSelectionScreen(cinema: filtered[i]),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header gồm: nút back, tiêu đề, ô tìm kiếm và dải brand chips
  Widget _headerSection(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF11111A), Color(0xFF151521)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Color(0xFFEDEDED),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              _circleIcon(Icons.chat_bubble_outline),
              const SizedBox(width: 8),
              _circleIcon(Icons.close),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Chọn theo rạp',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEDEDED),
            ),
          ),
          const SizedBox(height: 12),
          _searchField(),
          const SizedBox(height: 12),
          _brandChips(context),
        ],
      ),
    ),
  );

  /// Icon tròn nhỏ (trang trí)
  Widget _circleIcon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Color(0xFF1E1E2A),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 18, color: const Color(0xFFEDEDED)),
  );

  /// Ô tìm kiếm rạp
  Widget _searchField() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(28),
    ),
    child: TextField(
      onChanged: (v) => setState(() => searchQuery = v),
      style: const TextStyle(color: Color(0xFFEDEDED)),
      decoration: const InputDecoration(
        hintText: 'Tìm rạp phim...',
        hintStyle: TextStyle(color: Color(0xFFB9B9C3)),
        prefixIcon: Icon(Icons.search, color: Color(0xFFB9B9C3)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );

  /// Dải brand chips (đã tinh chỉnh kích thước để không overflow)
  Widget _brandChips(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(0.9, 1.3);
    final double totalHeight = 96 + (textScale - 1.0) * 6;

    return SizedBox(
      height: totalHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 6),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final item = _brands[i];
          final isSelected = selectedBrandKey == item['key'];
          return GestureDetector(
            onTap: () => setState(
              () => selectedBrandKey = isSelected ? null : item['key'],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B1E9B)
                          : const Color(0xFF222230),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CachedNetworkImage(
                      imageUrl: item['icon']!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    item['name']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.0,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF8B1E9B)
                          : const Color(0xFFEDEDED),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Chip TP đang chọn (giả lập)
  Widget _cityPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF8B1E9B)),
    ),
    child: const Row(
      children: [
        Icon(Icons.location_on, size: 16, color: Color(0xFF8B1E9B)),
        SizedBox(width: 6),
        Text(
          'TP.HN',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  /// Card 1 rạp + nút “Tìm đường”
  Widget _cinemaCard({required Cinema cinema, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151521),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF222230)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: cinema.imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.local_movies, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cinema.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFEDEDED),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cinema.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB9B9C3),
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFB9B9C3)),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openDirections(cinema.address),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B1E9B)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions, size: 16, color: Color(0xFF8B1E9B)),
                    SizedBox(width: 6),
                    Text(
                      'Tìm đường',
                      style: TextStyle(
                        color: Color(0xFFEDEDED),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
