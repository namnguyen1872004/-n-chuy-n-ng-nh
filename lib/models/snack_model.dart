class Snack {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;

  Snack({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
  });

  /// Parse dữ liệu từ Firebase hoặc Map sang Snack
  factory Snack.fromMap(Map<dynamic, dynamic> map) {
    return Snack(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse('${map['price'] ?? 0}') ?? 0.0,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
    );
  }

  /// Chuyển ngược Snack sang Map để lưu lên Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
    };
  }
}
