import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/supabase/db_attendance.dart';

class AttendanceMarkResult {
  final DbAttendanceSession session;
  final DbAttendanceRecord record;

  const AttendanceMarkResult({required this.session, required this.record});
}

class AttendanceService {
  AttendanceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();

  Future<DbAttendanceSession?> fetchActiveSession(String classId) async {
    final response = await _client
        .from('attendance_sessions')
        .select()
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final session = DbAttendanceSession.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (_isExpired(session)) {
      await _deactivateSession(session.id);
      return null;
    }
    return session;
  }

  Future<DbAttendanceSession> generateSession(
    String classId, {
    Duration ttl = const Duration(minutes: 30),
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    await _deactivateActiveSessions(classId);

    final token = _uuid.v4();
    final expiresAt = DateTime.now().add(ttl);
    final payload = {
      'class_id': classId,
      'coach_id': user.id,
      'qr_token': token,
      'expires_at': expiresAt.toIso8601String(),
      'is_active': true,
    };

    final inserted = await _client
        .from('attendance_sessions')
        .insert(payload)
        .select()
        .single();

    return DbAttendanceSession.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<AttendanceMarkResult> markAttendance(String qrToken) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    final normalizedToken = qrToken.trim();
    if (normalizedToken.isEmpty) {
      throw Exception('QR tidak valid.');
    }

    final rpcResult = await _markAttendanceViaRpc(normalizedToken);
    if (rpcResult != null) {
      return rpcResult;
    }

    return _markAttendanceLegacy(normalizedToken, user.id);
  }

  Future<AttendanceMarkResult?> _markAttendanceViaRpc(String qrToken) async {
    try {
      final response = await _client.rpc(
        'mark_attendance_by_qr',
        params: {'p_qr_token': qrToken, 'p_status': 'present'},
      );

      final rows = response is List
          ? List<Map<String, dynamic>>.from(response)
          : response == null
          ? <Map<String, dynamic>>[]
          : [Map<String, dynamic>.from(response as Map)];
      if (rows.isEmpty) {
        return null;
      }

      final row = rows.first;
      final sessionId = row['attendance_session_id']?.toString() ?? '';
      final classId = row['class_id']?.toString() ?? '';
      final coachId = row['coach_id']?.toString() ?? '';
      final recordId = row['record_id']?.toString() ?? '';
      final recordUserId = row['user_id']?.toString() ?? '';
      final status = row['status']?.toString() ?? 'present';
      final scannedAt = _parseTimestamp(row['scanned_at']);

      if (sessionId.isEmpty || classId.isEmpty) {
        throw Exception('Data absensi tidak lengkap dari server.');
      }

      return AttendanceMarkResult(
        session: DbAttendanceSession(
          id: sessionId,
          classId: classId,
          coachId: coachId,
          qrToken: qrToken,
          createdAt: scannedAt,
        ),
        record: DbAttendanceRecord(
          id: recordId.isNotEmpty ? recordId : '$sessionId:$recordUserId',
          attendanceSessionId: sessionId,
          userId: recordUserId,
          status: status,
          scannedAt: scannedAt,
        ),
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      final rpcUnavailable =
          text.contains('mark_attendance_by_qr') &&
          (text.contains('does not exist') ||
              text.contains('pgrst202') ||
              text.contains('42883'));
      final rpcAmbiguousColumn =
          text.contains('42702') &&
          text.contains('attendance_session_id') &&
          text.contains('ambiguous');
      if (rpcUnavailable) {
        return null;
      }
      if (rpcAmbiguousColumn) {
        return null;
      }
      rethrow;
    }
  }

  Future<AttendanceMarkResult> _markAttendanceLegacy(
    String qrToken,
    String userId,
  ) async {
    final response = await _client
        .from('attendance_sessions')
        .select()
        .eq('qr_token', qrToken)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      throw Exception('QR tidak valid.');
    }

    final session = DbAttendanceSession.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (_isExpired(session)) {
      await _deactivateSession(session.id);
      throw Exception('QR sudah kadaluarsa.');
    }

    final recordPayload = {
      'attendance_session_id': session.id,
      'user_id': userId,
      'status': 'present',
    };

    final recordRow = await _client
        .from('attendance_records')
        .upsert(recordPayload, onConflict: 'attendance_session_id,user_id')
        .select()
        .single();

    final record = DbAttendanceRecord.fromJson(
      Map<String, dynamic>.from(recordRow),
    );

    return AttendanceMarkResult(session: session, record: record);
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<void> _deactivateActiveSessions(String classId) async {
    await _client
        .from('attendance_sessions')
        .update({'is_active': false})
        .eq('class_id', classId)
        .eq('is_active', true);
  }

  Future<void> _deactivateSession(String sessionId) async {
    await _client
        .from('attendance_sessions')
        .update({'is_active': false})
        .eq('id', sessionId);
  }

  bool _isExpired(DbAttendanceSession session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    return expiresAt.isBefore(DateTime.now());
  }
}
