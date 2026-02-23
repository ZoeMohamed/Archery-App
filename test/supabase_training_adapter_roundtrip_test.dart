import 'package:al_ihsan_archery/adapters/supabase_training_adapter.dart';
import 'package:al_ihsan_archery/models/supabase/db_score_detail.dart';
import 'package:al_ihsan_archery/models/supabase/db_training_session.dart';
import 'package:al_ihsan_archery/utils/training_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toDbSession maps group session and target type correctly', () {
    final local = TrainingSession(
      id: 'local-group',
      date: DateTime(2026, 1, 10),
      numberOfPlayers: 2,
      playerNames: const ['Ali', 'Budi'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Target Animal',
      scores: const {
        'Ali': [
          ['5', '4'],
        ],
        'Budi': [
          ['3', '2'],
        ],
      },
    );

    final db = SupabaseTrainingAdapter.toDbSession(
      local,
      userId: 'user-1',
      distance: '20m',
    );

    expect(db.userId, 'user-1');
    expect(db.mode, 'group');
    expect(db.targetType, 'animal');
    expect(db.targetFaceType, 'Target Animal');
    expect(db.totalEnds, 1);
    expect(db.arrowsPerEnd, 2);
    expect(db.groupMembers, isNotNull);
    expect(db.groupMembers!.length, 2);
    expect(db.groupMembers!.first.initials, 'A');
  });

  test('toScoreDetails stores coordinates and player id mapping', () {
    final local = TrainingSession(
      id: 'local-1',
      date: DateTime(2026, 1, 11),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Face Ring 6',
      inputMethod: 'target_face',
      scores: const {
        'Saya': [
          ['6', '4'],
        ],
      },
      hitCoordinates: const {
        'Saya': [
          [
            {'x': 0.11, 'y': -0.22},
            {'x': -0.33, 'y': 0.44},
          ],
        ],
      },
    );

    final details = SupabaseTrainingAdapter.toScoreDetails(
      local,
      sessionId: 'session-1',
      playerIds: const {'Saya': 'user-1'},
    );

    expect(details.length, 2);
    expect(details[0].playerUserId, 'user-1');
    expect(details[0].playerName, isNull);
    expect(details[0].scoreNumeric, 6);
    expect(details[0].hitX, closeTo(0.11, 0.0001));
    expect(details[0].hitY, closeTo(-0.22, 0.0001));
    expect(details[1].scoreNumeric, 4);
    expect(details[1].hitX, closeTo(-0.33, 0.0001));
    expect(details[1].hitY, closeTo(0.44, 0.0001));
  });

  test(
    'toLocalSession infers target type from hit coordinates when missing',
    () {
      final dbSession = DbTrainingSession(
        id: 'db-1',
        userId: 'user-1',
        trainingDate: DateTime(2026, 1, 12),
        mode: 'individual',
        targetType: 'bullet',
        targetFaceType: null,
        inputMethod: 'target_face',
        totalEnds: 1,
        arrowsPerEnd: 2,
        numberOfPlayers: 1,
        trainingName: 'DB Session',
      );

      final details = <DbScoreDetail>[
        const DbScoreDetail(
          sessionId: 'db-1',
          endNumber: 1,
          arrowNumber: 1,
          scoreValue: '6',
          scoreNumeric: 6,
          hitX: 0.0,
          hitY: 0.0,
        ),
        const DbScoreDetail(
          sessionId: 'db-1',
          endNumber: 1,
          arrowNumber: 2,
          scoreValue: '5',
          scoreNumeric: 5,
          hitX: 0.2,
          hitY: 0.0,
        ),
      ];

      final local = SupabaseTrainingAdapter.toLocalSession(dbSession, details);

      expect(local.playerNames, contains('Saya'));
      expect(local.scores['Saya']![0][0], '6');
      expect(local.scores['Saya']![0][1], '5');
      expect(local.targetType, 'Face Ring 6');
      expect(local.hitCoordinates, isNotNull);
      expect(local.hitCoordinates!['Saya']![0][0]['x'], closeTo(0.0, 0.0001));
    },
  );
}
