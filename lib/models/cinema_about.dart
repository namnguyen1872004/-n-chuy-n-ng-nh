// lib/models/cinema_about.dart
//
// NOTE: Sửa lại đường dẫn import này theo đúng vị trí file Cinema của bạn.
import 'cinema_model.dart';

/// ===================================================================
/// 🎟 Promotion (Khuyến mãi của rạp)
/// - Dùng cho danh sách ưu đãi hiển thị trong trang “Giới thiệu rạp”
/// ===================================================================
class Promotion {
  final String title; // Tiêu đề khuyến mãi
  final String imageUrl; // Ảnh minh hoạ (URL)
  final String content; // Nội dung mô tả
  final String validUntil; // Hạn dùng (yyyy-MM-dd) – có thể để chuỗi

  Promotion({
    required this.title,
    required this.imageUrl,
    required this.content,
    required this.validUntil,
  });

  /// ✅ Parse an toàn từ Firebase/Map (chịu null/kiểu dữ liệu khác)
  factory Promotion.fromMap(Map<dynamic, dynamic> map) {
    return Promotion(
      title: (map['title'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      validUntil: (map['validUntil'] ?? '').toString(),
    );
  }

  /// ✅ Convert ngược để lưu lên Firebase
  Map<String, dynamic> toMap() => {
    'title': title,
    'imageUrl': imageUrl,
    'content': content,
    'validUntil': validUntil,
  };
}

/// ===================================================================
/// 🏢 CinemaAbout (Thông tin “bồi” thêm cho rạp)
///
/// Ý tưởng:
/// - Bạn đã có `Cinema base` (tên, địa chỉ, openHours, imageUrl, snacks…)
/// - `CinemaAbout` chỉ chứa phần mở rộng (brand, logo, album ảnh, tiện ích…)
/// - Tất cả field mở rộng đều OPTIONAL để không “khoá tay” dữ liệu Firebase.
/// - `fromMap()` parse linh hoạt: nhận List/Map/String cho nhiều kiểu khoá.
/// ===================================================================
class CinemaAbout {
  // ----------------- Dữ liệu gốc từ /cinemas -----------------
  final Cinema base;

  // ----------------- Mở rộng tuỳ chọn -----------------
  final String? brand; // Thương hiệu (CGV, BHD, Lotte,…)
  final String? logoUrl; // Logo rạp
  final List<String> images; // Album ảnh
  final String? phone; // SĐT liên hệ
  final String? email; // Email liên hệ
  final String? website; // Website
  final String? description; // Mô tả/giới thiệu
  final String? openHours; // Giờ mở cửa (ghi đè nếu khác base)
  final Map<String, String> openHoursByDay; // Giờ mở theo từng ngày
  final List<String> amenities; // Tiện ích (bãi đỗ xe, cafe,…)
  /// Bảng giá vé: ví dụ
  /// {
  ///   "weekday": {"2D": 75000, "3D": 95000},
  ///   "weekend": {"2D": 90000, "3D": 110000}
  /// }
  final Map<String, Map<String, int>> ticketPrices;
  final List<String> services; // Dịch vụ (đổi/return, đặt online,…)
  final List<Promotion> promotions; // Danh sách khuyến mãi

  CinemaAbout({
    required this.base,
    this.brand,
    this.logoUrl,
    this.images = const [],
    this.phone,
    this.email,
    this.website,
    this.description,
    this.openHours,
    this.openHoursByDay = const {},
    this.amenities = const [],
    this.ticketPrices = const {},
    this.services = const [],
    this.promotions = const [],
  });

  // ===================================================================
  // 🔧 Helpers parse — tách riêng để code gọn và dễ đọc
  // ===================================================================
  /// Ép mọi kiểu (List/String/khác) về List<String>
  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      // chỉ nhận phần tử là String
      return v.whereType().map((e) => e.toString()).toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  /// Ép mọi kiểu (Map/khác) về Map<String, String>
  static Map<String, String> _asStringMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    return <String, String>{};
  }

  /// Parse bảng giá: Map<String, Map<String, int>>
  static Map<String, Map<String, int>> _asPriceTable(dynamic v) {
    final out = <String, Map<String, int>>{};
    if (v is! Map) return out;

    v.forEach((groupKey, groupVal) {
      if (groupVal is Map) {
        final groupMap = <String, int>{};
        groupVal.forEach((formatKey, priceVal) {
          final parsed = (priceVal is int)
              ? priceVal
              : int.tryParse('$priceVal') ?? 0;
          groupMap[formatKey.toString()] = parsed;
        });
        out[groupKey.toString()] = groupMap;
      }
    });
    return out;
  }

  /// Parse danh sách Promotion từ List/khác
  static List<Promotion> _asPromotionList(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Promotion.fromMap(e)).toList();
    }
    return <Promotion>[];
  }

  // ===================================================================
  // ✅ Parse linh hoạt từ Firebase
  // - `raw` là phần mở rộng ở nhánh /cinema_about/{cinemaId}
  // - Nếu lẫn field của Cinema thì vẫn ưu tiên `base` (không đè lên base)
  // ===================================================================
  factory CinemaAbout.fromMap(
    Map<dynamic, dynamic> raw, {
    required Cinema base,
  }) {
    // Chuẩn hoá key: dynamic -> String
    final map = raw.map((k, v) => MapEntry(k.toString(), v));

    // Các field String optional: dùng hàm _takeStringOrNull để bỏ chuỗi rỗng
    String? _takeStringOrNull(String key) {
      final s = (map[key] ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return CinemaAbout(
      base: base,
      brand: _takeStringOrNull('brand'),
      logoUrl: _takeStringOrNull('logoUrl'),
      images: _asStringList(map['images']),
      phone: _takeStringOrNull('phone'),
      email: _takeStringOrNull('email'),
      website: _takeStringOrNull('website'),
      description: _takeStringOrNull('description'),
      openHours: _takeStringOrNull('openHours'),
      openHoursByDay: _asStringMap(map['openHoursByDay']),
      amenities: _asStringList(map['amenities']),
      ticketPrices: _asPriceTable(map['ticketPrices']),
      services: _asStringList(map['services']),
      promotions: _asPromotionList(map['promotions']),
    );
  }

  /// ✅ Convert sang Map để lưu lại lên Firebase
  /// (Bỏ qua field null để dữ liệu gọn gàng)
  Map<String, dynamic> toMap() => {
    if (brand != null) 'brand': brand,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (images.isNotEmpty) 'images': images,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (website != null) 'website': website,
    if (description != null) 'description': description,
    if (openHours != null) 'openHours': openHours,
    if (openHoursByDay.isNotEmpty) 'openHoursByDay': openHoursByDay,
    if (amenities.isNotEmpty) 'amenities': amenities,
    if (ticketPrices.isNotEmpty) 'ticketPrices': ticketPrices,
    if (services.isNotEmpty) 'services': services,
    if (promotions.isNotEmpty)
      'promotions': promotions.map((e) => e.toMap()).toList(),
  };
}
