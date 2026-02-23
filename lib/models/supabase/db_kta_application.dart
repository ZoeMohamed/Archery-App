import 'db_helpers.dart';

class DbKtaApplication {
  final String? id;
  final String userId;
  final String confirmedName;
  final String confirmedBirthPlace;
  final DateTime confirmedBirthDate;
  final String confirmedAddress;
  final String ktaPhotoUrl;
  final String? registrationPaymentId;
  final String status;
  final String? rejectionReason;
  final String? processedBy;
  final DateTime? processedAt;

  // Correction fields (from KTA OCR / admin edit)
  final String? memberNumber;
  final DateTime? ktaValidFrom;
  final DateTime? ktaValidUntil;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbKtaApplication({
    this.id,
    required this.userId,
    required this.confirmedName,
    required this.confirmedBirthPlace,
    required this.confirmedBirthDate,
    required this.confirmedAddress,
    required this.ktaPhotoUrl,
    this.registrationPaymentId,
    this.status = 'pending',
    this.rejectionReason,
    this.processedBy,
    this.processedAt,
    this.memberNumber,
    this.ktaValidFrom,
    this.ktaValidUntil,
    this.createdAt,
    this.updatedAt,
  });

  factory DbKtaApplication.fromJson(Map<String, dynamic> json) {
    return DbKtaApplication(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      confirmedName: json['confirmed_name']?.toString() ?? '',
      confirmedBirthPlace: json['confirmed_birth_place']?.toString() ?? '',
      confirmedBirthDate: DbHelpers.parseDate(json['confirmed_birth_date']) ??
          DateTime.now(),
      confirmedAddress: json['confirmed_address']?.toString() ?? '',
      ktaPhotoUrl: json['kta_photo_url']?.toString() ?? '',
      registrationPaymentId: json['registration_payment_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      processedBy: json['processed_by']?.toString(),
      processedAt: DbHelpers.parseTimestamp(json['processed_at']),
      memberNumber: json['member_number']?.toString(),
      ktaValidFrom: DbHelpers.parseDate(json['kta_valid_from']),
      ktaValidUntil: DbHelpers.parseDate(json['kta_valid_until']),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'confirmed_name': confirmedName,
      'confirmed_birth_place': confirmedBirthPlace,
      'confirmed_birth_date': DbHelpers.formatDate(confirmedBirthDate),
      'confirmed_address': confirmedAddress,
      'kta_photo_url': ktaPhotoUrl,
      'registration_payment_id': registrationPaymentId,
      'status': status,
      'rejection_reason': rejectionReason,
      'processed_by': processedBy,
      'processed_at': DbHelpers.formatTimestamp(processedAt),
      'member_number': memberNumber,
      'kta_valid_from': DbHelpers.formatDate(ktaValidFrom),
      'kta_valid_until': DbHelpers.formatDate(ktaValidUntil),
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
