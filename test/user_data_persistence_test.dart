import 'package:al_ihsan_archery/utils/user_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveData/loadData keeps profile and role fields', () async {
    final userData = UserData();
    userData.namaLengkap = 'Test User';
    userData.namaPengguna = 'testuser';
    userData.email = 'test@example.com';
    userData.nomorTelepon = '08123456789';
    userData.tanggalLahir = '15/01/2000';
    userData.kategori = 'Dewasa';
    userData.userId = 'uuid-123';
    userData.role = 'member';
    userData.isCoach = false;
    userData.memberStatus = 'active';
    userData.memberNumber = 'KPA20260001';
    userData.isMember = true;
    userData.ktaStatus = 'approved';
    userData.membershipNumber = 'KPA20260001';
    userData.membershipValidFrom = '2026-01-01';
    userData.membershipValidUntil = '2026-12-31';
    userData.ktaImagePath = '/tmp/kta.jpg';
    await userData.saveData();

    final reloaded = UserData();
    await reloaded.loadData();

    expect(reloaded.namaLengkap, 'Test User');
    expect(reloaded.email, 'test@example.com');
    expect(reloaded.userId, 'uuid-123');
    expect(reloaded.role, 'member');
    expect(reloaded.memberStatus, 'active');
    expect(reloaded.memberNumber, 'KPA20260001');
    expect(reloaded.isMember, isTrue);
    expect(reloaded.ktaStatus, 'approved');
    expect(reloaded.ktaImagePath, '/tmp/kta.jpg');
  });

  test('loadData syncs isMember from role when not demo mode', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'coach');
    await prefs.setBool('isMember', false);
    await prefs.setBool('isDemoMode', false);

    final userData = UserData();
    await userData.loadData();

    expect(userData.role, 'coach');
    expect(userData.isMember, isTrue);
  });

  test('loadData keeps manual isMember in demo mode', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'non_member');
    await prefs.setBool('isMember', true);
    await prefs.setBool('isDemoMode', true);

    final userData = UserData();
    await userData.loadData();

    expect(userData.role, 'non_member');
    expect(userData.isDemoMode, isTrue);
    expect(userData.isMember, isTrue);
  });

  test('calculateKategori returns expected age group', () {
    final userData = UserData();

    final now = DateTime.now();
    final age8 = DateTime(now.year - 8, now.month, now.day);
    final age10 = DateTime(now.year - 10, now.month, now.day);
    final age13 = DateTime(now.year - 13, now.month, now.day);
    final age20 = DateTime(now.year - 20, now.month, now.day);

    expect(userData.calculateKategori(age8), 'U9');
    expect(userData.calculateKategori(age10), 'U12');
    expect(userData.calculateKategori(age13), 'U15');
    expect(userData.calculateKategori(age20), 'Dewasa');
  });

  test('clearData resets values and removes stored keys', () async {
    final userData = UserData();
    userData.namaLengkap = 'Before Clear';
    userData.email = 'before@example.com';
    userData.userId = 'uuid-before';
    userData.role = 'admin';
    userData.isMember = true;
    await userData.saveData();

    await userData.clearData();

    expect(userData.namaLengkap, isEmpty);
    expect(userData.email, isEmpty);
    expect(userData.userId, isEmpty);
    expect(userData.role, 'non_member');
    expect(userData.isMember, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('namaLengkap'), isNull);
    expect(prefs.getString('email'), isNull);
    expect(prefs.getString('userId'), isNull);
    expect(prefs.getString('role'), isNull);
  });
}
