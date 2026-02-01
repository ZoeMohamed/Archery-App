import 'dart:convert';

import 'package:flutter/material.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import 'login_screen.dart';
import '../utils/user_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _namaPenggunaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _noTeleponController = TextEditingController();
  final TextEditingController _tanggalLahirController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _obscurePasswordLama = true;
  bool _obscurePasswordBaru = true;
  bool _isMember = false;
  bool _isLoading = true;
  bool _isRoleUpdating = false;
  List<String> _availableRoles = [];
  String _activeRole = 'non_member';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userData = UserData();
      await userData.loadData();
      var availableRoles = <String>[];
      var activeRole = userData.role;

      print('Profile: Loading user data...');
      print('Profile: userId = ${userData.userId}');
      print('Profile: role = ${userData.role}');
      print('Profile: isMember = ${userData.isMember}');
      print('Profile: isDemoMode = ${userData.isDemoMode}');

      final authUser = Supabase.instance.client.auth.currentUser;
      final supabaseUserId =
          userData.userId.isNotEmpty ? userData.userId : authUser?.id ?? '';

      // Always fetch from Supabase when user id is available
      if (supabaseUserId.isNotEmpty) {
        try {
          final response = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', supabaseUserId)
              .maybeSingle();

          if (response != null) {
            final roles = _parseRoles(response['roles']);
            activeRole =
                response['active_role']?.toString() ??
                (roles.isNotEmpty ? roles.first : 'non_member');
            final normalizedRoles = [
              ...roles,
              if (activeRole.isNotEmpty && !roles.contains(activeRole))
                activeRole,
            ];
            availableRoles = normalizedRoles;

            // Update UserData with fresh data from Supabase
            userData.userId = response['id']?.toString() ?? supabaseUserId;
            userData.namaLengkap = response['full_name'] ?? '';
            userData.email = response['email'] ?? '';
            userData.nomorTelepon = response['phone_number'] ?? '';
            userData.role = activeRole;
            userData.isCoach = roles.contains('coach');
            userData.memberNumber = response['member_number'] ?? '';
            userData.memberStatus = response['member_status'] ?? '';
            userData.isDemoMode = false;

            // Parse birth date if available
            if (response['birth_date'] != null) {
              try {
                final birthDate = DateTime.parse(response['birth_date']);
                userData.tanggalLahir = DateFormat(
                  'dd/MM/yyyy',
                ).format(birthDate);

                // Calculate kategori from age
                final age = DateTime.now().year - birthDate.year;
                if (age < 9) {
                  userData.kategori = 'U9';
                } else if (age < 12) {
                  userData.kategori = 'U12';
                } else if (age < 15) {
                  userData.kategori = 'U15';
                } else {
                  userData.kategori = 'Dewasa';
                }
              } catch (e) {
                print('Error parsing birth date: $e');
              }
            }

            // Determine membership status
            userData.isMember = _hasMemberRole(roles, activeRole);

            // Save updated data locally
            await userData.saveData();
            print(
              'Profile: Updated from Supabase - role=${userData.role}, isMember=${userData.isMember}',
            );
          }
        } catch (supabaseError) {
          print('Supabase fetch failed, using local data: $supabaseError');
        }
      } else if (userData.isDemoMode) {
        print('Profile: Demo mode active, using local data');
      }

      // Update UI with loaded data (from local storage or Supabase)
      if (mounted) {
        print(
          'Profile: Final values - role=${userData.role}, isMember=${userData.isMember}',
        );
        
        _namaLengkapController.text = userData.namaLengkap;
        _namaPenggunaController.text = userData.email.isNotEmpty 
            ? userData.email.split('@')[0] 
            : userData.namaPengguna;
        _emailController.text = userData.email;
        _noTeleponController.text = userData.nomorTelepon;
        _tanggalLahirController.text = userData.tanggalLahir;
        _kategoriController.text = userData.kategori;

        setState(() {
          _isMember = userData.isMember;
          _availableRoles = availableRoles;
          _activeRole = activeRole;
          _isLoading = false;
        });
        
        print('Profile: UI updated with _isMember = $_isMember');
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data profil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _namaPenggunaController.dispose();
    _emailController.dispose();
    _noTeleponController.dispose();
    _tanggalLahirController.dispose();
    _kategoriController.dispose();
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final userData = UserData();
      userData.namaLengkap = _namaLengkapController.text;
      userData.namaPengguna = _namaPenggunaController.text;
      userData.email = _emailController.text;
      userData.nomorTelepon = _noTeleponController.text;

      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan!'),
          backgroundColor: Color(0xFF10B982),
        ),
      );
    }
  }

  List<String> _parseRoles(dynamic value) {
    if (value is List) {
      return value
          .map((item) => _normalizeRole(item.toString()))
          .where((role) => role.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return [];
      }
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((item) => _normalizeRole(item.toString()))
                .where((role) => role.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        if (inner.trim().isEmpty) {
          return [];
        }
        return inner
            .split(',')
            .map((item) => _normalizeRole(item))
            .where((role) => role.isNotEmpty)
            .toList();
      }
      final normalized = _normalizeRole(trimmed);
      return normalized.isEmpty ? [] : [normalized];
    }
    return [];
  }

  String _normalizeRole(String value) {
    var trimmed = value.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 1) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed.trim();
  }

  bool _hasMemberRole(List<String> roles, String activeRole) {
    const memberRoles = {'member', 'admin', 'staff', 'coach'};
    if (memberRoles.contains(activeRole)) {
      return true;
    }
    return roles.any(memberRoles.contains);
  }

  List<String> _roleOptions() {
    const order = ['admin', 'staff', 'member', 'coach'];
    final available = {..._availableRoles, _activeRole};
    return order.where(available.contains).toList();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Pengurus';
      case 'member':
        return 'Member';
      case 'coach':
        return 'Pelatih';
      default:
        return role;
    }
  }

  Future<void> _setActiveRole(String role) async {
    if (_isRoleUpdating || role == _activeRole) {
      return;
    }
    final userData = UserData();
    if (userData.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun belum terhubung ke Supabase.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isRoleUpdating = true;
    });

    try {
      await Supabase.instance.client
          .from('users')
          .update({'active_role': role})
          .eq('id', userData.userId);

      userData.role = role;
      userData.isCoach = _availableRoles.contains('coach');
      userData.isMember = _hasMemberRole(_availableRoles, role);
      await userData.saveData();

      if (!mounted) return;
      setState(() {
        _activeRole = role;
        _isMember = userData.isMember;
        _isRoleUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role diubah ke ${_roleLabel(role)}'),
          backgroundColor: const Color(0xFF10B982),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRoleUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changePassword() async {
    if (_passwordLamaController.text.isEmpty ||
        _passwordBaruController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password lama dan baru harus diisi!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userData = UserData();
    if (_passwordLamaController.text != userData.password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password lama tidak sesuai!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordBaruController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password baru minimal 8 karakter!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    userData.password = _passwordBaruController.text;
    await userData.saveData(); // Save to SharedPreferences

    setState(() {
      _isChangingPassword = false;
      _passwordLamaController.clear();
      _passwordBaruController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password berhasil diubah!'),
        backgroundColor: Color(0xFF10B982),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              _performLogout();
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    Navigator.pop(context);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    final userData = UserData();
    await userData.clearData();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Profil',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B982)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Picture
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF10B982),
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Color(0xFF10B982),
                  ),
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Fitur upload foto akan segera hadir!',
                            ),
                            backgroundColor: Color(0xFF10B982),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B982),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            // Profile Form
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      label: 'Nama Lengkap',
                      controller: _namaLengkapController,
                      enabled: _isEditing,
                      hint: 'Masukkan nama lengkap',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Nama Pengguna',
                      controller: _namaPenggunaController,
                      enabled: _isEditing,
                      hint: 'Masukkan nama pengguna',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      enabled: _isEditing,
                      hint: 'Masukkan email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'No Telepon',
                      controller: _noTeleponController,
                      enabled: _isEditing,
                      hint: 'Masukkan nomor telepon',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Tanggal Lahir',
                      controller: _tanggalLahirController,
                      enabled: false,
                      hint: 'Tanggal lahir',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Kategori',
                      controller: _kategoriController,
                      enabled: false,
                      hint: 'Kategori',
                    ),
                    const SizedBox(height: 24),
                    // Edit/Save Button
                    ElevatedButton(
                      onPressed: () {
                        if (_isEditing) {
                          _saveProfile();
                        } else {
                          setState(() {
                            _isEditing = true;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B982),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Simpan Profil' : 'Edit Profile',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_roleOptions().isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B982).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.manage_accounts,
                            color: Color(0xFF10B982),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Role Akses',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (_isRoleUpdating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF10B982),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role aktif: ${_roleLabel(_activeRole)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _roleOptions().map((role) {
                        final selected = _activeRole == role;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF10B982).withOpacity(0.08)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF10B982)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: RadioListTile<String>(
                            value: role,
                            groupValue: _activeRole,
                            onChanged: _isRoleUpdating
                                ? null
                                : (value) {
                                    if (value != null) {
                                      _setActiveRole(value);
                                    }
                                  },
                            activeColor: const Color(0xFF10B982),
                            title: Text(
                              _roleLabel(role),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              selected ? 'Sedang aktif' : 'Nonaktif',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            if (_roleOptions().isNotEmpty) const SizedBox(height: 16),
            // Change Password Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ganti Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Switch(
                        value: _isChangingPassword,
                        onChanged: (value) {
                          setState(() {
                            _isChangingPassword = value;
                            if (!value) {
                              _passwordLamaController.clear();
                              _passwordBaruController.clear();
                            }
                          });
                        },
                        activeColor: const Color(0xFF10B982),
                      ),
                    ],
                  ),
                  if (_isChangingPassword) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Password Lama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordLamaController,
                      obscureText: _obscurePasswordLama,
                      decoration: InputDecoration(
                        hintText: 'Masukkan password lama',
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePasswordLama
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePasswordLama = !_obscurePasswordLama;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password Baru',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordBaruController,
                      obscureText: _obscurePasswordBaru,
                      decoration: InputDecoration(
                        hintText: 'Masukkan password baru (min 8 karakter)',
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePasswordBaru
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePasswordBaru = !_obscurePasswordBaru;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B982),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ubah Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action Buttons Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // KTA Button
                  Expanded(
                    child: _buildActionCard(
                      icon: _isMember
                          ? Icons.card_membership
                          : Icons.upload_file,
                      label: _isMember ? 'Kartu KTA' : 'Ajukan KTA',
                      color: const Color(0xFF10B982),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _isMember
                                ? const KtaCardScreen()
                                : const UploadKtaScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Logout Button
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.logout,
                      label: 'Keluar',
                      color: Colors.red,
                      onTap: _logout,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: enabled
                    ? const Color(0xFF10B982)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: enabled
                    ? const Color(0xFF10B982)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B982), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (enabled && (value == null || value.isEmpty)) {
              return '$label tidak boleh kosong';
            }
            return null;
          },
        ),
      ],
    );
  }
}
