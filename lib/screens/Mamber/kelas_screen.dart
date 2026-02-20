import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/supabase/db_attendance.dart';
import '../../utils/user_data.dart';
import '../../services/attendance_service.dart';
import '../attendance_scanner_screen.dart';

enum ClassStatus { upcoming, ongoing, completed }

class ClassSchedule {
  final String id;
  final String className;
  final String coach;
  final String coachId;
  final DateTime dateTime;
  final String duration;
  final String location;
  final int maxParticipants;
  final int currentParticipants;
  final int attendanceCount;
  final ClassStatus status;
  final bool isEnrolled;
  final bool hasAttended;
  final String? attendanceCode;
  final DateTime? attendanceGeneratedAt;

  ClassSchedule({
    required this.id,
    required this.className,
    required this.coach,
    required this.coachId,
    required this.dateTime,
    required this.duration,
    required this.location,
    required this.maxParticipants,
    required this.currentParticipants,
    this.attendanceCount = 0,
    required this.status,
    this.isEnrolled = false,
    this.hasAttended = false,
    this.attendanceCode,
    this.attendanceGeneratedAt,
  });

  ClassSchedule copyWith({
    String? id,
    String? className,
    String? coach,
    DateTime? dateTime,
    String? duration,
    String? location,
    int? maxParticipants,
    int? currentParticipants,
    int? attendanceCount,
    ClassStatus? status,
    bool? isEnrolled,
    bool? hasAttended,
    String? attendanceCode,
    DateTime? attendanceGeneratedAt,
  }) {
    return ClassSchedule(
      id: id ?? this.id,
      className: className ?? this.className,
      coach: coach ?? this.coach,
      coachId: coachId ?? this.coachId,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      status: status ?? this.status,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      hasAttended: hasAttended ?? this.hasAttended,
      attendanceCode: attendanceCode ?? this.attendanceCode,
      attendanceGeneratedAt:
          attendanceGeneratedAt ?? this.attendanceGeneratedAt,
    );
  }
}

