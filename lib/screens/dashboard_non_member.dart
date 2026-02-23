import 'dart:convert';

import 'package:flutter/material.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import 'Mamber/pembayaran_screen.dart';
import 'Mamber/notifikasi_screen.dart';
import 'Mamber/lomba_screen.dart';
import 'Mamber/kelas_screen.dart';
import 'coach_training_history_screen.dart';
import 'range_finder_screen.dart';
import '../utils/user_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardNonMember extends StatefulWidget {
  final Function(int)? onNavigate; // Callback untuk navigate ke tab lain

  const DashboardNonMember({super.key, this.onNavigate});

  @override
  State<DashboardNonMember> createState() => _DashboardNonMemberState();
}

class _DashboardNonMemberState extends State<DashboardNonMember> {
  bool _isLoading = true;
  bool _isMember = false;
  String _userName = 'Pemanah';
  String _activeRole = 'non_member';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didUpdateWidget(DashboardNonMember oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates (e.g., when returning from another tab)
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userData = UserData();
      await userData.loadData();

      print('Dashboard: Loading user data...');
      print('Dashboard: userId = ${userData.userId}');
      print('Dashboard: role = ${userData.role}');
      print('Dashboard: isMember = ${userData.isMember}');
      print('Dashboard: isDemoMode = ${userData.isDemoMode}');

      final authUser = Supabase.instance.client.auth.currentUser;
      final supabaseUserId = userData.userId.isNotEmpty
          ? userData.userId
          : authUser?.id ?? '';

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
            final activeRole =
                response['active_role']?.toString() ??
                (roles.isNotEmpty ? roles.first : 'non_member');
            final normalizedRoles = [
              ...roles,
              if (activeRole.isNotEmpty && !roles.contains(activeRole))
                activeRole,
            ];

            // Update UserData with fresh data from Supabase
            userData.userId = response['id']?.toString() ?? supabaseUserId;
            userData.namaLengkap = response['full_name'] ?? '';
            userData.email = response['email'] ?? '';
            userData.role = activeRole;
            userData.isCoach = normalizedRoles.contains('coach');
            userData.isMember = _hasMemberRole(normalizedRoles, activeRole);
            userData.isDemoMode = false;

            // Save updated data locally
            await userData.saveData();
            print(
              'Dashboard: Updated from Supabase - role=${userData.role}, isMember=${userData.isMember}',
            );
          }
        } catch (supabaseError) {
          print('Supabase fetch failed, using local data: $supabaseError');
          // Continue with local data if Supabase fails
        }
      }

      // Update UI from local data
      if (mounted) {
        print(
          'Dashboard: Final values - role=${userData.role}, isMember=${userData.isMember}',
        );

        setState(() {
          _isMember = userData.isMember;
          _activeRole = userData.role;
          // Use full name if available, otherwise use name from email, or default
          if (userData.namaLengkap.isNotEmpty) {
            _userName = userData.namaLengkap;
          } else if (userData.email.isNotEmpty) {
            _userName = userData.email.split('@')[0];
          } else {
            _userName = 'Pemanah';
          }
          _isLoading = false;
        });

        print('Dashboard: UI updated with _isMember = $_isMember');
      }
    } catch (e) {
      print('Error loading user data in dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    if (trimmed.startsWith('"') &&
        trimmed.endsWith('"') &&
        trimmed.length > 1) {
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

  bool _canAccessMenu(String key) {
    switch (_activeRole) {
      case 'admin':
        return true;
      case 'coach':
        return key != 'pembayaran';
      case 'staff':
      case 'pengurus':
        return key == 'lomba' || key == 'pembayaran';
      case 'member':
        return true;
      case 'non_member':
      default:
        return key == 'latihan' ||
            key == 'profil' ||
            key == 'riwayat' ||
            key == 'kta';
    }
  }

  bool get _isNonMember => _activeRole == 'non_member';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B982)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF10B982),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat Datang,',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Halo, $_userName!',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          // TODO: Implement notifications
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Hero Card with Recommendation Badge (only show for non-member)
                if (_isNonMember)
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('image/logo_Alihsan Archery.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 80),
                              const Text(
                                'Bergabunglah Menjadi Anggota Resmi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Dapatkan fasilitas premium dan bimbingan pelatih profesional.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const UploadKtaScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B982),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Ajukan KTA Sekarang',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B982),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Rekomendasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Menu Utama
                const Text(
                  'Menu Utama',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                // Grid Menu
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.sports_score,
                      title: 'Latihan',
                      subtitle: 'Akses penuh scoring',
                      color: const Color(0xFF10B982),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('latihan'),
                    ),
                    if (_activeRole == 'coach' || _activeRole == 'admin')
                      _buildMenuItem(
                        context,
                        icon: Icons.fact_check_outlined,
                        title: 'Validasi Skor',
                        subtitle: 'Pantau semua latihan',
                        color: const Color(0xFF22C55E),
                        iconColor: Colors.white,
                        isLocked: !_canAccessMenu('validasi'),
                      ),
                    _buildMenuItem(
                      context,
                      icon: Icons.assessment_outlined,
                      title: 'Profil Dasar',
                      subtitle: 'Kelola data diri & foto',
                      color: const Color(0xFF6366F1),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('profil'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      title: _isNonMember ? 'Pengajuan KTA' : 'KTA',
                      subtitle: _isNonMember
                          ? 'Daftar anggota resmi'
                          : 'Kartu anggota',
                      color: const Color(0xFFF59E0B),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('kta'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Riwayat Latihan',
                      subtitle: 'Pantau progress latihan',
                      color: const Color(0xFF3B82F6),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('riwayat'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.center_focus_strong,
                      title: 'Range Finder',
                      subtitle: 'Ukur jarak target',
                      color: const Color(0xFFEF4444),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('range_finder'),
                    ),
                    // Member-only features (locked for non-members)
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notifikasi',
                      subtitle: 'Event & pengumuman',
                      color: const Color(0xFFEC4899),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('notifikasi'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.emoji_events_outlined,
                      title: 'Lomba',
                      subtitle: 'Pendaftaran lomba',
                      color: const Color(0xFF8B5CF6),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('lomba'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.payment_outlined,
                      title: 'Pembayaran',
                      subtitle: 'Iuran & transaksi',
                      color: const Color(0xFF14B8A6),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('pembayaran'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.how_to_reg_outlined,
                      title: 'Absensi',
                      subtitle: 'Presensi latihan',
                      color: const Color(0xFFF97316),
                      iconColor: Colors.white,
                      isLocked: !_canAccessMenu('absensi'),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required bool isLocked,
  }) {
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Fitur ini tidak tersedia untuk role Anda saat ini.',
              ),
              backgroundColor: Color(0xFFF59E0B),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (title == 'Latihan') {
          // Navigate to Latihan tab (index 1)
          widget.onNavigate?.call(1);
        } else if (title == 'Profil Dasar') {
          // Navigate to Profil tab (index 4)
          widget.onNavigate?.call(4);
        } else if (title == 'KTA') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KtaCardScreen()),
          ).then((_) => _loadUserData()); // Refresh when returning
        } else if (title == 'Pengajuan KTA') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadKtaScreen()),
          ).then((_) => _loadUserData()); // Refresh when returning
        } else if (title == 'Riwayat Latihan') {
          // Navigate to Riwayat tab (index 3)
          widget.onNavigate?.call(3);
        } else if (title == 'Validasi Skor') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CoachTrainingHistoryScreen(),
            ),
          );
        } else if (title == 'Pembayaran') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PembayaranScreen()),
          );
        } else if (title == 'Notifikasi') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotifikasiScreen()),
          );
        } else if (title == 'Lomba') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LombaScreen()),
          );
        } else if (title == 'Absensi') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KelasScreen()),
          );
        } else if (title == 'Range Finder') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RangeFinderScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fitur ini akan segera hadir!'),
              backgroundColor: Color(0xFF10B982),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Stack(
        children: [
          SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.all(16),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLocked ? const Color(0xFF9CA3AF) : color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 32, color: iconColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isLocked
                          ? const Color(0xFF9CA3AF)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isLocked
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF6B7280),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Lock overlay
          if (isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
