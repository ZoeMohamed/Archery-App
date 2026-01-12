import 'package:flutter/material.dart';
import 'dashboard_non_member.dart';
import 'setup_training_screen.dart';
import 'archer_scoring_screen.dart';
import 'profile_screen.dart';
import 'upload_kta_screen.dart';
import 'kta_card_screen.dart';
import '../utils/user_data.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await UserData().loadData();
    setState(() {
      _isMember = UserData().isMember;
    });
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
    const ArcherScoringScreen(),
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
                ).then((_) {
                  // Refresh member status when returning
                  _loadUserData();
                });
              } else {
                setState(() {
                  _currentIndex = index;
                });
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
                ).then((_) {
                  // Refresh member status when returning
                  _loadUserData();
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