class KelasScreen extends StatefulWidget {
  const KelasScreen({super.key});

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  List<ClassSchedule> _classes = [];
  String _selectedFilter = 'Semua';
  bool _isCoach = false;
  String _activeRole = 'non_member';
  bool _isLoading = true;
  bool _supportsEnrollment = true;
  String? _errorMessage;
  String? _currentUserId;
  final SupabaseClient _client = Supabase.instance.client;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchClasses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final userData = UserData();
    await userData.loadData();
    if (!mounted) return;
    setState(() {
      _activeRole = userData.role;
      _isCoach = _activeRole == 'coach' || _activeRole == 'admin';
    });
  }

  Future<List<Map<String, dynamic>>> _fetchPublicProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return const [];
    }

    try {
      final response = await _client.rpc(
        'list_user_public_profiles',
        params: {'user_ids': userIds},
      );
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      final fallback = await _client
          .from('users')
          .select('id, full_name')
          .inFilter('id', userIds);
      return List<Map<String, dynamic>>.from(fallback as List);
    }
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User belum login.');
      }
      _currentUserId = user.id;

      final classRows = await _client
          .from('training_classes')
          .select()
          .order('scheduled_at', ascending: true);

      final classes = (classRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      if (classes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _classes = [];
          _isLoading = false;
        });
        return;
      }

      final classIds = classes
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .toList();

      final coachIds = classes
          .map((row) => row['coach_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final coachNames = <String, String>{};
      if (coachIds.isNotEmpty) {
        final coachRows = await _fetchPublicProfiles(coachIds);
        for (final row in coachRows) {
          final data = Map<String, dynamic>.from(row);
          final id = data['id']?.toString();
          if (id == null || id.isEmpty) continue;
          coachNames[id] = data['full_name']?.toString() ?? 'Pelatih';
        }
      }

      final sessionRows = await _client
          .from('attendance_sessions')
          .select('id,class_id,qr_token,expires_at,is_active,created_at')
          .inFilter('class_id', classIds);

      final sessions = (sessionRows as List)
          .map((row) => DbAttendanceSession.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      final sessionByClass = <String, DbAttendanceSession>{};
      final sessionIdToClassId = <String, String>{};
      for (final session in sessions) {
        sessionIdToClassId[session.id] = session.classId;
        if (!session.isActive) continue;
        final existing = sessionByClass[session.classId];
        if (existing == null) {
          sessionByClass[session.classId] = session;
          continue;
        }
        final existingTime = existing.createdAt ?? DateTime(1970);
        final newTime = session.createdAt ?? DateTime(1970);
        if (newTime.isAfter(existingTime)) {
          sessionByClass[session.classId] = session;
        }
      }

      final sessionIds =
          sessions.map((session) => session.id).where((id) => id.isNotEmpty).toList();

      final attendanceCounts = <String, int>{};
      final attendedClassIds = <String>{};

      if (sessionIds.isNotEmpty) {
        final recordRows = await _client
            .from('attendance_records')
            .select('attendance_session_id,user_id,status')
            .inFilter('attendance_session_id', sessionIds);
        for (final row in recordRows as List) {
          final data = Map<String, dynamic>.from(row as Map);
          final sessionId = data['attendance_session_id']?.toString();
          if (sessionId == null) continue;
          final classId = sessionIdToClassId[sessionId];
          if (classId == null) continue;
          attendanceCounts[classId] = (attendanceCounts[classId] ?? 0) + 1;
          if (data['user_id']?.toString() == user.id) {
            attendedClassIds.add(classId);
          }
        }
      }

      final enrollCounts = <String, int>{};
      final enrolledClassIds = <String>{};
      bool supportsEnrollment = true;
      try {
        final enrollRows = await _client
            .from('training_class_enrollments')
            .select('class_id,user_id')
            .inFilter('class_id', classIds);
        for (final row in enrollRows as List) {
          final data = Map<String, dynamic>.from(row as Map);
          final classId = data['class_id']?.toString();
          if (classId == null) continue;
          enrollCounts[classId] = (enrollCounts[classId] ?? 0) + 1;
          if (data['user_id']?.toString() == user.id) {
            enrolledClassIds.add(classId);
          }
        }
      } catch (_) {
        supportsEnrollment = false;
      }

      final now = DateTime.now();
      final mapped = classes.map((row) {
        final classId = row['id']?.toString() ?? '';
        final coachId = row['coach_id']?.toString() ?? '';
        final scheduledAtRaw = row['scheduled_at']?.toString();
        final scheduledAt =
            DateTime.tryParse(scheduledAtRaw ?? '') ?? now;
        final durationMinutes =
            (row['duration_minutes'] as num?)?.toInt() ?? 120;
        final status = _resolveStatus(scheduledAt, durationMinutes, now);
        final maxParticipants =
            (row['max_participants'] as num?)?.toInt() ??
            (row['maxParticipants'] as num?)?.toInt() ??
            20;
        final currentParticipants = supportsEnrollment
            ? (enrollCounts[classId] ?? 0)
            : (attendanceCounts[classId] ?? 0);
        final isEnrolled = supportsEnrollment
            ? enrolledClassIds.contains(classId)
            : attendedClassIds.contains(classId);
        final hasAttended = attendedClassIds.contains(classId);
        final session = sessionByClass[classId];
        return ClassSchedule(
          id: classId,
          className: row['title']?.toString() ?? 'Kelas',
          coach: coachNames[coachId] ?? 'Pelatih',
          coachId: coachId,
          dateTime: scheduledAt,
          duration: _formatDuration(durationMinutes),
          location: row['location']?.toString() ?? '-',
          maxParticipants: maxParticipants,
          currentParticipants: currentParticipants,
          attendanceCount: attendanceCounts[classId] ?? 0,
          status: status,
          isEnrolled: isEnrolled,
          hasAttended: hasAttended,
          attendanceCode: session?.qrToken,
          attendanceGeneratedAt: session?.createdAt,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _classes = mapped;
        _supportsEnrollment = supportsEnrollment;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  ClassStatus _resolveStatus(
    DateTime start,
    int durationMinutes,
    DateTime now,
  ) {
    final end = start.add(Duration(minutes: durationMinutes));
    if (now.isBefore(start)) {
      return ClassStatus.upcoming;
    }
    if (now.isAfter(end)) {
      return ClassStatus.completed;
    }
    return ClassStatus.ongoing;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '-';
    final hours = minutes / 60;
    if (hours < 1) {
      return '$minutes menit';
    }
    if (hours % 1 == 0) {
      return '${hours.toInt()} jam';
    }
    return '${hours.toStringAsFixed(1)} jam';
  }

  Future<void> _showCreateClassSheet() async {
    if (!_isCoach) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya pelatih yang bisa membuat kelas.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final rootContext = context;
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final durationController = TextEditingController(text: '120');
    final maxParticipantsController = TextEditingController(text: '20');
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool isSubmitting = false;
    String? errorText;

    void setError(StateSetter setModalState, String message) {
      setModalState(() {
        errorText = message;
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateLabel = selectedDate == null
                ? 'Pilih tanggal'
                : DateFormat('EEEE, dd MMMM yyyy').format(selectedDate!);
            final timeLabel = selectedTime == null
                ? 'Pilih jam'
                : selectedTime!.format(rootContext);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Buat Kelas Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nama Kelas',
                        hintText: 'Contoh: Teknik Dasar Recurve',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? now,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 2),
                              );
                              if (!context.mounted) return;
                              if (picked == null) return;
                              setModalState(() {
                                selectedDate = picked;
                              });
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(dateLabel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B982),
                              side: const BorderSide(
                                color: Color(0xFF10B982),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    selectedTime ?? TimeOfDay.now(),
                              );
                              if (!context.mounted) return;
                              if (picked == null) return;
                              setModalState(() {
                                selectedTime = picked;
                              });
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(timeLabel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B982),
                              side: const BorderSide(
                                color: Color(0xFF10B982),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Durasi (menit)',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Lokasi',
                        hintText: 'Contoh: Lapangan Indoor',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxParticipantsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Maksimal Peserta',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  setError(
                                    setModalState,
                                    'Nama kelas wajib diisi.',
                                  );
                                  return;
                                }
                                if (selectedDate == null ||
                                    selectedTime == null) {
                                  setError(
                                    setModalState,
                                    'Tanggal dan jam wajib dipilih.',
                                  );
                                  return;
                                }
                                final duration =
                                    int.tryParse(durationController.text) ??
                                        0;
                                if (duration <= 0) {
                                  setError(
                                    setModalState,
                                    'Durasi harus lebih dari 0.',
                                  );
                                  return;
                                }

                                final maxParticipants = int.tryParse(
                                      maxParticipantsController.text,
                                    ) ??
                                    0;
                                final selected = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                                final user = _client.auth.currentUser;
                                if (user == null) {
                                  setError(
                                    setModalState,
                                    'User belum login.',
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });

                                final payload = <String, dynamic>{
                                  'coach_id': user.id,
                                  'title': title,
                                  'scheduled_at': selected.toIso8601String(),
                                  'duration_minutes': duration,
                                };
                                final location =
                                    locationController.text.trim();
                                if (location.isNotEmpty) {
                                  payload['location'] = location;
                                }
                                if (maxParticipants > 0) {
                                  payload['max_participants'] =
                                      maxParticipants;
                                }

                                try {
                                  await _client
                                      .from('training_classes')
                                      .insert(payload);
                                } catch (e) {
                                  final message = e.toString();
                                  if (message.contains('max_participants')) {
                                    payload.remove('max_participants');
                                    await _client
                                        .from('training_classes')
                                        .insert(payload);
                                  } else {
                                    rethrow;
                                  }
                                }

                                if (!mounted) return;
                                Navigator.pop(context);
                                await _fetchClasses();
                                if (!mounted) return;
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kelas berhasil dibuat.'),
                                    backgroundColor: Color(0xFF10B982),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B982),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan Kelas'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<ClassSchedule> get filteredClasses {
    if (_selectedFilter == 'Semua') return _classes;

    ClassStatus? filterStatus;
    switch (_selectedFilter) {
      case 'Akan Datang':
        filterStatus = ClassStatus.upcoming;
        break;
      case 'Berlangsung':
        filterStatus = ClassStatus.ongoing;
        break;
      case 'Selesai':
        filterStatus = ClassStatus.completed;
        break;
    }

    return _classes.where((c) => c.status == filterStatus).toList();
  }

  Future<void> _enrollClass(int index) async {
    if (!_supportsEnrollment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran kelas belum tersedia.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final classItem = _classes[index];
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum login.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _client.from('training_class_enrollments').insert({
        'class_id': classItem.id,
        'user_id': user.id,
      });
      await _fetchClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil mendaftar kelas!'),
          backgroundColor: Color(0xFF10B982),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftar kelas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelEnrollment(int index) async {
    if (!_supportsEnrollment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran kelas belum tersedia.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final classItem = _classes[index];
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum login.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _client
          .from('training_class_enrollments')
          .delete()
          .eq('class_id', classItem.id)
          .eq('user_id', user.id);
      await _fetchClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran kelas dibatalkan'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolledCount = _classes.where((c) => c.isEnrolled).length;
    final attendedCount = _classes.where((c) => c.hasAttended).length;
    final createdCount = _isCoach
        ? _classes.where((c) => c.coachId == _currentUserId).length
        : 0;
    final totalAttendance = _isCoach
        ? _classes
            .where((c) => c.coachId == _currentUserId)
            .fold<int>(0, (sum, c) => sum + c.attendanceCount)
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: _isCoach
          ? FloatingActionButton.extended(
              onPressed: _showCreateClassSheet,
              backgroundColor: const Color(0xFF10B982),
              icon: const Icon(Icons.add),
              label: const Text('Buat Kelas'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF10B982), Color(0xFF059669)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard(
                            _isCoach ? 'Kelas Dibuat' : 'Kelas Terdaftar',
                            (_isCoach ? createdCount : enrolledCount)
                                .toString(),
                            Icons.class_,
                          ),
                          _buildStatCard(
                            _isCoach ? 'Total Kehadiran' : 'Kehadiran',
                            (_isCoach ? totalAttendance : attendedCount)
                                .toString(),
                            Icons.check_circle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Filter Chips
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Semua'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Akan Datang'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Berlangsung'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Selesai'),
                      ],
                    ),
                  ),
                ),
                // Classes List
                Expanded(
                  child: filteredClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada kelas',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kelas akan dibuat oleh pelatih',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchClasses,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredClasses.length,
                            itemBuilder: (context, index) {
                              final classItem = filteredClasses[index];
                              final actualIndex =
                                  _classes.indexOf(classItem);
                              return _buildClassCard(
                                classItem,
                                actualIndex,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: const Color(0xFF10B982),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildClassCard(ClassSchedule classItem, int index) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    final safeMaxParticipants =
        classItem.maxParticipants <= 0 ? 1 : classItem.maxParticipants;

    switch (classItem.status) {
      case ClassStatus.upcoming:
        statusColor = const Color(0xFF3B82F6);
        statusText = 'Akan Datang';
        statusIcon = Icons.schedule;
        break;
      case ClassStatus.ongoing:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Berlangsung';
        statusIcon = Icons.play_circle;
        break;
      case ClassStatus.completed:
        statusColor = const Color(0xFF6B7280);
        statusText = 'Selesai';
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: classItem.isEnrolled
            ? Border.all(color: const Color(0xFF10B982), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    classItem.className,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  classItem.coach,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B982),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(classItem.dateTime),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('HH:mm').format(classItem.dateTime)} (${classItem.duration})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  classItem.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        classItem.currentParticipants / safeMaxParticipants,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      classItem.currentParticipants >= safeMaxParticipants
                          ? Colors.red
                          : const Color(0xFF10B982),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${classItem.currentParticipants}/$safeMaxParticipants',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            if (_isCoach &&
                classItem.attendanceCode != null &&
                classItem.status != ClassStatus.completed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code,
                      size: 18,
                      color: Color(0xFF10B982),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR aktif: ${classItem.attendanceCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B982),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (classItem.status == ClassStatus.completed &&
                (_activeRole == 'member' || classItem.isEnrolled)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: classItem.hasAttended
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      classItem.hasAttended ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: classItem.hasAttended
                          ? const Color(0xFF10B982)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      classItem.hasAttended ? 'Hadir' : 'Tidak Hadir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: classItem.hasAttended
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_activeRole == 'member' &&
                classItem.status == ClassStatus.ongoing &&
                (classItem.isEnrolled || !_supportsEnrollment)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: classItem.hasAttended
                    ? ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Sudah Hadir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B982),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _startScanFlow(index),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan QR Absensi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B982),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
            ],
            if (_isCoach &&
                (classItem.status == ClassStatus.upcoming ||
                    classItem.status == ClassStatus.ongoing)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCoachQrSheet(index),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: Text(
                    classItem.attendanceCode == null
                        ? 'Generate QR Absensi'
                        : 'Lihat QR Absensi',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B982),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            if (!_isCoach &&
                classItem.status == ClassStatus.upcoming &&
                _supportsEnrollment) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: classItem.isEnrolled
                    ? OutlinedButton.icon(
                        onPressed: () => _cancelEnrollment(index),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Batalkan Pendaftaran'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed:
                            classItem.currentParticipants >=
                                classItem.maxParticipants
                            ? null
                            : () => _enrollClass(index),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(
                          classItem.currentParticipants >=
                                  classItem.maxParticipants
                              ? 'Kelas Penuh'
                              : 'Daftar Kelas',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B982),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                        ),
                      ),
              ),
            ],
            if (!_isCoach &&
                classItem.status == ClassStatus.upcoming &&
                !_supportsEnrollment) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Pendaftaran kelas belum tersedia. Absensi cukup dengan QR saat kelas berlangsung.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1D4ED8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCoachQrSheet(int index) async {
    if (!_isCoach) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya pelatih yang bisa generate QR.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final classItem = _classes[index];
    DbAttendanceSession? session;
    try {
      session = await _attendanceService.fetchActiveSession(classItem.id);
      session ??= await _attendanceService.generateSession(classItem.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal generate QR: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _classes[index] = classItem.copyWith(
        attendanceCode: session?.qrToken,
        attendanceGeneratedAt: session?.createdAt,
      );
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        var sheetCode = session?.qrToken ?? '';
        var sheetGeneratedAt = session?.createdAt ?? DateTime.now();
        var sheetExpiresAt = session?.expiresAt;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QR Absensi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    classItem.className,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B982),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: sheetCode,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sheetCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B982),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dibuat ${DateFormat('HH:mm').format(sheetGeneratedAt)}'
                          '${sheetExpiresAt != null ? ' • Berlaku sampai ${DateFormat('HH:mm').format(sheetExpiresAt!)}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Minta peserta scan QR ini untuk konfirmasi hadir.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final newSession = await _attendanceService
                              .generateSession(classItem.id);
                          setState(() {
                            _classes[index] = classItem.copyWith(
                              attendanceCode: newSession.qrToken,
                              attendanceGeneratedAt: newSession.createdAt,
                            );
                          });
                          setModalState(() {
                            sheetCode = newSession.qrToken;
                            sheetGeneratedAt =
                                newSession.createdAt ?? DateTime.now();
                            sheetExpiresAt = newSession.expiresAt;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal perbarui QR: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Perbarui QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B982),
                        side: const BorderSide(color: Color(0xFF10B982)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startScanFlow(int index) async {
    if (_activeRole != 'member') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan QR hanya untuk member.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final classItem = _classes[index];
    if (_supportsEnrollment && !classItem.isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda belum terdaftar di kelas ini.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScannerScreen(
          className: classItem.className,
        ),
      ),
    );

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final result = await _attendanceService.markAttendance(token);
      if (result.session.classId != classItem.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR ini bukan untuk kelas ini.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        return;
      }
      setState(() {
        _classes[index] = classItem.copyWith(hasAttended: true);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Absensi berhasil!'),
          backgroundColor: Color(0xFF10B982),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal absensi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
