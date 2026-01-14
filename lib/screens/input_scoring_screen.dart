import 'package:flutter/material.dart';
import 'main_navigation.dart';
import '../utils/training_data.dart';

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
        });
      }
    });
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
          total += session.convertScoreToInt(score);
        }
      }
    }
    return total;
  }

  int _getCompletedRounds(String playerName) {
    return session.scores[playerName]?.length ?? 0;
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
                session.scores[playerName]?.removeAt(roundIndex);
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

  void _inputScoresForRound(String playerName, int roundIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoundScoringScreen(
          session: session,
          playerName: playerName,
          roundIndex: roundIndex,
        ),
      ),
    ).then((_) {
      setState(() {});
      _checkIfAllComplete();
    });
  }

  void _checkIfAllComplete() {
    if (session.isComplete()) {
      _finishTraining();
    }
  }

  void _finishTraining() async {
    await TrainingData().saveCurrentSession();
    if (mounted) {
      // Navigate to MainNavigation with ArcherScoringScreen selected (index 3)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainNavigation(initialIndex: 3),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentPlayerName = session.playerNames[selectedPlayerIndex];

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
        title: const Text(
          'Input Scoring',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          // Player Stats Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Rambahan',
                  '${_getCompletedRounds(currentPlayerName)}/${session.numberOfRounds}',
                  Icons.repeat,
                ),
                Container(width: 2, height: 40, color: Colors.grey[300]),
                _buildStatItem(
                  'Total Skor',
                  '${_getTotalScore(currentPlayerName)}',
                  Icons.star,
                ),
              ],
            ),
          ),
          // Rounds List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: session.numberOfRounds,
              itemBuilder: (context, roundIndex) {
                bool isCompleted =
                    _getCompletedRounds(currentPlayerName) > roundIndex;
                List<String> roundScores = isCompleted
                    ? session.scores[currentPlayerName]![roundIndex]
                    : [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B982)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
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
                      // Round Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B982)
                              : Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${roundIndex + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? const Color(0xFF10B982)
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Rambahan ${roundIndex + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                      // Round Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (isCompleted) ...[
                              // Show scores
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: roundScores.map((score) {
                                  return _buildScoreBox(score);
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total: ${roundScores.fold<int>(0, (sum, score) => sum + session.convertScoreToInt(score))}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B982),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteRound(
                                      currentPlayerName,
                                      roundIndex,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    tooltip: 'Hapus Rambahan',
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Input button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _getCompletedRounds(currentPlayerName) ==
                                          roundIndex
                                      ? () => _inputScoresForRound(
                                          currentPlayerName,
                                          roundIndex,
                                        )
                                      : null,
                                  icon: const Icon(Icons.edit, size: 20),
                                  label: const Text('Input Skor'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B982),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor: Colors.grey[300],
                                    disabledForegroundColor: Colors.grey[500],
                                  ),
                                ),
                              ),
                              if (_getCompletedRounds(currentPlayerName) <
                                  roundIndex)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Selesaikan rambahan sebelumnya',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF10B982), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildScoreBox(String score) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (score) {
      case 'X':
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
      default:
        bgColor = const Color(0xFF9CA3AF);
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: score == '2' || score == '1'
            ? Border.all(color: Colors.grey, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        score,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

// Round Scoring Screen
class RoundScoringScreen extends StatefulWidget {
  final TrainingSession session;
  final String playerName;
  final int roundIndex;

  const RoundScoringScreen({
    super.key,
    required this.session,
    required this.playerName,
    required this.roundIndex,
  });

  @override
  State<RoundScoringScreen> createState() => _RoundScoringScreenState();
}

class _RoundScoringScreenState extends State<RoundScoringScreen> {
  late List<String> currentRoundScores;
  int currentArrow = 0;

  @override
  void initState() {
    super.initState();
    currentRoundScores = List.generate(
      widget.session.arrowsPerRound,
      (_) => '',
    );
  }

  void _inputScore(String score) {
    if (currentArrow < widget.session.arrowsPerRound) {
      setState(() {
        currentRoundScores[currentArrow] = score;
        currentArrow++;

        if (currentArrow == widget.session.arrowsPerRound) {
          _saveRound();
        }
      });
    }
  }

  void _saveRound() {
    if (widget.session.scores[widget.playerName] == null) {
      widget.session.scores[widget.playerName] = [];
    }
    widget.session.scores[widget.playerName]!.add(
      List.from(currentRoundScores),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rambahan ${widget.roundIndex + 1} tersimpan!'),
        backgroundColor: const Color(0xFF10B982),
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  int _getCurrentTotal() {
    int total = 0;
    for (var score in currentRoundScores) {
      total += widget.session.convertScoreToInt(score);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (currentArrow > 0) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Batalkan Input?'),
                  content: const Text('Skor yang sudah diinput akan hilang.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tidak'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Ya',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          children: [
            Text(
              widget.playerName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Rambahan ${widget.roundIndex + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Arrow ${currentArrow + 1}/${widget.session.arrowsPerRound}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B982),
                  ),
                ),
                Text(
                  'Total: ${_getCurrentTotal()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Score Boxes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skor Arrow:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(widget.session.arrowsPerRound, (
                      index,
                    ) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: index < currentArrow
                              ? const Color(0xFFE8F5E9)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
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
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: currentRoundScores[index].isEmpty
                                  ? Colors.grey[400]
                                  : const Color(0xFF10B982),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Score Keypad
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildScoreButton(
                    'X',
                    '10',
                    Colors.yellow[700]!,
                    Colors.black,
                  ),
                  _buildScoreButton(
                    '9',
                    '9',
                    Colors.yellow[700]!,
                    Colors.black,
                  ),
                  _buildScoreButton('8', '8', Colors.red[600]!, Colors.white),
                  _buildScoreButton('7', '7', Colors.red[600]!, Colors.white),
                  _buildScoreButton('6', '6', Colors.blue[600]!, Colors.white),
                  _buildScoreButton('5', '5', Colors.blue[500]!, Colors.white),
                  _buildScoreButton('4', '4', Colors.black, Colors.white),
                  _buildScoreButton('3', '3', Colors.black, Colors.white),
                  _buildScoreButton('2', '2', Colors.white, Colors.black),
                  _buildScoreButton('1', '1', Colors.white, Colors.black),
                  _buildScoreButton('M', '0', Colors.grey[400]!, Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreButton(
    String label,
    String value,
    Color color,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: currentArrow < widget.session.arrowsPerRound
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
                  fontSize: 16,
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
