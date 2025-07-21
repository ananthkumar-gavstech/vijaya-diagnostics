class OnboardingData {
  final String userId;
  final String aadhaarNumber;
  final String? aadhaarPhotoUrl;
  final OnboardingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  OnboardingData({
    required this.userId,
    required this.aadhaarNumber,
    this.aadhaarPhotoUrl,
    this.status = OnboardingStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    return OnboardingData(
      userId: map['userId'] ?? '',
      aadhaarNumber: map['aadhaarNumber'] ?? '',
      aadhaarPhotoUrl: map['aadhaarPhotoUrl'],
      status: OnboardingStatus.values.firstWhere(
        (status) => status.toString() == map['status'],
        orElse: () => OnboardingStatus.pending,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'aadhaarNumber': aadhaarNumber,
      'aadhaarPhotoUrl': aadhaarPhotoUrl,
      'status': status.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}

enum OnboardingStatus {
  pending,
  verified,
  rejected,
}
