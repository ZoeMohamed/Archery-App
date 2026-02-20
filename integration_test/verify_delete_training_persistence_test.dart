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
  late SupabaseTrainingService service;

  setUpAll(() async {
    await Supabase.initialize(
      url: _defaultSupabaseUrl,
      anonKey: _defaultAnonKey,
      debug: false,
    );
    client = Supabase.instance.client;
    service = SupabaseTrainingService(client: client);
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  testWidgets('deleted training does not reappear after re-fetch', (
    tester,
  ) async {
    final email = Platform.environment['SUPABASE_TEST_EMAIL'];
    final password = Platform.environment['SUPABASE_TEST_PASSWORD'];
    if (email == null || password == null) {
      fail(
        'Set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD to run this integration test.',
      );
    }

    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(auth.user, isNotNull);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TrainingSession(
      id: 'verify_delete_$marker',
      date: DateTime.now(),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 1,
      arrowsPerRound: 2,
      targetType: 'Default',
      inputMethod: 'arrow_values',
      scores: {
        'Saya': [
          ['6', '5'],
        ],
      },
      trainingName: 'VERIFY_DELETE_$marker',
    );

    String? sessionId;
    try {
      sessionId = await service.saveTrainingSession(session);
      expect(sessionId, isNotEmpty);

      final beforeDelete = await service.fetchTrainingHistory();
      expect(beforeDelete.any((item) => item.supabaseId == sessionId), isTrue);

      await service.deleteTrainingSession(sessionId);

      final afterDelete = await service.fetchTrainingHistory();
      expect(afterDelete.any((item) => item.supabaseId == sessionId), isFalse);
    } finally {
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          await client
              .from('score_details')
              .delete()
              .eq('session_id', sessionId);
        } catch (_) {}
        try {
          await client.from('training_sessions').delete().eq('id', sessionId);
        } catch (_) {}
      }
    }
  });
}
