import 'db_helpers.dart';

class DbMemberPaymentStatusView {
  final String id;
  final String fullName;
  final String email;
  final String? memberNumber;
  final List<String> roles;
  final String activeRole;
  final String ageCategory;
  final String? memberStatus;
  final DateTime? ktaValidFrom;
  final DateTime? ktaValidUntil;
  final bool ktaIsValid;
  final DateTime? lastPaymentMonth;
  final String? lastPaymentStatus;
  final int? monthsSincePayment;

  const DbMemberPaymentStatusView({
    required this.id,
    required this.fullName,
    required this.email,
    this.memberNumber,
    required this.roles,
    required this.activeRole,
    required this.ageCategory,
    this.memberStatus,
    this.ktaValidFrom,
    this.ktaValidUntil,
    required this.ktaIsValid,
    this.lastPaymentMonth,
    this.lastPaymentStatus,
    this.monthsSincePayment,
  });

  factory DbMemberPaymentStatusView.fromJson(Map<String, dynamic> json) {
    return DbMemberPaymentStatusView(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      memberNumber: json['member_number']?.toString(),
      roles: DbHelpers.parseStringList(json['roles']),
      activeRole: json['active_role']?.toString() ?? 'non_member',
      ageCategory: json['age_category']?.toString() ?? '',
      memberStatus: json['member_status']?.toString(),
      ktaValidFrom: DbHelpers.parseDate(json['kta_valid_from']),
      ktaValidUntil: DbHelpers.parseDate(json['kta_valid_until']),
      ktaIsValid: json['kta_is_valid'] == true,
      lastPaymentMonth: DbHelpers.parseDate(json['last_payment_month']),
      lastPaymentStatus: json['last_payment_status']?.toString(),
      monthsSincePayment: (json['months_since_payment'] as num?)?.toInt(),
    );
  }
}

class DbUserTrainingStatsView {
  final String userId;
  final String fullName;
  final List<String> roles;
  final String ageCategory;
  final int totalSessions;
  final double avgScore;
  final double avgAccuracy;
  final DateTime? lastTrainingDate;

  const DbUserTrainingStatsView({
    required this.userId,
    required this.fullName,
    required this.roles,
    required this.ageCategory,
    required this.totalSessions,
    required this.avgScore,
    required this.avgAccuracy,
    this.lastTrainingDate,
  });

  factory DbUserTrainingStatsView.fromJson(Map<String, dynamic> json) {
    return DbUserTrainingStatsView(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      roles: DbHelpers.parseStringList(json['roles']),
      ageCategory: json['age_category']?.toString() ?? '',
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0.0,
      avgAccuracy: (json['avg_accuracy'] as num?)?.toDouble() ?? 0.0,
      lastTrainingDate: DbHelpers.parseDate(json['last_training_date']),
    );
  }
}

class DbLatestCompetitionNewsView {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? competitionName;
  final DateTime? competitionDate;
  final String? location;
  final DateTime? publishedAt;
  final List<String> winnerIds;
  final List<String> winnerNames;

  const DbLatestCompetitionNewsView({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.competitionName,
    this.competitionDate,
    this.location,
    this.publishedAt,
    required this.winnerIds,
    required this.winnerNames,
  });

  factory DbLatestCompetitionNewsView.fromJson(Map<String, dynamic> json) {
    return DbLatestCompetitionNewsView(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      competitionName: json['competition_name']?.toString(),
      competitionDate: DbHelpers.parseDate(json['competition_date']),
      location: json['location']?.toString(),
      publishedAt: DbHelpers.parseTimestamp(json['published_at']),
      winnerIds: DbHelpers.parseStringList(json['winner_ids']),
      winnerNames: DbHelpers.parseStringList(json['winner_names']),
    );
  }
}
