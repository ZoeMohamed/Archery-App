import 'db_helpers.dart';

class DbAttendanceSession {
  final String id;
  final String classId;
  final String coachId;
  final String qrToken;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime? createdAt;

  const DbAttendanceSession({
    required this.id,
    required this.classId,
    required this.coachId,
    required this.qrToken,
    this.expiresAt,
    this.isActive = true,
    this.createdAt,
  });

  factory DbAttendanceSession.fromJson(Map<String, dynamic> json) {
    return DbAttendanceSession(
      id: json['id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      coachId: json['coach_id']?.toString() ?? '',
      qrToken: json['qr_token']?.toString() ?? '',
      expiresAt: DbHelpers.parseTimestamp(json['expires_at']),
      isActive: json['is_active'] == null ? true : json['is_active'] == true,
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
    );
  }
}

class DbAttendanceRecord {
  final String id;
  final String attendanceSessionId;
  final String userId;
  final String status;
  final DateTime? scannedAt;

  const DbAttendanceRecord({
    required this.id,
    required this.attendanceSessionId,
    required this.userId,
    required this.status,
    this.scannedAt,
  });

  factory DbAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return DbAttendanceRecord(
      id: json['id']?.toString() ?? '',
      attendanceSessionId:
          json['attendance_session_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'present',
      scannedAt: DbHelpers.parseTimestamp(json['scanned_at']),
    );
  }
}
