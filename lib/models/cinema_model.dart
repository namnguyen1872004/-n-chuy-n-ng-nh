import 'snack_model.dart';

/// ===================================================================
/// 🎬 CINEMA (RẠP PHIM)
/// - Dùng dữ liệu chính: id, name, address, distance, openHours, imageUrl
/// - Tận dụng danh sách snacks (bắp nước) nếu có
/// - Parse “linh hoạt” để không bị vỡ khi Firebase thay đổi schema nhỏ
/// ===================================================================
class Cinema {
  final String id;
  final String name;
  final String address;
  final double distance; // km
  final String openHours; // chuỗi giờ mở cửa (ví dụ: "8:00 - 22:00")
  final String imageUrl; // URL ảnh đại diện
  final List<Snack> snacks;

  Cinema({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.openHours,
    required this.imageUrl,
    required this.snacks,
  });

  // -----------------------------
  // 🔧 Helpers parse nho nhỏ
  // -----------------------------

  /// Lấy URL ảnh theo nhiều khoá phổ biến
  static String _pickImageUrl(Map<dynamic, dynamic> m) {
    const keys = ['imageUrl', 'imageURL', 'image', 'img'];
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  /// Parse danh sách Snack từ List/Map/null (không làm app crash)
  static List<Snack> _parseSnacks(dynamic raw) {
    final out = <Snack>[];
    if (raw == null) return out;

    try {
      if (raw is List) {
        // Dạng: [ {...}, {...} ]
        for (final item in raw) {
          if (item is Map) {
            out.add(Snack.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      } else if (raw is Map) {
        // Dạng: { key1: {...}, key2: {...} }
        for (final v in raw.values) {
          if (v is Map) {
            out.add(Snack.fromMap(Map<String, dynamic>.from(v)));
          }
        }
      }
    } catch (_) {
      // nuốt lỗi, trả list rỗng để UI vẫn chạy
    }
    return out;
  }

  /// ✅ Parse từ Firebase Map sang Cinema (an toàn kiểu)
  factory Cinema.fromMap(Map<dynamic, dynamic> map) {
    // Chuẩn hoá Map<dynamic,dynamic> -> Map<String,dynamic>
    final m = map.map((k, v) => MapEntry(k.toString(), v));

    // Distance: nhận num/string -> double
    double _parseDistance(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return Cinema(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      address: (m['address'] ?? '').toString(),
      distance: _parseDistance(m['distance']),
      openHours: (m['openHours'] ?? '').toString(),
      imageUrl: _pickImageUrl(m),
      snacks: _parseSnacks(m['snacks']),
    );
  }

  /// ✅ Convert ngược để lưu lên Firebase
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'distance': distance,
    'openHours': openHours,
    'imageUrl': imageUrl,
    'snacks': snacks.map((s) => s.toMap()).toList(),
  };

  /// 🛠 Tiện cho UI: tạo bản sao với vài trường thay đổi
  Cinema copyWith({
    String? id,
    String? name,
    String? address,
    double? distance,
    String? openHours,
    String? imageUrl,
    List<Snack>? snacks,
  }) {
    return Cinema(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      distance: distance ?? this.distance,
      openHours: openHours ?? this.openHours,
      imageUrl: imageUrl ?? this.imageUrl,
      snacks: snacks ?? this.snacks,
    );
  }
}
