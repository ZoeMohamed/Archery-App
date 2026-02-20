import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/user_data.dart';
import 'kta_card_screen.dart';
import 'verification_status_screen.dart';

class UploadKtaScreen extends StatefulWidget {
  const UploadKtaScreen({super.key});

  @override
  State<UploadKtaScreen> createState() => _UploadKtaScreenState();
}

class _UploadKtaScreenState extends State<UploadKtaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noAnggotaController = TextEditingController();
  String? _uploadedKtaImage;
  bool _isCheckingStatus = true;
  bool _isSubmitting = false;

  static const String _ktaBucket = 'kta_app';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userData = UserData();
    await userData.loadData();
    await _refreshKtaStatus(userData);
    if (!mounted) return;
    final status = userData.ktaStatus.toLowerCase().trim();
    if (status == 'pending') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const VerificationStatusScreen(),
        ),
      );
      return;
    }
    if (status == 'approved') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const KtaCardScreen()),
      );
      return;
    }
    setState(() {
      _isCheckingStatus = false;
    });
  }

  @override
  void dispose() {
    _noAnggotaController.dispose();
    super.dispose();
  }

  Future<void> _refreshKtaStatus(UserData userData) async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      final userId = userData.userId.isNotEmpty
          ? userData.userId
          : authUser?.id ?? '';
      if (userId.isEmpty) {
        return;
      }
      final response = await Supabase.instance.client
          .from('kta_applications')
          .select('status, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) {
        userData.ktaStatus = 'none';
        await userData.saveData();
        return;
      }
      final status = response['status']?.toString();
      if (status != null && status.trim().isNotEmpty) {
        userData.ktaStatus = status.trim();
        await userData.saveData();
      }
    } catch (_) {
      // Ignore status refresh errors and keep local state.
    }
  }

  void _pickKtaImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _uploadedKtaImage = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto KTA berhasil dipilih!'),
              backgroundColor: Color(0xFF10B982),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitKta() async {
    if (_formKey.currentState!.validate()) {
      if (_uploadedKtaImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan upload KTA terlebih dahulu!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update KTA status to pending and save image path
      if (_isSubmitting) return;
      setState(() {
        _isSubmitting = true;
      });

      final userData = UserData();
      await userData.loadData();
      final authUser = Supabase.instance.client.auth.currentUser;
      final userId = userData.userId.isNotEmpty
          ? userData.userId
          : authUser?.id ?? '';
      if (userId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
      if (userData.userId.isEmpty && authUser != null) {
        userData.userId = authUser.id;
      }

      var birthDate = _parseBirthDate(userData.tanggalLahir);
      if (birthDate == null) {
        birthDate = await _fetchBirthDateFromSupabase(userId);
        if (birthDate != null) {
          userData.tanggalLahir = _formatLocalDate(birthDate);
          await userData.saveData();
        }
      }
      if (birthDate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lengkapi tanggal lahir di profil terlebih dahulu.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final confirmedName = userData.namaLengkap.isNotEmpty
          ? userData.namaLengkap
          : userData.email;
      if (confirmedName.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama lengkap belum tersedia.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final profileReady = await _ensureUserProfile(userId, userData);
      if (!profileReady) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final ktaUrl = await _uploadKtaToSupabase(
        userId: userId,
        filePath: _uploadedKtaImage!,
      );

      if (ktaUrl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal upload foto KTA.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      try {
        await Supabase.instance.client.from('kta_applications').insert({
          'user_id': userId,
          'confirmed_name': confirmedName.trim(),
          'confirmed_birth_place': 'Tidak diketahui',
          'confirmed_birth_date': birthDate.toIso8601String().split('T').first,
          'confirmed_address': 'Tidak tersedia',
          'kta_photo_url': ktaUrl,
          'status': 'pending',
        });
      } catch (e) {
        debugPrint('KTA insert failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengajuan KTA: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      userData.ktaStatus = 'pending';
      userData.ktaImagePath = _uploadedKtaImage!;
      userData.membershipNumber = _noAnggotaController.text.trim();
      await userData.saveData();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const VerificationStatusScreen(),
        ),
      );
    }
  }

  Future<bool> _ensureUserProfile(String userId, UserData userData) async {
    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing != null) {
        return true;
      }

      final email = userData.email.isNotEmpty
          ? userData.email
          : Supabase.instance.client.auth.currentUser?.email ?? '';
      final fullName = userData.namaLengkap.isNotEmpty
          ? userData.namaLengkap
          : email;

      await Supabase.instance.client.from('users').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'roles': ['non_member'],
        'active_role': 'non_member',
      });
      return true;
    } catch (e) {
      debugPrint('Ensure user profile failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil pengguna belum ada di database. Hubungi admin untuk membuat profil.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<String?> _uploadKtaToSupabase({
    required String userId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      final extension = filePath.split('.').last.toLowerCase();
      final nonce = _secureObjectNonce();
      final path =
          'kta/$userId/${DateTime.now().millisecondsSinceEpoch}_$nonce.$extension';

      await Supabase.instance.client.storage
          .from(_ktaBucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return path;
    } catch (e) {
      debugPrint('KTA upload failed: $e');
      return null;
    }
  }

  DateTime? _parseBirthDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) {
        return null;
      }
      return DateTime(year, month, day);
    }
    return DateTime.tryParse(value);
  }

  Future<DateTime?> _fetchBirthDateFromSupabase(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('birth_date')
          .eq('id', userId)
          .maybeSingle();
      if (response == null) {
        return null;
      }
      final raw = response['birth_date'];
      if (raw is DateTime) {
        return DateTime(raw.year, raw.month, raw.day);
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatLocalDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _secureObjectNonce([int bytes = 12]) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      final value = random.nextInt(256);
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B982)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black87,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verifikasi Anggota',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload KTA Anda",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Lengkapi data di bawah untuk memverifikasi status keanggotaan Anda di Al Ihsan Archery.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // Upload Section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B982).withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.card_membership,
                            color: Color(0xFF10B982),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Foto Kartu Tanda Anggota",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Upload Area with Dashed Border
                    GestureDetector(
                      onTap: _pickKtaImage,
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: const Color(0xFF10B982),
                          strokeWidth: 2,
                          gap: 6,
                        ),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _uploadedKtaImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF10B982,
                                            ).withOpacity(0.25),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.cloud_upload_rounded,
                                        size: 36,
                                        color: Color(0xFF10B982),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "Tap untuk upload foto KTA",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Format: JPG, PNG (Maks. 5MB)",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(_uploadedKtaImage!),
                                        fit: BoxFit.cover,
                                      ),
                                      Container(
                                        color: Colors.black.withOpacity(0.4),
                                      ),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF10B982),
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                "Foto Terpilih",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF064E3B),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _uploadedKtaImage = null,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.15),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // No Anggota Input
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.badge,
                            color: Color(0xFF10B982),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Nomor Anggota",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noAnggotaController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 123456789',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(
                          Icons.credit_card,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
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
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nomor anggota wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitKta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B982),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF10B982).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Kirim Verifikasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF10B982),
            unselectedItemColor: const Color(0xFF9CA3AF),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            currentIndex: 2, // KTA is at index 2 (center button)
            onTap: (index) {
              if (index == 2) return; // Already on Upload KTA screen

              // Pop back to MainNavigation with the target index
              Navigator.pop(context, index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.flag_outlined),
                label: 'Latihan',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(height: 24), // Placeholder for center button
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Riwayat\nLatihan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profil',
              ),
            ],
          ),
          // Floating center button with diamond shape
          Positioned(
            top: -30,
            left: MediaQuery.of(context).size.width / 2 - 37,
            child: Transform.rotate(
              angle: 0.785398, // 45 degrees in radians (π/4)
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B982),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B982).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -0.785398, // Rotate content back
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_membership,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'KTA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dashed border
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(16),
        ),
      );

    final Path dashedPath = _dashPath(
      path,
      dashArray: CircularIntervalList<double>([gap * 2, gap]),
    );
    canvas.drawPath(dashedPath, paint);
  }

  Path _dashPath(
    Path source, {
    required CircularIntervalList<double> dashArray,
  }) {
    final Path dest = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray.next;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircularIntervalList<T> {
  final List<T> _vals;
  int _idx = 0;

  CircularIntervalList(this._vals);

  T get next {
    if (_idx >= _vals.length) {
      _idx = 0;
    }
    return _vals[_idx++];
  }
}
