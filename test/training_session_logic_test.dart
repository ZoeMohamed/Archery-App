import 'package:al_ihsan_archery/utils/training_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convertScoreToInt handles X, M, empty, numeric, and invalid', () {
    final session = TrainingSession(
      id: '1',
      date: DateTime(2026, 1, 1),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 1,
      targetType: 'Default',
      scores: const {
        'Saya': [
          ['X'],
        ],
      },
    );

    expect(session.convertScoreToInt('X'), 10);
    expect(session.convertScoreToInt('M'), 0);
    expect(session.convertScoreToInt(''), 0);
    expect(session.convertScoreToInt('7'), 7);
    expect(session.convertScoreToInt('abc'), 0);
  });

  test('getTotalScore and getAverageScore compute correctly', () {
    final session = TrainingSession(
      id: '2',
      date: DateTime(2026, 1, 2),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 2,
      arrowsPerRound: 3,
      targetType: 'Default',
      scores: const {
        'Saya': [
          ['10', '9', '8'],
          ['7', '6', 'M'],
        ],
      },
    );

    expect(session.getTotalScore('Saya'), 40);
    expect(session.getAverageScore('Saya'), closeTo(40 / 6, 0.0001));
  });

  test('isComplete detects incomplete score matrix', () {
    final complete = TrainingSession(
      id: '3',
      date: DateTime(2026, 1, 3),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 2,
      arrowsPerRound: 2,
      targetType: 'Default',
      scores: const {
        'Saya': [
          ['1', '2'],
          ['3', '4'],
        ],
      },
    );
    expect(complete.isComplete(), isTrue);

    final missingArrow = TrainingSession(
      id: '4',
      date: DateTime(2026, 1, 4),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 2,
      arrowsPerRound: 2,
      targetType: 'Default',
      scores: const {
        'Saya': [
          ['1', '2'],
          ['3'],
        ],
      },
    );
    expect(missingArrow.isComplete(), isFalse);

    final emptyScore = TrainingSession(
      id: '5',
      date: DateTime(2026, 1, 5),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Default',
      scores: const {
        'Saya': [
          ['1', ''],
        ],
      },
    );
    expect(emptyScore.isComplete(), isFalse);
  });

  test('toJson/fromJson keeps hitCoordinates and metadata', () {
    final original = TrainingSession(
      id: '6',
      supabaseId: 'supa-6',
      date: DateTime(2026, 2, 1),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Face Ring 6',
      inputMethod: 'target_face',
      scores: const {
        'Saya': [
          ['6', '5'],
        ],
      },
      hitCoordinates: const {
        'Saya': [
          [
            {'x': 0.1, 'y': 0.2},
            {'x': -0.3, 'y': 0.4},
          ],
        ],
      },
      trainingName: 'Roundtrip Test',
    );

    final encoded = original.toJson();
    final decoded = TrainingSession.fromJson(encoded);

    expect(decoded.id, original.id);
    expect(decoded.supabaseId, original.supabaseId);
    expect(decoded.inputMethod, 'target_face');
    expect(decoded.targetType, 'Face Ring 6');
    expect(decoded.trainingName, 'Roundtrip Test');
    expect(decoded.hitCoordinates, isNotNull);
    expect(decoded.hitCoordinates!['Saya']![0][0]['x'], closeTo(0.1, 0.0001));
    expect(decoded.hitCoordinates!['Saya']![0][1]['y'], closeTo(0.4, 0.0001));
  });
}
