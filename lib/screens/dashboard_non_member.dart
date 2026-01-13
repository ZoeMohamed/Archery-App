import 'package:flutter/material.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import 'Mamber/pembayaran_screen.dart';
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
  
  Future<String> _getCurrentRole() async {
    final userData = UserData();
    await userData.loadData();
    return userData.role;
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

      // Only fetch from Supabase if NOT in demo mode and user is logged in
      if (!userData.isDemoMode && userData.userId.isNotEmpty) {
        try {
          final response = await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', userData.userId)
              .maybeSingle();

          if (response != null) {
            // Update UserData with fresh data from Supabase
            userData.namaLengkap = response['full_name'] ?? '';
            userData.email = response['email'] ?? '';
            userData.role = response['role'] ?? 'non_member';

            // Determine membership status from role
            userData.isMember =
                userData.role == 'member' || userData.role == 'admin';

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
      } else if (userData.isDemoMode) {
        print('Dashboard: Demo mode active, using local data');
      }

      // Update UI from local data
      if (mounted) {
        print(
          'Dashboard: Final values - role=${userData.role}, isMember=${userData.isMember}',
        );

        setState(() {
          _isMember = userData.isMember;
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
                // Hero Card with Recommendation Badge (only show if not member)
                if (!_isMember)
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
                if (!_isMember) const SizedBox(height: 24),

                // DEBUG: Member Toggle Switch
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.bug_report,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DEBUG: Toggle Member Status',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _getCurrentRole(),
                              builder: (context, snapshot) {
                                final role = snapshot.data ?? 'non_member';
                                String statusText;
                                if (role == 'admin') {
                                  statusText = 'Status: Admin ✓';
                                } else if (role == 'member') {
                                  statusText = 'Status: Member ✓';
                                } else {
                                  statusText = 'Status: Non-Member';
                                }
                                return Text(
                                  statusText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isMember,
                        onChanged: (value) async {
                          final userData = UserData();
                          
                          // Enable demo mode when toggling
                          userData.isDemoMode = true;
                          userData.isMember = value;
                          userData.role = value ? 'admin' : 'non_member'; // Set to admin when enabled
                          
                          // If switching to member in demo mode, set up demo membership data
                          if (value && userData.membershipNumber.isEmpty) {
                            final now = DateTime.now();
                            final random = now.millisecondsSinceEpoch % 10000;
                            userData.membershipNumber = 'AIA-${now.year}-${random.toString().padLeft(4, '0')}';
                            userData.membershipValidFrom = '01/01/${now.year}';
                            userData.membershipValidUntil = '31/12/${now.year + 1}';
                            userData.ktaStatus = 'approved';
                            
                            // Set demo KTA data if not exists
                            if (userData.namaLengkap.isEmpty) {
                              userData.namaLengkap = 'Demo Admin';
                            }
                            if (userData.kategori.isEmpty) {
                              userData.kategori = 'Dewasa';
                            }
                          }
                          
                          await userData.saveData();
                          
                          print(
                            'Dashboard Toggle: isDemoMode=true, role=${userData.role}, isMember=${userData.isMember}',
                          );

                          setState(() {
                            _isMember = value;
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? '✓ Fitur Admin Dibuka (Demo Mode)'
                                      : '✗ Fitur Member Dikunci',
                                ),
                                backgroundColor: value
                                    ? const Color(0xFF10B982)
                                    : const Color(0xFF6B7280),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        activeColor: const Color(0xFF10B982),
                      ),
                    ],
                  ),
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
                      isLocked: false,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.assessment_outlined,
                      title: 'Profil Dasar',
                      subtitle: 'Kelola data diri & foto',
                      color: const Color(0xFF6366F1),
                      iconColor: Colors.white,
                      isLocked: false,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      title: _isMember ? 'KTA' : 'Pengajuan KTA',
                      subtitle: _isMember
                          ? 'Kartu anggota'
                          : 'Daftar anggota resmi',
                      color: const Color(0xFFF59E0B),
                      iconColor: Colors.white,
                      isLocked: false,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Riwayat Latihan',
                      subtitle: 'Pantau progress latihan',
                      color: const Color(0xFF3B82F6),
                      iconColor: Colors.white,
                      isLocked: false,
                    ),
                    // Member-only features (locked for non-members)
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notifikasi',
                      subtitle: 'Event & pengumuman',
                      color: const Color(0xFFEC4899),
                      iconColor: Colors.white,
                      isLocked: !_isMember,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.emoji_events_outlined,
                      title: 'Lomba',
                      subtitle: 'Pendaftaran lomba',
                      color: const Color(0xFF8B5CF6),
                      iconColor: Colors.white,
                      isLocked: !_isMember,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.payment_outlined,
                      title: 'Pembayaran',
                      subtitle: 'Iuran & transaksi',
                      color: const Color(0xFF14B8A6),
                      iconColor: Colors.white,
                      isLocked: !_isMember,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.how_to_reg_outlined,
                      title: 'Absensi',
                      subtitle: 'Presensi latihan',
                      color: const Color(0xFFF97316),
                      iconColor: Colors.white,
                      isLocked: !_isMember,
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
                'Fitur ini hanya tersedia untuk anggota. Silakan ajukan KTA terlebih dahulu.',
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
        } else if (title == 'Pembayaran') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PembayaranScreen()),
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
