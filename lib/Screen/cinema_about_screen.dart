// lib/screens/cinema_about_screen.dart

import 'dart:convert'; // NEW: dùng jsonEncode/jsonDecode để chuyển map <-> json text
import 'package:flutter/foundation.dart'; // NEW: dùng compute(...) chạy parse ở isolate phụ
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/cinema_model.dart';
import '../models/cinema_about.dart';
import '../models/snack_model.dart';

class CinemaAboutScreen extends StatefulWidget {
  final Cinema cinema; // Rạp cơ sở (base) truyền sang
  const CinemaAboutScreen({super.key, required this.cinema});

  @override
  State<CinemaAboutScreen> createState() => _CinemaAboutScreenState();
}

// AutomaticKeepAliveClientMixin: giữ state & scroll position khi rời về rồi quay lại màn
class _CinemaAboutScreenState extends State<CinemaAboutScreen>
    with AutomaticKeepAliveClientMixin {
  // DatabaseReference gốc tới Realtime Database
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Tương lai (Future) chứa thông tin mở rộng của rạp (CinemaAbout) lấy 1 lần từ '/cinema_about/{id}'
  late final Future<CinemaAbout?> _aboutFuture;

  // Giới hạn render để tránh build quá nhiều item 1 lượt (tối ưu hiệu năng)
  static const int _maxPromotions = 20;
  static const int _maxSnacks = 30;

  @override
  void initState() {
    super.initState();
    // Khởi tạo future ngay từ đầu, tránh gọi lại khi build nhiều lần
    _aboutFuture = _fetchAboutOnce();
  }

  @override
  bool get wantKeepAlive => true; // NEW: bật keep-alive state cho màn hình này

  // ---------- Parse ở isolate để không block UI thread ----------
  // Hàm tĩnh nhận tuple (jsonText, baseCinema) -> trả về CinemaAbout
  // Mục tiêu: chuyển JSON text sang Map và fromMap ở isolate phụ để UI không giật
  static CinemaAbout? _parseAboutIsolate((String, Cinema) data) {
    final (jsonText, base) = data; // Dart records: tách tuple
    final map = jsonDecode(jsonText) as Map<String, dynamic>; // JSON -> Map
    return CinemaAbout.fromMap(
      map,
      base: base,
    ); // Tạo CinemaAbout kèm base cinema
  }

  // Lấy dữ liệu mở rộng của rạp đúng 1 lần (one-shot) từ RTDB
  Future<CinemaAbout?> _fetchAboutOnce() async {
    try {
      final snap = await _db
          .child(
            'cinema_about/${widget.cinema.id}',
          ) // Path: /cinema_about/<id-rạp>
          .get()
          .timeout(
            const Duration(seconds: 4),
          ); // NEW: fail nhanh để UI không treo

      if (snap.exists && snap.value is Map) {
        // Chuyển snapshot.value (Map) -> JSON text để truyền qua isolate dễ & hiệu quả
        final jsonText = jsonEncode(snap.value);
        // compute(...) chạy _parseAboutIsolate ở isolate khác -> không nghẽn UI thread
        return await compute(_parseAboutIsolate, (jsonText, widget.cinema));
      }
    } catch (_) {
      // Bỏ qua lỗi (mạng, rules DB, format), fallback sẽ dùng dữ liệu 'base' (widget.cinema)
    }
    return null; // Không có about -> UI hiển thị phần base tối thiểu
  }

  @override
  Widget build(BuildContext context) {
    super.build(
      context,
    ); // NEW: bắt buộc khi dùng keep-alive để Flutter ghi nhớ trạng thái
    final base =
        widget.cinema; // Dữ liệu rạp cơ sở (ảnh, địa chỉ, hours, snacks...)

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          base.name, // Tên rạp ở tiêu đề
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<CinemaAbout?>(
        future: _aboutFuture, // Future lấy 1 lần
        builder: (context, snap) {
          // 1) Trạng thái đang chờ dữ liệu -> spinner
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            );
          }

          // 2) Dữ liệu có thể null -> chỉ có 'base' (fallback)
          final a = snap.data;

          // Dùng CustomScrollView + Sliver để tối ưu danh sách dài, mượt cuộn
          return CustomScrollView(
            physics: const BouncingScrollPhysics(), // NEW: kéo mượt kiểu iOS
            cacheExtent: 300, // NEW: giảm vùng pre-render để nhẹ hơn
            slivers: [
              // ---------------- Header: tên rạp + brand + logo ----------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _Header(
                    name: base.name,
                    brand: a?.brand ?? '', // From about (nếu có)
                    logoUrl: a?.logoUrl ?? '', // From about (nếu có)
                  ),
                ),
              ),

              // ---------------- Ảnh cover ----------------
              if ((a?.images.isNotEmpty ?? false) || base.imageUrl.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: RepaintBoundary(
                      // NEW: cô lập repaint của ảnh cover -> giảm layout/repaint thừa
                      child: _Cover(
                        imageUrl: (a?.images.isNotEmpty ?? false)
                            ? a!
                                  .images
                                  .first // Ưu tiên ảnh từ about
                            : base.imageUrl, // Fallback ảnh base
                      ),
                    ),
                  ),
                ),

              // ---------------- Thông tin cơ bản ----------------
              _section('Thông tin'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _InfoTile(icon: Icons.place, text: base.address),
                      if (base.openHours.isNotEmpty)
                        _InfoTile(
                          icon: Icons.schedule,
                          text: 'Giờ mở: ${base.openHours}',
                        ),
                      _InfoTile(
                        icon: Icons.social_distance,
                        text:
                            'Khoảng cách: ${base.distance.toStringAsFixed(1)} km',
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------- Liên hệ (nếu có) ----------------
              if ((a?.phone ?? '').isNotEmpty ||
                  (a?.email ?? '').isNotEmpty ||
                  (a?.website ?? '').isNotEmpty) ...[
                _section('Liên hệ'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if ((a?.phone ?? '').isNotEmpty)
                          _InfoTile(icon: Icons.call, text: a!.phone!),
                        if ((a?.email ?? '').isNotEmpty)
                          _InfoTile(icon: Icons.email, text: a!.email!),
                        if ((a?.website ?? '').isNotEmpty)
                          _InfoTile(icon: Icons.public, text: a!.website!),
                      ],
                    ),
                  ),
                ),
              ],

              // ---------------- Giờ mở cửa chi tiết ----------------
              if ((a?.openHours?.isNotEmpty ?? false) ||
                  (a?.openHoursByDay.isNotEmpty ?? false)) ...[
                _section('Giờ mở cửa'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((a?.openHours ?? '').isNotEmpty)
                          _InfoBox(
                            child: Text(
                              a!.openHours!, // chuỗi mô tả chung
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        if ((a?.openHoursByDay.isNotEmpty ?? false))
                          _InfoBox(
                            // NEW: giới hạn .take(14) để không render quá dài (tối ưu)
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: a!.openHoursByDay.entries
                                  .take(14)
                                  .map(
                                    (e) => Text(
                                      '${e.key}: ${e.value}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              // ---------------- Giới thiệu ----------------
              if ((a?.description ?? '').isNotEmpty) ...[
                _section('Giới thiệu'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InfoBox(
                      child: Text(
                        a!.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ---------------- Tiện ích ----------------
              if ((a?.amenities.isNotEmpty ?? false)) ...[
                _section('Tiện ích'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AmenitiesChips(
                      items: a!.amenities,
                    ), // các chip tiện ích
                  ),
                ),
              ],

              // ---------------- Giá vé ----------------
              if ((a?.ticketPrices.isNotEmpty ?? false)) ...[
                _section('Giá vé tham khảo'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: a!.ticketPrices.entries.map((grp) {
                        // Đặt lại nhãn nhóm giá cho thân thiện
                        final title = grp.key == 'weekday'
                            ? 'Ngày thường'
                            : (grp.key == 'weekend' ? 'Cuối tuần' : grp.key);
                        return _InfoBox(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // NEW: .take(12) giới hạn số dòng giá hiển thị
                              ...grp.value.entries
                                  .take(12)
                                  .map(
                                    (e) => Text(
                                      '${e.key}: ${e.value}đ',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // ---------------- Khuyến mãi (lazy) ----------------
              if ((a?.promotions.isNotEmpty ?? false)) ...[
                _section('Khuyến mãi'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: RepaintBoundary(
                        // NEW: mỗi card nằm trong RepaintBoundary giảm repaint dây chuyền
                        child: _PromotionCard(promotion: a!.promotions[i]),
                      ),
                    ),
                    childCount: a!.promotions.length.clamp(0, _maxPromotions),
                    addAutomaticKeepAlives: false, // NEW: tự tối ưu list
                    addRepaintBoundaries: true, // NEW
                    addSemanticIndexes: false, // NEW
                  ),
                ),
              ],

              // ---------------- Snacks (lazy) ----------------
              if (base.snacks.isNotEmpty) ...[
                _section('Bắp nước & đồ ăn'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: RepaintBoundary(
                        // NEW: giảm repaint cho mỗi tile
                        child: _SnackTile(snack: base.snacks[i]),
                      ),
                    ),
                    childCount: base.snacks.length.clamp(0, _maxSnacks),
                    addAutomaticKeepAlives: false, // NEW
                    addRepaintBoundaries: true, // NEW
                    addSemanticIndexes: false, // NEW
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ],
          );
        },
      ),
    );
  }

  // Title chung cho các block (gói trong SliverToBoxAdapter để nhét vào CustomScrollView)
  SliverToBoxAdapter _section(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: _SectionTitle(title),
    ),
  );
}

// ============================== UI Components ===============================

class _Header extends StatelessWidget {
  final String name;
  final String brand;
  final String logoUrl;
  const _Header({
    required this.name,
    required this.brand,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl.isNotEmpty;
    final hasBrand = brand.isNotEmpty;

    return Row(
      children: [
        if (hasLogo)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: logoUrl,
              width: 56,
              height: 56,
              memCacheWidth: 112, // Cache ảnh kích thước nhỏ (tiết kiệm RAM)
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low, // NEW: lọc ảnh nhẹ hơn
              fadeInDuration: Duration.zero, // NEW: bỏ animation để mượt hơn
              fadeOutDuration: Duration.zero, // NEW
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.movie, color: Colors.white54),
              progressIndicatorBuilder: (_, __, ___) => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (hasLogo) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tên rạp (đậm)
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // Brand (nếu có)
              if (hasBrand)
                Text(brand, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final String imageUrl;
  const _Cover({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9, // Duy trì tỉ lệ ảnh cover
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          memCacheWidth: 720, // NEW: nhỏ hơn 960 để tiết kiệm bộ nhớ
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low, // NEW: giảm chi phí lọc
          fadeInDuration: Duration.zero, // NEW: giảm jank animation
          fadeOutDuration: Duration.zero, // NEW
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF1C1C28),
            child: const Icon(Icons.image, color: Colors.white54),
          ),
          progressIndicatorBuilder: (_, __, ___) => const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    // Tiêu đề block (màu trắng, đậm)
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    // 1 dòng thông tin (icon + text) trong một container tối giản
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B1E9B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Widget child;
  const _InfoBox({required this.child});

  @override
  Widget build(BuildContext context) {
    // Hộp chứa nội dung văn bản/nhóm dòng (vd mô tả, giờ mở cửa chi tiết)
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
      ),
      child: child,
    );
  }
}

class _AmenitiesChips extends StatelessWidget {
  final List<String> items;
  const _AmenitiesChips({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink(); // Không gì để hiển thị
    // Hiển thị list tiện ích dạng chip đơn giản
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF222230)),
              ),
              child: Text(e, style: const TextStyle(color: Colors.white70)),
            ),
          )
          .toList(),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final Promotion
  promotion; // Thực thể khuyến mãi (title, content, image, validUntil)
  const _PromotionCard({required this.promotion});

  @override
  Widget build(BuildContext context) {
    final hasImg = promotion.imageUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: promotion.imageUrl,
                height: 150,
                width: double.infinity,
                memCacheWidth: 800, // NEW: khống chế kích thước cache để nhẹ
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low, // NEW
                fadeInDuration: Duration.zero, // NEW
                fadeOutDuration: Duration.zero, // NEW
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề khuyến mãi
                Text(
                  promotion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                // Nội dung khuyến mãi
                Text(
                  promotion.content,
                  style: const TextStyle(color: Colors.white70),
                ),
                // Hạn sử dụng (nếu có)
                if (promotion.validUntil.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'HSD: ${promotion.validUntil}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnackTile extends StatelessWidget {
  final Snack snack; // Món/bắp nước: name, price, imageUrl?
  const _SnackTile({required this.snack});

  @override
  Widget build(BuildContext context) {
    final hasImg = (snack.imageUrl ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
      ),
      child: Row(
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: snack.imageUrl!,
                width: 56,
                height: 56,
                memCacheWidth: 224, // Giới hạn cache ảnh nhỏ
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low, // NEW
                fadeInDuration: Duration.zero, // NEW
                fadeOutDuration: Duration.zero, // NEW
              ),
            ),
          if (hasImg) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên món
                Text(
                  snack.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Giá món
                Text(
                  '${snack.price}đ',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
