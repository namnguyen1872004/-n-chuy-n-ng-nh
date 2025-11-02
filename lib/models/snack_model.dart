class Snack {
  final String id;
  final String name;

  /// Giá tính theo **VND (đồng)**, đã chuẩn hoá khi parse.
  final double price;

  /// URL ảnh (tự bắt nhiều key phổ biến khi parse)
  final String imageUrl;
  final String description;

  Snack({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
  });

  /// --- Helpers nội bộ ---

  /// Chuẩn hoá giá về VND:
  /// - Nếu giá < 1000 (ví dụ 65 / "65") → coi là đơn vị **nghìn** → 65,000đ
  /// - Nếu >= 1000 → coi là **đồng** → giữ nguyên.
  static int _toVND(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) {
      final v = raw.toDouble();
      return v < 1000 ? (v * 1000).round() : v.round();
    }
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleaned.isEmpty) return 0;
      final v = double.tryParse(cleaned) ?? 0;
      return v < 1000 ? (v * 1000).round() : v.round();
    }
    return 0;
  }

  /// Bắt URL ảnh theo nhiều key phổ biến trong Firebase.
  static String _pickImageUrl(Map<dynamic, dynamic> map) {
    const candidates = [
      'imageUrl',
      'imageURL',
      'image',
      'img',
      'thumbnail',
      'thumb',
      'url',
      'photo',
      'picture',
    ];
    for (final k in candidates) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  /// Parse dữ liệu từ Firebase/Map sang Snack (chịu được Map<dynamic,dynamic>)
  factory Snack.fromMap(Map<dynamic, dynamic> map) {
    final mm = map.map((k, v) => MapEntry(k.toString(), v));

    return Snack(
      id: (mm['id'] ?? '').toString(),
      name: (mm['name'] ?? '').toString(),
      price: _toVND(mm['price']).toDouble(), // <- luôn là VND (đồng)
      imageUrl: _pickImageUrl(mm),
      description: (mm['description'] ?? '').toString(),
    );
  }

  /// Chuyển ngược Snack sang Map để lưu lên Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price, // VND (đồng)
      'imageUrl': imageUrl, // thống nhất 1 key khi lưu
      'description': description,
    };
  }
}
