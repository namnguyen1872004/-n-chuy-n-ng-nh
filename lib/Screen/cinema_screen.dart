import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cinema_about_screen.dart';
import '../models/cinema_model.dart';

/// ---------------------------------------------------------------------------
/// MÀN HÌNH CHỌN RẠP (CinemaScreen)
/// - Nguồn dữ liệu: Firebase Realtime Database path `/cinemas` (stream onValue)
/// - Cách lấy dữ liệu:
///     + Lắng nghe thay đổi realtime bằng `_db.child('cinemas').onValue`
///     + Map `DataSnapshot.value` -> `List<Cinema>` ngay trên stream để build() nhẹ
/// - Tối ưu hiệu năng:
///     + `distinct(...)` để tránh rebuild khi dữ liệu không đổi (so sánh name/address)
///     + Debounce ô tìm kiếm (giảm setState liên tục)
///     + Dùng `SliverList` + `SliverChildBuilderDelegate` cho list dài
///     + Giới hạn memCacheWidth & tắt fade anim của ảnh (mượt hơn, ít jank)
/// - Tương tác:
///     + Gõ tìm kiếm -> lọc theo tên/địa chỉ
///     + Chọn brand chip -> lọc theo brand suy diễn từ tên rạp (cgv/lotte/bhd)
///     + Nhấn item -> push sang `CinemaAboutScreen`
///     + Nút "Tìm đường" -> mở Google Maps chỉ đường tới địa chỉ rạp
/// ---------------------------------------------------------------------------
class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});
  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  // Tham chiếu gốc tới Realtime Database
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ---- UI state (bộ lọc, cờ nhận biết đã có dữ liệu lần đầu, city hiển thị)
  String _search = '';
  String? _brandKey; // null = không lọc theo brand
  bool _hadDataOnce = false; // để phân biệt "đang tải lần đầu" vs "trống"
  final String _city = 'TP.HN';

  // ---- debounce search: tránh setState mỗi ký tự -> giảm rebuild
  Timer? _debounce;
  static const _searchDelay = Duration(milliseconds: 250);

  // ---- realtime stream: đã parse sẵn sang List<Cinema> để build() nhẹ hơn
  late final Stream<List<Cinema>> _cinemas$;

  // ---- danh sách brand filter hiển thị (key hiển thị + icon)
  static const List<Map<String, String>> _brands = [
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
    // Tạo stream realtime từ path '/cinemas'
    // 1) onValue -> DataSnapshot
    // 2) map -> parse snapshot.value thành List<Cinema> (_parseCinemas)
    // 3) distinct -> chỉ emit khi nội dung thực sự đổi (dựa vào name/address)
    _cinemas$ = _db
        .child('cinemas')
        .onValue
        .map((e) => _parseCinemas(e.snapshot.value))
        .distinct((a, b) {
          // So sánh đơn giản: số lượng + name/address theo cùng thứ tự
          if (a.length != b.length) return false;
          for (int i = 0; i < a.length; i++) {
            if (a[i].name != b[i].name || a[i].address != b[i].address) {
              return false;
            }
          }
          return true; // không đổi -> không rebuild
        });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // hủy timer debounce khi rời màn hình
    super.dispose();
  }

  /// Suy ra brand từ tên rạp (client-side): dùng để lọc theo chip
  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('cgv')) return 'cgv';
    if (n.contains('lotte')) return 'lotte';
    if (n.contains('bhd')) return 'bhd';
    return 'other';
  }

  /// Lọc danh sách rạp theo từ khoá (_search) + brand (_brandKey)
  /// - q rỗng và brand null -> trả về nguyên danh sách (không copy thừa)
  /// - trả List không growable để tránh bị sửa đổi ngoài ý muốn
  List<Cinema> _filterCinemas(List<Cinema> src) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty && _brandKey == null) return src;
    return src
        .where((c) {
          final okSearch =
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q);
          final okBrand = (_brandKey == null)
              ? true
              : _detectBrand(c.name) == _brandKey;
          return okSearch && okBrand;
        })
        .toList(growable: false);
  }

  /// Mở Google Maps chỉ đường tới địa chỉ rạp (external app)
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

  /// Parse snapshot.value -> List<Cinema>
  /// - Hỗ trợ 2 case: value là Map (key bất kỳ) hoặc List (mảng)
  /// - Mỗi phần tử map -> `Cinema.fromMap`
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
    // Có thể sort theo tên nếu muốn:
    // out.sort((a,b) => a.name.compareTo(b.name));
    return out;
  }

  /// Debounce cho ô tìm kiếm: chỉ setState sau 250ms không gõ tiếp
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (!mounted) return;
      setState(() => _search = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0F);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // -------- Header: back + title + search + brand chips --------
            SliverToBoxAdapter(child: _header(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Placeholder tiêu đề trước khi có data realtime (giữ layout)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: const [
                    _TitleSkeleton(), // khối giả để giữ vị trí tiêu đề
                    Spacer(),
                    _CityPill(city: 'TP.HN'),
                  ],
                ),
              ),
            ),

            // -------- Stream danh sách rạp (đã parse sẵn ra List<Cinema>) --------
            StreamBuilder<List<Cinema>>(
              stream: _cinemas$,
              builder: (context, snap) {
                // Lần đầu chờ dữ liệu -> hiện loader to
                if (snap.connectionState == ConnectionState.waiting &&
                    !_hadDataOnce) {
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

                // Có lỗi stream -> thông báo
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

                // Lấy data (có thể rỗng)
                final data = snap.data ?? const <Cinema>[];
                if (!_hadDataOnce && data.isNotEmpty) _hadDataOnce = true;

                // Lọc theo từ khoá & brand
                final filtered = _filterCinemas(data);
                final title = 'Rạp đề xuất (${filtered.length})';

                // Case: không có bất kỳ rạp nào từ server
                if (data.isEmpty) {
                  return SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _TitleRow(title: title, city: _city),
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Không có rạp khả dụng!',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ]),
                  );
                }

                // Case: có rạp nhưng lọc xong trống
                if (filtered.isEmpty) {
                  return SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _TitleRow(title: title, city: _city),
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Không có rạp khớp bộ lọc hiện tại',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ]),
                  );
                }

                // ---- Danh sách rạp hiệu quả: build theo index (SliverChildBuilderDelegate)
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Hàng đầu tiên là thanh tiêu đề thật (đã biết số lượng)
                      if (index == 0) {
                        return _TitleRow(title: title, city: _city);
                      }
                      // Các hàng tiếp theo là card rạp
                      final cinema = filtered[index - 1];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _CinemaCard(
                          cinema: cinema,
                          onTap: () {
                            // Điều hướng sang màn "Giới thiệu rạp"
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CinemaAboutScreen(cinema: cinema),
                              ),
                            );
                          },
                          onDirection: () => _openDirections(cinema.address),
                        ),
                      );
                    },
                    childCount: filtered.length + 1, // +1 cho title row
                    addAutomaticKeepAlives: false, // giảm overhead
                    addRepaintBoundaries: true, // tách repaint cho từng item
                    addSemanticIndexes: false, // bớt index semantics
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER (gradient + back + title + search + brand chips)
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
            // Thanh top: back + 2 icon tròn
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
                const _CircleIcon(icon: Icons.chat_bubble_outline),
                const SizedBox(width: 8),
                const _CircleIcon(icon: Icons.close),
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
            _searchField(), // Ô tìm kiếm (debounce)
            const SizedBox(height: 12),
            _brandChips(), // Chips brand để lọc nhanh
          ],
        ),
      ),
    );
  }

  /// Ô tìm kiếm với style tối
  Widget _searchField() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(28),
    ),
    child: TextField(
      onChanged: _onSearchChanged, // debounce 250ms
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

  /// Hàng chips brand (CGV/Lotte/BHD)
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
                // Ô icon brand
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B1E9B) // viền tím khi chọn
                          : const Color(0xFF222230),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CachedNetworkImage(
                      imageUrl: item['icon']!,
                      fit: BoxFit.contain,
                      memCacheWidth: 256, // ảnh nhỏ, tiết kiệm RAM
                      fadeInDuration: Duration.zero, // tắt animation để mượt
                      fadeOutDuration: Duration.zero,
                      filterQuality: FilterQuality.low,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.local_movies, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Tên brand
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
}

