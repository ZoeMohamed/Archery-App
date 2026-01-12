import 'package:flutter/material.dart';
import 'dashboard_non_member.dart';
import '../utils/user_data.dart';
import 'package:intl/intl.dart';

enum VerificationStatus {
  pending,
  approved,
  rejected,
}

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  // Untuk demo, kita set status pending dulu
  VerificationStatus _status = VerificationStatus.pending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardNonMember()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Status Verifikasi',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
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
              // Status Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Status Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        size: 50,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Status Title
                    Text(
                      _getStatusTitle(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Status Message
                    Text(
                      _getStatusMessage(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Additional Info based on status
                    if (_status == VerificationStatus.pending)
                      _buildPendingInfo()
                    else if (_status == VerificationStatus.approved)
                      _buildApprovedInfo()
                    else
                      _buildRejectedInfo(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Demo Buttons (untuk testing status)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Demo: Ubah Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _status = VerificationStatus.pending;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _status = VerificationStatus.approved;
                              });
                              
                              // Activate membership
                              final userData = UserData();
                              userData.isMember = true;
                              userData.ktaStatus = 'approved';
                              
                              // Generate membership number (format: AIA-YYYY-XXXX)
                              final now = DateTime.now();
                              final random = now.millisecondsSinceEpoch % 10000;
                              userData.membershipNumber = 'AIA-${now.year}-${random.toString().padLeft(4, '0')}';
                              
                              // Set validity period (2 years from now)
                              final validFrom = now;
                              final validUntil = DateTime(now.year + 2, now.month, now.day);
                              userData.membershipValidFrom = DateFormat('dd/MM/yyyy').format(validFrom);
                              userData.membershipValidUntil = DateFormat('dd/MM/yyyy').format(validUntil);
                              
                              // Save to SharedPreferences
                              await userData.saveData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B982),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Approved',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _status = VerificationStatus.rejected;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Rejected',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Back to Dashboard Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardNonMember()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B982),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kembali ke Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case VerificationStatus.pending:
        return const Color(0xFFF59E0B); // Orange
      case VerificationStatus.approved:
        return const Color(0xFF10B982); // Green
      case VerificationStatus.rejected:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case VerificationStatus.pending:
        return Icons.access_time_rounded;
      case VerificationStatus.approved:
        return Icons.check_circle_rounded;
      case VerificationStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  String _getStatusTitle() {
    switch (_status) {
      case VerificationStatus.pending:
        return 'Menunggu Verifikasi';
      case VerificationStatus.approved:
        return 'Terverifikasi!';
      case VerificationStatus.rejected:
        return 'Ditolak';
    }
  }

  String _getStatusMessage() {
    switch (_status) {
      case VerificationStatus.pending:
        return 'Pengajuan KTA Anda sedang dalam proses verifikasi oleh admin. Mohon tunggu konfirmasi lebih lanjut.';
      case VerificationStatus.approved:
        return 'Selamat! Pengajuan KTA Anda telah disetujui. Anda sekarang adalah member resmi Al Ihsan Archery.';
      case VerificationStatus.rejected:
        return 'Mohon maaf, pengajuan KTA Anda ditolak. Silakan periksa data dan dokumen Anda dan coba lagi.';
    }
  }

  Widget _buildPendingInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 20, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informasi Verifikasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Proses verifikasi memakan waktu 1-3 hari kerja\n'
            '• Pastikan dokumen KTA yang diupload jelas\n'
            '• Anda akan menerima notifikasi saat verifikasi selesai',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF92400E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B982).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.card_membership, size: 20, color: Color(0xFF10B982)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Detail Keanggotaan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B982),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Status: Member Aktif\n'
            '• Berlaku hingga: 31 Desember 2026\n'
            '• Akses penuh ke semua fasilitas club',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF065F46),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, size: 20, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alasan Penolakan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Dokumen KTA tidak jelas/tidak terbaca\n'
            '• Nomor anggota tidak valid\n'
            '• Data tidak sesuai dengan database',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF991B1B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Upload Ulang KTA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
