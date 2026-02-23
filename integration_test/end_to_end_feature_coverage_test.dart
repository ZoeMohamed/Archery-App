import 'dart:io';
import 'dart:math';

import 'package:al_ihsan_archery/services/attendance_service.dart';
import 'package:al_ihsan_archery/services/supabase_payment_service.dart';
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
  late SupabaseTrainingService trainingService;
  late SupabasePaymentService paymentService;
  late AttendanceService attendanceService;
  late String email;
  late String password;
  late String userId;
  late List<String> roles;

  Future<void> signIn() async {
    await client.auth.signOut();
    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(auth.user, isNotNull);
    userId = auth.user!.id;
  }

  setUpAll(() async {
    final envEmail = Platform.environment['SUPABASE_TEST_EMAIL'];
    final envPassword = Platform.environment['SUPABASE_TEST_PASSWORD'];
    if (envEmail == null || envPassword == null) {
      fail(
        'Set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD to run this integration test.',
      );
    }
    email = envEmail;
    password = envPassword;

    await _ensureSupabaseInitialized();
    client = Supabase.instance.client;
    trainingService = SupabaseTrainingService(client: client);
    paymentService = SupabasePaymentService(client: client);
    attendanceService = AttendanceService(client: client);

    await signIn();
    final profile = await client
        .from('users')
        .select('roles')
        .eq('id', userId)
        .maybeSingle();
    roles = _parseRoles(profile?['roles']);
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  testWidgets(
    'profile update works and role escalation from client is blocked',
    (tester) async {
      await signIn();

      final original = await client
          .from('users')
          .select('full_name,phone_number')
          .eq('id', userId)
          .single();
      final originalData = Map<String, dynamic>.from(original);

      final marker = DateTime.now().millisecondsSinceEpoch.toString();
      final newName = 'E2E Profile $marker';
      final newPhone = '0812${marker.substring(marker.length - 8)}';

      try {
        await client
            .from('users')
            .update({'full_name': newName, 'phone_number': newPhone})
            .eq('id', userId);

        final updated = await client
            .from('users')
            .select('full_name,phone_number')
            .eq('id', userId)
            .single();
        final updatedData = Map<String, dynamic>.from(updated);
        expect(updatedData['full_name'], newName);
        expect(updatedData['phone_number'], newPhone);

        Future<void> escalation() async {
          await client
              .from('users')
              .update({
                'roles': ['admin'],
              })
              .eq('id', userId);
        }

        await expectLater(escalation(), throwsException);
      } finally {
        await client
            .from('users')
            .update({
              'full_name': originalData['full_name'],
              'phone_number': originalData['phone_number'],
            })
            .eq('id', userId);
      }
    },
  );

  testWidgets('disposable registration flow creates and persists profile', (
    tester,
  ) async {
    await signIn();

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final disposableEmail = 'e2e.reg.$marker@example.com';
    final disposablePassword = 'Tmp!$marker' 'aA';

    String? disposableUserId;
    try {
      await client.auth.signOut();
      final signUp = await client.auth.signUp(
        email: disposableEmail,
        password: disposablePassword,
        emailRedirectTo: null,
      );
      disposableUserId = signUp.user?.id;
      expect(disposableUserId, isNotNull);

      // Ensure session exists for the newly created account.
      if (client.auth.currentUser?.id != disposableUserId) {
        final relogin = await client.auth.signInWithPassword(
          email: disposableEmail,
          password: disposablePassword,
        );
        disposableUserId = relogin.user?.id ?? disposableUserId;
      }

      expect(client.auth.currentUser?.id, disposableUserId);
      final profilePayload = {
        'id': disposableUserId,
        'email': disposableEmail,
        'full_name': 'E2E Registrasi $marker',
        'phone_number': '0812${marker.substring(marker.length - 8)}',
        'birth_date': '2000-01-01',
        'roles': ['non_member'],
        'active_role': 'non_member',
      };

      try {
        await client.from('users').insert(profilePayload);
      } catch (error) {
        final text = error.toString().toLowerCase();
        final duplicate =
            text.contains('duplicate') ||
            text.contains('already exists') ||
            text.contains('23505');
        if (!duplicate) {
          rethrow;
        }
        await client
            .from('users')
            .update({
              'email': disposableEmail,
              'full_name': 'E2E Registrasi $marker',
              'phone_number': '0812${marker.substring(marker.length - 8)}',
              'birth_date': '2000-01-01',
              'active_role': 'non_member',
            })
            .eq('id', disposableUserId!);
      }

      final profile = await client
          .from('users')
          .select('id,email,full_name,active_role,roles')
          .eq('id', disposableUserId!)
          .single();
      final profileData = Map<String, dynamic>.from(profile);
      expect(profileData['email'], disposableEmail);
      expect(profileData['full_name'], 'E2E Registrasi $marker');
      expect(profileData['active_role'], 'non_member');
      expect(_parseRoles(profileData['roles']).contains('non_member'), isTrue);

      await client.auth.signOut();
      final loginAgain = await client.auth.signInWithPassword(
        email: disposableEmail,
        password: disposablePassword,
      );
      expect(loginAgain.user?.id, disposableUserId);
    } finally {
      // Sign back in to the main test account for subsequent tests.
      await signIn();
    }
  });

  testWidgets('active role switch persists for owned role', (tester) async {
    await signIn();

    final profile = await client
        .from('users')
        .select('roles,active_role')
        .eq('id', userId)
        .single();
    final data = Map<String, dynamic>.from(profile);
    final currentRoles = _parseRoles(data['roles']);
    final originalActiveRole = data['active_role']?.toString() ?? 'non_member';

    expect(currentRoles.isNotEmpty, isTrue);
    expect(currentRoles.contains(originalActiveRole), isTrue);

    final targetRole = currentRoles.firstWhere(
      (role) => role != originalActiveRole,
      orElse: () => originalActiveRole,
    );

    try {
      await client
          .from('users')
          .update({'active_role': targetRole})
          .eq('id', userId);

      final updated = await client
          .from('users')
          .select('active_role')
          .eq('id', userId)
          .single();
      expect(updated['active_role'], targetRole);
    } finally {
      await _safeRun(
        () => client
            .from('users')
            .update({'active_role': originalActiveRole})
            .eq('id', userId),
      );
    }
  });

  testWidgets('settings read and write works for admin role', (tester) async {
    await signIn();
    expect(roles.contains('admin'), isTrue);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final key = 'e2e_setting_$marker';
    final inserted = await client
        .from('settings')
        .insert({
          'key': key,
          'value': '1',
          'data_type': 'number',
          'description': 'E2E settings test',
        })
        .select('id,key,value,data_type')
        .single();
    final insertedData = Map<String, dynamic>.from(inserted);
    final settingId = insertedData['id']?.toString();
    expect(settingId, isNotNull);
    expect(insertedData['key'], key);

    try {
      await client.from('settings').update({'value': '2'}).eq('id', settingId!);
      final updated = await client
          .from('settings')
          .select('id,key,value')
          .eq('id', settingId)
          .single();
      final updatedData = Map<String, dynamic>.from(updated);
      expect(updatedData['value'], '2');
    } finally {
      await _safeRun(
        () => client.from('settings').delete().eq('id', settingId!),
      );
    }
  });

  testWidgets('notifications query for user/global works', (tester) async {
    await signIn();

    final response = await client
        .from('notifications')
        .select('id,user_id,title,message,created_at')
        .or('user_id.eq.$userId,user_id.is.null')
        .order('created_at', ascending: false)
        .limit(20);

    final rows = List<Map<String, dynamic>>.from(response as List);
    for (final row in rows) {
      final owner = row['user_id']?.toString();
      expect(owner == null || owner == userId, isTrue);
    }
  });

  testWidgets('training create, read history, and delete flow works', (
    tester,
  ) async {
    await signIn();

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TrainingSession(
      id: 'e2e_training_$marker',
      date: DateTime.now(),
      numberOfPlayers: 1,
      playerNames: const ['Saya'],
      numberOfRounds: 2,
      arrowsPerRound: 3,
      targetType: 'Face Ring 6',
      inputMethod: 'target_face',
      scores: {
        'Saya': [
          ['6', '5', '4'],
          ['3', '2', '1'],
        ],
      },
      hitCoordinates: {
        'Saya': [
          [
            {'x': 0.10, 'y': 0.10},
            {'x': 0.20, 'y': 0.10},
            {'x': 0.30, 'y': 0.20},
          ],
          [
            {'x': 0.40, 'y': 0.20},
            {'x': 0.50, 'y': 0.30},
            {'x': 0.60, 'y': 0.30},
          ],
        ],
      },
      trainingName: 'E2E TRAINING $marker',
    );

    String? sessionId;
    try {
      sessionId = await trainingService.saveTrainingSession(session);
      expect(sessionId, isNotEmpty);

      final sessionRow = await client
          .from('training_sessions')
          .select('id,user_id,total_ends,arrows_per_end')
          .eq('id', sessionId)
          .single();
      final saved = Map<String, dynamic>.from(sessionRow);
      expect(saved['user_id'], userId);
      expect(saved['total_ends'], 2);
      expect(saved['arrows_per_end'], 3);

      final scoreRows = await client
          .from('score_details')
          .select('id')
          .eq('session_id', sessionId);
      expect((scoreRows as List).length, 6);

      final history = await trainingService.fetchTrainingHistory();
      expect(history.any((item) => item.supabaseId == sessionId), isTrue);

      await trainingService.deleteTrainingSession(sessionId);

      final afterDelete = await client
          .from('training_sessions')
          .select('id')
          .eq('id', sessionId);
      expect((afterDelete as List).isEmpty, isTrue);
      sessionId = null;
    } finally {
      if (sessionId != null && sessionId.isNotEmpty) {
        await _safeRun(
          () => client
              .from('score_details')
              .delete()
              .eq('session_id', sessionId!),
        );
        await _safeRun(
          () => client.from('training_sessions').delete().eq('id', sessionId!),
        );
      }
    }
  });

  testWidgets('payment proof upload, payment creation, and signed URL work', (
    tester,
  ) async {
    await signIn();

    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final marker = now.millisecondsSinceEpoch.toString();
    final tempFile = await _createTempImageFile(marker);

    String? storagePath;
    String? paymentId;
    try {
      storagePath = await paymentService.uploadPaymentProof(
        file: tempFile,
        userId: userId,
        paymentMonth: month,
      );
      expect(storagePath, isNotEmpty);

      final created = await paymentService.createMonthlyPayment(
        userId: userId,
        amount: 100000,
        proofUrl: storagePath,
        paymentMonth: month,
        notes: 'E2E payment $marker',
      );
      paymentId = created['id']?.toString();
      expect(paymentId, isNotNull);

      final payment = await paymentService.fetchPaymentById(paymentId!);
      expect(payment, isNotNull);
      expect(payment!['user_id'], userId);
      expect(payment['status'], 'pending');

      final signedUrl = await paymentService.resolveProofUrl(storagePath);
      expect(signedUrl, isNotNull);
      expect(signedUrl, contains('/storage/v1/object/sign/'));

      final list = await paymentService.fetchMonthlyPaymentsForUser(userId);
      expect(list.any((item) => item.id == paymentId), isTrue);
    } finally {
      if (paymentId != null && paymentId.isNotEmpty) {
        await _safeRun(
          () => client.from('payments').delete().eq('id', paymentId!),
        );
      }
      if (storagePath != null && storagePath.isNotEmpty) {
        await _safeRun(
          () => client.storage
              .from(SupabasePaymentService.paymentBucket)
              .remove([storagePath!]),
        );
      }
      if (await tempFile.exists()) {
        await _safeRun(() => tempFile.delete());
      }
    }
  });

  testWidgets('payment can be verified by admin/staff role', (tester) async {
    await signIn();

    final now = DateTime.now();
    final marker = now.millisecondsSinceEpoch.toString();
    // Use a per-run unique date to avoid collisions with historical verified rows.
    final month = DateTime(
      now.year + 20,
      (now.millisecond % 12) + 1,
      (now.microsecond % 27) + 1,
    );
    final tempFile = await _createTempImageFile('verify_$marker');

    String? storagePath;
    String? paymentId;
    try {
      storagePath = await paymentService.uploadPaymentProof(
        file: tempFile,
        userId: userId,
        paymentMonth: month,
      );

      final created = await paymentService.createMonthlyPayment(
        userId: userId,
        amount: 100000,
        proofUrl: storagePath,
        paymentMonth: month,
        notes: 'E2E verify payment $marker',
      );
      paymentId = created['id']?.toString();
      expect(paymentId, isNotNull);

      await client
          .from('payments')
          .update({
            'status': 'verified',
            'verified_by': userId,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId!);

      final verified = await client
          .from('payments')
          .select('id,status,verified_by')
          .eq('id', paymentId)
          .single();
      final verifiedData = Map<String, dynamic>.from(verified);
      expect(verifiedData['status'], 'verified');
      expect(verifiedData['verified_by'], userId);
    } finally {
      if (paymentId != null && paymentId.isNotEmpty) {
        await _safeRun(
          () => client.from('payments').delete().eq('id', paymentId!),
        );
      }
      if (storagePath != null && storagePath.isNotEmpty) {
        await _safeRun(
          () => client.storage
              .from(SupabasePaymentService.paymentBucket)
              .remove([storagePath!]),
        );
      }
      if (await tempFile.exists()) {
        await _safeRun(() => tempFile.delete());
      }
    }
  });

  testWidgets('KTA application and storage flow work', (tester) async {
    await signIn();

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final tempFile = await _createTempImageFile(marker);
    final storagePath = 'kta/$userId/e2e_kta_$marker.jpg';
    String? applicationId;

    try {
      await client.storage
          .from('kta_app')
          .upload(
            storagePath,
            tempFile,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final inserted = await client
          .from('kta_applications')
          .insert({
            'user_id': userId,
            'confirmed_name': 'E2E User',
            'confirmed_birth_place': 'Jakarta',
            'confirmed_birth_date': '2000-01-01',
            'confirmed_address': 'E2E Street 123',
            'kta_photo_url': storagePath,
            'status': 'pending',
          })
          .select('id,status,user_id')
          .single();

      final row = Map<String, dynamic>.from(inserted);
      applicationId = row['id']?.toString();
      expect(applicationId, isNotNull);
      expect(row['status'], 'pending');
      expect(row['user_id'], userId);
    } finally {
      if (applicationId != null && applicationId.isNotEmpty) {
        await _safeRun(
          () =>
              client.from('kta_applications').delete().eq('id', applicationId!),
        );
      }
      await _safeRun(
        () => client.storage.from('kta_app').remove([storagePath]),
      );
      if (await tempFile.exists()) {
        await _safeRun(() => tempFile.delete());
      }
    }
  });

  testWidgets('coach feedback create/read/delete works', (tester) async {
    await signIn();
    final hasCoachRole = roles.contains('coach') || roles.contains('admin');
    expect(hasCoachRole, isTrue);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    String? feedbackId;
    try {
      final inserted = await client
          .from('coach_feedback')
          .insert({
            'coach_id': userId,
            'athlete_id': userId,
            'feedback_text': 'E2E coach feedback $marker',
            'feedback_type': 'general',
            'rating': 5,
          })
          .select('id,coach_id,athlete_id,feedback_type,rating')
          .single();
      final insertedData = Map<String, dynamic>.from(inserted);
      feedbackId = insertedData['id']?.toString();
      expect(feedbackId, isNotNull);
      expect(insertedData['coach_id'], userId);
      expect(insertedData['athlete_id'], userId);

      final selected = await client
          .from('coach_feedback')
          .select('id,coach_id,athlete_id')
          .eq('id', feedbackId!)
          .single();
      final selectedData = Map<String, dynamic>.from(selected);
      expect(selectedData['id'], feedbackId);
    } finally {
      if (feedbackId != null && feedbackId.isNotEmpty) {
        await _safeRun(
          () => client.from('coach_feedback').delete().eq('id', feedbackId!),
        );
      }
    }
  });

  testWidgets('competition news create/update/delete works across schema variants', (
    tester,
  ) async {
    await signIn();
    expect(roles.contains('admin') || roles.contains('staff'), isTrue);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    String? newsId;
    try {
      final basePayload = {
        'title': 'E2E NEWS $marker',
        'content': 'Konten E2E competition',
        'competition_name': 'E2E Cup',
        'competition_date': '2026-02-21',
        'location': 'Jakarta',
        'category': 'Senior',
        'total_participants': 10,
        'is_published': true,
        'published_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic> insertedData;
      try {
        final inserted = await client
            .from('competition_news')
            .insert(basePayload)
            .select('id,title,is_published')
            .single();
        insertedData = Map<String, dynamic>.from(inserted);
      } catch (error) {
        final fallbackPayload = <String, dynamic>{
          ...basePayload,
          'winner_ids': [userId],
        };
        final inserted = await client
            .from('competition_news')
            .insert(fallbackPayload)
            .select('id,title,is_published')
            .single();
        insertedData = Map<String, dynamic>.from(inserted);
      }

      newsId = insertedData['id']?.toString();
      expect(newsId, isNotNull);
      expect(insertedData['is_published'], isTrue);

      await client
          .from('competition_news')
          .update({'title': 'E2E NEWS UPDATED $marker'})
          .eq('id', newsId!);

      final updated = await client
          .from('competition_news')
          .select('id,title,is_published')
          .eq('id', newsId)
          .single();
      final updatedData = Map<String, dynamic>.from(updated);
      expect(updatedData['title'], 'E2E NEWS UPDATED $marker');

      final feedRows = await _selectRowsWithColumnFallback(
        client: client,
        tableOrView: 'v_latest_competition_news',
        columns: [
          'id',
          'title',
          'competition_name',
          'competition_date',
          'published_at',
          'winner_names',
          'medals',
        ],
      );
      expect(feedRows.any((row) => row['id']?.toString() == newsId), isTrue);
    } finally {
      if (newsId != null && newsId.isNotEmpty) {
        await _safeRun(
          () => client
              .from('competition_winners')
              .delete()
              .eq('competition_news_id', newsId!),
        );
        await _safeRun(
          () => client.from('competition_news').delete().eq('id', newsId!),
        );
      }
    }
  });

  testWidgets('competition feed view query works across schema variants', (
    tester,
  ) async {
    await signIn();
    final rows = await _selectRowsWithColumnFallback(
      client: client,
      tableOrView: 'v_latest_competition_news',
      columns: [
        'id',
        'title',
        'competition_name',
        'competition_date',
        'published_at',
        'winner_names',
        'medals',
      ],
      orderBy: 'published_at',
    );

    for (final row in rows) {
      expect(row.containsKey('id'), isTrue);
      expect(row.containsKey('title'), isTrue);
    }
  });

  testWidgets('attendance class, QR session, and mark attendance flow work', (
    tester,
  ) async {
    await signIn();

    final hasCoachOrAdmin = roles.contains('coach') || roles.contains('admin');
    expect(
      hasCoachOrAdmin,
      isTrue,
      reason:
          'Test account needs coach/admin role for training class and attendance session creation.',
    );

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    String? classId;
    String? firstSessionId;
    String? secondSessionId;

    try {
      final classRow = await client
          .from('training_classes')
          .insert({
            'coach_id': userId,
            'title': 'E2E Class $marker',
            'scheduled_at': DateTime.now()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
            'duration_minutes': 90,
            'location': 'E2E Range',
          })
          .select('id')
          .single();
      classId = classRow['id']?.toString();
      expect(classId, isNotNull);

      final firstSession = await attendanceService.generateSession(
        classId!,
        ttl: const Duration(minutes: 20),
      );
      firstSessionId = firstSession.id;
      expect(firstSession.qrToken, isNotEmpty);

      final markResult = await attendanceService.markAttendance(
        firstSession.qrToken,
      );
      expect(markResult.record.userId, userId);
      expect(markResult.record.attendanceSessionId, firstSession.id);

      final active = await attendanceService.fetchActiveSession(classId);
      expect(active, isNotNull);
      expect(active!.id, firstSession.id);

      final secondSession = await attendanceService.generateSession(
        classId,
        ttl: const Duration(minutes: 25),
      );
      secondSessionId = secondSession.id;
      expect(secondSession.id, isNot(firstSession.id));

      final oldSessionRow = await client
          .from('attendance_sessions')
          .select('is_active')
          .eq('id', firstSession.id)
          .single();
      expect(oldSessionRow['is_active'], isFalse);
    } finally {
      if (secondSessionId != null && secondSessionId.isNotEmpty) {
        final sessionId = secondSessionId;
        await _safeRun(
          () => client
              .from('attendance_records')
              .delete()
              .eq('attendance_session_id', sessionId),
        );
      }
      if (firstSessionId != null && firstSessionId.isNotEmpty) {
        final sessionId = firstSessionId;
        await _safeRun(
          () => client
              .from('attendance_records')
              .delete()
              .eq('attendance_session_id', sessionId),
        );
      }
      if (secondSessionId != null && secondSessionId.isNotEmpty) {
        final sessionId = secondSessionId;
        await _safeRun(
          () => client.from('attendance_sessions').delete().eq('id', sessionId),
        );
      }
      if (firstSessionId != null && firstSessionId.isNotEmpty) {
        final sessionId = firstSessionId;
        await _safeRun(
          () => client.from('attendance_sessions').delete().eq('id', sessionId),
        );
      }
      if (classId != null && classId.isNotEmpty) {
        final targetClassId = classId;
        await _safeRun(
          () =>
              client.from('training_classes').delete().eq('id', targetClassId),
        );
      }
    }
  });

  testWidgets('invalid QR token is rejected', (tester) async {
    await signIn();
    final invalidToken =
        'invalid-token-${DateTime.now().millisecondsSinceEpoch}';
    Future<void> attempt() async {
      await attendanceService.markAttendance(invalidToken);
    }

    await expectLater(attempt(), throwsException);
  });
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: _defaultSupabaseUrl,
      anonKey: _defaultAnonKey,
      debug: false,
    );
  }
}

List<String> _parseRoles(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return <String>[];
}

Future<File> _createTempImageFile(String suffix) async {
  final random = Random();
  final bytes = List<int>.generate(512, (_) => random.nextInt(256));
  final file = File('${Directory.systemTemp.path}/al_ihsan_e2e_$suffix.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> _safeRun(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> _selectRowsWithColumnFallback({
  required SupabaseClient client,
  required String tableOrView,
  required List<String> columns,
  String? orderBy,
}) async {
  final requestedColumns = List<String>.from(columns);
  final removedColumns = <String>{};

  while (true) {
    try {
      final baseQuery = client
          .from(tableOrView)
          .select(requestedColumns.join(','));
      final rows = orderBy != null && orderBy.trim().isNotEmpty
          ? await baseQuery.order(orderBy, ascending: false).limit(30)
          : await baseQuery.limit(30);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      final missing = _extractMissingColumn(error, tableOrView: tableOrView);
      if (missing == null || removedColumns.contains(missing)) {
        rethrow;
      }
      requestedColumns.remove(missing);
      removedColumns.add(missing);
    }
  }
}

String? _extractMissingColumn(Object error, {required String tableOrView}) {
  final text = error.toString();

  final schemaCachePattern = RegExp(
    "Could not find the '([^']+)' column of '$tableOrView'",
  );
  final schemaCacheMatch = schemaCachePattern.firstMatch(text);
  if (schemaCacheMatch != null) {
    return schemaCacheMatch.group(1);
  }

  final pgPattern = RegExp(
    'column\\s+$tableOrView\\.([a-zA-Z0-9_]+)\\s+does not exist',
    caseSensitive: false,
  );
  final pgMatch = pgPattern.firstMatch(text);
  return pgMatch?.group(1);
}
