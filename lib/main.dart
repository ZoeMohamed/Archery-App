import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
  }
  
  runApp(const MainApp());
}

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
      home: const LoginScreen(),
    );
  }
}
