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
  final String userId;
  final String memberName;
  final String? memberNumber;
  final String paymentType;
  final DateTime date;
  final double amount;
  final String imagePath;
  final String comment;
  final PaymentStatus status;
  final String? rejectionReason;

  PaymentRecord({
    required this.id,
    required this.userId,
    required this.memberName,
    this.memberNumber,
    this.paymentType = 'monthly_dues',
    required this.date,
    required this.amount,
    required this.imagePath,
    required this.comment,
    required this.status,
    this.rejectionReason,
  });

  PaymentRecord copyWith({
    String? id,
    String? userId,
    String? memberName,
    String? memberNumber,
    String? paymentType,
    DateTime? date,
    double? amount,
    String? imagePath,
    String? comment,
    PaymentStatus? status,
    String? rejectionReason,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      memberName: memberName ?? this.memberName,
      memberNumber: memberNumber ?? this.memberNumber,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      imagePath: imagePath ?? this.imagePath,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
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
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isManager = false;
  String? _errorMessage;
  String _selectedStatusFilter = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _paymentHistory = [];
        _unpaidMonths = [];
        _isLoading = false;
        _errorMessage = 'Silakan login terlebih dahulu.';
      });
      return;
    }

    try {
      _isManager = await _resolveRole(user.id);

      if (_isManager) {
        final managerRows = await Supabase.instance.client
            .from('payments')
            .select()
            .order('created_at', ascending: false);
        final managerPayments = List<Map<String, dynamic>>.from(
          managerRows as List,
        ).map(DbPayment.fromJson).toList();

        final userIds = managerPayments
            .map((payment) => payment.userId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final memberNames = await _fetchMemberNames(userIds);

        final mapped = <PaymentRecord>[];
        for (final payment in managerPayments) {
          final fallbackName = payment.userId.isNotEmpty
              ? 'User ${payment.userId.substring(0, 8)}'
              : 'Member';
          mapped.add(
            await _mapDbPayment(
              payment,
              memberName: memberNames[payment.userId] ?? fallbackName,
            ),
          );
        }

        if (!mounted) return;
        setState(() {
          _paymentHistory = mapped;
          _unpaidMonths = [];
          _isLoading = false;
        });
        return;
      }

      final payments = await _paymentService.fetchMonthlyPaymentsForUser(
        user.id,
      );
      final mapped = <PaymentRecord>[];
      for (final payment in payments) {
        mapped.add(await _mapDbPayment(payment, memberName: 'Saya'));
      }

      await _loadUnpaidMonths(user.id, payments);
      if (!mounted) return;
      setState(() {
        _paymentHistory = mapped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentHistory = [];
        _unpaidMonths = [];
        _isLoading = false;
        _errorMessage = 'Gagal memuat data pembayaran: $e';
      });
    }
  }

  Future<bool> _resolveRole(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('active_role,roles')
          .eq('id', userId)
          .maybeSingle();
      final activeRole =
          response?['active_role']?.toString().trim().toLowerCase() ??
          'non_member';
      final rawRoles = response?['roles'];
      final roles = rawRoles is List
          ? rawRoles.map((item) => item.toString().trim().toLowerCase()).toSet()
          : <String>{};
      final isManager =
          activeRole == 'admin' ||
          activeRole == 'staff' ||
          activeRole == 'pengurus' ||
          roles.contains('admin') ||
          roles.contains('staff') ||
          roles.contains('pengurus');
      return isManager;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _fetchMemberNames(List<String> userIds) async {
    final names = <String, String>{};
    if (userIds.isEmpty) {
      return names;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'list_user_public_profiles',
        params: {'user_ids': userIds},
      );
      for (final row in (response as List)) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = data['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final fullName = data['full_name']?.toString().trim();
        if (fullName != null && fullName.isNotEmpty) {
          names[id] = fullName;
        }
      }
      return names;
    } catch (_) {
      return names;
    }
  }

  Future<PaymentRecord> _mapDbPayment(
    DbPayment payment, {
    required String memberName,
  }) async {
    final proofUrl = await _paymentService.resolveProofUrl(payment.proofUrl);
    final date = payment.paymentMonth ?? payment.createdAt ?? DateTime.now();
    final status = _mapPaymentStatus(payment.status);
    final comment = payment.notes?.trim() ?? '';
    return PaymentRecord(
      id: payment.id ?? '',
      userId: payment.userId,
      memberName: memberName,
      paymentType: payment.paymentType,
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

  String _toDbPaymentStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return 'verified';
      case PaymentStatus.rejected:
        return 'rejected';
      case PaymentStatus.pending:
        return 'pending';
    }
  }

  PaymentStatus? _statusFromFilter(String value) {
    switch (value) {
      case 'Pending':
        return PaymentStatus.pending;
      case 'Disetujui':
        return PaymentStatus.approved;
      case 'Ditolak':
        return PaymentStatus.rejected;
      default:
        return null;
    }
  }

  List<PaymentRecord> get _filteredPayments {
    var result = List<PaymentRecord>.from(_paymentHistory);
    final statusFilter = _statusFromFilter(_selectedStatusFilter);
    if (statusFilter != null) {
      result = result
          .where((payment) => payment.status == statusFilter)
          .toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((payment) {
        return payment.memberName.toLowerCase().contains(query) ||
            payment.userId.toLowerCase().contains(query) ||
            (payment.memberNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return result;
  }

  String _paymentTitle(PaymentRecord payment) {
    if (payment.paymentType == 'registration') {
      return 'Biaya Registrasi';
    }
    return 'Iuran ${_formatPaymentMonth(payment.date)}';
  }

  Future<void> _updatePaymentStatus({
    required int index,
    required PaymentRecord payment,
    required PaymentStatus newStatus,
    String? rejectionReason,
  }) async {
    if (!_isManager) {
      return;
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User belum login.');
    }

    final payload = <String, dynamic>{'status': _toDbPaymentStatus(newStatus)};
    if (newStatus == PaymentStatus.approved) {
      payload['verified_by'] = currentUser.id;
      payload['verified_at'] = DateTime.now().toIso8601String();
      payload['rejection_reason'] = null;
    } else if (newStatus == PaymentStatus.rejected) {
      payload['verified_by'] = null;
      payload['verified_at'] = null;
      payload['rejection_reason'] = rejectionReason?.trim().isNotEmpty == true
          ? rejectionReason!.trim()
          : null;
    } else {
      payload['verified_by'] = null;
      payload['verified_at'] = null;
      payload['rejection_reason'] = null;
    }

    await Supabase.instance.client
        .from('payments')
        .update(payload)
        .eq('id', payment.id);

    if (!mounted) return;
    setState(() {
      _paymentHistory[index] = payment.copyWith(
        status: newStatus,
        rejectionReason: newStatus == PaymentStatus.rejected
            ? payload['rejection_reason']
            : null,
      );
    });
  }

  Future<void> _loadUnpaidMonths(
    String userId,
    List<DbPayment> payments,
  ) async {
    final startMonth = await _paymentService.fetchBillingStartMonth(userId);
    final currentMonth = _currentMonth();
    final coveredMonths = payments
        .where(
          (payment) =>
              payment.paymentMonth != null && payment.status != 'rejected',
        )
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
    final displayedPayments = _isManager ? _filteredPayments : _paymentHistory;

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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPaymentHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderSummary(
            displayedCount: displayedPayments.length,
            totalCount: _paymentHistory.length,
          ),
          if (_isManager) _buildManagerFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B982)),
                  )
                : _errorMessage != null && _paymentHistory.isEmpty
                ? _buildErrorState()
                : displayedPayments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedPayments.length,
                    itemBuilder: (context, index) {
                      final payment = displayedPayments[index];
                      final sourceIndex = _paymentHistory.indexWhere(
                        (item) => item.id == payment.id,
                      );
                      return _buildPaymentCard(
                        payment,
                        sourceIndex >= 0 ? sourceIndex : index,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _isManager
          ? null
          : FloatingActionButton(
              onPressed: _showPaymentForm,
              backgroundColor: const Color(0xFF10B982),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildHeaderSummary({
    required int displayedCount,
    required int totalCount,
  }) {
    final title = _isManager ? 'Panel Pembayaran Pengurus' : 'Iuran Bulanan';
    final subtitle = _isManager
        ? 'Kelola dan verifikasi pembayaran member'
        : 'Rp 100.000';

    return Container(
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
            child: Icon(
              _isManager ? Icons.manage_accounts : Icons.account_balance_wallet,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: _isManager ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isManager) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric(
                          label: 'Ditampilkan',
                          value: '$displayedCount',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeaderMetric(
                          label: 'Total Data',
                          value: '$totalCount',
                        ),
                      ),
                    ],
                  ),
                  if (_selectedStatusFilter != 'Semua') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Filter aktif: $_selectedStatusFilter',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!_isManager) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                      style: TextStyle(fontSize: 12, color: Colors.white70),
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
        ],
      ),
    );
  }

  Widget _buildHeaderMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerFilters() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'Semua',
                      child: Text('Semua Status'),
                    ),
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'Disetujui',
                      child: Text('Disetujui'),
                    ),
                    DropdownMenuItem(value: 'Ditolak', child: Text('Ditolak')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Filter Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Cari member',
                    hintText: 'Nama / User ID',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _searchQuery.isEmpty
                        ? const Icon(Icons.search)
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final text = _isManager
        ? 'Belum ada data pembayaran sesuai filter.'
        : 'Belum ada riwayat pembayaran';
    final sub = _isManager
        ? 'Coba ubah filter atau refresh data.'
        : 'Tap tombol + untuk membayar';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPaymentHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B982),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
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
                            _paymentTitle(payment),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatPaymentDate(payment.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              if (_isManager) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    payment.memberName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
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
                if (payment.rejectionReason != null &&
                    payment.rejectionReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Alasan ditolak: ${payment.rejectionReason}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
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
        canManageStatus: _isManager,
        onStatusSubmitted: _isManager
            ? (newStatus, rejectionReason) async {
                await _updatePaymentStatus(
                  index: index,
                  payment: payment,
                  newStatus: newStatus,
                  rejectionReason: rejectionReason,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Status pembayaran berhasil diperbarui.'),
                    backgroundColor: Color(0xFF10B982),
                  ),
                );
              }
            : null,
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
        }

        final payment = PaymentRecord(
          id:
              insertedId ??
              'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          userId: currentUser.id,
          memberName: 'Saya',
          paymentType: 'monthly_dues',
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                color: const Color(0xFF10B982).withOpacity(0.5),
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
                                                color: const Color(
                                                  0xFF10B982,
                                                ).withOpacity(0.2),
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
                                            color: const Color(
                                              0xFF10B982,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            File(_uploadedImage!),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
  final bool canManageStatus;
  final Future<void> Function(PaymentStatus, String?)? onStatusSubmitted;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.canManageStatus = false,
    this.onStatusSubmitted,
  });

  @override
  State<PaymentDetailSheet> createState() => _PaymentDetailSheetState();
}

