import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cinema_about_screen.dart'; // ✅ Màn “Giới thiệu rạp”
import '../models/cinema_model.dart'; // ✅ Model Cinema

/// ===============================================================
/// MÀN HÌNH CHỌN RẠP (CinemaScreen)
/// - Header: back + title + ô tìm kiếm + dải brand filter
/// - Body: danh sách rạp realtime từ Firebase (/cinemas)
/// - Có thể lọc theo từ khoá & brand
/// - Nhấn item → sang CinemaAboutScreen
/// ===============================================================
class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  // Firebase
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // State hiển thị
  String _search = '';
  String? _brandKey; // null = không lọc
  bool _hadDataOnce = false; // để phân biệt “đang tải lần đầu” hay “trống”
  String _city = 'TP.HN'; // demo: city pill (chưa lọc server)

  // Debounce cho ô tìm kiếm
  Timer? _debounce;
  static const _searchDelay = Duration(milliseconds: 250);

  // Danh sách brand hiển thị
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
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Suy ra brand từ tên rạp (để filter nhanh phía client)
  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('cgv')) return 'cgv';
    if (n.contains('lotte')) return 'lotte';
    if (n.contains('bhd')) return 'bhd';
    return 'other';
  }

  /// Lọc danh sách rạp theo từ khoá + brand
  List<Cinema> _filterCinemas(List<Cinema> src) {
    final q = _search.trim().toLowerCase();
    return src.where((c) {
      final okSearch =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
      final okBrand = (_brandKey == null)
          ? true
          : _detectBrand(c.name) == _brandKey;
      return okSearch && okBrand;
    }).toList();
  }

  /// Mở Google Maps “Tìm đường” tới địa chỉ rạp
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

  /// Parse snapshot.value → List<Cinema> (hỗ trợ Map/List)
  List<Cinema> _parseCinemas(dynamic raw) {
    final out = <Cinema>[];
    if (raw is Map) {
      final mm = Map<String, dynamic>.from(raw);
      for (final v in mm.values) {
        if (v is Map) out.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
      }
    } else if (raw is List) {
      for (final v in raw) {
        if (v is Map) out.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
      }
    }
    return out;
    // Có thể sort theo tên nếu muốn: out..sort((a,b) => a.name.compareTo(b.name));
  }

  /// Debounce khi gõ tìm kiếm (tránh rebuild liên tục)
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (!mounted) return;
      setState(() => _search = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ---------- Header: back + title + search + brand chips ----------
            SliverToBoxAdapter(child: _header(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ---------- Tiêu đề + chip city ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    // Số lượng rạp hiển thị sẽ set sau (khi có snapshot)
                    const _TitleSkeleton(), // chỗ giữ layout, thay bằng real sau
                    const Spacer(),
                    _cityPill(_city),
                  ],
                ),
              ),
            ),

            // ---------- Danh sách rạp realtime ----------
            StreamBuilder<DatabaseEvent>(
              stream: _db.child('cinemas').onValue,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !_hadDataOnce) {
                  // Lần đầu: hiển thị loader lớn
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(50),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B1E9B),
                        ),
                      ),
                    ),
                  );
                }

                if (snap.hasError) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Không tải được danh sách rạp.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }

                final raw = snap.data?.snapshot.value;
                final cinemas = _parseCinemas(raw);
                if (!_hadDataOnce && cinemas.isNotEmpty) _hadDataOnce = true;

                final filtered = _filterCinemas(cinemas);

                // Cập nhật tiêu đề có số lượng
                final title = 'Rạp đề xuất (${filtered.length})';

                // Ghép lại tiêu đề (thay skeleton ở trên)
                final titleBar = SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                        const Spacer(),
                        _cityPill(_city),
                      ],
                    ),
                  ),
                );

                if (cinemas.isEmpty) {
                  return SliverList.list(
                    children: [
                      titleBar,
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Không có rạp khả dụng!',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (filtered.isEmpty) {
                  return SliverList.list(
                    children: [
                      titleBar,
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Không có rạp khớp bộ lọc hiện tại',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Danh sách rạp sau khi lọc
                return SliverList.separated(
                  itemCount:
                      filtered.length +
                      1, // +1 để chèn lại titleBar (đã biết số)
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    if (i == 0) return titleBar; // hàng đầu là tiêu đề thực tế
                    final cinema = filtered[i - 1];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: _cinemaCard(
                        cinema: cinema,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CinemaAboutScreen(cinema: cinema),
                            ),
                          );
                        },
                        onDirection: () => _openDirections(cinema.address),
                      ),
                    );
                  },
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  // ------------------------- HEADER -------------------------
  Widget _header(BuildContext context) {
    return Container(
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
            _brandChips(),
          ],
        ),
      ),
    );
  }

  // Nút icon tròn trang trí
  Widget _circleIcon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Color(0xFF1E1E2A),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 18, color: Color(0xFFEDEDED)),
  );

  // Ô tìm kiếm với debounce
  Widget _searchField() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(28),
    ),
    child: TextField(
      onChanged: _onSearchChanged,
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

  // Chips chọn brand
  Widget _brandChips() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 6),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final item = _brands[i];
          final isSelected = _brandKey == item['key'];
          return GestureDetector(
            onTap: () =>
                setState(() => _brandKey = isSelected ? null : item['key']),
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
                      memCacheWidth: 256, // ✅ tiết kiệm RAM
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.local_movies, color: Colors.white54),
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

  // Pill thành phố (demo)
  Widget _cityPill(String city) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF8B1E9B)),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on, size: 16, color: Color(0xFF8B1E9B)),
        const SizedBox(width: 6),
        Text(
          city,
          style: const TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  // Card 1 rạp
  Widget _cinemaCard({
    required Cinema cinema,
    required VoidCallback onTap,
    required VoidCallback onDirection,
  }) {
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
                    memCacheWidth: 200, // ✅ nhẹ máy
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF222230)),
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
              onTap: onDirection,
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

/// Skeleton nhỏ để giữ layout tiêu đề trước khi có realtime data
class _TitleSkeleton extends StatelessWidget {
  const _TitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
