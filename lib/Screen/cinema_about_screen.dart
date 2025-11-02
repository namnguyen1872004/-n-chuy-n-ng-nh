// lib/screens/cinema_about_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/cinema_model.dart';
import '../models/cinema_about.dart';
import '../models/snack_model.dart';

class CinemaAboutScreen extends StatefulWidget {
  final Cinema cinema;
  const CinemaAboutScreen({super.key, required this.cinema});

  @override
  State<CinemaAboutScreen> createState() => _CinemaAboutScreenState();
}

class _CinemaAboutScreenState extends State<CinemaAboutScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  late final Future<CinemaAbout?> _aboutFuture;

  // Giới hạn render để tránh build quá nhiều item 1 lượt
  static const int _maxPromotions = 20;
  static const int _maxSnacks = 30;

  @override
  void initState() {
    super.initState();
    _aboutFuture = _fetchAboutOnce();
  }

  Future<CinemaAbout?> _fetchAboutOnce() async {
    try {
      final snap = await _db
          .child('cinema_about/${widget.cinema.id}')
          .get()
          .timeout(const Duration(seconds: 5)); // tránh treo

      if (snap.exists && snap.value is Map) {
        return CinemaAbout.fromMap(
          Map<dynamic, dynamic>.from(snap.value as Map),
          base: widget.cinema,
        );
      }
    } catch (_) {
      // bỏ qua lỗi mạng/rules -> fallback base
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.cinema;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          base.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<CinemaAbout?>(
        future: _aboutFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            );
          }
          final a = snap.data; // có thể null

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _Header(
                    name: base.name,
                    brand: a?.brand ?? '',
                    logoUrl: a?.logoUrl ?? '',
                  ),
                ),
              ),

              if ((a?.images.isNotEmpty ?? false) || base.imageUrl.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _Cover(
                      imageUrl: (a?.images.isNotEmpty ?? false)
                          ? a!.images.first
                          : base.imageUrl,
                    ),
                  ),
                ),

              // ----- Thông tin cơ bản -----
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

              // ----- Liên hệ -----
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

              // ----- Giờ mở cửa chi tiết -----
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
                              a!.openHours!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        if ((a?.openHoursByDay.isNotEmpty ?? false))
                          _InfoBox(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: a!.openHoursByDay.entries
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

              // ----- Giới thiệu -----
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

              // ----- Tiện ích -----
              if ((a?.amenities.isNotEmpty ?? false)) ...[
                _section('Tiện ích'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AmenitiesChips(items: a!.amenities),
                  ),
                ),
              ],

              // ----- Giá vé -----
              if ((a?.ticketPrices.isNotEmpty ?? false)) ...[
                _section('Giá vé tham khảo'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: a!.ticketPrices.entries.map((grp) {
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
                              ...grp.value.entries.map(
                                (e) => Text(
                                  '${e.key}: ${e.value}đ',
                                  style: const TextStyle(color: Colors.white70),
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

              // ----- Khuyến mãi (lazy) -----
              if ((a?.promotions.isNotEmpty ?? false)) ...[
                _section('Khuyến mãi'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _PromotionCard(promotion: a!.promotions[i]),
                    ),
                    childCount: a!.promotions.length.clamp(0, _maxPromotions),
                  ),
                ),
              ],

              // ----- Snacks (lazy) -----
              if (base.snacks.isNotEmpty) ...[
                _section('Bắp nước & đồ ăn'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _SnackTile(snack: base.snacks[i]),
                    ),
                    childCount: base.snacks.length.clamp(0, _maxSnacks),
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

  // Title chung cho các block
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
              memCacheWidth: 112,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
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
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          memCacheWidth: 960, // ~HD nhẹ
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
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
    if (items.isEmpty) return const SizedBox.shrink();
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
  final Promotion promotion;
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
                memCacheWidth: 900,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  promotion.content,
                  style: const TextStyle(color: Colors.white70),
                ),
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
  final Snack snack;
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
                memCacheWidth: 224,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
          if (hasImg) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snack.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
