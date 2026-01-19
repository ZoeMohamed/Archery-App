import 'db_helpers.dart';

class DbScoreDetail {
  final String? id;
  final String sessionId;
  final int endNumber;
  final int arrowNumber;
  final String? playerUserId;
  final String? playerName;
  final String scoreValue;
  final int scoreNumeric;
  final DateTime? createdAt;

  const DbScoreDetail({
    this.id,
    required this.sessionId,
    required this.endNumber,
    required this.arrowNumber,
    this.playerUserId,
    this.playerName,
    required this.scoreValue,
    required this.scoreNumeric,
    this.createdAt,
  });

  factory DbScoreDetail.fromJson(Map<String, dynamic> json) {
    return DbScoreDetail(
      id: json['id']?.toString(),
      sessionId: json['session_id']?.toString() ?? '',
      endNumber: (json['end_number'] as num?)?.toInt() ?? 0,
      arrowNumber: (json['arrow_number'] as num?)?.toInt() ?? 0,
      playerUserId: json['player_user_id']?.toString(),
      playerName: json['player_name']?.toString(),
      scoreValue: json['score_value']?.toString() ?? '',
      scoreNumeric: (json['score_numeric'] as num?)?.toInt() ?? 0,
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'end_number': endNumber,
      'arrow_number': arrowNumber,
      'player_user_id': playerUserId,
      'player_name': playerName,
      'score_value': scoreValue,
      'score_numeric': scoreNumeric,
      'created_at': DbHelpers.formatTimestamp(createdAt),
    };
  }
}
