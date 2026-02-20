import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supabase/db_payment.dart';
import '../services/supabase_payment_service.dart';
import '../utils/user_data.dart';

class KtaCardScreen extends StatefulWidget {
  const KtaCardScreen({super.key});

  @override
  State<KtaCardScreen> createState() => _KtaCardScreenState();
}

class _KtaCardScreenState extends State<KtaCardScreen> {
  static const String _ktaBucket = 'kta_app';

  bool _isLoading = true;
  String _ktaNumber = '';
  String _validFrom = '';
  String _validUntil = '';
  String? _resolvedKtaImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = UserData();
    await userData.loadData();

    _ktaNumber = _resolveMemberNumber(userData);
    _validFrom = userData.membershipValidFrom;
    _validUntil = userData.membershipValidUntil;

    await _refreshKtaFromSupabase(userData);
    _resolvedKtaImageUrl = await _resolveKtaImageUrl(userData.ktaImagePath);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshKtaFromSupabase(UserData userData) async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final userId = userData.userId.isNotEmpty
        ? userData.userId
        : authUser?.id ?? '';
    if (userId.isEmpty) {
      return;
    }

    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select(
            'member_number, kta_valid_from, kta_valid_until, kta_issued_date, kta_photo_url',
          )
          .eq('id', userId)
          .maybeSingle();

      if (userResponse != null) {
        final memberNumber = userResponse['member_number']?.toString() ?? '';
        if (memberNumber.isNotEmpty) {
          _ktaNumber = memberNumber;
          userData.memberNumber = memberNumber;
          userData.membershipNumber = memberNumber;
        }

        final ktaPhotoUrl = userResponse['kta_photo_url']?.toString() ?? '';
        if (ktaPhotoUrl.isNotEmpty) {
          userData.ktaImagePath = ktaPhotoUrl;
        }

        final validFromRaw = userResponse['kta_valid_from']?.toString() ?? '';
        final validUntilRaw = userResponse['kta_valid_until']?.toString() ?? '';
        final issuedRaw = userResponse['kta_issued_date']?.toString() ?? '';
        final validFrom =
            _parseSupabaseDate(validFromRaw) ?? _parseSupabaseDate(issuedRaw);
        final validUntil = _parseSupabaseDate(validUntilRaw);
        if (_applyValidityDates(validFrom, validUntil)) {
          // Supabase validity data applied.
        }
      }

      final paymentService = SupabasePaymentService();
      final payments = await paymentService.fetchMonthlyPaymentsForUser(userId);
      final latestPaid = _latestEligiblePayment(payments);
      if (latestPaid != null) {
        final paidDate = _normalizeDate(
          latestPaid.verifiedAt ??
              latestPaid.createdAt ??
              latestPaid.paymentMonth,
        );
        if (paidDate != null) {
          final validUntil = _addMonth(paidDate);
          _validFrom = _formatDate(paidDate);
          _validUntil = _formatDate(validUntil);
        }
      }

