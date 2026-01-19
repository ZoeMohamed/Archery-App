import 'db_helpers.dart';

class DbUser {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? address;
  final String? birthPlace;
  final List<String> roles;
  final String activeRole;
  final String? memberNumber;
  final String? memberStatus;
  final String? ktaPhotoUrl;
  final DateTime? ktaIssuedDate;
  final DateTime? ktaValidFrom;
  final DateTime? ktaValidUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.birthDate,
    this.address,
    this.birthPlace,
    required this.roles,
    required this.activeRole,
    this.memberNumber,
    this.memberStatus,
    this.ktaPhotoUrl,
    this.ktaIssuedDate,
    this.ktaValidFrom,
    this.ktaValidUntil,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMember => roles.contains('member') || roles.contains('admin');
  bool get isCoach => roles.contains('coach');
  bool get isAdmin => roles.contains('admin');
  bool get isStaff => roles.contains('staff');

  factory DbUser.fromJson(Map<String, dynamic> json) {
    final roles = DbHelpers.parseStringList(json['roles']);
    final activeRole =
        (json['active_role'] as String?) ?? (roles.isNotEmpty ? roles.first : 'non_member');
    return DbUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      birthDate: DbHelpers.parseDate(json['birth_date']),
      address: json['address']?.toString(),
      birthPlace: json['birth_place']?.toString(),
      roles: roles.isEmpty ? ['non_member'] : roles,
      activeRole: activeRole,
      memberNumber: json['member_number']?.toString(),
      memberStatus: json['member_status']?.toString(),
      ktaPhotoUrl: json['kta_photo_url']?.toString(),
      ktaIssuedDate: DbHelpers.parseDate(json['kta_issued_date']),
      ktaValidFrom: DbHelpers.parseDate(json['kta_valid_from']),
      ktaValidUntil: DbHelpers.parseDate(json['kta_valid_until']),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'birth_date': DbHelpers.formatDate(birthDate),
      'address': address,
      'birth_place': birthPlace,
      'roles': roles,
      'active_role': activeRole,
      'member_number': memberNumber,
      'member_status': memberStatus,
      'kta_photo_url': ktaPhotoUrl,
      'kta_issued_date': DbHelpers.formatDate(ktaIssuedDate),
      'kta_valid_from': DbHelpers.formatDate(ktaValidFrom),
      'kta_valid_until': DbHelpers.formatDate(ktaValidUntil),
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
