import 'package:flutter/material.dart';
import 'training_result_screen.dart';
import '../utils/training_data.dart';
import '../services/supabase_training_service.dart';

class InputScoringScreen extends StatefulWidget {
  const InputScoringScreen({super.key});

  @override
  State<InputScoringScreen> createState() => _InputScoringScreenState();
}

class _InputScoringScreenState extends State<InputScoringScreen>
    with SingleTickerProviderStateMixin {
  late TrainingSession session;
  int selectedPlayerIndex = 0;
  late TabController _tabController;
  int currentRoundIndex = 0;
  int currentArrowIndex = 0;
  double keypadTopPosition =
      0.0; // Position offset for draggable keypad
  bool isKeypadVisible = true; // Toggle keypad visibility

  @override
  void initState() {
    super.initState();
    session = TrainingData().currentSession!;
    _tabController = TabController(
      length: session.numberOfPlayers,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedPlayerIndex = _tabController.index;
          _initializeScoresForPlayer();
          _findCurrentPosition();
        });
      }
    });
    _initializeScoresForPlayer();
    _findCurrentPosition();
  }

  void _initializeScoresForPlayer() {
    String playerName = session.playerNames[selectedPlayerIndex];
    if (session.scores[playerName] == null) {
      session.scores[playerName] = [];
    }
    // Initialize all rounds with empty scores
    while (session.scores[playerName]!.length < session.numberOfRounds) {
      session.scores[playerName]!.add(
        List.generate(session.arrowsPerRound, (_) => ''),
      );
    }
  }

  void _findCurrentPosition() {
    String playerName = session.playerNames[selectedPlayerIndex];
    // Find first empty score position
    for (int r = 0; r < session.numberOfRounds; r++) {
      for (int a = 0; a < session.arrowsPerRound; a++) {
        if (session.scores[playerName]![r][a].isEmpty) {
          currentRoundIndex = r;
          currentArrowIndex = a;
          return;
        }
      }
    }
    // All filled, stay at last position
    currentRoundIndex = session.numberOfRounds - 1;
    currentArrowIndex = session.arrowsPerRound - 1;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  bool _isRoundComplete(String playerName, int roundIndex) {
    if (session.scores[playerName] == null ||
        roundIndex >= session.scores[playerName]!.length) {
      return false;
    }
    return session.scores[playerName]![roundIndex].every(
      (score) => score.isNotEmpty,
    );
  }

  void _deleteRound(String playerName, int roundIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Rambahan'),
        content: Text(
          'Hapus skor Rambahan ${roundIndex + 1} untuk $playerName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Reset all scores in this round to empty
                session.scores[playerName]![roundIndex] = List.generate(
                  session.arrowsPerRound,
                  (_) => '',
                );
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rambahan ${roundIndex + 1} dihapus'),
                  backgroundColor: const Color(0xFF10B982),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _inputScore(
    String playerName,
    int roundIndex,
    int arrowIndex,
    String score,
  ) {
    setState(() {
      session.scores[playerName]![roundIndex][arrowIndex] = score;

      // Auto-advance to next arrow
      currentArrowIndex++;
      if (currentArrowIndex >= session.arrowsPerRound) {
        // Move to next round
        currentArrowIndex = 0;
        currentRoundIndex++;
        if (currentRoundIndex >= session.numberOfRounds) {
          // All rounds complete
          currentRoundIndex = session.numberOfRounds - 1;
          currentArrowIndex = session.arrowsPerRound - 1;
        }
      }

      _checkIfAllComplete();
    });
  }

  void _inputScoreQuick(String score) {
    String playerName = session.playerNames[selectedPlayerIndex];

    // Check if current position is valid
    if (currentRoundIndex >= session.numberOfRounds) return;
    if (currentArrowIndex >= session.arrowsPerRound) return;

    // Check if position already filled
    if (session
        .scores[playerName]![currentRoundIndex][currentArrowIndex]
        .isNotEmpty) {
      return;
    }

    _inputScore(playerName, currentRoundIndex, currentArrowIndex, score);
  }

  void _deleteLastScore() {
    String playerName = session.playerNames[selectedPlayerIndex];

    setState(() {
      // Move back one position
      if (currentArrowIndex > 0) {
        currentArrowIndex--;
      } else if (currentRoundIndex > 0) {
        currentRoundIndex--;
        currentArrowIndex = session.arrowsPerRound - 1;
      } else {
        return; // Already at first position
      }

      // Clear the score
      session.scores[playerName]![currentRoundIndex][currentArrowIndex] = '';
    });
  }

  void _nextEnd() {
    setState(() {
      // Move to next round, first arrow
      currentRoundIndex++;
      currentArrowIndex = 0;
      if (currentRoundIndex >= session.numberOfRounds) {
        currentRoundIndex = session.numberOfRounds - 1;
        currentArrowIndex = session.arrowsPerRound - 1;
      }
    });
  }

  void _checkIfAllComplete() {
    if (session.isComplete()) {
      _finishTraining();
    }
  }

  void _finishTraining() async {
    await TrainingData().saveCurrentSession();
    try {
      final supabaseId =
          await SupabaseTrainingService().saveTrainingSession(session);
      if (supabaseId.isNotEmpty) {
        session.supabaseId = supabaseId;
        await TrainingData().saveData();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Latihan berhasil disimpan ke Supabase'),
            backgroundColor: Color(0xFF10B982),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simpan ke Supabase: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (mounted) {
      // Navigate to Result Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TrainingResultScreen(session: session),
        ),
      );
    }
  }

  int _getGolds(String playerName) {
    int golds = 0;
    if (session.scores[playerName] != null) {
      for (var round in session.scores[playerName]!) {
        for (var score in round) {
          if (score == 'X' || score == '10') {
            golds++;
          }
        }
      }
    }
    return golds;
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
    String currentPlayerName = session.playerNames[selectedPlayerIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
                content: const Text(
                  'Progress scoring akan hilang. Apakah Anda yakin?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tidak'),
                  ),
                  TextButton(
                    onPressed: () {
                      TrainingData().currentSession = null;
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Ya, Batalkan',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          currentPlayerName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: session.numberOfPlayers > 1
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
                tabs: session.playerNames.map((name) {
                  return Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 18),
                          const SizedBox(width: 6),
                          Text(name),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Header Stats - Distance, Golds, Average, Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Target: ${session.targetType}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB020),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Golds: ${_getGolds(currentPlayerName)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B982),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Avg: ${_getAverageScore(currentPlayerName).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Total: ${_getTotalScore(currentPlayerName)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Detail button for multiple players (above rounds)
          if (session.numberOfPlayers > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AverageTableScreen(session: session),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.table_chart,
                  size: 18,
                  color: Color(0xFF10B982),
                ),
                label: const Text(
                  'Detail',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B982),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B982), width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          // Rounds Table with scores
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: session.numberOfRounds,
              itemBuilder: (context, roundIndex) {
                List<String> roundScores =
                    session.scores[currentPlayerName]![roundIndex];
                bool isComplete = _isRoundComplete(
                  currentPlayerName,
                  roundIndex,
                );
                int roundTotal = _getRoundTotal(currentPlayerName, roundIndex);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rambahan: ${roundIndex + 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B982),
                            ),
                          ),
                          Row(
                            children: [
                              if (isComplete)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B982),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Total: $roundTotal',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              if (isComplete) const SizedBox(width: 8),
                              if (isComplete)
                                GestureDetector(
                                  onTap: () => _deleteRound(
                                    currentPlayerName,
                                    roundIndex,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(session.arrowsPerRound, (
                          arrowIndex,
                        ) {
                          String score = roundScores[arrowIndex];
                          bool isCurrent =
                              roundIndex == currentRoundIndex &&
                              arrowIndex == currentArrowIndex;
                          return GestureDetector(
                            onTap: () {
                              // Allow jumping to this position if it's empty or previous positions are filled
                              setState(() {
                                currentRoundIndex = roundIndex;
                                currentArrowIndex = arrowIndex;
                              });
                            },
                            child: _buildScoreBox(score, isCurrent: isCurrent),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Keypad at bottom (draggable)
          if (isKeypadVisible)
            Transform.translate(
              offset: Offset(0, keypadTopPosition),
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    keypadTopPosition += details.delta.dy;
                    // Limit dragging range to prevent going off-screen
                    if (keypadTopPosition > 50) keypadTopPosition = 50;
                    if (keypadTopPosition < -300) keypadTopPosition = -300;
                  });
                },
                child: Container(
                  //margin: const EdgeInsets.only(top: 0),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle indicator
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'AVG: ${_getAverageScore(currentPlayerName).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B982),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Total: ${_getTotalScore(currentPlayerName)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B982),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6), //
                      // Keypad grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                        childAspectRatio: 2.0,
                        children: [
                          _buildKeypadButton(
                            'X',
                            const Color(0xFFFBBF24),
                            Colors.black,
                          ),
                          _buildKeypadButton(
                            '10',
                            const Color(0xFFFBBF24),
                            Colors.black,
                          ),
                          _buildKeypadButton(
                            '9',
                            const Color(0xFFFBBF24),
                            Colors.black,
                          ),
                          _buildKeypadButton(
                            '8',
                            const Color(0xFFEF4444),
                            Colors.white,
                          ),
                          _buildKeypadButton(
                            '7',
                            const Color(0xFFEF4444),
                            Colors.white,
                          ),
                          _buildKeypadButton(
                            '6',
                            const Color(0xFF3B82F6),
                            Colors.white,
                          ),
                          _buildKeypadButton(
                            '5',
                            const Color(0xFF3B82F6),
                            Colors.white,
                          ),
                          _buildActionButton(
                            icon: Icons.arrow_back,
                            color: Colors.white,
                            iconColor: Colors.orange,
                            onTap: _deleteLastScore,
                          ),
                          _buildKeypadButton(
                            '4',
                            const Color(0xFF1F2937),
                            Colors.white,
                          ),
                          _buildKeypadButton(
                            '3',
                            const Color(0xFF1F2937),
                            Colors.white,
                          ),
                          _buildKeypadButton('2', Colors.white, Colors.black),
                          _buildKeypadButton('1', Colors.white, Colors.black),
                          _buildKeypadButton(
                            'M',
                            const Color(0xFF10B982),
                            Colors.white,
                          ),
                          const SizedBox(), // Empty space
                          const SizedBox(), // Empty space
                          _buildActionButton(
                            text: 'Next End',
                            color: Colors.white,
                            textColor: Colors.orange,
                            onTap: _nextEnd,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Finish button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: session.isComplete()
                              ? _finishTraining
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB020),
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Finish',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isKeypadVisible = !isKeypadVisible;
            // Reset position when showing keypad
            if (isKeypadVisible) {
              keypadTopPosition = 0.0;
            }
          });
        },
        backgroundColor: const Color(0xFF10B982),
        child: Icon(
          isKeypadVisible ? Icons.keyboard_hide : Icons.keyboard,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildScoreBox(String score, {bool isCurrent = false}) {
    Color bgColor;
    Color textColor = Colors.white;

    if (score.isEmpty) {
      // Empty box for incomplete rounds
      return Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFFFE4B5) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? const Color(0xFFFF9800) : Colors.grey[300]!,
            width: isCurrent ? 3 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    switch (score) {
      case 'X':
      case '10':
      case '9':
        bgColor = const Color(0xFFFBBF24);
        textColor = Colors.black;
        break;
      case '8':
      case '7':
        bgColor = const Color(0xFFEF4444);
        break;
      case '6':
      case '5':
        bgColor = const Color(0xFF3B82F6);
        break;
      case '4':
      case '3':
        bgColor = const Color(0xFF1F2937);
        break;
      case '2':
      case '1':
        bgColor = Colors.white;
        textColor = Colors.black;
        break;
      default: // 'M'
        bgColor = const Color(0xFF9CA3AF);
        break;
    }

    return Container(
      width: 45,
      height: 45,
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String label, Color bgColor, Color textColor) {
    return GestureDetector(
      onTap: () => _inputScoreQuick(label),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (label == '2' || label == '1') ? Colors.grey[300]! : bgColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    String? text,
    required Color color,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: iconColor, size: 16)
              : Text(
                  text!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}
