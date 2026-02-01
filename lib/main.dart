import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/supabase_service.dart';
import 'utils/user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    print('Error initializing date formatting: $e');
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
    // Continue even if Supabase fails to initialize
  }
  
  runApp(const MainApp());
}

const bool _debugAutoLoginEnabled = false;
const String _debugAutoLoginEmail = 'user@klub.com';
const String _debugAutoLoginPassword = '22110436*';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Al Ihsan Archery',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF10B982),
        fontFamily: 'Roboto',
      ),
      home: kDebugMode && _debugAutoLoginEnabled
          ? const _DebugAutoLoginGate()
          : const _AuthGate(),
    );
  }
}

class _DebugAutoLoginGate extends StatefulWidget {
  const _DebugAutoLoginGate();

  @override
  State<_DebugAutoLoginGate> createState() => _DebugAutoLoginGateState();
}

class _DebugAutoLoginGateState extends State<_DebugAutoLoginGate> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _attemptLogin();
  }

  Future<void> _attemptLogin() async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _debugAutoLoginEmail,
        password: _debugAutoLoginPassword,
      );
      if (response.user == null) {
        throw Exception('Auto-login failed.');
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Debug auto-login failed.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to login'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const MainNavigation();
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _isLoading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await UserData().loadData();
    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;
    setState(() {
      _hasSession = session != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _hasSession ? const MainNavigation() : const LoginScreen();
  }
}
