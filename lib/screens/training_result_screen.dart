import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/training_data.dart';

class TrainingResultScreen extends StatelessWidget {
  final TrainingSession session;

  const TrainingResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Training Results',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Green Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF10B982),
                    Color(0xFF059669),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Trophy Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Training ${DateFormat('d/M/yyyy').format(session.date)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('d/M/yyyy').format(session.date),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Player Results - Loop untuk semua player
            ...session.playerNames.map((playerName) {
              return _buildPlayerStats(playerName);
            }).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStats(String playerName) {
    final totalScore = session.getTotalScore(playerName);
    final avgScore = session.getAverageScore(playerName);
    final totalArrows = session.numberOfRounds * session.arrowsPerRound;
    
    // Calculate accuracy
    int hitCount = 0;
    for (int round = 0; round < session.numberOfRounds; round++) {
      final roundScores = session.scores[playerName]?[round] ?? [];
      for (var score in roundScores) {
        if (score != 'M') hitCount++;
      }
    }
    final accuracy = (hitCount / totalArrows) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.numberOfPlayers > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              playerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B982),
              ),
            ),
          ),
        if (session.numberOfPlayers > 1) const SizedBox(height: 12),
        // Stats Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildStatCard(
                icon: Icons.star,
                iconColor: Colors.orange,
                value: totalScore.toString(),
                label: 'Total Score',
                valueColor: Colors.orange,
              ),
              _buildStatCard(
                icon: Icons.trending_up,
                iconColor: Colors.blue,
                value: avgScore.toStringAsFixed(2),
                label: 'Average',
                valueColor: Colors.blue,
              ),
              _buildStatCard(
                icon: Icons.adjust,
                iconColor: Colors.green,
                value: '${accuracy.toStringAsFixed(1)}%',
                label: 'Accuracy',
                valueColor: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.arrow_forward,
                iconColor: Colors.purple,
                value: totalArrows.toString(),
                label: 'Arrows',
                valueColor: Colors.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Round Details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Round Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // Round Cards
              ...List.generate(session.numberOfRounds, (roundIndex) {
                return _buildRoundCard(roundIndex, playerName);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: iconColor),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(int roundIndex, String playerName) {
    final roundScores = session.scores[playerName]?[roundIndex] ?? [];
    int roundTotal = 0;
    for (var score in roundScores) {
      roundTotal += session.convertScoreToInt(score);
    }
    final roundAvg = roundScores.isNotEmpty ? roundTotal / roundScores.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Round ${roundIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $roundTotal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B982),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score boxes
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roundScores.map((score) {
              return _buildScoreBox(score);
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Average: ${roundAvg.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBox(String score) {
    Color bgColor;
    Color textColor = Colors.white;
    
    switch (score) {
      case 'X':
      case '9':
        bgColor = const Color(0xFFFBBF24); // Yellow
        break;
      case '8':
      case '7':
        bgColor = const Color(0xFFEF4444); // Red
        break;
      case '6':
      case '5':
        bgColor = const Color(0xFF3B82F6); // Blue
        break;
      case '4':
      case '3':
        bgColor = const Color(0xFF1F2937); // Black
        break;
      case '2':
      case '1':
        bgColor = Colors.white;
        textColor = Colors.black;
        break;
      default: // M
        bgColor = const Color(0xFF9CA3AF); // Grey
        break;
    }
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: score == '2' || score == '1' 
            ? Border.all(color: Colors.grey, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        score,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
