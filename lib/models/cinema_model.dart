import 'snack_model.dart';

class Cinema {
  final String id;
  final String name;
  final String address;
  final double distance; // Khoảng cách (km)
  final String openHours; // Giờ mở cửa
  final String imageUrl; // Ảnh rạp
  final List<Snack> snacks; // Danh sách đồ ăn

  Cinema({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.openHours,
    required this.imageUrl,
    required this.snacks,
  });

  /// Parse từ Firebase Map sang Cinema
  factory Cinema.fromMap(Map<dynamic, dynamic> map) {
    return Cinema(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      distance: (map['distance'] is num)
          ? (map['distance'] as num).toDouble()
          : double.tryParse('${map['distance'] ?? 0}') ?? 0.0,
      openHours: (map['openHours'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      snacks: (map['snacks'] is List)
          ? (map['snacks'] as List)
                .map((v) => Snack.fromMap(Map<String, dynamic>.from(v)))
                .toList()
          : (map['snacks'] is Map)
          ? (map['snacks'] as Map).values
                .map((v) => Snack.fromMap(Map<String, dynamic>.from(v)))
                .toList()
          : [],
    );
  }

  /// Convert ngược để lưu lên Firebase (dùng List thay vì Map)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'distance': distance,
      'openHours': openHours,
      'imageUrl': imageUrl,

      'snacks': snacks.map((s) => s.toMap()).toList(),
    };
  }
}
