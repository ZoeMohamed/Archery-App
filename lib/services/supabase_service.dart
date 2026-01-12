import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal();

  // Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';
  
  static SupabaseClient? _client;
  
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase has not been initialized. Call initialize() first.');
    }
    return _client!;
  }

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Set to false in production
    );
    _client = Supabase.instance.client;
  }

  // Test connection to Supabase
  Future<Map<String, dynamic>> testConnection() async {
    try {
      // Test by querying the current timestamp from Supabase
      await client
          .from('_test_')
          .select()
          .limit(1);
      
      return {
        'success': true,
        'message': 'Successfully connected to Supabase!',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Even if table doesn't exist, connection works if we get a proper error
      if (e.toString().contains('relation') || e.toString().contains('does not exist')) {
        return {
          'success': true,
          'message': 'Connected to Supabase! (No test table found, but connection works)',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to connect: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  // Example: Fetch users (you'll need to create this table)
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await client
          .from('users')
          .select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // Example: Insert user
  Future<bool> insertUser(Map<String, dynamic> userData) async {
    try {
      await client
          .from('users')
          .insert(userData);
      return true;
    } catch (e) {
      print('Error inserting user: $e');
      return false;
    }
  }

  // Example: Update user
  Future<bool> updateUser(String id, Map<String, dynamic> userData) async {
    try {
      await client
          .from('users')
          .update(userData)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Example: Delete user
  Future<bool> deleteUser(String id) async {
    try {
      await client
          .from('users')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Sign up user with Supabase Auth
  Future<Map<String, dynamic>> signUp(String email, String password) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return {
          'success': true,
          'user': response.user,
          'message': 'Sign up successful!',
        };
      } else {
        return {
          'success': false,
          'message': 'Sign up failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Sign in user with Supabase Auth
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return {
          'success': true,
          'user': response.user,
          'message': 'Sign in successful!',
        };
      } else {
        return {
          'success': false,
          'message': 'Sign in failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Enhanced sign in with email and fetch profile
  Future<Map<String, dynamic>> signInWithEmail(
    String email, 
    String password,
  ) async {
    try {
      print('Attempting login for: $email'); // Debug
      
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      print('Auth successful! User: ${response.user?.id}'); // Debug
      print('Session token: ${response.session?.accessToken.substring(0, 30)}...'); // Debug
      
      if (response.user != null) {
        // Skip profile fetch for now - test auth only
        print('Returning success without profile fetch'); // Debug
        
        return {
          'success': true,
          'user': response.user,
          'profile': {
            'id': response.user!.id,
            'email': response.user!.email,
            'role': 'non_member', // Temporary default
          },
          'message': 'Login successful!',
        };
      }
      
      return {
        'success': false,
        'message': 'Login failed',
      };
    } catch (e) {
      print('SignInWithEmail error: $e'); // Debug
      print('Error type: ${e.runtimeType}'); // Debug
      return {
        'success': false,
        'message': _parseError(e),
      };
    }
  }

  // Fetch user profile from public.users table
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      print('Querying users table with auth_user_id: $userId'); // Debug
      
      // Try simple query first to check RLS
      final testResponse = await client
          .from('users')
          .select('id, auth_user_id, email, full_name, role')
          .eq('auth_user_id', userId);
      
      print('Test query result count: ${testResponse.length}'); // Debug
      print('Test query result: $testResponse'); // Debug
      
      if (testResponse.isEmpty) {
        print('No user found with auth_user_id: $userId');
        return null;
      }
      
      // Get the first result
      final response = testResponse.first;
      
      print('Profile query successful: $response'); // Debug
      return response;
    } catch (e) {
      print('Error fetching profile: $e');
      print('Error details: ${e.runtimeType}');
      return null;
    }
  }

  // Parse authentication errors to user-friendly messages
  String _parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('invalid login credentials') || 
        errorStr.contains('invalid_credentials')) {
      return 'Email atau password salah';
    } else if (errorStr.contains('email not confirmed')) {
      return 'Email belum diverifikasi';
    } else if (errorStr.contains('network') || errorStr.contains('failed host lookup')) {
      return 'Tidak ada koneksi internet';
    } else if (errorStr.contains('too many requests')) {
      return 'Terlalu banyak percobaan. Silakan tunggu beberapa saat';
    }
    
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return client.auth.currentUser;
  }

  // Check if user is logged in
  bool get isLoggedIn {
    return client.auth.currentUser != null;
  }

  // Get current session
  Session? get currentSession {
    return client.auth.currentSession;
  }
}
