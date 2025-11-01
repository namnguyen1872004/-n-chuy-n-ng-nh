import 'snack_model.dart';

class Cinema {
  final String id;
  final String name;
  final String address;
  final double distance;
  final String openHours;
  final String imageUrl;
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

  /// ✅ Parse từ Firebase Map sang Cinema
  factory Cinema.fromMap(Map<dynamic, dynamic> map) {
    List<Snack> snackList = [];

    final rawSnacks = map['snacks'];
    if (rawSnacks != null) {
      try {
        if (rawSnacks is List) {
          // ✅ snacks là List<Object?>
          snackList = rawSnacks
              .whereType<Map>() // loại bỏ phần tử null hoặc không phải map
              .map((v) => Snack.fromMap(Map<String, dynamic>.from(v)))
              .toList();
        } else if (rawSnacks is Map) {
          // ✅ snacks là Map<String, dynamic>
          snackList = rawSnacks.values
              .whereType<Map>()
              .map((v) => Snack.fromMap(Map<String, dynamic>.from(v)))
              .toList();
        }
      } catch (e) {
        snackList = [];
      }
    }

    return Cinema(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      distance: (map['distance'] is num)
          ? (map['distance'] as num).toDouble()
          : double.tryParse('${map['distance'] ?? 0}') ?? 0.0,
      openHours: (map['openHours'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      snacks: snackList,
    );
  }

  /// ✅ Convert ngược để lưu lên Firebase
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
