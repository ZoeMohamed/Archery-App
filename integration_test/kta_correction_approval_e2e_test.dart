import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _defaultSupabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
const String _defaultAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;
  late String adminEmail;
  late String adminPassword;
  late String adminUserId;
  late List<String> adminRoles;

  Future<void> signInAsAdmin() async {
    await client.auth.signOut();
    final auth = await client.auth.signInWithPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(auth.user, isNotNull);
    adminUserId = auth.user!.id;
  }

  setUpAll(() async {
    final envEmail = Platform.environment['SUPABASE_TEST_EMAIL'];
    final envPassword = Platform.environment['SUPABASE_TEST_PASSWORD'];
    final defineEmail = const String.fromEnvironment('SUPABASE_TEST_EMAIL');
    final definePassword = const String.fromEnvironment(
      'SUPABASE_TEST_PASSWORD',
    );
    final resolvedEmail = (envEmail != null && envEmail.trim().isNotEmpty)
        ? envEmail
        : (defineEmail.trim().isNotEmpty ? defineEmail : null);
    final resolvedPassword =
        (envPassword != null && envPassword.trim().isNotEmpty)
        ? envPassword
        : (definePassword.trim().isNotEmpty ? definePassword : null);
    if (resolvedEmail == null || resolvedPassword == null) {
      fail(
        'Set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD to run this integration test.',
      );
    }
    adminEmail = resolvedEmail;
    adminPassword = resolvedPassword;

    await _ensureSupabaseInitialized();
    client = Supabase.instance.client;

    await signInAsAdmin();
    final profile = await client
        .from('users')
        .select('roles')
        .eq('id', adminUserId)
        .single();
    adminRoles = _parseRoles(profile['roles']);
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  testWidgets(
    'KTA correction fields saved on application and synced to users on approval',
    (tester) async {
      await signInAsAdmin();
      expect(
        adminRoles.contains('admin') || adminRoles.contains('staff'),
        isTrue,
        reason: 'Test account must be admin/staff to approve KTA applications.',
      );

      final marker = DateTime.now().millisecondsSinceEpoch.toString();
      final disposableEmail = 'e2e.kta.$marker@example.com';
      final disposablePassword =
          'Tmp!$marker'
          'aA';
      final targetMemberNumber = _buildUniqueMemberNumber(marker);
      final targetValidUntil = DateTime(2026, 6, 30);
      final targetValidFrom = DateTime(2025, 6, 30);

      String? disposableUserId;
      String? applicationId;
      String? storagePath;
      File? tempFile;

      try {
        await client.auth.signOut();
        final signUp = await client.auth.signUp(
          email: disposableEmail,
          password: disposablePassword,
          emailRedirectTo: null,
        );
        disposableUserId = signUp.user?.id;
        expect(disposableUserId, isNotNull);

        if (client.auth.currentUser?.id != disposableUserId) {
          final relogin = await client.auth.signInWithPassword(
            email: disposableEmail,
            password: disposablePassword,
          );
          disposableUserId = relogin.user?.id ?? disposableUserId;
        }

        await client.from('users').insert({
          'id': disposableUserId,
          'email': disposableEmail,
          'full_name': 'E2E KTA $marker',
          'phone_number': '0812${marker.substring(marker.length - 8)}',
          'birth_date': '2000-01-01',
          'roles': ['non_member'],
          'active_role': 'non_member',
        });

        tempFile = await _createTempImageFile('kta_$marker');
        storagePath = 'kta/$disposableUserId/e2e_kta_$marker.jpg';
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
              'user_id': disposableUserId,
              'confirmed_name': 'E2E KTA $marker',
              'confirmed_birth_place': 'Jakarta',
              'confirmed_birth_date': '2000-01-01',
              'confirmed_address': 'E2E Street 123',
              'kta_photo_url': storagePath,
              'member_number': targetMemberNumber,
              'kta_valid_from': _formatDate(targetValidFrom),
              'kta_valid_until': _formatDate(targetValidUntil),
              'status': 'pending',
            })
            .select('id,status,member_number,kta_valid_from,kta_valid_until')
            .single();

        applicationId = inserted['id']?.toString();
        expect(applicationId, isNotNull);
        expect(inserted['status'], 'pending');
        expect(inserted['member_number'], targetMemberNumber);
        expect(
          inserted['kta_valid_until']?.toString(),
          _formatDate(targetValidUntil),
        );

        await signInAsAdmin();
        await client
            .from('kta_applications')
            .update({
              'status': 'approved',
              'processed_by': adminUserId,
              'processed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', applicationId!);

        final approved = await client
            .from('kta_applications')
            .select('status,member_number,kta_valid_from,kta_valid_until')
            .eq('id', applicationId)
            .single();
        expect(approved['status'], 'approved');
        expect(approved['member_number'], targetMemberNumber);
        expect(
          approved['kta_valid_from']?.toString(),
          _formatDate(targetValidFrom),
        );
        expect(
          approved['kta_valid_until']?.toString(),
          _formatDate(targetValidUntil),
        );

        final userRow = await client
            .from('users')
            .select(
              'roles,active_role,member_number,kta_valid_from,kta_valid_until,kta_photo_url',
            )
            .eq('id', disposableUserId!)
            .single();
        final userData = Map<String, dynamic>.from(userRow);
        final userRoles = _parseRoles(userData['roles']);

        expect(userRoles.contains('member'), isTrue);
        expect(userData['member_number'], targetMemberNumber);
        expect(
          userData['kta_valid_from']?.toString(),
          _formatDate(targetValidFrom),
        );
        expect(
          userData['kta_valid_until']?.toString(),
          _formatDate(targetValidUntil),
        );
        expect(userData['kta_photo_url'], storagePath);
      } on PostgrestException catch (error) {
        final text = error.message.toLowerCase();
        final missingColumn =
            text.contains('could not find the') &&
            (text.contains('member_number') ||
                text.contains('kta_valid_from') ||
                text.contains('kta_valid_until'));
        if (missingColumn) {
          fail(
            'Kolom koreksi KTA belum ada di kta_applications. '
            'Jalankan sql/kta_application_corrections_and_approval_sync.sql '
            'lalu ulangi integration test.',
          );
        }
        rethrow;
      } finally {
        await signInAsAdmin();
        if (applicationId != null && applicationId.isNotEmpty) {
          await _safeRun(
            () => client
                .from('kta_applications')
                .delete()
                .eq('id', applicationId!),
          );
        }
        if (storagePath != null && storagePath.isNotEmpty) {
          await _safeRun(
            () => client.storage.from('kta_app').remove([storagePath!]),
          );
        }
        if (tempFile != null && await tempFile.exists()) {
          await _safeRun(() => tempFile!.delete());
        }
      }
    },
  );
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

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _buildUniqueMemberNumber(String marker) {
  final compact = marker.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  final suffix = compact.length > 9
      ? compact.substring(compact.length - 9)
      : compact;
  return 'E2E$suffix';
}

Future<File> _createTempImageFile(String suffix) async {
  final random = Random();
  final bytes = List<int>.generate(512, (_) => random.nextInt(256));
  final file = File(
    '${Directory.systemTemp.path}/al_ihsan_kta_e2e_$suffix.jpg',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> _safeRun(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {}
}
