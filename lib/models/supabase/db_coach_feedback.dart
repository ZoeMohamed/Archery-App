import 'db_helpers.dart';

class DbCoachFeedback {
  final String? id;
  final String coachId;
  final String athleteId;
  final String? sessionId;
  final String feedbackText;
  final String feedbackType;
  final int? rating;
  final DateTime? createdAt;

  const DbCoachFeedback({
    this.id,
    required this.coachId,
    required this.athleteId,
    this.sessionId,
    required this.feedbackText,
    this.feedbackType = 'general',
    this.rating,
    this.createdAt,
  });

  factory DbCoachFeedback.fromJson(Map<String, dynamic> json) {
    return DbCoachFeedback(
      id: json['id']?.toString(),
      coachId: json['coach_id']?.toString() ?? '',
      athleteId: json['athlete_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      feedbackText: json['feedback_text']?.toString() ?? '',
      feedbackType: json['feedback_type']?.toString() ?? 'general',
      rating: (json['rating'] as num?)?.toInt(),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_id': coachId,
      'athlete_id': athleteId,
      'session_id': sessionId,
      'feedback_text': feedbackText,
      'feedback_type': feedbackType,
      'rating': rating,
      'created_at': DbHelpers.formatTimestamp(createdAt),
    };
  }
}
