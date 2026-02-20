import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  static final UserData _instance = UserData._internal();
  
  factory UserData() {
    return _instance;
  }
  
  UserData._internal();

  String namaLengkap = '';
  String namaPengguna = '';
  String email = '';
  String nomorTelepon = '';
  String tanggalLahir = '';
  String kategori = '';
  
  // Membership fields
  bool isMember = false;
  String ktaStatus = 'none'; // none, pending, approved, rejected
  String membershipNumber = '';
  String membershipValidFrom = '';
  String membershipValidUntil = '';
  String ktaImagePath = ''; // Path to uploaded KTA image

  // New Supabase fields
  String userId = ''; // UUID from auth
  String role = 'non_member'; // non_member, member, admin
  bool isCoach = false;
  String memberStatus = ''; // active, inactive
  String memberNumber = '';
  
  // Demo mode flag - prevents Supabase from overriding local toggle
  bool isDemoMode = false;

  // Load data from SharedPreferences
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    namaLengkap = prefs.getString('namaLengkap') ?? '';
    namaPengguna = prefs.getString('namaPengguna') ?? '';
    email = prefs.getString('email') ?? '';
    nomorTelepon = prefs.getString('nomorTelepon') ?? '';
    tanggalLahir = prefs.getString('tanggalLahir') ?? '';
    kategori = prefs.getString('kategori') ?? '';
    isMember = prefs.getBool('isMember') ?? false;
    ktaStatus = prefs.getString('ktaStatus') ?? 'none';
    membershipNumber = prefs.getString('membershipNumber') ?? '';
    membershipValidFrom = prefs.getString('membershipValidFrom') ?? '';
    membershipValidUntil = prefs.getString('membershipValidUntil') ?? '';
    ktaImagePath = prefs.getString('ktaImagePath') ?? '';
    
    // Load Supabase fields
    userId = prefs.getString('userId') ?? '';
    role = prefs.getString('role') ?? 'non_member';
    isCoach = prefs.getBool('isCoach') ?? false;
    memberStatus = prefs.getString('memberStatus') ?? '';
    memberNumber = prefs.getString('memberNumber') ?? '';
    isDemoMode = prefs.getBool('isDemoMode') ?? false;
    
    // Ensure isMember is in sync with role
    if (!isDemoMode) {
      const memberRoles = {'member', 'admin', 'staff', 'coach'};
      isMember = memberRoles.contains(role);
    }
  }

  // Save data to SharedPreferences
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('namaLengkap', namaLengkap);
    await prefs.setString('namaPengguna', namaPengguna);
    await prefs.setString('email', email);
    await prefs.setString('nomorTelepon', nomorTelepon);
    await prefs.setString('tanggalLahir', tanggalLahir);
    await prefs.setString('kategori', kategori);
    
    // Save Supabase fields
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setBool('isCoach', isCoach);
    await prefs.setString('memberStatus', memberStatus);
    await prefs.setString('memberNumber', memberNumber);
    await prefs.setBool('isDemoMode', isDemoMode);
    await prefs.setBool('isMember', isMember);
    await prefs.setString('ktaStatus', ktaStatus);
    await prefs.setString('membershipNumber', membershipNumber);
    await prefs.setString('membershipValidFrom', membershipValidFrom);
    await prefs.setString('membershipValidUntil', membershipValidUntil);
    await prefs.setString('ktaImagePath', ktaImagePath);
  }

  // Calculate kategori based on tanggal lahir
  String calculateKategori(DateTime birthDate) {
    final now = DateTime.now();
    final age = now.year - birthDate.year - 
                ((now.month > birthDate.month || 
                  (now.month == birthDate.month && now.day >= birthDate.day)) 
                  ? 0 : 1);

    if (age < 9) {
      return 'U9';
    } else if (age < 12) {
      return 'U12';
    } else if (age < 15) {
      return 'U15';
    } else {
      return 'Dewasa';
    }
  }

  Future<void> clearData() async {
    namaLengkap = '';
    namaPengguna = '';
    email = '';
    nomorTelepon = '';
    tanggalLahir = '';
    kategori = '';
    
    isMember = false;
    ktaStatus = 'none';
    membershipNumber = '';
    membershipValidFrom = '';
    membershipValidUntil = '';
    ktaImagePath = '';
    
    // Clear Supabase fields
    userId = '';
    role = 'non_member';
    isCoach = false;
    memberStatus = '';
    memberNumber = '';
    isDemoMode = false;
    
    // Clear user-related keys from SharedPreferences (keep other app data)
    final prefs = await SharedPreferences.getInstance();
    const keys = [
      'namaLengkap',
      'namaPengguna',
      'email',
      'nomorTelepon',
      'tanggalLahir',
      'kategori',
      'isMember',
      'ktaStatus',
      'membershipNumber',
      'membershipValidFrom',
      'membershipValidUntil',
      'ktaImagePath',
      'userId',
      'role',
      'isCoach',
      'memberStatus',
      'memberNumber',
      'isDemoMode',
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
