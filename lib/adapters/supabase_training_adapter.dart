import '../models/supabase/db_score_detail.dart';
import '../models/supabase/db_training_session.dart';
import '../utils/training_data.dart';

class SupabaseTrainingAdapter {
  static DbTrainingSession toDbSession(
    TrainingSession local, {
    required String userId,
    String? distance,
    String? notes,
  }) {
    final isGroup = local.numberOfPlayers > 1;
    final mode = isGroup ? 'group' : 'individual';
    final groupMembers = isGroup
        ? local.playerNames
            .map(
              (name) => DbGroupMember(
                name: name,
                initials: _initialsForName(name),
              ),
            )
            .toList()
        : null;

    return DbTrainingSession(
      userId: userId,
      trainingDate: local.date,
      mode: mode,
      targetType: _mapTargetType(local.targetType),
      distance: distance,
      totalEnds: local.numberOfRounds,
      arrowsPerEnd: local.arrowsPerRound,
      groupMembers: groupMembers,
      notes: notes,
    );
  }

  static List<DbScoreDetail> toScoreDetails(
    TrainingSession local, {
    required String sessionId,
    Map<String, String>? playerIds,
    String? defaultUserId,
  }) {
    final details = <DbScoreDetail>[];
    for (final playerName in local.playerNames) {
      final rounds = local.scores[playerName] ?? [];
      for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
        final arrows = rounds[roundIndex];
        for (var arrowIndex = 0; arrowIndex < arrows.length; arrowIndex++) {
          final scoreValue = arrows[arrowIndex];
          if (scoreValue.isEmpty) {
            continue;
          }
          final playerUserId =
              playerIds?[playerName] ?? _defaultPlayerId(local, defaultUserId);
          final playerLabel =
              playerUserId == null ? playerName : null;
          details.add(
            DbScoreDetail(
              sessionId: sessionId,
              endNumber: roundIndex + 1,
              arrowNumber: arrowIndex + 1,
              playerUserId: playerUserId,
              playerName: playerLabel,
              scoreValue: scoreValue,
              scoreNumeric: local.convertScoreToInt(scoreValue),
            ),
          );
        }
      }
    }
    return details;
  }

  static String _mapTargetType(String localTarget) {
    final normalized = localTarget.toLowerCase();
    if (normalized.contains('animal')) {
      return 'animal';
    }
    return 'bullet';
  }

  static String? _defaultPlayerId(
    TrainingSession local,
    String? defaultUserId,
  ) {
    if (local.numberOfPlayers == 1) {
      return defaultUserId;
    }
    return null;
  }

  static String _initialsForName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.where((part) => part.isNotEmpty).take(2).map(
          (part) => part[0].toUpperCase(),
        );
    return letters.join();
  }
}
