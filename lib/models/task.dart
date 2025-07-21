class Task {
  final String id;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? assignedToUserId;
  final String? assignedToEmail;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.assignedToUserId,
    this.assignedToEmail,
    this.status = TaskStatus.unassigned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      locationName: map['locationName'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      assignedToUserId: map['assignedToUserId'],
      assignedToEmail: map['assignedToEmail'],
      status: TaskStatus.values.firstWhere(
        (status) => status.toString() == map['status'],
        orElse: () => TaskStatus.unassigned,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'assignedToUserId': assignedToUserId,
      'assignedToEmail': assignedToEmail,
      'status': status.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}

enum TaskStatus {
  unassigned,
  assigned,
  completed,
}
