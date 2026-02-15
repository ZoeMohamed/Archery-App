import 'package:al_ihsan_archery/adapters/supabase_training_adapter.dart';
import 'package:al_ihsan_archery/models/supabase/db_score_detail.dart';
import 'package:al_ihsan_archery/models/supabase/db_training_session.dart';
import 'package:flutter_test/flutter_test.dart';

DbTrainingSession _baseSession({
  String? targetFaceType,
  String inputMethod = 'target_face',
}) {
  return DbTrainingSession(
    id: 'session-1',
    userId: 'user-1',
    trainingDate: DateTime(2026, 2, 15),
    mode: 'individual',
    targetType: 'bullet',
    targetFaceType: targetFaceType,
    inputMethod: inputMethod,
    totalEnds: 1,
    arrowsPerEnd: 4,
  );
}

void main() {
  test('uses stored target_face_type when available', () {
    final session = _baseSession(targetFaceType: 'Ring Puta');
    final details = [
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 1,
        scoreValue: '2',
        scoreNumeric: 2,
        hitX: 0.1,
        hitY: 0.1,
      ),
    ];

    final local = SupabaseTrainingAdapter.toLocalSession(session, details);
    expect(local.targetType, 'Ring Puta');
  });

  test('infers Face Ring 6 from legacy hit coordinates', () {
    final session = _baseSession(targetFaceType: null);
    final details = [
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 1,
        scoreValue: '4',
        scoreNumeric: 4,
        hitX: 0.05,
        hitY: -0.37,
      ),
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 2,
        scoreValue: '2',
        scoreNumeric: 2,
        hitX: 0.72,
        hitY: -0.42,
      ),
    ];

    final local = SupabaseTrainingAdapter.toLocalSession(session, details);
    expect(local.targetType, 'Face Ring 6');
  });

  test('infers Face Mega Mendung from legacy hit coordinates', () {
    final session = _baseSession(targetFaceType: null);
    final details = [
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 1,
        scoreValue: '4',
        scoreNumeric: 4,
        hitX: 0.0,
        hitY: 0.74,
      ),
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 2,
        scoreValue: '2',
        scoreNumeric: 2,
        hitX: 0.0,
        hitY: 0.9,
      ),
    ];

    final local = SupabaseTrainingAdapter.toLocalSession(session, details);
    expect(local.targetType, 'Face Mega Mendung');
  });

  test('keeps Default when input method is arrow_values', () {
    final session = _baseSession(
      targetFaceType: null,
      inputMethod: 'arrow_values',
    );
    final details = [
      const DbScoreDetail(
        sessionId: 'session-1',
        endNumber: 1,
        arrowNumber: 1,
        scoreValue: '8',
        scoreNumeric: 8,
      ),
    ];

    final local = SupabaseTrainingAdapter.toLocalSession(session, details);
    expect(local.targetType, 'Default');
  });
}
