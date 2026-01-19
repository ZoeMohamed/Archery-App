import 'db_helpers.dart';

class DbPayment {
  final String? id;
  final String userId;
  final String paymentType;
  final DateTime? paymentMonth;
  final int amount;
  final String proofUrl;
  final String? notes;
  final String status;
  final String? rejectionReason;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbPayment({
    this.id,
    required this.userId,
    required this.paymentType,
    this.paymentMonth,
    required this.amount,
    required this.proofUrl,
    this.notes,
    this.status = 'pending',
    this.rejectionReason,
    this.verifiedBy,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DbPayment.fromJson(Map<String, dynamic> json) {
    return DbPayment(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? 'monthly_dues',
      paymentMonth: DbHelpers.parseDate(json['payment_month']),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      proofUrl: json['proof_url']?.toString() ?? '',
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      verifiedBy: json['verified_by']?.toString(),
      verifiedAt: DbHelpers.parseTimestamp(json['verified_at']),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'payment_type': paymentType,
      'payment_month': DbHelpers.formatDate(paymentMonth),
      'amount': amount,
      'proof_url': proofUrl,
      'notes': notes,
      'status': status,
      'rejection_reason': rejectionReason,
      'verified_by': verifiedBy,
      'verified_at': DbHelpers.formatTimestamp(verifiedAt),
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
