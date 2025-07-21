class User {
  final String id;
  final String email;
  final UserType userType;
  final String? name;
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.userType,
    this.name,
    this.isAvailable = true,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      userType: UserType.values.firstWhere(
        (type) => type.toString() == map['userType'],
        orElse: () => UserType.crewMember,
      ),
      name: map['name'],
      isAvailable: map['isAvailable'] ?? true,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'userType': userType.toString(),
      'name': name,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}

enum UserType {
  crewMember,
  admin,
}
