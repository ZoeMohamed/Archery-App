import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/training_data.dart';
import 'summary_table_screen.dart';

class TrainingResultScreen extends StatefulWidget {
  final TrainingSession session;

  const TrainingResultScreen({super.key, required this.session});

  @override
  State<TrainingResultScreen> createState() => _TrainingResultScreenState();
}

class _TrainingResultScreenState extends State<TrainingResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.session.numberOfPlayers,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedPlayerIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Training Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.description, color: Colors.white),
            tooltip: 'Ringkasan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SummaryTableScreen(session: widget.session),
                ),
              );
            },
          ),
          if (widget.session.numberOfPlayers > 1)
            IconButton(
              icon: const Icon(Icons.table_chart, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AverageTableScreen(session: widget.session),
                  ),
                );
              },
            ),
        ],
        bottom: widget.session.numberOfPlayers > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                tabs: widget.session.playerNames.map((name) {
                  return Tab(text: name);
                }).toList(),
              )
            : null,
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
                  colors: [Color(0xFF10B982), Color(0xFF059669)],
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
                    'Training ${DateFormat('d/M/yyyy').format(widget.session.date)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('d/M/yyyy').format(widget.session.date),
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Player Results - Show only selected player
            _buildPlayerStats(widget.session.playerNames[_selectedPlayerIndex]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStats(String playerName) {
    final totalScore = widget.session.getTotalScore(playerName);
    final avgScore = widget.session.getAverageScore(playerName);
    final totalArrows =
        widget.session.numberOfRounds * widget.session.arrowsPerRound;

    // Calculate accuracy
    int hitCount = 0;
    for (int round = 0; round < widget.session.numberOfRounds; round++) {
      final roundScores = widget.session.scores[playerName]?[round] ?? [];
      for (var score in roundScores) {
        if (score != 'M') hitCount++;
      }
    }
    final accuracy = (hitCount / totalArrows) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                'Detail per Rambahan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // Round Cards
              ...List.generate(widget.session.numberOfRounds, (roundIndex) {
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(int roundIndex, String playerName) {
    final roundScores = widget.session.scores[playerName]?[roundIndex] ?? [];
    int roundTotal = 0;
    for (var score in roundScores) {
      roundTotal += widget.session.convertScoreToInt(score);
    }
    final roundAvg = roundScores.isNotEmpty
        ? roundTotal / roundScores.length
        : 0;

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
                'Rambahan ${roundIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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

// Average Table Screen
class AverageTableScreen extends StatelessWidget {
  final TrainingSession session;

  const AverageTableScreen({super.key, required this.session});

  int _getTotalScore(String playerName) {
    int total = 0;
    if (session.scores[playerName] != null) {
      for (var round in session.scores[playerName]!) {
        for (var score in round) {
          if (score.isNotEmpty) {
            total += session.convertScoreToInt(score);
          }
        }
      }
    }
    return total;
  }

  int _getRoundTotal(String playerName, int roundIndex) {
    int total = 0;
    if (session.scores[playerName] != null &&
        roundIndex < session.scores[playerName]!.length) {
      for (var score in session.scores[playerName]![roundIndex]) {
        if (score.isNotEmpty) {
          total += session.convertScoreToInt(score);
        }
      }
    }
    return total;
  }

  double _getAverageScore(String playerName) {
    int total = _getTotalScore(playerName);
    int arrowCount = 0;
    if (session.scores[playerName] != null) {
      for (var round in session.scores[playerName]!) {
        for (var score in round) {
          if (score.isNotEmpty) arrowCount++;
        }
      }
    }
    if (arrowCount == 0) return 0;
    return total / arrowCount;
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
          'Average',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Main Result Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B982),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'AVG',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        ...List.generate(session.numberOfRounds, (index) {
                          return Expanded(
                            flex: 1,
                            child: Text(
                              'R${index + 1}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Total Score',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table Rows for each player
                  ...session.playerNames.map((playerName) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              playerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          ...List.generate(session.numberOfRounds, (
                            roundIndex,
                          ) {
                            int roundTotal = _getRoundTotal(
                              playerName,
                              roundIndex,
                            );
                            return Expanded(
                              flex: 1,
                              child: Text(
                                roundTotal > 0 ? '$roundTotal' : '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                _showPlayerDetailDialog(context, playerName);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B982),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'View Detail',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerDetailDialog(BuildContext context, String playerName) {
    int totalScore = _getTotalScore(playerName);
    double avgScore = _getAverageScore(playerName);

    // Calculate accuracy
    int hitCount = 0;
    int totalArrows = 0;
    if (session.scores[playerName] != null) {
      for (var round in session.scores[playerName]!) {
        for (var score in round) {
          if (score.isNotEmpty) {
            totalArrows++;
            if (score != 'M') hitCount++;
          }
        }
      }
    }
    double accuracy = totalArrows > 0 ? (hitCount / totalArrows) * 100 : 0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1FAF5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                playerName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    label: 'Total Score',
                    value: '$totalScore',
                    icon: Icons.star,
                    color: const Color(0xFFFBBF24),
                  ),
                  _buildStatColumn(
                    label: 'Average',
                    value: avgScore.toStringAsFixed(2),
                    icon: Icons.trending_up,
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    label: 'Accuracy',
                    value: '${accuracy.toStringAsFixed(1)}%',
                    icon: Icons.adjust,
                    color: const Color(0xFF10B982),
                  ),
                  _buildStatColumn(
                    label: 'Arrows',
                    value: '$totalArrows',
                    icon: Icons.arrow_forward,
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B982),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
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

  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
