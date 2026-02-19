import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/supabase/db_views.dart';

enum MedalType { gold, silver, bronze, participant }

class CompetitionAchievement {
  final String id;
  final String competitionName;
  final String category;
  final List<String> winners;
  final String? imageUrl;
  final DateTime date;
  final String location;
  final MedalType medal;
  final int ranking;
  final int totalParticipants;
  final String notes;

  CompetitionAchievement({
    required this.id,
    required this.competitionName,
    required this.category,
    this.winners = const [],
    this.imageUrl,
    required this.date,
    required this.location,
    required this.medal,
    required this.ranking,
    required this.totalParticipants,
    this.notes = '',
  });
}

class LombaScreen extends StatefulWidget {
  const LombaScreen({super.key});

  @override
  State<LombaScreen> createState() => _LombaScreenState();
}

class _LombaScreenState extends State<LombaScreen> {
  List<CompetitionAchievement> _achievements = [];
  String _selectedFilter = 'Semua';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('v_latest_competition_news')
          .select()
          .order('published_at', ascending: false)
          .order('competition_date', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);
      final items = rows
          .map((row) => DbLatestCompetitionNewsView.fromJson(row))
          .where((news) => news.publishedAt != null)
          .map(_mapCompetitionNews)
          .toList();

      if (!mounted) return;
      setState(() {
        _achievements = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data lomba.';
      });
    }
  }

  List<CompetitionAchievement> get filteredAchievements {
    if (_selectedFilter == 'Semua') return _achievements;

    MedalType? filterMedal;
    switch (_selectedFilter) {
      case 'Emas':
        filterMedal = MedalType.gold;
        break;
      case 'Perak':
        filterMedal = MedalType.silver;
        break;
      case 'Perunggu':
        filterMedal = MedalType.bronze;
        break;
    }

    return _achievements.where((a) => a.medal == filterMedal).toList();
  }

  @override
  Widget build(BuildContext context) {
    final goldCount = _achievements
        .where((a) => a.medal == MedalType.gold)
        .length;
    final silverCount = _achievements
        .where((a) => a.medal == MedalType.silver)
        .length;
    final bronzeCount = _achievements
        .where((a) => a.medal == MedalType.bronze)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Prestasi Lomba',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF10B982), Color(0xFF059669)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: Colors.yellow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Total Prestasi',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_achievements.length} Lomba',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Medal Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMedalStat('🥇', goldCount, 'Emas'),
                      _buildMedalStat('🥈', silverCount, 'Perak'),
                      _buildMedalStat('🥉', bronzeCount, 'Perunggu'),
                    ],
                  ),
                ],
              ),
            ),
            // Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Semua'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Emas'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Perak'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Perunggu'),
                  ],
                ),
              ),
            ),
            // Achievements List
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(100),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF10B982)),
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    : filteredAchievements.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada prestasi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prestasi akan ditambahkan oleh admin',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredAchievements.length,
                            itemBuilder: (context, index) {
                              final achievement = filteredAchievements[index];
                              return _buildAchievementCard(achievement);
                            },
                          ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalStat(String emoji, int count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: const Color(0xFF10B982),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildAchievementCard(CompetitionAchievement achievement) {
    String medalEmoji;
    Color medalColor;

    switch (achievement.medal) {
      case MedalType.gold:
        medalEmoji = '🥇';
        medalColor = const Color(0xFFFFD700);
        break;
      case MedalType.silver:
        medalEmoji = '🥈';
        medalColor = const Color(0xFFC0C0C0);
        break;
      case MedalType.bronze:
        medalEmoji = '🥉';
        medalColor = const Color(0xFFCD7F32);
        break;
      case MedalType.participant:
        medalEmoji = '🏅';
        medalColor = const Color(0xFF9CA3AF);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAchievementDetail(achievement),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (achievement.imageUrl != null &&
                  achievement.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildPosterImage(achievement.imageUrl!),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: medalColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            medalEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement.competitionName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _buildCardSubtitle(achievement),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMMM yyyy', 'id_ID')
                              .format(achievement.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          achievement.location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        if (achievement.ranking > 0 &&
                            achievement.totalParticipants > 0)
                          Text(
                            'Peringkat ${achievement.ranking} dari ${achievement.totalParticipants} peserta',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B982),
                            ),
                          )
                        else
                          const Text(
                            'Hasil lomba belum tersedia',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B982),
                            ),
                          ),
                      ],
                    ),
                    if (achievement.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF10B982),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                achievement.notes,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementDetail(CompetitionAchievement achievement) {
    String medalEmoji;
    String medalText;

    switch (achievement.medal) {
      case MedalType.gold:
        medalEmoji = '🥇';
        medalText = 'Medali Emas';
        break;
      case MedalType.silver:
        medalEmoji = '🥈';
        medalText = 'Medali Perak';
        break;
      case MedalType.bronze:
        medalEmoji = '🥉';
        medalText = 'Medali Perunggu';
        break;
      case MedalType.participant:
        medalEmoji = '🏅';
        medalText = 'Partisipan';
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Medal
                Center(
                  child: Column(
                    children: [
                      Text(medalEmoji, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(
                        medalText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B982),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Details
                Text(
                  achievement.competitionName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                if (achievement.imageUrl != null &&
                    achievement.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildPosterImage(achievement.imageUrl!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow(
                  'Kategori',
                  achievement.category.isNotEmpty
                      ? achievement.category
                      : '-',
                ),
                _buildDetailRow(
                  'Pemenang',
                  achievement.winners.isNotEmpty
                      ? _formatWinnerNames(achievement.winners)
                      : '-',
                ),
                _buildDetailRow(
                  'Tanggal',
                  DateFormat('dd MMMM yyyy', 'id_ID')
                      .format(achievement.date),
                ),
                _buildDetailRow('Lokasi', achievement.location),
                if (achievement.ranking > 0 && achievement.totalParticipants > 0)
                  _buildDetailRow(
                    'Peringkat',
                    '${achievement.ranking} dari ${achievement.totalParticipants} peserta',
                  ),
                if (achievement.notes.isNotEmpty)
                  _buildDetailRow('Catatan', achievement.notes),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B982),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text(
                    'Tutup',
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  CompetitionAchievement _mapCompetitionNews(
    DbLatestCompetitionNewsView news,
  ) {
    final competitionName = (news.competitionName ?? news.title).trim();
    final date = news.competitionDate ??
        news.publishedAt ??
        DateTime.now();
    final location = (news.location ?? '').trim().isEmpty
        ? 'Lokasi belum ditentukan'
        : news.location!.trim();
    final ranking = _extractRanking(news.content);
    final totalParticipants = _extractTotalParticipants(news.content);
    final medal = _inferMedal(
      news.title,
      news.content,
      ranking: ranking,
    );
    final winners = _cleanWinnerNames(news.winnerNames);

    return CompetitionAchievement(
      id: news.id,
      competitionName: competitionName,
      category: _extractCategory(news.content),
      winners: winners,
      imageUrl: _cleanImageUrl(news.imageUrl),
      date: date,
      location: location,
      medal: medal,
      ranking: ranking ?? 0,
      totalParticipants: totalParticipants ?? 0,
      notes: news.content.trim(),
    );
  }

  String _buildCardSubtitle(CompetitionAchievement achievement) {
    if (achievement.category.isNotEmpty) {
      return 'Kategori: ${achievement.category}';
    }
    if (achievement.winners.isNotEmpty) {
      return 'Pemenang: ${_formatWinnerNames(achievement.winners)}';
    }
    return 'Informasi lomba';
  }

  String? _cleanImageUrl(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  String _formatWinnerNames(List<String> winners) {
    if (winners.length > 3) {
      final shown = winners.take(3).join(', ');
      final remaining = winners.length - 3;
      return '$shown +$remaining';
    }
    return winners.join(', ');
  }

  List<String> _cleanWinnerNames(List<String> winners) {
    return winners
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'null')
        .toList();
  }

  String _extractCategory(String content) {
    final match = RegExp(
      r'(?:kategori|category)\s*[:\-]?\s*([^\n\.,]+)',
      caseSensitive: false,
    ).firstMatch(content);
    if (match == null) {
      return '';
    }
    return match.group(1)?.trim() ?? '';
  }

  MedalType _inferMedal(
    String title,
    String content, {
    int? ranking,
  }) {
    final text = '${title.toLowerCase()} ${content.toLowerCase()}';
    if (text.contains('emas') || text.contains('gold') || ranking == 1) {
      return MedalType.gold;
    }
    if (text.contains('perak') || text.contains('silver') || ranking == 2) {
      return MedalType.silver;
    }
    if (text.contains('perunggu') || text.contains('bronze') || ranking == 3) {
      return MedalType.bronze;
    }
    return MedalType.participant;
  }

  int? _extractRanking(String content) {
    final match = RegExp(
      r'(?:juara|peringkat|rank)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(content);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  int? _extractTotalParticipants(String content) {
    final match = RegExp(
      r'dari\s*(\d+)\s*peserta',
      caseSensitive: false,
    ).firstMatch(content);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  Widget _buildPosterImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF9CA3AF),
            size: 32,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: const Color(0xFFF3F4F6),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF10B982)),
            ),
          ),
        );
      },
    );
  }
}
