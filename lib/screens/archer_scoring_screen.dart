import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'training_result_screen.dart';
import '../utils/training_data.dart';
import '../services/supabase_training_service.dart';

class ArcherScoringScreen extends StatefulWidget {
  const ArcherScoringScreen({super.key});

  @override
  State<ArcherScoringScreen> createState() => ArcherScoringScreenState();
}

class ArcherScoringScreenState extends State<ArcherScoringScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData(showLoading: true);
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    final trainingData = TrainingData();
    await trainingData.loadData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    try {
      final service = SupabaseTrainingService();
      final remoteSessions = await service.fetchTrainingHistory();
      await trainingData.mergeRemoteSessions(remoteSessions);
      try {
        final synced = await service.syncPendingSessions(
          trainingData.sessions,
        );
        if (synced > 0) {
          await trainingData.saveData();
        }
      } catch (e) {
        debugPrint('Supabase sync failed, using merged data: $e');
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Supabase fetch failed, using local data: $e');
    }
  }

  Future<void> refresh() async {
    await _loadData(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = TrainingData().getCompletedSessions();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F5E9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Archer Scoring',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF10B982),
        onRefresh: refresh,
        child: sessions.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_score,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Belum ada latihan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tarik ke bawah untuk refresh',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _buildTrainingCard(session);
                },
              ),
      ),
    );
  }

  Widget _buildTrainingCard(TrainingSession session) {
    String dateStr = DateFormat('d/M/yyyy').format(session.date);
    String displayTitle = session.trainingName ?? 'Training $dateStr';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF10B982),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          // Training Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.numberOfRounds} Rambahan • ${session.arrowsPerRound} Arrows/Rambahan',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                // Show scores for each player
                ...session.playerNames.map((playerName) {
                  int totalScore = session.getTotalScore(playerName);
                  double avgScore = session.getAverageScore(playerName);

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (session.numberOfPlayers > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              playerName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B982),
                              ),
                            ),
                          ),
                        if (session.numberOfPlayers > 1)
                          const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Score: $totalScore • Avg: ${avgScore.toStringAsFixed(1)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B982),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          // Menu Icon
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'detail',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Detail'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'detail') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TrainingResultScreen(session: session),
                  ),
                );
              } else if (value == 'delete') {
                _deleteSession(session);
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteSession(TrainingSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Training'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus data training ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await TrainingData().removeSession(session);
              setState(() {});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Training berhasil dihapus'),
                    backgroundColor: Color(0xFF10B982),
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
