import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ dùng launchUrl theo chuẩn pub.dev

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

  // ========= URL Launcher:  =========
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

    //  kiểm tra trực tiếp kết quả launchUrl
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps')));
    }
  }
  // ============================================================================

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
      backgroundColor: const Color(0xFF0B0B0F),
      body: Column(
        children: [
          // Header gradient (tối)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF11111A), Color(0xFF151521)],
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
                            color: Color(0xFFEDEDED),
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
                        color: Color(0xFFEDEDED),
                        letterSpacing: 0.2,
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
                    color: Color(0xFFEDEDED),
                  ),
                ),
                const Spacer(),
                _cityPill(),
              ],
            ),
          ),

          // List cinemas
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemBuilder: (_, i) => _cinemaCard(
                      index: i,
                      cinema: filtered[i],
                      onTap: () {
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MovieSelectionScreen(cinema: filtered[i]),
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
      color: const Color(0xFF1E1E2A),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2A2A3A)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Icon(icon, size: 18, color: const Color(0xFFEDEDED)),
  );

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF222230)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.35),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        style: const TextStyle(color: Color(0xFFEDEDED)),
        cursorColor: const Color(0xFF8B1E9B),
        decoration: const InputDecoration(
          hintText: 'Tìm rạp phim...',
          hintStyle: TextStyle(color: Color(0xFFB9B9C3)),
          prefixIcon: Icon(Icons.search, color: Color(0xFFB9B9C3)),
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
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B1E9B)
                          : const Color(0xFF222230),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: CachedNetworkImage(
                      imageUrl: item['icon']!,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF8B1E9B),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.local_activity,
                        color: Color(0xFFB9B9C3),
                      ),
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

  Widget _cityPill() {
    return InkWell(
      onTap: () {}, // có thể mở dialog chọn thành phố nếu muốn
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151521),
          border: Border.all(color: const Color(0xFF8B1E9B)),
          borderRadius: BorderRadius.circular(24),
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
          color: const Color(0xFF151521),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF222230)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
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
                    placeholder: (_, __) => Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xFF222230),
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF8B1E9B),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.local_movies,
                      size: 36,
                      color: Color(0xFFB9B9C3),
                    ),
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
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cinema.distance > 0
                            ? 'Khoảng cách: ${cinema.distance.toStringAsFixed(1)} km'
                            : 'Bạn vừa chọn rạp này',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB9B9C3),
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
                          border: Border.all(color: const Color(0xFF222230)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFF1C1C28),
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav
                              ? const Color(0xFF8B1E9B)
                              : const Color(0xFFEDEDED),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chevron_right, color: Color(0xFFB9B9C3)),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFEDEDED),
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(text: cinema.address),
                        const TextSpan(text: '   '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => _openDirections(cinema.address),
                            child: const Text(
                              'Tìm đường',
                              style: TextStyle(
                                color: Color(0xFF8B1E9B),
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
