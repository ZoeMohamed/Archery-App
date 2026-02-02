import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_navigation.dart';
import '../utils/user_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaLengkapController = TextEditingController();
  final _namaPenggunaController = TextEditingController();
  final _emailController = TextEditingController();
  final _nomorTeleponController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final _passwordController = TextEditingController();
  final _kategoriController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _namaPenggunaController.dispose();
    _emailController.dispose();
    _nomorTeleponController.dispose();
    _tanggalLahirController.dispose();
    _passwordController.dispose();
    _kategoriController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF10B982)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _tanggalLahirController.text =
            "${picked.day}/${picked.month}/${picked.year}";

        // Auto-calculate kategori
        final userData = UserData();
        final kategori = userData.calculateKategori(picked);
        _kategoriController.text = kategori;
      });
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String? userId;
      final dateParts = _tanggalLahirController.text.split('/');
      final birthDate =
          '${dateParts[2]}-${dateParts[1].padLeft(2, '0')}-${dateParts[0].padLeft(2, '0')}';

      try {
        print('Starting registration for: ${_emailController.text}');

        // Parse birth date to proper format (YYYY-MM-DD)
        print('Parsed birth date: $birthDate');

        // Try to signup - catch database errors but continue
        try {
          final authResponse = await Supabase.instance.client.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            emailRedirectTo: null,
          );

          print('Auth signup response: ${authResponse.user?.id}');
          print('Auth session: ${authResponse.session != null}');

          if (authResponse.user != null) {
            userId = authResponse.user!.id;
            print('User created with ID: $userId');
          }
        } catch (signupError) {
          print('Signup error (may be non-fatal): $signupError');

          // Check if it's database error but auth might have succeeded
          final errorStr = signupError.toString().toLowerCase();

          if (errorStr.contains('database error') ||
              errorStr.contains('unexpected_failure')) {
            print('Database error detected - trying to login instead');

            // Auth user might exist, try logging in
            try {
              final loginResponse = await Supabase.instance.client.auth
                  .signInWithPassword(
                    email: _emailController.text.trim(),
                    password: _passwordController.text,
                  );

              if (loginResponse.user != null) {
                userId = loginResponse.user!.id;
                print('Logged in with existing user: $userId');
              }
            } catch (loginError) {
              print('Login also failed: $loginError');
              // Will throw error at the end if no userId
            }
          }

          // If still no userId, check for duplicate email error (means account exists)
          if (userId == null &&
              (errorStr.contains('already') ||
                  errorStr.contains('exists') ||
                  errorStr.contains('duplicate'))) {
            throw Exception(
              'Email sudah terdaftar. Silakan gunakan email lain atau login.',
            );
          }

          // If still no userId and not duplicate, re-throw
          if (userId == null) {
            throw signupError;
          }
        }

        // At this point, we should have userId either from signup or login
        if (userId == null) {
          throw Exception('Gagal membuat akun. Silakan coba lagi.');
        }

        final profileCreated = await _createUserProfile(
          userId: userId,
          birthDate: birthDate,
        );
        if (!profileCreated) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }

        // 2. Save to local storage immediately (bypass database profile for now)
        final userData = UserData();
        userData.userId = userId;
        userData.namaLengkap = _namaLengkapController.text;
        userData.namaPengguna = _namaPenggunaController.text;
        userData.email = _emailController.text;
        userData.nomorTelepon = _nomorTeleponController.text;
        userData.tanggalLahir = _tanggalLahirController.text;
        userData.kategori = _kategoriController.text;
        userData.role = 'non_member';
        userData.isCoach = false;
        userData.isMember = false;
        userData.ktaStatus = 'none';

        await userData.saveData();
        print('Local data saved successfully');

        if (!mounted) return;

        // 3. Show success and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registrasi berhasil! Selamat datang, ${_namaLengkapController.text}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } catch (e) {
        print('Registration error: $e');
        print('Error type: ${e.runtimeType}');

        // Special handling for database error - try to login with credentials
        final errorStr = e.toString().toLowerCase();
        print('Error string check: $errorStr');

        if (errorStr.contains('database') ||
            errorStr.contains('unexpected_failure')) {
          print('Database error during signup - attempting login recovery');

          try {
            // User might have been created in auth, try login
            final loginResponse = await Supabase.instance.client.auth
                .signInWithPassword(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                );

            print('Login attempt result: ${loginResponse.user?.id}');

            if (loginResponse.user != null) {
              print(
                'Login recovery successful! User ID: ${loginResponse.user!.id}',
              );

              final profileCreated = await _createUserProfile(
                userId: loginResponse.user!.id,
                birthDate: birthDate,
              );
              if (!profileCreated) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
                return;
              }

              // Save to local storage
              final userData = UserData();
              userData.userId = loginResponse.user!.id;
              userData.namaLengkap = _namaLengkapController.text;
              userData.namaPengguna = _namaPenggunaController.text;
              userData.email = _emailController.text;
              userData.nomorTelepon = _nomorTeleponController.text;
              userData.tanggalLahir = _tanggalLahirController.text;
              userData.kategori = _kategoriController.text;
              userData.role = 'non_member';
              userData.isCoach = false;
              userData.isMember = false;
              userData.ktaStatus = 'none';

              await userData.saveData();
              print('Local data saved after recovery');

              if (!mounted) return;

              // Success - navigate
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Registrasi berhasil! Selamat datang, ${_namaLengkapController.text}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );

              // Exit early - success!
              setState(() => _isLoading = false);
              return;
            }
          } catch (loginError) {
            print('Login recovery failed: $loginError');
            // Continue to show error message
          }
        }

        String errorMessage = 'Terjadi kesalahan saat registrasi';

        if (errorStr.contains('email') &&
            (errorStr.contains('already') ||
                errorStr.contains('registered') ||
                errorStr.contains('exists'))) {
          errorMessage =
              'Email sudah terdaftar. Silakan gunakan email lain atau login.';
        } else if (errorStr.contains('password')) {
          errorMessage = 'Password terlalu lemah (minimal 6 karakter)';
        } else if (errorStr.contains('network') ||
            errorStr.contains('connection')) {
          errorMessage = 'Tidak ada koneksi internet. Periksa koneksi Anda.';
        } else if (errorStr.contains('invalid') && errorStr.contains('email')) {
          errorMessage = 'Format email tidak valid';
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
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _createUserProfile({
    required String userId,
    required String birthDate,
  }) async {
    try {
      await Supabase.instance.client.from('users').upsert({
        'id': userId,
        'email': _emailController.text.trim(),
        'full_name': _namaLengkapController.text.trim(),
        'phone_number': _nomorTeleponController.text.trim(),
        'birth_date': birthDate,
        'roles': ['non_member'],
        'active_role': 'non_member',
      });
      return true;
    } catch (e) {
      print('Profile insert failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil ke database: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Al Ihsan Archery',
          style: TextStyle(
            color: Color(0xFF10B982),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Daftar untuk memulai',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // Nama Lengkap
                const Text(
                  'Nama Lengkap',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _namaLengkapController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama lengkap Anda',
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
                      return 'Nama lengkap tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Nama Pengguna
                const Text(
                  'Nama Pengguna',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _namaPenggunaController,
                  decoration: InputDecoration(
                    hintText: 'Min 5 karakter alfanumerik',
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
                      return 'Nama pengguna tidak boleh kosong';
                    }
                    if (value.length < 5) {
                      return 'Minimal 5 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Email
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'contoh@email.com',
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
                const SizedBox(height: 16),
                // Nomor Telepon
                const Text(
                  'Nomor Telepon',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF10B982)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '+62',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _nomorTeleponController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: '8xx-xxxx-xxxx',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B982),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B982),
                            ),
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
                            return 'Nomor telepon tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tanggal Lahir
                const Text(
                  'Tanggal Lahir',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tanggalLahirController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: InputDecoration(
                    hintText: 'Pilih tanggal lahir',
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
                    suffixIcon: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF10B982),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Tanggal lahir tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Kata Sandi
                const Text(
                  'Kata Sandi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Min 8 karakter, huruf & angka',
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
                    if (value.length < 8) {
                      return 'Minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Kategori (Read-only, auto-calculated)
                const Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _kategoriController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Kategori akan terisi otomatis',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
                    suffixIcon: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF10B982),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                          'Buat Akun',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun? ',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Masuk',
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
