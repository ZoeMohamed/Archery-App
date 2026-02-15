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
                (name) =>
                    DbGroupMember(name: name, initials: _initialsForName(name)),
              )
              .toList()
        : null;

    return DbTrainingSession(
      userId: userId,
      trainingDate: local.date,
      mode: mode,
      targetType: _mapTargetType(local.targetType),
      inputMethod: local.inputMethod,
      distance: distance,
      trainingName: local.trainingName,
      numberOfPlayers: local.numberOfPlayers,
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
          final playerLabel = playerUserId == null ? playerName : null;
          final hit = _extractHitCoordinate(
            local,
            playerName: playerName,
            roundIndex: roundIndex,
            arrowIndex: arrowIndex,
          );
          details.add(
            DbScoreDetail(
              sessionId: sessionId,
              endNumber: roundIndex + 1,
              arrowNumber: arrowIndex + 1,
              playerUserId: playerUserId,
              playerName: playerLabel,
              scoreValue: scoreValue,
              scoreNumeric: local.convertScoreToInt(scoreValue),
              hitX: hit?['x'],
              hitY: hit?['y'],
            ),
          );
        }
      }
    }
    return details;
  }

  static TrainingSession toLocalSession(
    DbTrainingSession dbSession,
    List<DbScoreDetail> details,
  ) {
    final playerNames = _resolvePlayerNames(dbSession, details);
    final resolvedNames = playerNames.isEmpty ? ['Saya'] : playerNames;
    final totalEnds = dbSession.totalEnds;
    final arrowsPerEnd = dbSession.arrowsPerEnd;
    final scores = <String, List<List<String>>>{};
    for (final name in resolvedNames) {
      scores[name] = List.generate(
        totalEnds,
        (_) => List.filled(arrowsPerEnd, 'M'),
      );
    }

    final userIdToName = <String, String>{};
    final groupMembers = dbSession.groupMembers ?? [];
    for (final member in groupMembers) {
      if ((member.userId ?? '').isNotEmpty && member.name.isNotEmpty) {
        userIdToName[member.userId!] = member.name;
      }
    }

    for (final detail in details) {
      final playerName = _resolveDetailPlayerName(
        detail,
        resolvedNames,
        userIdToName,
      );
      if (!scores.containsKey(playerName)) {
        scores[playerName] = List.generate(
          totalEnds,
          (_) => List.filled(arrowsPerEnd, 'M'),
        );
        resolvedNames.add(playerName);
      }
      final roundIndex = detail.endNumber - 1;
      final arrowIndex = detail.arrowNumber - 1;
      if (roundIndex < 0 ||
          roundIndex >= totalEnds ||
          arrowIndex < 0 ||
          arrowIndex >= arrowsPerEnd) {
        continue;
      }
      scores[playerName]![roundIndex][arrowIndex] = detail.scoreValue;
    }

    final numberOfPlayers = dbSession.numberOfPlayers ?? resolvedNames.length;
    final restoredCoordinates = _restoreHitCoordinates(
      dbSession: dbSession,
      details: details,
      playerNames: resolvedNames,
      scores: scores,
      userIdToName: userIdToName,
      totalEnds: totalEnds,
      arrowsPerEnd: arrowsPerEnd,
    );

    return TrainingSession(
      id: dbSession.id ?? '',
      supabaseId: dbSession.id,
      date: DateTime(
        dbSession.trainingDate.year,
        dbSession.trainingDate.month,
        dbSession.trainingDate.day,
      ),
      numberOfPlayers: numberOfPlayers > 0 ? numberOfPlayers : 1,
      playerNames: resolvedNames,
      numberOfRounds: totalEnds,
      arrowsPerRound: arrowsPerEnd,
      targetType: _mapTargetTypeToLocal(dbSession.targetType),
      inputMethod: dbSession.inputMethod,
      scores: scores,
      hitCoordinates: restoredCoordinates,
      trainingName: _normalizeTrainingName(dbSession),
    );
  }

  static String _mapTargetType(String localTarget) {
    final normalized = localTarget.toLowerCase();
    if (normalized.contains('animal')) {
      return 'animal';
    }
    return 'bullet';
  }

  static String _mapTargetTypeToLocal(String targetType) {
    if (targetType.toLowerCase().contains('animal')) {
      return 'Target Animal';
    }
    return 'Default';
  }

  static List<String> _resolvePlayerNames(
    DbTrainingSession dbSession,
    List<DbScoreDetail> details,
  ) {
    if (dbSession.mode == 'individual') {
      return ['Saya'];
    }

    final groupMembers = dbSession.groupMembers ?? [];
    if (groupMembers.isNotEmpty) {
      return groupMembers
          .map((member) => member.name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }

    final names = <String>[];
    for (final detail in details) {
      final name = detail.playerName?.trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      if (!names.contains(name)) {
        names.add(name);
      }
    }
    if (names.isNotEmpty) {
      return names;
    }

    final count = dbSession.numberOfPlayers ?? 0;
    if (count > 0) {
      return List.generate(count, (index) => 'Pemain ${index + 1}');
    }

    return ['Saya'];
  }

  static String _resolveDetailPlayerName(
    DbScoreDetail detail,
    List<String> fallbackNames,
    Map<String, String> userIdToName,
  ) {
    final explicitName = detail.playerName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      return explicitName;
    }
    final mappedName = userIdToName[detail.playerUserId ?? ''];
    if (mappedName != null && mappedName.isNotEmpty) {
      return mappedName;
    }
    return fallbackNames.isNotEmpty ? fallbackNames.first : 'Saya';
  }

  static String? _normalizeTrainingName(DbTrainingSession session) {
    final name = session.trainingName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final notes = session.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }
    return null;
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
    final letters = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase());
    return letters.join();
  }

  static Map<String, double>? _extractHitCoordinate(
    TrainingSession session, {
    required String playerName,
    required int roundIndex,
    required int arrowIndex,
  }) {
    final playerRounds = session.hitCoordinates?[playerName];
    if (playerRounds == null || roundIndex >= playerRounds.length) {
      return null;
    }
    final roundHits = playerRounds[roundIndex];
    if (arrowIndex >= roundHits.length) {
      return null;
    }
    final hit = roundHits[arrowIndex];
    final x = hit['x'];
    final y = hit['y'];
    if (x == null || y == null) {
      return null;
    }
    return {'x': x, 'y': y};
  }

  static Map<String, List<List<Map<String, double>>>>? _restoreHitCoordinates({
    required DbTrainingSession dbSession,
    required List<DbScoreDetail> details,
    required List<String> playerNames,
    required Map<String, List<List<String>>> scores,
    required Map<String, String> userIdToName,
    required int totalEnds,
    required int arrowsPerEnd,
  }) {
    final shouldIncludeCoordinates =
        dbSession.inputMethod == 'target_face' ||
        details.any((detail) => detail.hitX != null && detail.hitY != null);
    if (!shouldIncludeCoordinates) {
      return null;
    }

    final coordinates = <String, List<List<Map<String, double>>>>{};
    for (final name in playerNames) {
      coordinates[name] = List.generate(
        totalEnds,
        (_) => List.generate(arrowsPerEnd, (_) => {'x': 0.0, 'y': 0.0}),
      );
    }

    for (final detail in details) {
      final hitX = detail.hitX;
      final hitY = detail.hitY;
      if (hitX == null || hitY == null) {
        continue;
      }
      final playerName = _resolveDetailPlayerName(
        detail,
        playerNames,
        userIdToName,
      );
      if (!coordinates.containsKey(playerName)) {
        coordinates[playerName] = List.generate(
          totalEnds,
          (_) => List.generate(arrowsPerEnd, (_) => {'x': 0.0, 'y': 0.0}),
        );
        if (!scores.containsKey(playerName)) {
          scores[playerName] = List.generate(
            totalEnds,
            (_) => List.filled(arrowsPerEnd, 'M'),
          );
        }
      }
      final roundIndex = detail.endNumber - 1;
      final arrowIndex = detail.arrowNumber - 1;
      if (roundIndex < 0 ||
          roundIndex >= totalEnds ||
          arrowIndex < 0 ||
          arrowIndex >= arrowsPerEnd) {
        continue;
      }
      coordinates[playerName]![roundIndex][arrowIndex] = {'x': hitX, 'y': hitY};
    }

    return coordinates;
  }
}
