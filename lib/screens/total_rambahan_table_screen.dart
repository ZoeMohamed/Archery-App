import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/training_data.dart';

class TotalRambahanTableScreen extends StatelessWidget {
  final TrainingSession session;

  const TotalRambahanTableScreen({super.key, required this.session});

  // Calculate total score per round for a player
  int _getRoundTotal(String playerName, int roundIndex) {
    if (session.scores[playerName] == null) {
      return 0;
    }

    if (roundIndex >= session.scores[playerName]!.length) {
      return 0;
    }

    int total = 0;

    List<String> roundScores = session.scores[playerName]![roundIndex];

    for (var score in roundScores) {
      if (score.isNotEmpty) {
        int scoreValue = session.convertScoreToInt(score);
        total += scoreValue;
      }
    }

    return total;
  }

  // Calculate grand total across all rounds for a player
  int _getGrandTotal(String playerName) {
    int sum = 0;
    for (int i = 0; i < session.numberOfRounds; i++) {
      sum += _getRoundTotal(playerName, i);
    }
    return sum;
  }

  // Calculate average per round for a player
  double _getAveragePerRound(String playerName) {
    if (session.numberOfRounds <= 0) {
      return 0;
    }
    return _getGrandTotal(playerName) / session.numberOfRounds;
  }

  // Get players sorted by rank (highest grand total first)
  List<Map<String, dynamic>> _getPlayersWithRank() {
    List<Map<String, dynamic>> playerData = [];

    for (String playerName in session.playerNames) {
      int grandTotal = _getGrandTotal(playerName);
      playerData.add({
        'name': playerName,
        'grandTotal': grandTotal,
      });
    }

    // Sort by grand total descending
    playerData.sort((a, b) =>
        (b['grandTotal'] as int).compareTo(a['grandTotal'] as int));

    // Add rank
    for (int i = 0; i < playerData.length; i++) {
      playerData[i]['rank'] = i + 1;
    }

    return playerData;
  }

  @override
  Widget build(BuildContext context) {
    // Only show if 2 or more players
    if (session.numberOfPlayers < 2) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10B982),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Total Rambahan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Tabel ini hanya tersedia untuk latihan dengan 2 atau lebih pemain.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final playersWithRank = _getPlayersWithRank();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Total Rambahan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B982),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'image/Logo 2.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Training Info Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Latihan tgl',
                      DateFormat('d MMM yyyy , HH:mm').format(session.date),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Jarak',
                      session.distance?.isNotEmpty == true
                          ? session.distance!
                          : '-',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Jml rambahan', '${session.numberOfRounds}'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Jml arrow', '${session.arrowsPerRound}'),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 0,
                    headingRowHeight: 40,
                    dataRowHeight: 40,
                    border: TableBorder.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                    columns: [
                      // Player name column
                      DataColumn(
                        label: Container(
                          width: 100,
                          alignment: Alignment.center,
                          child: const Text(
                            'Pemanah',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // Rank column
                      DataColumn(
                        label: Container(
                          width: 55,
                          alignment: Alignment.center,
                          child: const Text(
                            'Rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // Total column
                      DataColumn(
                        label: Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // Average column
                      DataColumn(
                        label: Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: const Text(
                            'Avg',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // R1 to Rx columns
                      ...List.generate(
                        session.numberOfRounds,
                        (index) => DataColumn(
                          label: Container(
                            width: 55,
                            alignment: Alignment.center,
                            child: Text(
                              'R${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: playersWithRank.map((playerData) {
                      final playerName = playerData['name'] as String;
                      final grandTotal = playerData['grandTotal'] as int;
                      final rank = playerData['rank'] as int;
                      final avgPerRound = _getAveragePerRound(playerName);

                      return DataRow(
                        cells: [
                          // Player name
                          DataCell(
                            Container(
                              width: 100,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                playerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Rank
                          DataCell(
                            Container(
                              width: 55,
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRankColor(rank),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  rank.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Grand Total
                          DataCell(
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Text(
                                grandTotal.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B982),
                                ),
                              ),
                            ),
                          ),
                          // Average per round
                          DataCell(
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Text(
                                avgPerRound.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          // Round totals
                          ...List.generate(
                            session.numberOfRounds,
                            (roundIndex) {
                              final roundTotal =
                                  _getRoundTotal(playerName, roundIndex);
                              return DataCell(
                                Container(
                                  width: 55,
                                  alignment: Alignment.center,
                                  child: Text(
                                    roundTotal.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _getScoreColor(roundTotal),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B982),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int total) {
    if (total >= 54) {
      return const Color(0xFFFBBF24); // Gold
    } else if (total >= 42) {
      return const Color(0xFFEF4444); // Red
    } else if (total >= 30) {
      return const Color(0xFF3B82F6); // Blue
    } else {
      return Colors.black87;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24); // Gold
      case 2:
        return const Color(0xFF9CA3AF); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}