class _PaymentDetailSheetState extends State<PaymentDetailSheet> {
  late PaymentStatus _currentStatus;
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  bool _isSubmittingStatus = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.payment.status;
    _rejectionReasonController.text = widget.payment.rejectionReason ?? '';
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
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
                DateFormat('dd MMMM yyyy', 'id_ID').format(widget.payment.date),
              ),
              _buildDetailRow(
                'Jenis',
                _paymentTypeLabel(widget.payment.paymentType),
              ),
              _buildDetailRow('Status', _statusLabel(_currentStatus)),
              if (widget.canManageStatus) ...[
                _buildDetailRow('Member', widget.payment.memberName),
                _buildDetailRow('User ID', widget.payment.userId),
              ],
              if (widget.payment.comment.isNotEmpty)
                _buildDetailRow('Komentar', widget.payment.comment),
              if (widget.payment.rejectionReason != null &&
                  widget.payment.rejectionReason!.trim().isNotEmpty)
                _buildDetailRow(
                  'Alasan Ditolak',
                  widget.payment.rejectionReason!.trim(),
                ),
              const SizedBox(height: 20),
              if (widget.canManageStatus &&
                  widget.onStatusSubmitted != null) ...[
                const Text(
                  'Kelola Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(PaymentStatus.pending, const Color(0xFFF59E0B)),
                    _statusChip(
                      PaymentStatus.approved,
                      const Color(0xFF10B982),
                    ),
                    _statusChip(
                      PaymentStatus.rejected,
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
                if (_currentStatus == PaymentStatus.rejected) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Alasan penolakan',
                      hintText: 'Isi alasan jika status ditolak',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmittingStatus ? null : _submitStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B982),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmittingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Status'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
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

  Future<void> _submitStatus() async {
    final handler = widget.onStatusSubmitted;
    if (handler == null) {
      return;
    }
    if (_currentStatus == PaymentStatus.rejected &&
        _rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan penolakan wajib diisi untuk status ditolak.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingStatus = true;
    });
    try {
      await handler(
        _currentStatus,
        _currentStatus == PaymentStatus.rejected
            ? _rejectionReasonController.text
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingStatus = false;
        });
      }
    }
  }

  Widget _statusChip(PaymentStatus status, Color color) {
    return ChoiceChip(
      label: Text(_statusLabel(status)),
      selected: _currentStatus == status,
      selectedColor: color.withOpacity(0.18),
      labelStyle: TextStyle(
        color: _currentStatus == status ? color : const Color(0xFF6B7280),
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() {
          _currentStatus = status;
        });
      },
    );
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.approved:
        return 'Disetujui';
      case PaymentStatus.rejected:
        return 'Ditolak';
    }
  }

  String _paymentTypeLabel(String paymentType) {
    switch (paymentType) {
      case 'registration':
        return 'Registrasi';
      case 'monthly_dues':
        return 'Iuran Bulanan';
      default:
        return paymentType;
    }
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
