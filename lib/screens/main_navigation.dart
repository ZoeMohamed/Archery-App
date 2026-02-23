import 'package:flutter/material.dart';
import 'dashboard_non_member.dart';
import 'setup_training_screen.dart';
import 'archer_scoring_screen.dart';
import 'profile_screen.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import '../utils/user_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isMember = false;
  String _activeRole = 'non_member';
  final GlobalKey<ArcherScoringScreenState> _archerScoringKey =
      GlobalKey<ArcherScoringScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user data when dependencies change (e.g., returning from another screen)
    _refreshUserData();
  }

  Future<void> _loadUserData() async {
    await _refreshUserData(syncFromServer: true);
  }

  Future<void> _refreshUserData({bool syncFromServer = false}) async {
    final userData = UserData();
    await userData.loadData();

    String activeRole = _normalizeRole(userData.role);
    var roleSet = <String>{if (activeRole.isNotEmpty) activeRole};

    if (syncFromServer) {
      final authUser = Supabase.instance.client.auth.currentUser;
      final userId = userData.userId.isNotEmpty
          ? userData.userId
          : authUser?.id ?? '';
      if (userId.isNotEmpty) {
        try {
          final response = await Supabase.instance.client
              .from('users')
              .select('active_role,roles')
              .eq('id', userId)
              .maybeSingle();
          if (response != null) {
            activeRole = _normalizeRole(response['active_role']?.toString());
            roleSet = {
              ..._parseRoles(response['roles']),
              if (activeRole.isNotEmpty) activeRole,
            };

            activeRole = _deriveEffectiveRole(
              activeRole: activeRole,
              roles: roleSet,
              fallbackIsMember: userData.isMember,
            );

            userData.role = activeRole;
            userData.isMember = _deriveMemberFlag(
              activeRole: activeRole,
              roles: roleSet,
              fallbackIsMember: userData.isMember,
            );
            await userData.saveData();
          }
        } catch (_) {
          // Keep local role if server sync fails.
        }
      }
    }

    activeRole = _deriveEffectiveRole(
      activeRole: activeRole,
      roles: roleSet,
      fallbackIsMember: userData.isMember,
    );
    final isMember = _deriveMemberFlag(
      activeRole: activeRole,
      roles: roleSet,
      fallbackIsMember: userData.isMember,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isMember = isMember;
      _activeRole = activeRole.isEmpty ? 'non_member' : activeRole;
      if (_isPengurusRole &&
          (_currentIndex == 1 || _currentIndex == 2 || _currentIndex == 3)) {
        _currentIndex = 0;
      }
    });
  }

  bool get _isPengurusRole =>
      _activeRole == 'pengurus' || _activeRole == 'staff';

  String _normalizeRole(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  List<String> _parseRoles(dynamic value) {
    if (value is List) {
      return value
          .map((item) => _normalizeRole(item?.toString()))
          .where((role) => role.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final normalized = _normalizeRole(value);
      if (normalized.isEmpty) {
        return [];
      }
      return [normalized];
    }
    return [];
  }

  String _deriveEffectiveRole({
    required String activeRole,
    required Set<String> roles,
    required bool fallbackIsMember,
  }) {
    var role = activeRole.isNotEmpty ? activeRole : 'non_member';
    final hasPengurusRole =
        roles.contains('pengurus') || roles.contains('staff');

    // Guard against stale active_role from local cache:
    // If active_role is staff/pengurus but roles no longer contain it,
    // fallback to a valid member role.
    if ((role == 'pengurus' || role == 'staff') && !hasPengurusRole) {
      if (roles.contains('member')) {
        role = 'member';
      } else if (roles.contains('coach')) {
        role = 'coach';
      } else if (roles.contains('admin')) {
        role = 'admin';
      } else if (fallbackIsMember) {
        role = 'member';
      } else {
        role = 'non_member';
      }
    }

    if (role.isEmpty) {
      return 'non_member';
    }
    return role;
  }

  bool _deriveMemberFlag({
    required String activeRole,
    required Set<String> roles,
    required bool fallbackIsMember,
  }) {
    const memberRoles = {'member', 'admin', 'coach', 'staff', 'pengurus'};
    if (memberRoles.contains(activeRole)) {
      return true;
    }
    if (roles.any(memberRoles.contains)) {
      return true;
    }
    return fallbackIsMember;
  }

  bool _isDisabledTabForRole(int index) {
    if (!_isPengurusRole) {
      return false;
    }
    return index == 1 || index == 3;
  }

  void _showRestrictedMessage([
    String message = 'Tab ini tidak tersedia untuk role pengurus.',
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFF59E0B),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openKtaCenter() async {
    await _refreshUserData(syncFromServer: true);
    if (!mounted) {
      return;
    }
    if (_isPengurusRole) {
      _showRestrictedMessage('Fitur KTA tidak tersedia untuk role pengurus.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _isMember ? const KtaCardScreen() : const UploadKtaScreen(),
      ),
    ).then((targetIndex) {
      // Refresh member status when returning (without resetting)
      _refreshUserData(syncFromServer: true);

      // If a target index was returned, navigate to that tab
      if (targetIndex != null && targetIndex is int && targetIndex != 2) {
        if (_isDisabledTabForRole(targetIndex)) {
          return;
        }
        setState(() {
          _currentIndex = targetIndex;
        });
      }
    });
  }

  List<Widget> get _screens => [
    DashboardNonMember(
      onNavigate: (index) {
        if (_isDisabledTabForRole(index)) {
          _showRestrictedMessage();
          return;
        }
        setState(() {
          _currentIndex = index;
        });
      },
    ),
    const SetupTrainingScreen(),
    const SizedBox(), // Placeholder for center button
    ArcherScoringScreen(key: _archerScoringKey),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF10B982),
            unselectedItemColor: const Color(0xFF9CA3AF),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            currentIndex: _currentIndex,
            onTap: (index) async {
              await _refreshUserData(syncFromServer: true);
              if (_isDisabledTabForRole(index)) {
                _showRestrictedMessage();
                return;
              }
              if (index == 2) {
                if (_isPengurusRole) {
                  _showRestrictedMessage(
                    'Fitur KTA tidak tersedia untuk role pengurus.',
                  );
                  return;
                }
                _openKtaCenter();
              } else {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 3) {
                  _archerScoringKey.currentState?.refresh();
                }
              }
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
            child: GestureDetector(
              onTap: _openKtaCenter,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.rotate(
                    angle: 0.785398, // 45 degrees in radians (π/4)
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isPengurusRole
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF10B982),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isPengurusRole
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF10B982))
                                    .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -0.785398, // Rotate content back
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_membership,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 3),
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
                  if (_isPengurusRole)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
