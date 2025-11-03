import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cinema_about_screen.dart';
import '../models/cinema_model.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});
  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ---- UI state
  String _search = '';
  String? _brandKey; // null = no filter
  bool _hadDataOnce = false;
  final String _city = 'TP.HN';

  // ---- debounce search
  Timer? _debounce;
  static const _searchDelay = Duration(milliseconds: 250);

  // ---- realtime stream (đã parse sẵn)
  late final Stream<List<Cinema>> _cinemas$;

  // ---- brands
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
    // Parse snapshot -> List<Cinema> NGAY TRÊN STREAM (giảm work trong build)
    _cinemas$ = _db
        .child('cinemas')
        .onValue
        .map((e) => _parseCinemas(e.snapshot.value))
        // distinct theo số lượng + tên (tránh rebuild khi data không đổi)
        .distinct((a, b) {
          if (a.length != b.length) return false;
          for (int i = 0; i < a.length; i++) {
            if (a[i].name != b[i].name || a[i].address != b[i].address) {
              return false;
            }
          }
          return true;
        });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('cgv')) return 'cgv';
    if (n.contains('lotte')) return 'lotte';
    if (n.contains('bhd')) return 'bhd';
    return 'other';
  }

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
    // Optional: out.sort((a,b) => a.name.compareTo(b.name));
    return out;
  }

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
            SliverToBoxAdapter(child: _header(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Placeholder tiêu đề (sẽ thay khi có data)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: const [
                    _TitleSkeleton(),
                    Spacer(),
                    _CityPill(city: 'TP.HN'),
                  ],
                ),
              ),
            ),

            // Danh sách rạp realtime (đã parse sẵn)
            StreamBuilder<List<Cinema>>(
              stream: _cinemas$,
              builder: (context, snap) {
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

                final data = snap.data ?? const <Cinema>[];
                if (!_hadDataOnce && data.isNotEmpty) _hadDataOnce = true;

                final filtered = _filterCinemas(data);
                final title = 'Rạp đề xuất (${filtered.length})';

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

                // --- Danh sách hiệu quả: SliverChildBuilderDelegate
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0) {
                        return _TitleRow(title: title, city: _city);
                      }
                      final cinema = filtered[index - 1];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _CinemaCard(
                          cinema: cinema,
                          onTap: () {
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
                    childCount: filtered.length + 1,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
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

  // ---------------- HEADER
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
            _searchField(),
            const SizedBox(height: 12),
            _brandChips(),
          ],
        ),
      ),
    );
  }

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
                      memCacheWidth: 256,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      filterQuality: FilterQuality.low,
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
}

// ----------------- Stateless helper widgets (const-friendly)

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
                    memCacheWidth: 200,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    filterQuality: FilterQuality.low,
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

/// Skeleton giữ layout tiêu đề trước realtime
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
