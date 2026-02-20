import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adapters/supabase_training_adapter.dart';
import '../models/supabase/db_score_detail.dart';
import '../models/supabase/db_training_session.dart';
import '../utils/user_data.dart';
import 'training_result_screen.dart';

class CoachTrainingHistoryScreen extends StatefulWidget {
  const CoachTrainingHistoryScreen({super.key});

  @override
  State<CoachTrainingHistoryScreen> createState() =>
      _CoachTrainingHistoryScreenState();
}

class _CoachTrainingHistoryScreenState
    extends State<CoachTrainingHistoryScreen> {
  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _errorMessage;
  String? _selectedUserId;
  List<_CoachSessionItem> _items = [];
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userData = UserData();
    await userData.loadData();
    final role = userData.role;
    final isAuthorized = role == 'coach' || role == 'admin';
    if (!mounted) return;
    setState(() {
      _isAuthorized = isAuthorized;
    });
    if (isAuthorized) {
      await _loadData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPublicProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return const [];
    }

    final client = Supabase.instance.client;
    try {
      final response = await client.rpc(
        'list_user_public_profiles',
        params: {'user_ids': userIds},
      );
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      final fallback = await client
          .from('users')
          .select('id, full_name')
          .inFilter('id', userIds);
      return List<Map<String, dynamic>>.from(fallback as List);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final sessionRows = await client
          .from('training_sessions')
          .select(
            'id, user_id, training_date, training_name, total_score, '
            'accuracy_percentage, total_ends, arrows_per_end, '
            'number_of_players, mode, target_type, group_members, notes',
          )
          .order('training_date', ascending: false);

      final sessions = (sessionRows as List)
          .map((row) => DbTrainingSession.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      final userIds = sessions.map((session) => session.userId).toSet().toList();
      final userNames = <String, String>{};
      if (userIds.isNotEmpty) {
        final userRows = await _fetchPublicProfiles(userIds);
        for (final row in userRows) {
          final data = Map<String, dynamic>.from(row);
          final id = data['id']?.toString();
          if (id == null || id.isEmpty) continue;
          userNames[id] = data['full_name']?.toString() ?? 'Pemanah';
        }
      }

      if (!mounted) return;
      setState(() {
        _userNames = userNames;
        _items = sessions
            .map(
              (session) => _CoachSessionItem(
                session: session,
                userName: userNames[session.userId] ?? 'Pemanah',
              ),
            )
            .toList();
        if (_selectedUserId != null &&
            !_userNames.containsKey(_selectedUserId)) {
          _selectedUserId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F5E9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10B982),
          elevation: 0,
          title: const Text(
            'Validasi Skor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Text(
            'Menu ini hanya untuk pelatih.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    final filteredItems = _selectedUserId == null
        ? _items
        : _items
            .where((item) => item.session.userId == _selectedUserId)
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        title: const Text(
          'Validasi Skor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilterCard(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorCard(_errorMessage!),
            ],
            const SizedBox(height: 12),
            if (filteredItems.isEmpty)
              _buildEmptyState()
            else
              ...filteredItems.map(_buildSessionCard),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final items = _userNames.entries
        .map(
          (entry) => DropdownMenuItem<String?>(
            value: entry.key,
            child: Text(entry.value),
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Pemanah',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _selectedUserId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('Semua Pemanah'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Semua Pemanah'),
              ),
              ...items,
            ],
            onChanged: (value) {
              setState(() {
                _selectedUserId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(_CoachSessionItem item) {
    final session = item.session;
    final dateLabel = DateFormat('d MMM yyyy').format(session.trainingDate);
    final title =
        session.trainingName?.trim().isNotEmpty == true
            ? session.trainingName!.trim()
            : 'Latihan $dateLabel';
    final totalScore = session.totalScore;
    final accuracy = session.accuracyPercentage;
    final players =
        session.numberOfPlayers ??
        (session.groupMembers?.length ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF10B982),
            child: Text(
              item.userName.isNotEmpty
                  ? item.userName.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.userName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.group,
                        size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Text(
                      '$players pemain',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Skor: $totalScore',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B982),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Akurasi: ${accuracy.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF10B982)),
            onPressed: () => _openDetail(item),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.sports_score, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Belum ada riwayat latihan',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(_CoachSessionItem item) async {
    final sessionId = item.session.id;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = Supabase.instance.client;
      final detailRows = await client
          .from('score_details')
          .select()
          .eq('session_id', sessionId)
          .order('end_number', ascending: true)
          .order('arrow_number', ascending: true);

      final details = (detailRows as List)
          .map((row) => DbScoreDetail.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      final localSession =
          SupabaseTrainingAdapter.toLocalSession(item.session, details);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrainingResultScreen(session: localSession),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _CoachSessionItem {
  final DbTrainingSession session;
  final String userName;

  const _CoachSessionItem({
    required this.session,
    required this.userName,
  });
}
