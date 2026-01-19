import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_payment_service.dart';
import '../../models/supabase/db_payment.dart';

enum PaymentStatus { pending, approved, rejected }

class PaymentRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String imagePath;
  final String comment;
  final PaymentStatus status;
  final String? rejectionReason;

  PaymentRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.imagePath,
    required this.comment,
    required this.status,
    this.rejectionReason,
  });
}

class PembayaranScreen extends StatefulWidget {
  const PembayaranScreen({super.key});

  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  List<PaymentRecord> _paymentHistory = [];
  List<DateTime> _unpaidMonths = [];
  final SupabasePaymentService _paymentService = SupabasePaymentService();

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _loadDemoPayments();
      return;
    }

    try {
      final payments =
          await _paymentService.fetchMonthlyPaymentsForUser(user.id);
      if (payments.isEmpty) {
        await _loadUnpaidMonths(user.id, payments);
        if (mounted) {
          setState(() {
            _paymentHistory = [];
          });
        }
        return;
      }

      final mapped = <PaymentRecord>[];
      for (final payment in payments) {
        mapped.add(await _mapDbPayment(payment));
      }

      await _loadUnpaidMonths(user.id, payments);
      if (mounted) {
        setState(() {
          _paymentHistory = mapped;
        });
      }
    } catch (_) {
      _loadDemoPayments();
    }
  }

  void _loadDemoPayments() {
    if (!mounted) return;
    setState(() {
      _paymentHistory = [
        PaymentRecord(
          id: 'PAY-001',
          date: DateTime(2026, 1, 5),
          amount: 100000.0,
          imagePath: '',
          comment: 'Iuran bulan Januari 2026',
          status: PaymentStatus.approved,
        ),
        PaymentRecord(
          id: 'PAY-002',
          date: DateTime(2025, 12, 10),
          amount: 100000.0,
          imagePath: '',
          comment: 'Iuran bulan Desember 2025',
          status: PaymentStatus.approved,
        ),
      ];
      _unpaidMonths = [_currentMonth()];
    });
  }

  Future<PaymentRecord> _mapDbPayment(DbPayment payment) async {
    final proofUrl = await _paymentService.resolveProofUrl(payment.proofUrl);
    final date =
        payment.paymentMonth ?? payment.createdAt ?? DateTime.now();
    final status = _mapPaymentStatus(payment.status);
    final comment = payment.notes?.trim() ?? '';
    return PaymentRecord(
      id: payment.id ?? '',
      date: date,
      amount: payment.amount.toDouble(),
      imagePath: proofUrl ?? '',
      comment: comment,
      status: status,
      rejectionReason: payment.rejectionReason,
    );
  }

  PaymentStatus _mapPaymentStatus(String status) {
    switch (status) {
      case 'verified':
        return PaymentStatus.approved;
      case 'rejected':
        return PaymentStatus.rejected;
      default:
        return PaymentStatus.pending;
    }
  }

  Future<void> _loadUnpaidMonths(
    String userId,
    List<DbPayment> payments,
  ) async {
    final startMonth = await _paymentService.fetchBillingStartMonth(userId);
    final currentMonth = _currentMonth();
    final coveredMonths = payments
        .where((payment) =>
            payment.paymentMonth != null && payment.status != 'rejected')
        .map((payment) => _monthKey(payment.paymentMonth!))
        .toSet();

    final earliestMonth = _earliestPaymentMonth(payments);
    final baseMonth = startMonth ?? earliestMonth ?? currentMonth;
    final unpaid = _calculateUnpaidMonths(
      startMonth: baseMonth,
      currentMonth: currentMonth,
      coveredMonths: coveredMonths,
    );

    if (mounted) {
      setState(() {
        _unpaidMonths = unpaid;
      });
    }
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime? _earliestPaymentMonth(List<DbPayment> payments) {
    DateTime? earliest;
    for (final payment in payments) {
      final month = payment.paymentMonth ?? payment.createdAt;
      if (month == null) {
        continue;
      }
      final normalized = DateTime(month.year, month.month, 1);
      if (earliest == null || normalized.isBefore(earliest)) {
        earliest = normalized;
      }
    }
    return earliest;
  }

  List<DateTime> _calculateUnpaidMonths({
    required DateTime startMonth,
    required DateTime currentMonth,
    required Set<String> coveredMonths,
  }) {
    final unpaid = <DateTime>[];
    var cursor = DateTime(startMonth.year, startMonth.month, 1);
    while (!cursor.isAfter(currentMonth)) {
      if (!coveredMonths.contains(_monthKey(cursor))) {
        unpaid.add(cursor);
      }
      cursor = _addMonths(cursor, 1);
    }
    return unpaid.reversed.toList();
  }

  DateTime _addMonths(DateTime value, int months) {
    final year = value.year + ((value.month - 1 + months) ~/ 12);
    final month = (value.month - 1 + months) % 12 + 1;
    return DateTime(year, month, 1);
  }

  String _monthKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}';
  }

  String _formatUnpaidMonth(DateTime value) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(value);
  }

  String _formatPaymentMonth(DateTime value) {
    return DateFormat('MMMM yyyy', 'id_ID').format(value);
  }

  String _formatPaymentDate(DateTime value) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(value);
  }

  void _showPaymentForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentFormScreen(
          onPaymentSubmitted: (payment) {
            setState(() {
              _paymentHistory.insert(0, payment);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pembayaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF10B982), Color(0xFF059669)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Iuran Bulanan',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rp 100.000',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Belum dibayar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_unpaidMonths.isEmpty)
                        const Text(
                          'Semua iuran sudah dibayar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: _unpaidMonths
                              .map(
                                (month) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatUnpaidMonth(month),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Payment History
          Expanded(
            child: _paymentHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada riwayat pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap tombol + untuk membayar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paymentHistory.length,
                    itemBuilder: (context, index) {
                      final payment = _paymentHistory[index];
                      return _buildPaymentCard(payment, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPaymentForm,
        backgroundColor: const Color(0xFF10B982),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRecord payment, int index) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case PaymentStatus.approved:
        statusColor = const Color(0xFF10B982);
        statusIcon = Icons.check_circle;
        statusText = 'Disetujui';
        break;
      case PaymentStatus.rejected:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusText = 'Ditolak';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showPaymentDetail(payment, index);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.payment, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iuran ${_formatPaymentMonth(payment.date)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatPaymentDate(payment.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jumlah Pembayaran',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(payment.amount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B982),
                      ),
                    ),
                  ],
                ),
                if (payment.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    payment.comment,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentDetail(PaymentRecord payment, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentDetailSheet(
        payment: payment,
        onStatusChanged: (newStatus) {
          setState(() {
            _paymentHistory[index] = PaymentRecord(
              id: payment.id,
              date: payment.date,
              amount: payment.amount,
              imagePath: payment.imagePath,
              comment: payment.comment,
              status: newStatus,
            );
          });
        },
      ),
    );
  }
}

// Payment Form Screen
class PaymentFormScreen extends StatefulWidget {
  final Function(PaymentRecord) onPaymentSubmitted;

  const PaymentFormScreen({super.key, required this.onPaymentSubmitted});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _paymentService = SupabasePaymentService();
  String? _uploadedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _uploadedImage = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bukti pembayaran berhasil dipilih!'),
              backgroundColor: Color(0xFF10B982),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      if (_uploadedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan upload bukti pembayaran terlebih dahulu!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_isSubmitting) {
        return;
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final now = DateTime.now();
        final paymentMonth = DateTime(now.year, now.month, 1);
        final proofPath = await _paymentService.uploadPaymentProof(
          file: File(_uploadedImage!),
          userId: currentUser.id,
          paymentMonth: paymentMonth,
        );

        final inserted = await _paymentService.createMonthlyPayment(
          userId: currentUser.id,
          amount: 100000,
          proofUrl: proofPath,
          paymentMonth: paymentMonth,
          notes: _commentController.text,
        );

        final insertedId = inserted['id']?.toString();
        if (insertedId != null) {
          final verify = await _paymentService.fetchPaymentById(insertedId);
          if (verify == null) {
            throw Exception('Payment insert verification failed.');
          }
          print('Payment saved to Supabase: $verify');
        }

        final payment = PaymentRecord(
          id: insertedId ??
              'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          date: DateTime.now(),
          amount: 100000.0,
          imagePath: _uploadedImage!,
          comment: _commentController.text,
          status: PaymentStatus.pending,
        );

        widget.onPaymentSubmitted(payment);
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pembayaran berhasil diajukan! Menunggu verifikasi admin.',
            ),
            backgroundColor: Color(0xFF10B982),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B982), Color(0xFF059669)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bayar Iuran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount Info
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10B982), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B982).withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Jumlah Iuran',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Rp 100.000',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Transfer ke rekening club yang telah ditentukan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Upload Proof
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
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
                              color: const Color(0xFF10B982).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Color(0xFF10B982),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Upload Bukti Pembayaran',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Text(
                            '*',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pastikan foto jelas dan nominal terlihat.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            height: 200,
                            decoration: BoxDecoration(
                              color: _uploadedImage == null
                                  ? const Color(0xFFECFDF5)
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    const Color(0xFF10B982).withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: _uploadedImage == null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF10B982)
                                                    .withOpacity(0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.cloud_upload_rounded,
                                            size: 36,
                                            color: Color(0xFF10B982),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Tap untuk upload bukti transfer',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF4B5563),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B982)
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'JPG, PNG • maks 5MB',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.file(
                                            File(_uploadedImage!),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.55),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        left: 16,
                                        bottom: 16,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Bukti pembayaran terpilih',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _uploadedImage = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Comment
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
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
                              color: const Color(0xFF10B982).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note,
                              color: Color(0xFF10B982),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Komentar (Opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Iuran bulan Januari 2026',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B982),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Submit Button
                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10B982), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B982).withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Kirim Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Payment Detail Bottom Sheet
class PaymentDetailSheet extends StatefulWidget {
  final PaymentRecord payment;
  final Function(PaymentStatus) onStatusChanged;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    required this.onStatusChanged,
  });

  @override
  State<PaymentDetailSheet> createState() => _PaymentDetailSheetState();
}

class _PaymentDetailSheetState extends State<PaymentDetailSheet> {
  late PaymentStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.payment.status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Detail Pembayaran',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Payment Info
              _buildDetailRow(
                'Tanggal',
                DateFormat('dd MMMM yyyy', 'id_ID')
                    .format(widget.payment.date),
              ),
              if (widget.payment.comment.isNotEmpty)
                _buildDetailRow('Komentar', widget.payment.comment),
              const SizedBox(height: 20),
              // Proof Image
              if (widget.payment.imagePath.isNotEmpty) ...[
                const Text(
                  'Bukti Pembayaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.payment.imagePath.startsWith('http')
                      ? Image.network(
                          widget.payment.imagePath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(widget.payment.imagePath),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 20),
              ],
              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B982),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: const Text(
                  'Tutup',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
