import 'package:flutter/material.dart';
import '../utils/training_data.dart';

class SummaryTableScreen extends StatelessWidget {
  final TrainingSession session;

  const SummaryTableScreen({super.key, required this.session});

  double _getRoundAverage(String playerName, int roundIndex) {
    // Check if player has scores
    if (session.scores[playerName] == null) {
      return 0;
    }

    // Check if round index is valid
    if (roundIndex >= session.scores[playerName]!.length) {
      return 0;
    }

    int total = 0;
    int count = 0;

    List<String> roundScores = session.scores[playerName]![roundIndex];

    for (var score in roundScores) {
      if (score.isNotEmpty) {
        int scoreValue = session.convertScoreToInt(score);
        total += scoreValue;
        count++;
      }
    }

    return count > 0 ? total / count : 0;
  }

  @override
  Widget build(BuildContext context) {
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
          'Ringkasan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: session.numberOfPlayers,
        itemBuilder: (context, playerIndex) {
          String playerName = session.playerNames[playerIndex];
          return _buildPlayerTable(playerName);
        },
      ),
    );
  }

  Widget _buildPlayerTable(String playerName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
          // Player Name Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF10B982),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              playerName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 0,
                headingRowHeight: 40,
                dataRowHeight: 36,
                border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                columns: [
                  DataColumn(
                    label: Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: const Text(
                        '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(
                    session.arrowsPerRound,
                    (index) => DataColumn(
                      label: Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: Text(
                          'arrow${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: 50,
                      alignment: Alignment.center,
                      child: const Text(
                        'AVG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: List.generate(session.numberOfRounds, (roundIndex) {
                  // Safely get round scores with null checks
                  List<String> roundScores = [];
                  if (session.scores[playerName] != null &&
                      roundIndex < session.scores[playerName]!.length) {
                    roundScores = session.scores[playerName]![roundIndex];
                  }

                  double roundAvg = _getRoundAverage(playerName, roundIndex);

                  return DataRow(
                    cells: [
                      // Round label
                      DataCell(
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: Text(
                            'R${roundIndex + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // Arrow scores
                      ...List.generate(session.arrowsPerRound, (arrowIndex) {
                        String score = '';
                        if (arrowIndex < roundScores.length) {
                          score = roundScores[arrowIndex];
                        }
                        return DataCell(
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Text(
                              score,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _getScoreColor(score),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Average
                      DataCell(
                        Container(
                          width: 50,
                          alignment: Alignment.center,
                          child: Text(
                            roundAvg > 0 ? roundAvg.toStringAsFixed(1) : '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B982),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(String score) {
    if (score.isEmpty) {
      return Colors.black87;
    }

    switch (score) {
      case 'X':
      case '10':
        return const Color(0xFFFBBF24);
      case '9':
        return const Color(0xFFFBBF24);
      case '8':
      case '7':
        return const Color(0xFFEF4444);
      case '6':
      case '5':
        return const Color(0xFF3B82F6);
      case '4':
      case '3':
        return const Color(0xFF1F2937);
      case 'M':
        return const Color(0xFF9CA3AF);
      default:
        return Colors.black87;
    }
  }
}
