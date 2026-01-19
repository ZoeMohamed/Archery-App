import '../models/supabase/db_user.dart';
import '../utils/user_data.dart';

class SupabaseUserAdapter {
  static DbUser toDbUser(UserData data) {
    final role = data.role.trim().isNotEmpty ? data.role.trim() : 'non_member';
    final roles = <String>{role};
    if (data.isCoach) {
      roles.add('coach');
    }
    if (data.isMember) {
      roles.add('member');
    }
    if (role == 'admin') {
      roles.add('admin');
    }
    if (role == 'staff') {
      roles.add('staff');
    }
    if (roles.isEmpty) {
      roles.add('non_member');
    }

    final birthDate = _parseLocalDate(data.tanggalLahir);
    final memberNumber = data.memberNumber.isNotEmpty
        ? data.memberNumber
        : data.membershipNumber;

    return DbUser(
      id: data.userId,
      email: data.email,
      fullName: data.namaLengkap,
      phoneNumber: data.nomorTelepon,
      birthDate: birthDate,
      roles: roles.toList(),
      activeRole: role,
      memberNumber: memberNumber.isNotEmpty ? memberNumber : null,
      memberStatus: data.memberStatus.isNotEmpty ? data.memberStatus : null,
      ktaPhotoUrl: data.ktaImagePath.isNotEmpty ? data.ktaImagePath : null,
      ktaValidFrom: _parseLocalDate(data.membershipValidFrom),
      ktaValidUntil: _parseLocalDate(data.membershipValidUntil),
    );
  }

  static UserData applyToUserData(DbUser user) {
    final data = UserData();
    data.userId = user.id;
    data.email = user.email;
    data.namaLengkap = user.fullName;
    data.nomorTelepon = user.phoneNumber ?? '';
    data.tanggalLahir = _formatLocalDate(user.birthDate);
    data.role = user.activeRole.isNotEmpty
        ? user.activeRole
        : (user.roles.isNotEmpty ? user.roles.first : 'non_member');
    data.isCoach = user.roles.contains('coach');
    data.isMember = user.roles.contains('member') || user.roles.contains('admin');
    data.memberNumber = user.memberNumber ?? '';
    data.memberStatus = user.memberStatus ?? '';
    data.membershipNumber = user.memberNumber ?? '';
    data.membershipValidFrom = _formatLocalDate(user.ktaValidFrom);
    data.membershipValidUntil = _formatLocalDate(user.ktaValidUntil);
    data.ktaImagePath = user.ktaPhotoUrl ?? '';
    return data;
  }

  static DateTime? _parseLocalDate(String value) {
    if (value.isEmpty) {
      return null;
    }
    final parts = value.split('/');
    if (parts.length != 3) {
      return DateTime.tryParse(value);
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static String _formatLocalDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}
