import 'package:flutter/material.dart';
import 'dashboard_non_member.dart';
import 'setup_training_screen.dart';
import 'archer_scoring_screen.dart';
import 'profile_screen.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import '../utils/user_data.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isMember = false;
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
    await UserData().loadData();
    if (mounted) {
      setState(() {
        _isMember = UserData().isMember;
      });
    }
  }

  Future<void> _refreshUserData() async {
    // Just reload from local storage without resetting anything
    final userData = UserData();
    await userData.loadData();
    if (mounted) {
      setState(() {
        _isMember = userData.isMember;
      });
    }
  }

  List<Widget> get _screens => [
    DashboardNonMember(
      onNavigate: (index) {
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
            onTap: (index) {
              if (index == 2) {
                // Center button - navigate to KTA screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _isMember
                        ? const KtaCardScreen()
                        : const UploadKtaScreen(),
                  ),
                ).then((targetIndex) {
                  // Refresh member status when returning (without resetting)
                  _refreshUserData();

                  // If a target index was returned, navigate to that tab
                  if (targetIndex != null &&
                      targetIndex is int &&
                      targetIndex != 2) {
                    setState(() {
                      _currentIndex = targetIndex;
                    });
                  }
                });
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _isMember
                        ? const KtaCardScreen()
                        : const UploadKtaScreen(),
                  ),
                ).then((targetIndex) {
                  // Refresh member status when returning (without resetting)
                  _refreshUserData();

                  // If a target index was returned, navigate to that tab
                  if (targetIndex != null &&
                      targetIndex is int &&
                      targetIndex != 2) {
                    setState(() {
                      _currentIndex = targetIndex;
                    });
                  }
                });
              },
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
            ),
          ),
        ],
      ),
    );
  }
}
