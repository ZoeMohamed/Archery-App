import 'package:flutter/material.dart';
import 'registration_screen.dart';
import 'main_navigation.dart';
import '../utils/user_data.dart';
import '../models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Attempting login for: ${_emailController.text}');

        // 1. Sign in with Supabase Auth
        final authResponse = await Supabase.instance.client.auth
            .signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

        print('Auth successful! User: ${authResponse.user?.id}');

        if (authResponse.user == null) {
          throw Exception('Login gagal. Silakan coba lagi.');
        }

        final userId = authResponse.user!.id;
        final userEmail = authResponse.user!.email ?? _emailController.text;

        if (!mounted) return;

        // 2. Try to fetch profile from database, but don't fail if not exists
        String userName = userEmail.split('@')[0]; // Default name from email
        String userRole = 'non_member';

        try {
          final profileResponse = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', userId)
              .maybeSingle(); // Use maybeSingle instead of single

          if (profileResponse != null) {
            print('Profile fetched: $profileResponse');
            final profile = UserProfile.fromJson(profileResponse);

            // Store full profile data
            final userData = UserData();
            userData.userId = profile.id;
            userData.email = profile.email;
            userData.namaLengkap = profile.fullName;
            userData.nomorTelepon = profile.phoneNumber ?? '';
            userData.role = profile.role;
            userData.isCoach = profile.isCoach;
            userData.isMember = profile.isMember;
            userData.memberNumber = profile.memberNumber ?? '';
            userData.memberStatus = profile.memberStatus ?? '';
            userData.ktaStatus = profile.isMember ? 'approved' : 'none';
            userData.ktaImagePath = profile.ktaPhotoUrl ?? '';

            if (profile.birthDate != null) {
              userData.tanggalLahir = profile.getFormattedBirthDate();
              userData.kategori = profile.getAgeCategory();
            }

            await userData.saveData();
            userName = profile.fullName;
          } else {
            // Profile not in database yet, use minimal data from auth
            print('No profile found, using auth data only');
            final userData = UserData();
            userData.userId = userId;
            userData.email = userEmail;
            userData.namaLengkap = userName;
            userData.role = userRole;
            userData.isCoach = false;
            userData.isMember = false;
            userData.ktaStatus = 'none';

            await userData.saveData();
          }
        } catch (profileError) {
          print('Profile fetch error (non-fatal): $profileError');
          // Continue with minimal data
          final userData = UserData();
          userData.userId = userId;
          userData.email = userEmail;
          userData.namaLengkap = userName;
          userData.role = userRole;
          userData.isCoach = false;
          userData.isMember = false;
          userData.ktaStatus = 'none';

          await userData.saveData();
        }

        // 3. Navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );

        // 4. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang, $userName!'),
            backgroundColor: const Color(0xFF10B982),
          ),
        );
      } catch (e) {
        print('Login error: $e');
        print('Error type: ${e.runtimeType}');

        if (!mounted) return;

        String errorMessage = 'Terjadi kesalahan saat login';

        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('invalid login credentials') ||
            errorStr.contains('invalid_credentials')) {
          errorMessage = 'Email atau password salah';
        } else if (errorStr.contains('email not confirmed')) {
          errorMessage = 'Email belum diverifikasi. Periksa inbox Anda.';
        } else if (errorStr.contains('network') ||
            errorStr.contains('connection')) {
          errorMessage = 'Tidak ada koneksi internet';
        } else if (errorStr.contains('too many requests')) {
          errorMessage = 'Terlalu banyak percobaan. Tunggu beberapa saat.';
        } else if (errorStr.contains('user not found') ||
            errorStr.contains('no rows')) {
          errorMessage =
              'Akun tidak ditemukan. Silakan registrasi terlebih dahulu.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Image.asset(
                    'image/logo_Alihsan Archery.png',
                    height: 200,
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C6B7A),
                  ),
                ),
                const SizedBox(height: 32),
                // Email Field
                const Text(
                  'Alamat Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nama@contoh.com',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B982)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B982)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B982),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!value.contains('@')) {
                      return 'Email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Password Field
                const Text(
                  'Kata Sandi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Masukkan kata sandi Anda',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B982)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B982)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B982),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kata sandi tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B982),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun ? ',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Daftar sekarang',
                        style: TextStyle(
                          color: Color(0xFF10B982),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