// ----------------- Stateless helper widgets (const-friendly)

/// Nút icon tròn trang trí ở header
class _CircleIcon extends StatelessWidget {
  final IconData icon;
  const _CircleIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2A),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Color(0xFFEDEDED)),
    );
  }
}

/// Pill hiển thị thành phố ở tiêu đề phụ
class _CityPill extends StatelessWidget {
  final String city;
  const _CityPill({required this.city});
  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}

/// Hàng tiêu đề thật (sau khi có dữ liệu) gồm title đếm số rạp + city pill
class _TitleRow extends StatelessWidget {
  final String title;
  final String city;
  const _TitleRow({required this.title, required this.city});
  @override
  Widget build(BuildContext context) {
    return Padding(
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
          _CityPill(city: city),
        ],
      ),
    );
  }
}

/// Card 1 rạp: ảnh + tên + địa chỉ + nút "Tìm đường"
class _CinemaCard extends StatelessWidget {
  final Cinema cinema;
  final VoidCallback onTap;
  final VoidCallback onDirection;
  const _CinemaCard({
    required this.cinema,
    required this.onTap,
    required this.onDirection,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap, // mở màn CinemaAboutScreen
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
            // Hàng trên: ảnh logo rạp + tên + địa chỉ + chevron
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: cinema.imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    memCacheWidth: 200, // ảnh nhỏ, đủ sắc nét
                    fadeInDuration: Duration.zero, // tắt anim -> mượt
                    fadeOutDuration: Duration.zero,
                    filterQuality: FilterQuality.low, // lọc nhẹ
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
                      // Tên rạp
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
                      // Địa chỉ rạp
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
            // Nút "Tìm đường" -> gọi onDirection mở Maps
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

/// Skeleton giữ layout tiêu đề trước realtime (tránh nhảy layout)
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
