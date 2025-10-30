class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final int points;
  final String? photoUrl;
  final String createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    this.points = 0,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<dynamic, dynamic> map, {required String uid}) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      points: map['points'] is int
          ? map['points'] as int
          : int.tryParse('${map['points'] ?? 0}') ?? 0,
      photoUrl: map['photoUrl'] as String?,
      createdAt:
          map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'points': points,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
    }..removeWhere((key, value) => value == null);
  }

  UserModel copyWith({
    String? name,
    String? phone,
    int? points,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      points: points ?? this.points,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