      userData.membershipValidFrom = _validFrom;
      userData.membershipValidUntil = _validUntil;
      await userData.saveData();
    } catch (e) {
      debugPrint('KTA: failed to fetch Supabase data: $e');
    }
  }

  Future<String?> _resolveKtaImageUrl(String rawPath) async {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (_looksLikeHttpUrl(trimmed)) {
      final normalized = _normalizeKtaStoragePath(trimmed);
      if (normalized == null) {
        return trimmed;
      }
      try {
        return await Supabase.instance.client.storage
            .from(_ktaBucket)
            .createSignedUrl(normalized, 3600);
      } catch (_) {
        return trimmed;
      }
    }

    if (_looksLikeLocalFile(trimmed)) {
      return null;
    }

    try {
      return await Supabase.instance.client.storage
          .from(_ktaBucket)
          .createSignedUrl(trimmed, 3600);
    } catch (_) {
      return null;
    }
  }

  String? _normalizeKtaStoragePath(String rawPath) {
    final publicMarker = '/storage/v1/object/public/$_ktaBucket/';
    final signMarker = '/storage/v1/object/sign/$_ktaBucket/';

    final publicIndex = rawPath.indexOf(publicMarker);
    if (publicIndex >= 0) {
      return Uri.decodeComponent(
        rawPath.substring(publicIndex + publicMarker.length),
      );
    }

    final signIndex = rawPath.indexOf(signMarker);
    if (signIndex >= 0) {
      final rawTail = rawPath.substring(signIndex + signMarker.length);
      final queryIndex = rawTail.indexOf('?');
      final pathOnly = queryIndex >= 0
          ? rawTail.substring(0, queryIndex)
          : rawTail;
      return Uri.decodeComponent(pathOnly);
    }

    return null;
  }

  bool _looksLikeHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  bool _looksLikeLocalFile(String value) {
    if (_looksLikeHttpUrl(value)) {
      return false;
    }
    return File(value).existsSync();
  }

  Widget _buildKtaImage(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return _buildImageUnavailable();
    }

    if (_looksLikeLocalFile(trimmed)) {
      return Image.file(
        File(trimmed),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageUnavailable(),
      );
    }

    final url = _resolvedKtaImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageUnavailable(),
      );
    }

    if (_looksLikeHttpUrl(trimmed)) {
      return Image.network(
        trimmed,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageUnavailable(),
      );
    }

    return _buildImageUnavailable();
  }

  Widget _buildImageUnavailable() {
    return Container(
      width: double.infinity,
      height: 200,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Text(
        'Foto KTA tidak tersedia',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _resolveMemberNumber(UserData userData) {
    if (userData.memberNumber.isNotEmpty) {
      return userData.memberNumber;
    }
    if (userData.membershipNumber.isNotEmpty) {
      return userData.membershipNumber;
    }
    return '';
  }

  DbPayment? _latestEligiblePayment(List<DbPayment> payments) {
    final eligible = payments.where((payment) {
      final status = payment.status.toLowerCase().trim();
      if (status.isEmpty) {
        return true;
      }
      return status != 'rejected' &&
          status != 'failed' &&
          status != 'canceled' &&
          status != 'cancelled';
    }).toList();

    if (eligible.isEmpty) {
      return null;
    }

    eligible.sort((a, b) {
      final aDate = _paymentDateForSort(a);
      final bDate = _paymentDateForSort(b);
      return bDate.compareTo(aDate);
    });

    return eligible.first;
  }

  DateTime _paymentDateForSort(DbPayment payment) {
    return payment.verifiedAt ??
        payment.createdAt ??
        payment.paymentMonth ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _normalizeDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _addMonth(DateTime value) {
    final nextMonth = DateTime(value.year, value.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(nextMonth.year, nextMonth.month, day);
  }

  DateTime? _parseSupabaseDate(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  bool _applyValidityDates(DateTime? validFrom, DateTime? validUntil) {
    if (validFrom != null && validUntil != null) {
      _validFrom = _formatDate(validFrom);
      _validUntil = _formatDate(validUntil);
      return true;
    }
    if (validFrom != null) {
      _validFrom = _formatDate(validFrom);
      _validUntil = _formatDate(_addMonth(validFrom));
      return true;
    }
    return false;
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B982)),
        ),
      );
    }

    final userData = UserData();
    final hasKtaImage = userData.ktaImagePath.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kartu Tanda Anggota',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // KTA Card
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF10B982),
                          const Color(0xFF059669),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.1,
                            child: CustomPaint(painter: CardPatternPainter()),
                          ),
                        ),
                        // Card content
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo and Title
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'image/logo_Alihsan Archery.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Al Ihsan Archery',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Kartu Tanda Anggota',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              // Member Number
                              const Text(
                                'No. Anggota',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _ktaNumber.isNotEmpty ? _ktaNumber : '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Member Name
                              const Text(
                                'Nama Anggota',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userData.namaLengkap,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Validity Period
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Berlaku Dari',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _validFrom.isNotEmpty
                                              ? _validFrom
                                              : '-',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Berlaku Sampai',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _validUntil.isNotEmpty
                                              ? _validUntil
                                              : '-',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Category Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Kategori: ${userData.kategori}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Uploaded KTA Photo Section
              if (hasKtaImage)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B982).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.photo_library,
                              color: Color(0xFF10B982),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Foto KTA Asli',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildKtaImage(userData.ktaImagePath),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B982).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.verified,
                              color: Color(0xFF10B982),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'KTA telah diverifikasi dan disetujui',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasKtaImage) const SizedBox(height: 30),
              // Info Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B982).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF10B982),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Informasi Keanggotaan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.email_outlined,
                      'Email',
                      userData.email,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.phone_outlined,
                      'No. Telepon',
                      userData.nomorTelepon,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.cake_outlined,
                      'Tanggal Lahir',
                      userData.tanggalLahir,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Benefits Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B982).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B982).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF10B982),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Fasilitas Anggota',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B982),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitItem('Akses penuh sistem scoring'),
                    _buildBenefitItem('Notifikasi event & pengumuman'),
                    _buildBenefitItem('Pendaftaran lomba online'),
                    _buildBenefitItem('Pembayaran iuran digital'),
                    _buildBenefitItem('Presensi latihan otomatis'),
                    _buildBenefitItem('Bimbingan pelatih profesional'),
                  ],
                ),
              ),
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
              if (index == 2) return; // Already on KTA screen

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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B982)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for card background pattern
class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw some decorative circles
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 30, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.9), 40, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
