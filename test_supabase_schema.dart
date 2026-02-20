import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';

/// Test script to verify Supabase schema and data
/// Run inside Flutter app with hot reload
Future<void> testSupabaseSchema() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('===========================================');
  print('SUPABASE SCHEMA VERIFICATION TEST');
  print('===========================================\n');

  try {
    // Initialize Supabase
    print('1. Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://qwnpzycbaljsddpoxsbh.supabase.co',
      anonKey: 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0',
    );
    
    final supabase = Supabase.instance.client;
    print('✓ Supabase initialized successfully\n');

    // Test tables
    final tables = [
      'users',
      'kta_applications',
      'training_sessions',
      'score_details',
      'payments',
      'notifications',
      'settings',
      'coach_feedback',
    ];

    print('2. Testing table accessibility...');
    int successCount = 0;
    int failCount = 0;

    for (final table in tables) {
      try {
        final response = await supabase
            .from(table)
            .select('*')
            .limit(1);
        
        print('   ✓ Table "$table" - accessible (${response.length} rows sampled)');
        successCount++;
      } catch (e) {
        print('   ✗ Table "$table" - ERROR: $e');
        failCount++;
      }
    }

    print('\n3. Checking users table data...');
    try {
      final users = await supabase
          .from('users')
          .select('id, email, full_name, role, is_coach, member_number, member_status');
      
      print('   Total users found: ${users.length}');
      
      if (users.isEmpty) {
        print('   ⚠ WARNING: No users found! Seed data not loaded.');
      } else {
        print('\n   User Details:');
        for (final user in users) {
          print('   - ${user['full_name']} (${user['email']})');
          print('     Role: ${user['role']}, Coach: ${user['is_coach']}, Member#: ${user['member_number']}');
        }
      }
    } catch (e) {
      print('   ✗ ERROR querying users: $e');
    }

    print('\n4. Testing views...');
    
    // Test v_members_payment_status
    try {
      final membersView = await supabase
          .from('v_members_payment_status')
          .select('*')
          .limit(5);
      print('   ✓ View "v_members_payment_status" - accessible (${membersView.length} rows)');
    } catch (e) {
      print('   ✗ View "v_members_payment_status" - ERROR: $e');
    }

    // Test v_user_training_stats
    try {
      final statsView = await supabase
          .from('v_user_training_stats')
          .select('*')
          .limit(5);
      print('   ✓ View "v_user_training_stats" - accessible (${statsView.length} rows)');
    } catch (e) {
      print('   ✗ View "v_user_training_stats" - ERROR: $e');
    }

    print('\n5. Testing authentication...');
    
    // Try to sign in with test user
    try {
      final email = const String.fromEnvironment('SUPABASE_TEST_EMAIL');
      final password = const String.fromEnvironment('SUPABASE_TEST_PASSWORD');
      if (email.isEmpty || password.isEmpty) {
        print('   ⚠ Skipping auth test: SUPABASE_TEST_EMAIL/PASSWORD not set.');
      } else {
        print('   Attempting login with $email...');
        final authResponse = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (authResponse.user != null) {
          print('   ✓ Login successful!');
          print('     User ID: ${authResponse.user!.id}');
          print('     Email: ${authResponse.user!.email}');
          
          // Try to fetch profile
          try {
            final profile = await supabase
                .from('users')
                .select('*')
                .eq('id', authResponse.user!.id)
                .single();
            
            print('   ✓ Profile fetch successful!');
            print('     Name: ${profile['full_name']}');
            print('     Role: ${profile['role']}');
          } catch (e) {
            print('   ✗ Profile fetch failed: $e');
          }
          
          // Sign out
          await supabase.auth.signOut();
          print('   ✓ Sign out successful');
        } else {
          print('   ✗ Login failed - no user returned');
        }
      }
    } catch (e) {
      print('   ✗ Login failed: $e');
      print('   This likely means seed data has not been loaded into auth.users');
    }

    // Summary
    print('\n===========================================');
    print('SUMMARY');
    print('===========================================');
    print('Tables accessible: $successCount/${tables.length}');
    print('Tables failed: $failCount/${tables.length}');
    
    if (successCount == tables.length) {
      print('\n✓ ALL TESTS PASSED - Schema is correct!');
    } else {
      print('\n⚠ SOME TESTS FAILED - Check errors above');
    }
    
  } catch (e, stackTrace) {
    print('\n✗ FATAL ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}
