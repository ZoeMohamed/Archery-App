import 'package:flutter/material.dart';
import 'archer_scoring_screen.dart';
import '../utils/training_data.dart';

class InputScoringScreen extends StatefulWidget {
  const InputScoringScreen({super.key});

  @override
  State<InputScoringScreen> createState() => _InputScoringScreenState();
}

class _InputScoringScreenState extends State<InputScoringScreen> {
  late TrainingSession session;
  int currentPlayerIndex = 0;
  int currentRound = 0;
  int currentArrow = 0;
  List<String> currentRoundScores = [];

  @override
  void initState() {
    super.initState();
    session = TrainingData().currentSession!;
    _initializeCurrentRound();
  }

  void _initializeCurrentRound() {
    String currentPlayer = session.playerNames[currentPlayerIndex];
    if (session.scores[currentPlayer] == null) {
      session.scores[currentPlayer] = [];
    }
    if (currentRound < session.scores[currentPlayer]!.length) {
      currentRoundScores = List.from(session.scores[currentPlayer]![currentRound]);
      currentArrow = currentRoundScores.where((s) => s.isNotEmpty).length;
    } else {
      currentRoundScores = List.generate(session.arrowsPerRound, (_) => '');
      currentArrow = 0;
    }
  }

  void _inputScore(String score) {
    if (currentArrow < session.arrowsPerRound) {
      setState(() {
        currentRoundScores[currentArrow] = score;
        currentArrow++;

        // Check if round is complete
        if (currentArrow == session.arrowsPerRound) {
          _saveCurrentRound();
          _moveToNextRound();
        }
      });
    }
  }

  void _saveCurrentRound() {
    String currentPlayer = session.playerNames[currentPlayerIndex];
    if (currentRound < session.scores[currentPlayer]!.length) {
      session.scores[currentPlayer]![currentRound] = List.from(currentRoundScores);
    } else {
      session.scores[currentPlayer]!.add(List.from(currentRoundScores));
    }
  }

  void _moveToNextRound() {
    if (currentRound + 1 < session.numberOfRounds) {
      // Next round for same player
      currentRound++;
      _initializeCurrentRound();
    } else {
      // Move to next player or finish
      if (currentPlayerIndex + 1 < session.numberOfPlayers) {
        currentPlayerIndex++;
        currentRound = 0;
        _initializeCurrentRound();
      } else {
        // All players finished all rounds
        _finishTraining();
      }
    }
  }

  void _finishTraining() async {
    await TrainingData().saveCurrentSession();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ArcherScoringScreen()),
      );
    }
  }

  int _getCurrentTotal() {
    int total = 0;
    for (var score in currentRoundScores) {
      if (score == 'X') {
        total += 10;
      } else if (score == 'M' || score.isEmpty) {
        total += 0;
      } else {
        total += int.tryParse(score) ?? 0;
      }
    }
    return total;
  }

  int _getTotalScore() {
    String currentPlayer = session.playerNames[currentPlayerIndex];
    int total = 0;
    if (session.scores[currentPlayer] != null) {
      for (var round in session.scores[currentPlayer]!) {
        for (var score in round) {
          if (score == 'X') {
            total += 10;
          } else if (score == 'M' || score.isEmpty) {
            total += 0;
          } else {
            total += int.tryParse(score) ?? 0;
          }
        }
      }
    }
    return total + _getCurrentTotal();
  }

  int _getTotalArrowsShot() {
    String currentPlayer = session.playerNames[currentPlayerIndex];
    int count = 0;
    if (session.scores[currentPlayer] != null) {
      count = session.scores[currentPlayer]!.fold(0, (sum, round) => sum + round.length);
    }
    return count + currentArrow;
  }

  @override
  Widget build(BuildContext context) {
    String currentPlayer = session.playerNames[currentPlayerIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Batalkan Latihan?'),
                content: const Text('Progress scoring akan hilang. Apakah Anda yakin?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tidak'),
                  ),
                  TextButton(
                    onPressed: () {
                      TrainingData().currentSession = null;
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back
                    },
                    child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        title: const Text(
          'Input Scoring',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round ${currentRound + 1}/${session.numberOfRounds}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Arrow ${currentArrow + 1}/${session.arrowsPerRound}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B982),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Player name (if multiple players)
          if (session.numberOfPlayers > 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B982),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    currentPlayer,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          if (session.numberOfPlayers > 1) const SizedBox(height: 20),
          // Round Scores
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Round 1 Scores:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Score boxes - Wrapped with SingleChildScrollView for responsiveness
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(session.arrowsPerRound, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    width: 45,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: index < currentArrow
                                          ? const Color(0xFFE8F5E9)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: index == currentArrow
                                            ? const Color(0xFF10B982)
                                            : Colors.grey[300]!,
                                        width: index == currentArrow ? 3 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        currentRoundScores[index].isEmpty
                                            ? (index + 1).toString()
                                            : currentRoundScores[index],
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: currentRoundScores[index].isEmpty
                                              ? Colors.grey[400]
                                              : const Color(0xFF10B982),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Total
                          Text(
                            'Total: ${_getCurrentTotal()}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B982),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Score Keypad
                    _buildScoreKeypad(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTotalScore().toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              width: 2,
              height: 50,
              color: Colors.grey[700],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Arrows Shot',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getTotalArrowsShot()}/${session.numberOfRounds * session.arrowsPerRound}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreKeypad() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildScoreButton('X', '10', Colors.yellow[700]!, Colors.black),
        _buildScoreButton('9', '9', Colors.yellow[700]!, Colors.black),
        _buildScoreButton('8', '8', Colors.red[600]!, Colors.white),
        _buildScoreButton('7', '7', Colors.red[600]!, Colors.white),
        _buildScoreButton('6', '6', Colors.blue[600]!, Colors.white),
        _buildScoreButton('5', '5', Colors.blue[500]!, Colors.white),
        _buildScoreButton('4', '4', Colors.black, Colors.white),
        _buildScoreButton('3', '3', Colors.black, Colors.white),
        _buildScoreButton('2', '2', Colors.white, Colors.black),
        _buildScoreButton('1', '1', Colors.white, Colors.black),
        _buildScoreButton('M', '', Colors.grey[400]!, Colors.black),
      ],
    );
  }

  Widget _buildScoreButton(String label, String value, Color color, Color textColor) {
    return GestureDetector(
      onTap: currentArrow < session.arrowsPerRound
          ? () => _inputScore(label)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color == Colors.white ? Colors.grey[300]! : color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
