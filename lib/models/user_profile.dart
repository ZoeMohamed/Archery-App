class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String role; // non_member, member, admin
  final bool isCoach;
  final String? memberNumber;
  final String? memberStatus; // active, inactive
  final String? ktaPhotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.birthDate,
    required this.role,
    this.isCoach = false,
    this.memberNumber,
    this.memberStatus,
    this.ktaPhotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      birthDate: json['birth_date'] != null 
          ? DateTime.parse(json['birth_date']) 
          : null,
      role: json['role'],
      isCoach: json['is_coach'] ?? false,
      memberNumber: json['member_number'],
      memberStatus: json['member_status'],
      ktaPhotoUrl: json['kta_photo_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'role': role,
      'is_coach': isCoach,
      'member_number': memberNumber,
      'member_status': memberStatus,
      'kta_photo_url': ktaPhotoUrl,
    };
  }

  String getAgeCategory() {
    if (birthDate == null) return 'Dewasa';
    
    final now = DateTime.now();
    final age = now.year - birthDate!.year - 
                ((now.month > birthDate!.month || 
                  (now.month == birthDate!.month && now.day >= birthDate!.day)) 
                  ? 0 : 1);

    if (age < 9) return 'U9';
    if (age < 12) return 'U12';
    if (age < 15) return 'U15';
    return 'Dewasa';
  }

  int? getAge() {
    if (birthDate == null) return null;
    
    final now = DateTime.now();
    return now.year - birthDate!.year - 
           ((now.month > birthDate!.month || 
             (now.month == birthDate!.month && now.day >= birthDate!.day)) 
             ? 0 : 1);
  }

  String getFormattedBirthDate() {
    if (birthDate == null) return '';
    return '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}';
  }

  bool get isMember => role == 'member';
  bool get isAdmin => role == 'admin';
  bool get isNonMember => role == 'non_member';
  bool get isActiveMember => memberStatus == 'active';
  bool get hasKtaPhoto => ktaPhotoUrl != null && ktaPhotoUrl!.isNotEmpty;
}
