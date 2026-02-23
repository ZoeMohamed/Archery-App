import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestDbScreen extends StatefulWidget {
  const TestDbScreen({super.key});

  @override
  State<TestDbScreen> createState() => _TestDbScreenState();
}

class _TestDbScreenState extends State<TestDbScreen> {
  String _result = 'Tap a button to test';
  bool _isLoading = false;

  Future<void> _testSelect() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing SELECT...';
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.from('users').select('*').limit(5);

      setState(() {
        _result =
            '✅ SELECT SUCCESS!\n\nData: $response\n\nRows: ${response.length}';
      });
    } catch (e) {
      setState(() {
        _result = '❌ SELECT FAILED!\n\nError: $e\n\nType: ${e.runtimeType}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testInsert() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing INSERT...';
    });

    try {
      // Note: users.id has FOREIGN KEY to auth.users(id)
      // So we can only insert if user exists in auth.users first
      // This test checks if RLS allows insert

      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        setState(() {
          _result =
              '⚠️ INSERT TEST SKIPPED\n\n'
              'Reason: users.id REFERENCES auth.users(id)\n\n'
              'This means you can ONLY insert into users table if:\n'
              '1. User already exists in auth.users\n'
              '2. Insert id matches auth user id\n\n'
              '👉 Test "Auth Signup" instead - that will test the full flow!';
        });
        return;
      }

      try {
        await client.from('users').insert({
          'id': currentUser.id,
          'email': currentUser.email ?? '',
          'full_name': 'Test User',
          'roles': ['non_member'],
          'active_role': 'non_member',
        });
        setState(() {
          _result = '✅ INSERT SUCCESS!\n\nUser ID: ${currentUser.id}';
        });
      } catch (insertError) {
        final errorText = insertError.toString().toLowerCase();
        final isDuplicate =
            errorText.contains('duplicate') ||
            errorText.contains('already exists') ||
            errorText.contains('23505');
        if (!isDuplicate) {
          rethrow;
        }

        await client
            .from('users')
            .update({
              'email': currentUser.email ?? '',
              'full_name': 'Test User',
            })
            .eq('id', currentUser.id);
        setState(() {
          _result =
              '✅ UPDATE SUCCESS (existing row)\n\nUser ID: ${currentUser.id}';
        });
      }
    } catch (e) {
      setState(() {
        _result =
            '❌ INSERT/UPSERT FAILED!\n\nError: $e\n\nType: ${e.runtimeType}\n\n'
            'Note: This is expected if no user is logged in.\n'
            'Try "Test Auth Signup" instead!';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testTableStructure() async {
    setState(() {
      _isLoading = true;
      _result = 'Checking table structure...';
    });

    try {
      final client = Supabase.instance.client;

      // Try to get column info by selecting with specific columns
      final response = await client
          .from('users')
          .select('''
        id,
        email,
        full_name,
        phone_number,
        birth_date,
        roles,
        active_role,
        member_number,
        member_status,
        kta_photo_url,
        created_at,
        updated_at
      ''')
          .limit(1);

      setState(() {
        _result =
            '✅ TABLE STRUCTURE OK!\n\nAll expected columns exist.\n\nSample: $response';
      });
    } catch (e) {
      setState(() {
        _result =
            '❌ TABLE STRUCTURE ERROR!\n\nMissing columns or wrong types.\n\nError: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAuth() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing Auth signup...';
    });

    try {
      final client = Supabase.instance.client;
      // Use a more valid-looking email format
      final timestamp = DateTime.now().millisecondsSinceEpoch % 100000;
      final testEmail = 'testuser$timestamp@gmail.com';
      final testPassword = 'Tmp!${DateTime.now().millisecondsSinceEpoch}Aa';

      final response = await client.auth.signUp(
        email: testEmail,
        password: testPassword,
      );

      if (response.user != null) {
        setState(() {
          _result =
              '✅ AUTH SIGNUP SUCCESS!\n\nUser ID: ${response.user!.id}\nEmail: ${response.user!.email}';
        });
      } else {
        setState(() {
          _result = '⚠️ AUTH SIGNUP - No user returned\n\nResponse: $response';
        });
      }
    } catch (e) {
      setState(() {
        _result =
            '❌ AUTH SIGNUP FAILED!\n\nError: $e\n\nType: ${e.runtimeType}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
        backgroundColor: const Color(0xFF10B982),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Supabase Database Tests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testSelect,
                  child: const Text('Test SELECT'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testInsert,
                  child: const Text('Test INSERT'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testTableStructure,
                  child: const Text('Check Structure'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Test Auth Signup'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
