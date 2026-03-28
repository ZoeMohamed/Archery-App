import '../models/supabase/db_score_detail.dart';
import '../models/supabase/db_training_session.dart';
import '../utils/training_data.dart';
import 'dart:math' as math;

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
      targetFaceType: local.targetType,
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
    final resolvedSessionDate = _resolveSessionDateTime(dbSession);
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
      date: resolvedSessionDate,
      numberOfPlayers: numberOfPlayers > 0 ? numberOfPlayers : 1,
      playerNames: resolvedNames,
      numberOfRounds: totalEnds,
      arrowsPerRound: arrowsPerEnd,
      targetType: _resolveLocalTargetType(dbSession, details),
      inputMethod: dbSession.inputMethod,
      distance: dbSession.distance,
      scores: scores,
      hitCoordinates: restoredCoordinates,
      trainingName: _normalizeTrainingName(dbSession),
    );
  }

  static DateTime _resolveSessionDateTime(DbTrainingSession dbSession) {
    final rawBaseDate = dbSession.trainingDate;
    final baseDate = rawBaseDate.isUtc ? rawBaseDate.toLocal() : rawBaseDate;
    final hasTimeComponent =
        baseDate.hour != 0 ||
        baseDate.minute != 0 ||
        baseDate.second != 0 ||
        baseDate.millisecond != 0 ||
        baseDate.microsecond != 0;

    if (hasTimeComponent) {
      return baseDate;
    }

    final createdAt = dbSession.createdAt;
    if (createdAt == null) {
      return baseDate;
    }

    final createdAtLocal = createdAt.isUtc ? createdAt.toLocal() : createdAt;
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      createdAtLocal.hour,
      createdAtLocal.minute,
      createdAtLocal.second,
      createdAtLocal.millisecond,
      createdAtLocal.microsecond,
    );
  }

  static String _mapTargetType(String localTarget) {
    final normalized = localTarget.toLowerCase();
    if (normalized.contains('animal')) {
      return 'animal';
    }
    return 'bullet';
  }

  static String _resolveLocalTargetType(
    DbTrainingSession dbSession,
    List<DbScoreDetail> details,
  ) {
    final storedTarget = dbSession.targetFaceType?.trim();
    if (storedTarget != null && storedTarget.isNotEmpty) {
      return storedTarget;
    }

    if (dbSession.targetType.toLowerCase().contains('animal')) {
      return 'Target Animal';
    }

    if (dbSession.inputMethod != 'target_face') {
      return 'Default';
    }

    final inferredFromHits = _inferTargetTypeFromHitCoordinates(details);
    if (inferredFromHits != null) {
      return inferredFromHits;
    }

    int maxScore = 0;
    for (final detail in details) {
      if (detail.scoreNumeric > maxScore) {
        maxScore = detail.scoreNumeric;
      }
    }
    if (maxScore >= 7) {
      return 'Face Mega Mendung';
    }
    if (maxScore > 0 && maxScore <= 2) {
      return 'Ring Puta';
    }
    return 'Face Ring 6';
  }

  static String? _inferTargetTypeFromHitCoordinates(
    List<DbScoreDetail> details,
  ) {
    final candidateTypes = ['Face Ring 6', 'Ring Puta', 'Face Mega Mendung'];
    final scoredDetails = details
        .where((detail) => detail.hitX != null && detail.hitY != null)
        .toList();
    if (scoredDetails.isEmpty) {
      return null;
    }

    String? bestType;
    int bestMatches = -1;
    int bestMismatches = 1 << 30;

    for (final type in candidateTypes) {
      int matches = 0;
      int mismatches = 0;
      for (final detail in scoredDetails) {
        final predicted = _predictScore(
          targetType: type,
          x: detail.hitX ?? 0.0,
          y: detail.hitY ?? 0.0,
        );
        if (predicted == detail.scoreNumeric) {
          matches++;
        } else {
          mismatches++;
        }
      }

      if (matches > bestMatches ||
          (matches == bestMatches && mismatches < bestMismatches)) {
        bestType = type;
        bestMatches = matches;
        bestMismatches = mismatches;
      }
    }

    if (bestType == null || bestMatches <= 0) {
      return null;
    }
    return bestType;
  }

  static int _predictScore({
    required String targetType,
    required double x,
    required double y,
  }) {
    final distance = math.sqrt((x * x) + (y * y));
    if (targetType == 'Face Ring 6') {
      if (distance <= 0.167) return 6;
      if (distance <= 0.334) return 5;
      if (distance <= 0.501) return 4;
      if (distance <= 0.668) return 3;
      if (distance <= 0.835) return 2;
      if (distance <= 1.0) return 1;
      return 0;
    }

    if (targetType == 'Ring Puta') {
      if (distance <= 0.4) return 2;
      if (distance <= 1.0) return 1;
      return 0;
    }

    return _predictMegaMendungScore(x, y);
  }

  static int _predictMegaMendungScore(double x, double y) {
    final upper = _checkPrismaAtas(x, y);
    if (upper > 0) {
      return upper;
    }
    final lower = _checkPrismaBawah(x, y);
    if (lower > 0) {
      return lower;
    }
    final distance = math.sqrt((x * x) + (y * y));
    if (distance <= 1.0) {
      return 1;
    }
    return 0;
  }

  static int _checkPrismaAtas(double x, double y) {
    final dy = y + 0.35;
    final dx = x;
    final distFromCenter = math.sqrt((dx * dx) + (dy * dy));
    if (distFromCenter <= 0.11) {
      return 10;
    }
    final dist = dx.abs() + dy.abs();
    if (dist <= 0.25) {
      return 9;
    }
    if (dist <= 0.35) {
      return 8;
    }
    if (dist <= 0.45) {
      return 7;
    }
    return 0;
  }

  static int _checkPrismaBawah(double x, double y) {
    final dy = y - 0.3;
    final dx = x;
    final distFromCenter = math.sqrt((dx * dx) + (dy * dy));
    if (distFromCenter <= 0.14) {
      return 6;
    }
    final dist = dx.abs() + dy.abs();
    if (dist <= 0.33) {
      return 5;
    }
    if (dist <= 0.45) {
      return 4;
    }
    if (dist <= 0.55) {
      return 3;
    }
    if (dist <= 0.65) {
      return 2;
    }
    return 0;
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
