import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _defaultSupabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
const String _defaultAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;

  final envEmail = Platform.environment['SUPABASE_TEST_EMAIL'];
  final envPassword = Platform.environment['SUPABASE_TEST_PASSWORD'];
  late final String email;
  late final String password;

  setUpAll(() async {
    final checkedEmail = envEmail;
    final checkedPassword = envPassword;
    if (checkedEmail == null || checkedPassword == null) {
      fail(
        'Set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD to run this integration test.',
      );
    }
    email = checkedEmail;
    password = checkedPassword;
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

  testWidgets('edit profile persists after re-login', (tester) async {
    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(auth.user, isNotNull);

    final userId = auth.user!.id;
    final original = await client
        .from('users')
        .select('full_name,phone_number')
        .eq('id', userId)
        .single();
    final originalData = Map<String, dynamic>.from(original);

    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final newName = 'QA Profile $marker';
    final newPhone = '0812${marker.substring(marker.length - 8)}';

    try {
      await client
          .from('users')
          .update({
            'full_name': newName,
            'phone_number': newPhone,
          })
          .eq('id', userId);

      final afterSave = await client
          .from('users')
          .select('full_name,phone_number')
          .eq('id', userId)
          .single();
      final afterSaveData = Map<String, dynamic>.from(afterSave);
      expect(afterSaveData['full_name'], newName);
      expect(afterSaveData['phone_number'], newPhone);

      await client.auth.signOut();
      final relogin = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      expect(relogin.user, isNotNull);

      final afterRelogin = await client
          .from('users')
          .select('full_name,phone_number')
          .eq('id', userId)
          .single();
      final afterReloginData = Map<String, dynamic>.from(afterRelogin);
      expect(afterReloginData['full_name'], newName);
      expect(afterReloginData['phone_number'], newPhone);
    } finally {
      await client
          .from('users')
          .update({
            'full_name': originalData['full_name'],
            'phone_number': originalData['phone_number'],
          })
          .eq('id', userId);
    }
  });

  testWidgets('change password updates auth and can login with new password', (
    tester,
  ) async {
    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(auth.user, isNotNull);

    final tempPassword = 'Temp!${DateTime.now().millisecondsSinceEpoch}aA';
    var passwordChanged = false;

    try {
      await client.auth.updateUser(UserAttributes(password: tempPassword));

      await client.auth.signOut();
      final loginWithTemp = await client.auth.signInWithPassword(
        email: email,
        password: tempPassword,
      );
      expect(loginWithTemp.user, isNotNull);
      passwordChanged = true;
    } finally {
      if (passwordChanged) {
        try {
          await client.auth.updateUser(UserAttributes(password: password));
        } catch (_) {
          try {
            await client.auth.signOut();
            await client.auth.signInWithPassword(
              email: email,
              password: tempPassword,
            );
            await client.auth.updateUser(UserAttributes(password: password));
          } catch (_) {}
        }
      }

      await client.auth.signOut();
      final finalLogin = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      expect(finalLogin.user, isNotNull);
    }
  });
}
