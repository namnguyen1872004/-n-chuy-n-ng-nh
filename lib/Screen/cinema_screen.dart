import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart'; // ⬅️ thêm

// ✅ Import đúng file movie_selection_screen.dart
import './movie_selection_screen.dart';

import '../models/cinema_model.dart';
import '../models/snack_model.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<Cinema> cinemas = [];
  String searchQuery = '';
  bool isLoading = true;

  // UI state
  final Set<int> favorites = {};
  String city = 'TP.HN';

  // key để biết đang lọc theo brand nào (null = không lọc)
  String? selectedBrandKey;

  // === Brand chips (3 rạp phổ biến) ===
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
    fetchCinemasFromFirebase();
  }

  // ========= URL Launcher: mở Google Maps chỉ đường theo địa chỉ =========
  Future<void> _openDirections(String address) async {
    if (address.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có địa chỉ để tìm đường')),
      );
      return;
    }
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps')));
    }
  }
  // ======================================================================

  // Parse snacks -> List<Snack> an toàn
  List<Snack> _parseSnacks(dynamic raw) {
    final List<Snack> result = [];
    if (raw == null) return result;

    if (raw is List) {
      for (final item in raw) {
        if (item == null) continue;
        if (item is Snack) {
          result.add(item);
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          result.add(
            Snack(
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              price: double.tryParse('${m['price'] ?? 0}') ?? 0.0,
              imageUrl: (m['imageUrl'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
            ),
          );
        }
      }
      return result;
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final v in map.values) {
        if (v == null) continue;
        if (v is Snack) {
          result.add(v);
        } else if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          result.add(
            Snack(
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              price: double.tryParse('${m['price'] ?? 0}') ?? 0.0,
              imageUrl: (m['imageUrl'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
            ),
          );
        }
      }
    }
    return result;
  }

  Future<void> fetchCinemasFromFirebase() async {
    try {
      final snapshot = await _database.child('cinemas').get();
      if (!mounted) return;

      if (!snapshot.exists) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy dữ liệu rạp trên Firebase'),
          ),
        );
        return;
      }

      final raw = snapshot.value;
      final List<Cinema> loaded = [];

      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        for (final entry in data.entries) {
          final m = Map<String, dynamic>.from(entry.value);
          loaded.add(
            Cinema(
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              address: (m['address'] ?? '').toString(),
              distance: double.tryParse('${m['distance'] ?? 0}') ?? 0.0,
              openHours: (m['openHours'] ?? '').toString(),
              imageUrl: (m['imageUrl'] ?? '').toString(),
              snacks: _parseSnacks(m['snacks']),
            ),
          );
        }
      } else if (raw is List) {
        for (final e in raw) {
          if (e == null) continue;
          final m = Map<String, dynamic>.from(e as Map);
          loaded.add(
            Cinema(
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              address: (m['address'] ?? '').toString(),
              distance: double.tryParse('${m['distance'] ?? 0}') ?? 0.0,
              openHours: (m['openHours'] ?? '').toString(),
              imageUrl: (m['imageUrl'] ?? '').toString(),
              snacks: _parseSnacks(m['snacks']),
            ),
          );
        }
      } else {
        throw Exception('Dữ liệu không hợp lệ trong Firebase.');
      }

      setState(() {
        cinemas = loaded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
    }
  }

  // Suy ra brand từ tên rạp
  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('cgv')) return 'cgv';
    if (n.contains('lotte')) return 'lotte';
    if (n.contains('bhd')) return 'bhd';
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = cinemas.where((c) {
      final q = searchQuery.toLowerCase();
      final matchesSearch =
          c.name.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
      final matchesBrand = selectedBrandKey == null
          ? true
          : _detectBrand(c.name) == selectedBrandKey;
      return matchesSearch && matchesBrand;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFAD0E9), Color(0xFFFDE2F3)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  top: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const Spacer(),
                        _circleIcon(Icons.chat_bubble_outline),
                        const SizedBox(width: 8),
                        _circleIcon(Icons.close),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chọn theo rạp',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _searchField(),
                    const SizedBox(height: 12),
                    _brandChips(),
                  ],
                ),
              ),
            ),
          ),

          // Section title + city pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Rạp đề xuất (${filtered.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _cityPill(), // ⬅️ hiển thị theo biến city
              ],
            ),
          ),

          // List cinemas
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemBuilder: (_, i) => _cinemaCard(
                      index: i,
                      cinema: filtered[i],
                      onTap: () {
                        if (!mounted) return;
                        // ✅ Điều hướng đúng: truyền tham số 'cinema'
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovieSelectionScreen(
                              cinema: filtered[i], // ✅ Đúng tham số
                            ),
                          ),
                        );
                      },
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: filtered.length,
                  ),
          ),
        ],
      ),
    );
  }

  // ===== widgets con =====
  Widget _circleIcon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, size: 18, color: Colors.black87),
  );

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: const InputDecoration(
          hintText: 'Tìm rạp phim...',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _brandChips() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 6),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = _brands[i];
          final isSelected = selectedBrandKey == item['key'];
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedBrandKey = isSelected ? null : item['key'];
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF4AA6)
                          : Colors.black12,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: CachedNetworkImage(
                      imageUrl: item['icon']!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.local_activity),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    item['name']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: isSelected
                          ? const Color(0xFFFF4AA6)
                          : Colors.black87,
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

  Widget _cityPill() {
    return InkWell(
      onTap: () {}, // có thể mở dialog chọn thành phố nếu muốn
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.pink.shade50,
          border: Border.all(color: const Color(0xFFFF85C1)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Color(0xFFFF4AA6)),
            const SizedBox(width: 6),
            Text(
              city, // ⬅️ dùng biến city thay vì text cứng
              style: const TextStyle(
                color: Color(0xFFFF4AA6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cinemaCard({
    required int index,
    required Cinema cinema,
    required VoidCallback onTap,
  }) {
    final isFav = favorites.contains(index);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
                        const Icon(Icons.local_movies, size: 36),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cinema.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cinema.distance > 0
                            ? 'Khoảng cách: ${cinema.distance.toStringAsFixed(1)} km'
                            : 'Bạn vừa chọn rạp này',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        if (isFav) {
                          favorites.remove(index);
                        } else {
                          favorites.add(index);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav
                              ? const Color(0xFFFF4AA6)
                              : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 56),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(text: cinema.address),
                        const TextSpan(text: '   '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => _openDirections(
                              cinema.address,
                            ), // ✅ mở Google Maps
                            child: const Text(
                              'Tìm đường',
                              style: TextStyle(
                                color: Color(0xFFFF4AA6),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
