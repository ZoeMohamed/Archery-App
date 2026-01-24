import 'package:supabase_flutter/supabase_flutter.dart';

import '../adapters/supabase_training_adapter.dart';
import '../models/supabase/db_score_detail.dart';
import '../models/supabase/db_training_session.dart';
import '../utils/training_data.dart';

class SupabaseTrainingService {
  SupabaseTrainingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> saveTrainingSession(
    TrainingSession session, {
    String? distance,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    final dbSession = SupabaseTrainingAdapter.toDbSession(
      session,
      userId: user.id,
      distance: distance,
    );
    final payload = _cleanPayload(dbSession.toJson());

    final inserted = await _client
        .from('training_sessions')
        .insert(payload)
        .select()
        .single();
    final savedSession = DbTrainingSession.fromJson(
      Map<String, dynamic>.from(inserted),
    );

    final details = SupabaseTrainingAdapter.toScoreDetails(
      session,
      sessionId: savedSession.id ?? '',
      defaultUserId: user.id,
    );
    if (details.isNotEmpty) {
      final detailPayload = details
          .map((detail) => _cleanPayload(detail.toJson()))
          .toList();
      await _client.from('score_details').insert(detailPayload);
    }

    return savedSession.id ?? '';
  }

  Future<List<TrainingSession>> fetchTrainingHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    final sessionRows = await _client
        .from('training_sessions')
        .select()
        .eq('user_id', user.id)
        .order('training_date', ascending: false);

    final dbSessions = (sessionRows as List)
        .map((row) => DbTrainingSession.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();

    if (dbSessions.isEmpty) {
      return [];
    }

    final sessionIds = dbSessions
        .map((session) => session.id)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    final detailsBySession = <String, List<DbScoreDetail>>{};
    if (sessionIds.isNotEmpty) {
      final detailRows = await _client
          .from('score_details')
          .select()
          .inFilter('session_id', sessionIds)
          .order('end_number', ascending: true)
          .order('arrow_number', ascending: true);

      for (final row in detailRows as List) {
        final detail = DbScoreDetail.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        detailsBySession.putIfAbsent(detail.sessionId, () => []).add(detail);
      }
    }

    return dbSessions.map((session) {
      final details = detailsBySession[session.id ?? ''] ?? [];
      return SupabaseTrainingAdapter.toLocalSession(session, details);
    }).toList();
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    final cleaned = <String, dynamic>{};
    payload.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is String && value.trim().isEmpty) {
        return;
      }
      if (value is List && value.isEmpty) {
        return;
      }
      cleaned[key] = value;
    });
    cleaned.remove('id');
    cleaned.remove('created_at');
    cleaned.remove('updated_at');
    return cleaned;
  }
}
