import 'dart:io';

import 'package:al_ihsan_archery/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _defaultSupabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
const String _defaultAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;

  final email = Platform.environment['SUPABASE_TEST_EMAIL'] ?? 'user@klub.com';
  final password =
      Platform.environment['SUPABASE_TEST_PASSWORD'] ?? '22110436*';

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
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.text('Edit Profile'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), newName);
      await tester.enterText(textFields.at(3), newPhone);

      await tester.scrollUntilVisible(
        find.text('Simpan Profil'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Profil'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

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
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.scrollUntilVisible(
        find.byType(Switch).first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      final oldPasswordField = fields.at(6);
      final newPasswordField = fields.at(7);

      await tester.ensureVisible(oldPasswordField);
      await tester.pumpAndSettle();
      await tester.enterText(oldPasswordField, password);
      await tester.enterText(newPasswordField, tempPassword);

      await tester.tap(find.text('Ubah Password'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

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
