import 'package:flutter/foundation.dart';
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
      distance: distance ?? session.distance,
    );
    final payload = _cleanPayload(dbSession.toJson());

    final inserted = await _insertTrainingSessionWithFallback(payload);
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
      await _insertScoreDetailsWithFallback(detailPayload);
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
        .map(
          (row) =>
              DbTrainingSession.fromJson(Map<String, dynamic>.from(row as Map)),
        )
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

  Future<int> syncPendingSessions(List<TrainingSession> sessions) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    int syncedCount = 0;
    for (final session in sessions) {
      if (!session.isComplete()) {
        continue;
      }
      final supabaseId = session.supabaseId;
      if (supabaseId != null && supabaseId.isNotEmpty) {
        continue;
      }
      try {
        final savedId = await saveTrainingSession(session);
        if (savedId.isNotEmpty) {
          session.supabaseId = savedId;
          syncedCount++;
        }
      } catch (e) {
        // Keep going; a single failure shouldn't block the rest.
        debugPrint('Failed to sync training session: $e');
      }
    }
    return syncedCount;
  }

  Future<void> deleteTrainingSession(String sessionId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }
    if (sessionId.trim().isEmpty) {
      throw Exception('ID training tidak valid.');
    }

    final deleted = await _client
        .from('training_sessions')
        .delete()
        .eq('id', sessionId)
        .eq('user_id', user.id)
        .select('id');

    final rows = List<Map<String, dynamic>>.from(deleted as List);
    if (rows.isEmpty) {
      throw Exception('Training tidak ditemukan atau tidak punya akses hapus.');
    }
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

  Future<Map<String, dynamic>> _insertTrainingSessionWithFallback(
    Map<String, dynamic> originalPayload,
  ) async {
    final payload = Map<String, dynamic>.from(originalPayload);
    final removedColumns = <String>{};

    while (true) {
      try {
        final inserted = await _client
            .from('training_sessions')
            .insert(payload)
            .select()
            .single();
        return Map<String, dynamic>.from(inserted);
      } catch (error) {
        final missing = _extractMissingColumn(
          error,
          table: 'training_sessions',
        );
        if (missing == null || removedColumns.contains(missing)) {
          rethrow;
        }
        payload.remove(missing);
        removedColumns.add(missing);
        debugPrint(
          'training_sessions missing column "$missing", retrying without it.',
        );
      }
    }
  }

  Future<void> _insertScoreDetailsWithFallback(
    List<Map<String, dynamic>> originalPayload,
  ) async {
    var payload = originalPayload
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final removedColumns = <String>{};

    while (true) {
      try {
        await _client.from('score_details').insert(payload);
        return;
      } catch (error) {
        final missing = _extractMissingColumn(error, table: 'score_details');
        if (missing == null || removedColumns.contains(missing)) {
          rethrow;
        }
        payload = payload.map((row) {
          row.remove(missing);
          return row;
        }).toList();
        removedColumns.add(missing);
        debugPrint(
          'score_details missing column "$missing", retrying without it.',
        );
      }
    }
  }

  String? _extractMissingColumn(Object error, {required String table}) {
    final text = error.toString();
    final pattern = RegExp("Could not find the '([^']+)' column of '$table'");
    final match = pattern.firstMatch(text);
    return match?.group(1);
  }
}
