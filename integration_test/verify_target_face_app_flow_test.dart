import 'dart:io';

import 'package:al_ihsan_archery/services/supabase_training_service.dart';
import 'package:al_ihsan_archery/utils/training_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _defaultSupabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
const String _defaultAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;

  setUpAll(() async {
    await Supabase.initialize(
      url: _defaultSupabaseUrl,
      anonKey: _defaultAnonKey,
      debug: false,
    );
    client = Supabase.instance.client;
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  testWidgets('target-face app flow stores input_method and hit coordinates', (
    tester,
  ) async {
    final email =
        Platform.environment['SUPABASE_TEST_EMAIL'] ?? 'user@klub.com';
    final password =
        Platform.environment['SUPABASE_TEST_PASSWORD'] ?? '22110436*';

    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(auth.user, isNotNull);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TrainingSession(
      id: 'verify_ui_like_$marker',
      date: DateTime.now(),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Face Ring 6',
      inputMethod: 'target_face',
      scores: {
        'Saya': [
          ['6', '4'],
        ],
      },
      hitCoordinates: {
        'Saya': [
          [
            {'x': 0.11, 'y': -0.22},
            {'x': -0.33, 'y': 0.44},
          ],
        ],
      },
      trainingName: 'VERIFY_UI_FLOW_$marker',
    );

    String? sessionId;
    try {
      sessionId = await SupabaseTrainingService(
        client: client,
      ).saveTrainingSession(session);
      expect(sessionId, isNotEmpty);

      final sessionRow = await client
          .from('training_sessions')
          .select('id,input_method,target_face_type,training_name')
          .eq('id', sessionId)
          .single();
      final sessionData = Map<String, dynamic>.from(sessionRow);
      expect(sessionData['input_method'], 'target_face');
      expect(sessionData['target_face_type'], 'Face Ring 6');

      final detailRows = await client
          .from('score_details')
          .select('arrow_number,score_value,hit_x,hit_y')
          .eq('session_id', sessionId)
          .order('arrow_number', ascending: true);

      final rows = List<Map<String, dynamic>>.from(detailRows);
      expect(rows.length, 2);
      expect(rows[0]['score_value'], '6');
      expect(rows[0]['hit_x'], isNotNull);
      expect(rows[0]['hit_y'], isNotNull);
      expect(rows[1]['score_value'], '4');
      expect(rows[1]['hit_x'], isNotNull);
      expect(rows[1]['hit_y'], isNotNull);
    } finally {
      if (sessionId != null && sessionId.isNotEmpty) {
        await client.from('score_details').delete().eq('session_id', sessionId);
        await client.from('training_sessions').delete().eq('id', sessionId);
      }
    }
  });
}
