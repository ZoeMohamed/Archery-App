import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/training_data.dart';
import 'summary_table_screen.dart';
import '../widgets/target_face_input.dart';

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
              if (widget.session.inputMethod == 'target_face') ...[
                const SizedBox(height: 6),
                _buildAccumulatedTargetSection(playerName),
              ],
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
            color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.05),
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
          if (widget.session.inputMethod == 'target_face') ...[
            const SizedBox(height: 16),
            _buildTargetHitSection(
              playerName: playerName,
              roundIndex: roundIndex,
              roundScores: roundScores,
            ),
          ],
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
      case '10':
      case '9':
        bgColor = const Color(0xFFFBBF24); // Yellow
        textColor = Colors.black;
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

  Widget _buildTargetHitSection({
    required String playerName,
    required int roundIndex,
    required List<String> roundScores,
  }) {
    final visualTargetType = _resolveVisualTargetType(
      widget.session.targetType,
    );
    final roundHits = _getRoundHits(
      playerName: playerName,
      roundIndex: roundIndex,
      arrowCount: roundScores.length,
    );
    final hitPoints = _getRecordedHitPoints(roundScores, roundHits);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visual Target',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            visualTargetType,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _buildTargetPreview(hitPoints, targetType: visualTargetType),
          const SizedBox(height: 12),
          const Text(
            'Detail Panah Yang Kena Target',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (hitPoints.isEmpty)
            const Text(
              'Belum ada panah yang kena target pada rambahan ini.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            )
          else
            Column(children: hitPoints.map(_buildHitDetailRow).toList()),
        ],
      ),
    );
  }

  Widget _buildAccumulatedTargetSection(String playerName) {
    final visualTargetType = _resolveVisualTargetType(
      widget.session.targetType,
    );
    final hitPoints = _getAccumulatedHitPoints(playerName);
    final totalArrows =
        widget.session.numberOfRounds * widget.session.arrowsPerRound;
    final totalScore = widget.session.getTotalScore(playerName);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B982), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Keseluruhan',
                style: TextStyle(
                  fontSize: 20,
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
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Total: $totalScore',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B982),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTargetPreview(
            hitPoints,
            targetType: visualTargetType,
            markerSize: 20,
            markerColor: Colors.white,
            markerTextColor: const Color(0xFFEF4444),
            markerBorderColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Menampilkan ${hitPoints.length} hit dari total $totalArrows arrow',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetPreview(
    List<_RoundHitPoint> hitPoints, {
    required String targetType,
    double markerSize = 24,
    Color markerColor = const Color(0xFFEF4444),
    Color markerTextColor = Colors.white,
    Color markerBorderColor = Colors.white,
  }) {
    const double targetSize = 220;

    return Center(
      child: Container(
        width: targetSize + 20,
        height: targetSize + 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SizedBox(
          width: targetSize,
          height: targetSize,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(targetSize, targetSize),
                painter: TargetFacePainter(
                  targetType: targetType,
                  hits: const [],
                ),
              ),
              ...hitPoints.map((point) {
                final radius = targetSize / 2;
                final center = targetSize / 2;
                final clampedX = point.x.clamp(-1.0, 1.0);
                final clampedY = point.y.clamp(-1.0, 1.0);
                final left = center + (clampedX * radius) - (markerSize / 2);
                final top = center + (clampedY * radius) - (markerSize / 2);

                return Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(markerSize / 2),
                      border: Border.all(color: markerBorderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${point.arrowNumber}',
                      style: TextStyle(
                        fontSize: markerSize <= 20 ? 10 : 11,
                        color: markerTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHitDetailRow(
    _RoundHitPoint point, {
    bool showRoundContext = false,
  }) {
    final distancePercent =
        (math.sqrt((point.x * point.x) + (point.y * point.y)) * 100)
            .toStringAsFixed(1);
    final arrowLabel = showRoundContext
        ? 'R${point.roundNumber ?? 1} • Panah ${point.roundArrowNumber ?? point.arrowNumber}'
        : 'Panah ${point.arrowNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Text(
            arrowLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          _buildMiniScoreBadge(point.score),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'x ${point.x.toStringAsFixed(2)} • y ${point.y.toStringAsFixed(2)} • r $distancePercent%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScoreBadge(String score) {
    final style = _getScoreStyle(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: style.hasBorder
            ? Border.all(color: Colors.grey, width: 1.5)
            : null,
      ),
      child: Text(
        score,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: style.text,
        ),
      ),
    );
  }

  List<_RoundHitPoint> _getAccumulatedHitPoints(String playerName) {
    final points = <_RoundHitPoint>[];
    var markerNumber = 1;

    for (
      var roundIndex = 0;
      roundIndex < widget.session.numberOfRounds;
      roundIndex++
    ) {
      final roundScores = widget.session.scores[playerName]?[roundIndex] ?? [];
      final roundHits = _getRoundHits(
        playerName: playerName,
        roundIndex: roundIndex,
        arrowCount: roundScores.length,
      );

      for (var arrowIndex = 0; arrowIndex < roundScores.length; arrowIndex++) {
        final score = roundScores[arrowIndex];
        if (score.isEmpty || widget.session.convertScoreToInt(score) <= 0) {
          continue;
        }
        final hit = arrowIndex < roundHits.length
            ? roundHits[arrowIndex]
            : const {'x': 0.0, 'y': 0.0};
        points.add(
          _RoundHitPoint(
            arrowNumber: markerNumber,
            score: score,
            x: hit['x'] ?? 0.0,
            y: hit['y'] ?? 0.0,
            roundNumber: roundIndex + 1,
            roundArrowNumber: arrowIndex + 1,
          ),
        );
        markerNumber++;
      }
    }
    return points;
  }

  List<Map<String, double>> _getRoundHits({
    required String playerName,
    required int roundIndex,
    required int arrowCount,
  }) {
    final playerRounds = widget.session.hitCoordinates?[playerName];
    final roundData = (playerRounds != null && roundIndex < playerRounds.length)
        ? playerRounds[roundIndex]
        : null;

    return List.generate(arrowCount, (index) {
      if (roundData != null && index < roundData.length) {
        final rawHit = roundData[index];
        final x = (rawHit['x'] as num?)?.toDouble() ?? 0.0;
        final y = (rawHit['y'] as num?)?.toDouble() ?? 0.0;
        return {'x': x, 'y': y};
      }
      return {'x': 0.0, 'y': 0.0};
    });
  }

  List<_RoundHitPoint> _getRecordedHitPoints(
    List<String> roundScores,
    List<Map<String, double>> roundHits,
  ) {
    final points = <_RoundHitPoint>[];
    for (var i = 0; i < roundScores.length; i++) {
      final score = roundScores[i];
      if (score.isEmpty || widget.session.convertScoreToInt(score) <= 0) {
        continue;
      }
      final hit = i < roundHits.length
          ? roundHits[i]
          : const {'x': 0.0, 'y': 0.0};
      points.add(
        _RoundHitPoint(
          arrowNumber: i + 1,
          score: score,
          x: hit['x'] ?? 0.0,
          y: hit['y'] ?? 0.0,
        ),
      );
    }
    return points;
  }

  _ScoreStyle _getScoreStyle(String score) {
    switch (score) {
      case 'X':
      case '10':
      case '9':
        return const _ScoreStyle(
          background: Color(0xFFFBBF24),
          text: Colors.black,
          hasBorder: false,
        );
      case '8':
      case '7':
        return const _ScoreStyle(
          background: Color(0xFFEF4444),
          text: Colors.white,
          hasBorder: false,
        );
      case '6':
      case '5':
        return const _ScoreStyle(
          background: Color(0xFF3B82F6),
          text: Colors.white,
          hasBorder: false,
        );
      case '4':
      case '3':
        return const _ScoreStyle(
          background: Color(0xFF1F2937),
          text: Colors.white,
          hasBorder: false,
        );
      case '2':
      case '1':
        return const _ScoreStyle(
          background: Colors.white,
          text: Colors.black,
          hasBorder: true,
        );
      default:
        return const _ScoreStyle(
          background: Color(0xFF9CA3AF),
          text: Colors.white,
          hasBorder: false,
        );
    }
  }

  String _resolveVisualTargetType(String targetType) {
    final normalized = targetType.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'default') {
      return 'Face Ring 6';
    }
    return targetType;
  }
}

class _RoundHitPoint {
  final int arrowNumber;
  final String score;
  final double x;
  final double y;
  final int? roundNumber;
  final int? roundArrowNumber;

  const _RoundHitPoint({
    required this.arrowNumber,
    required this.score,
    required this.x,
    required this.y,
    this.roundNumber,
    this.roundArrowNumber,
  });
}

class _ScoreStyle {
  final Color background;
  final Color text;
  final bool hasBorder;

  const _ScoreStyle({
    required this.background,
    required this.text,
    required this.hasBorder,
  });
}
