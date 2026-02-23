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

class _MemberOption {
  final String id;
  final String fullName;

  const _MemberOption({required this.id, required this.fullName});
}

class _AchievementDraft {
  final String title;
  final String competitionName;
  final String location;
  final String category;
  final DateTime competitionDate;
  final int? totalParticipants;
  final String memberId;
  final MedalType medal;
  final int rank;
  final int? score;
  final int? maxScore;
  final String notes;
  final String? imageUrl;

  const _AchievementDraft({
    required this.title,
    required this.competitionName,
    required this.location,
    required this.category,
    required this.competitionDate,
    this.totalParticipants,
    required this.memberId,
    required this.medal,
    required this.rank,
    this.score,
    this.maxScore,
    this.notes = '',
    this.imageUrl,
  });
}

class _CreateAchievementSheet extends StatefulWidget {
  final List<_MemberOption> memberOptions;

  const _CreateAchievementSheet({required this.memberOptions});

  @override
  State<_CreateAchievementSheet> createState() =>
      _CreateAchievementSheetState();
}

class _CreateAchievementSheetState extends State<_CreateAchievementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _competitionController = TextEditingController();
  final _locationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _totalParticipantsController = TextEditingController();
  final _rankController = TextEditingController();
  final _scoreController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _notesController = TextEditingController();
  final _imageUrlController = TextEditingController();
  DateTime _competitionDate = DateTime.now();
  MedalType _medal = MedalType.gold;
  String? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    if (widget.memberOptions.isNotEmpty) {
      _selectedMemberId = widget.memberOptions.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _competitionController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _totalParticipantsController.dispose();
    _rankController.dispose();
    _scoreController.dispose();
    _maxScoreController.dispose();
    _notesController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF10B982), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    );
  }

  int? _parseOptionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  Future<void> _pickCompetitionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _competitionDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _competitionDate = picked;
    });
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    final selectedMemberId = _selectedMemberId;
    if (selectedMemberId == null || selectedMemberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih member pemenang terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rank = _parseOptionalInt(_rankController.text);
    if (rank == null || rank <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peringkat harus berupa angka lebih dari 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalParticipants = _parseOptionalInt(
      _totalParticipantsController.text,
    );
    if (totalParticipants != null && totalParticipants < rank) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Total peserta tidak boleh lebih kecil dari peringkat.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final score = _parseOptionalInt(_scoreController.text);
    final maxScore = _parseOptionalInt(_maxScoreController.text);
    if (score != null && score < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skor tidak boleh negatif.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (maxScore != null && maxScore < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skor maksimal tidak boleh negatif.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (score != null && maxScore != null && score > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skor tidak boleh lebih besar dari skor maksimal.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _AchievementDraft(
        title: _titleController.text.trim(),
        competitionName: _competitionController.text.trim(),
        location: _locationController.text.trim(),
        category: _categoryController.text.trim(),
        competitionDate: _competitionDate,
        totalParticipants: totalParticipants,
        memberId: selectedMemberId,
        medal: _medal,
        rank: rank,
        score: score,
        maxScore: maxScore,
        notes: _notesController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Prestasi Lomba',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Isi data hasil lomba, lalu simpan untuk tampil di aplikasi member.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMemberId,
                    decoration: _inputDecoration('Member Pemenang'),
                    items: widget.memberOptions
                        .map(
                          (member) => DropdownMenuItem<String>(
                            value: member.id,
                            child: Text(member.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMemberId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pilih member pemenang.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'Judul Berita',
                      hintText: 'Contoh: Juara 1 Kejurda Surabaya 2026',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Judul berita wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _competitionController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'Nama Lomba',
                      hintText: 'Contoh: Kejurda Panahan Jawa Timur',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Nama lomba wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Kategori',
                            hintText: 'Recurve U15',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Kategori wajib diisi.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<MedalType>(
                          initialValue: _medal,
                          decoration: _inputDecoration('Medali'),
                          items: const [
                            DropdownMenuItem(
                              value: MedalType.gold,
                              child: Text('Emas'),
                            ),
                            DropdownMenuItem(
                              value: MedalType.silver,
                              child: Text('Perak'),
                            ),
                            DropdownMenuItem(
                              value: MedalType.bronze,
                              child: Text('Perunggu'),
                            ),
                            DropdownMenuItem(
                              value: MedalType.participant,
                              child: Text('Partisipan'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _medal = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'Lokasi',
                      hintText: 'Contoh: Lapangan KONI Surabaya',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Lokasi wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickCompetitionDate,
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        'Tanggal Lomba',
                        suffixIcon: const Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          'id_ID',
                        ).format(_competitionDate),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rankController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Peringkat'),
                          validator: (value) {
                            final parsed = _parseOptionalInt(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Isi angka > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _totalParticipantsController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Total Peserta'),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return null;
                            }
                            final parsed = _parseOptionalInt(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Angka tidak valid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _scoreController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Skor'),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return null;
                            }
                            final parsed = _parseOptionalInt(value ?? '');
                            if (parsed == null || parsed < 0) {
                              return 'Angka tidak valid';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _maxScoreController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Skor Maks'),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return null;
                            }
                            final parsed = _parseOptionalInt(value ?? '');
                            if (parsed == null || parsed < 0) {
                              return 'Angka tidak valid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'URL Gambar (opsional)',
                      hintText: 'https://...',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return null;
                      }
                      final uri = Uri.tryParse(text);
                      if (uri == null ||
                          !uri.hasScheme ||
                          (uri.scheme != 'http' && uri.scheme != 'https')) {
                        return 'URL gambar tidak valid.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: _inputDecoration(
                      'Catatan (opsional)',
                      hintText: 'Contoh: Menang tie-break di end terakhir.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF9CA3AF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B982),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  bool _canManageAchievements = false;
  bool _isCreatingAchievement = false;
  List<_MemberOption> _memberOptions = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _resolveManagementAccess();
    await _loadAchievements();
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

  Future<void> _resolveManagementAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('active_role,roles')
          .eq('id', user.id)
          .maybeSingle();
      final activeRole =
          response?['active_role']?.toString().trim().toLowerCase() ??
          'non_member';
      final roles = <String>{activeRole};
      final rawRoles = response?['roles'];
      if (rawRoles is List) {
        for (final role in rawRoles) {
          final normalized = role.toString().trim().toLowerCase();
          if (normalized.isNotEmpty) {
            roles.add(normalized);
          }
        }
      }

      final canManage =
          roles.contains('admin') ||
          roles.contains('staff') ||
          roles.contains('pengurus');
      if (!canManage) {
        if (!mounted) return;
        setState(() {
          _canManageAchievements = false;
          _memberOptions = [];
        });
        return;
      }

      final members = await _fetchMemberOptions();
      if (!mounted) return;
      setState(() {
        _canManageAchievements = true;
        _memberOptions = members;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canManageAchievements = false;
        _memberOptions = [];
      });
    }
  }

  Future<List<_MemberOption>> _fetchMemberOptions() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'list_user_public_profiles',
        params: {'user_ids': null},
      );
      final rows = List<Map<String, dynamic>>.from(response as List);
      final options = rows
          .map(
            (row) => _MemberOption(
              id: row['id']?.toString() ?? '',
              fullName: row['full_name']?.toString().trim() ?? '',
            ),
          )
          .where((row) => row.id.isNotEmpty && row.fullName.isNotEmpty)
          .toList();
      options.sort((a, b) => a.fullName.compareTo(b.fullName));
      return options;
    } catch (_) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('id,full_name')
            .order('full_name', ascending: true);
        final rows = List<Map<String, dynamic>>.from(response as List);
        return rows
            .map(
              (row) => _MemberOption(
                id: row['id']?.toString() ?? '',
                fullName: row['full_name']?.toString().trim() ?? '',
              ),
            )
            .where((row) => row.id.isNotEmpty && row.fullName.isNotEmpty)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> _openCreateAchievementSheet() async {
    if (!_canManageAchievements || _isCreatingAchievement) {
      return;
    }
    if (_memberOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daftar member belum tersedia. Coba refresh data.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final draft = await showModalBottomSheet<_AchievementDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _CreateAchievementSheet(memberOptions: _memberOptions),
    );
    if (draft == null) {
      return;
    }
    await _createAchievement(draft);
  }

  Future<void> _createAchievement(_AchievementDraft draft) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login tidak ditemukan. Silakan login ulang.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingAchievement = true;
    });

    try {
      final nowIso = DateTime.now().toIso8601String();
      final competitionDate = DateFormat('yyyy-MM-dd').format(
        DateTime(
          draft.competitionDate.year,
          draft.competitionDate.month,
          draft.competitionDate.day,
        ),
      );

      final lines = <String>[];
      if (draft.notes.trim().isNotEmpty) {
        lines.add(draft.notes.trim());
      }
      lines.add('Juara ${draft.rank}');
      if (draft.totalParticipants != null && draft.totalParticipants! > 0) {
        lines.add(
          'Peringkat ${draft.rank} dari ${draft.totalParticipants} peserta',
        );
      }
      if (draft.category.trim().isNotEmpty) {
        lines.add('Kategori: ${draft.category.trim()}');
      }

      final newsPayload = <String, dynamic>{
        'title': draft.title.trim(),
        'content': lines.join('\n'),
        'competition_name': draft.competitionName.trim(),
        'competition_date': competitionDate,
        'location': draft.location.trim(),
        'category': draft.category.trim(),
        'total_participants': draft.totalParticipants,
        'published_by': currentUser.id,
        'is_published': true,
        'published_at': nowIso,
      };
      final cleanedImageUrl = draft.imageUrl?.trim();
      if (cleanedImageUrl != null && cleanedImageUrl.isNotEmpty) {
        newsPayload['image_url'] = cleanedImageUrl;
      }

      final insertedNews = await Supabase.instance.client
          .from('competition_news')
          .insert(newsPayload)
          .select('id')
          .single();
      final competitionNewsId = insertedNews['id']?.toString();
      if (competitionNewsId == null || competitionNewsId.isEmpty) {
        throw Exception('ID berita lomba tidak valid.');
      }

      final winnerPayload = <String, dynamic>{
        'competition_news_id': competitionNewsId,
        'user_id': draft.memberId,
        'rank': draft.rank,
      };
      final medal = _toDbMedal(draft.medal);
      if (medal != null) {
        winnerPayload['medal'] = medal;
      }
      if (draft.score != null) {
        winnerPayload['score'] = draft.score;
      }
      if (draft.maxScore != null) {
        winnerPayload['max_score'] = draft.maxScore;
      }

      await Supabase.instance.client
          .from('competition_winners')
          .insert(winnerPayload);

      await _loadAchievements();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prestasi lomba berhasil ditambahkan.'),
          backgroundColor: Color(0xFF10B982),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      var message = 'Gagal menyimpan prestasi lomba.';
      if (e is PostgrestException) {
        final text = e.message.toLowerCase();
        if (e.code == '42501' || text.contains('permission')) {
          message =
              'Akses ditolak oleh database. Pastikan role pengurus diizinkan untuk kelola lomba.';
        } else if (e.message.trim().isNotEmpty) {
          message = e.message;
        }
      } else {
        final text = e.toString();
        if (text.trim().isNotEmpty) {
          message = text;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAchievement = false;
        });
      }
    }
  }

  String? _toDbMedal(MedalType medal) {
    switch (medal) {
      case MedalType.gold:
        return 'gold';
      case MedalType.silver:
        return 'silver';
      case MedalType.bronze:
        return 'bronze';
      case MedalType.participant:
        return null;
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
        actions: _canManageAchievements
            ? [
                IconButton(
                  onPressed: _isCreatingAchievement
                      ? null
                      : _openCreateAchievementSheet,
                  icon: _isCreatingAchievement
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.add_circle_outline),
                  color: Colors.white,
                  tooltip: 'Tambah prestasi',
                ),
              ]
            : null,
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
                      color: Colors.white.withValues(alpha: 0.2),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF10B982),
                        ),
                      ),
                    ),
                  )
                : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 100,
                    ),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                          _canManageAchievements
                              ? 'Ketuk tombol + di atas untuk menambahkan prestasi.'
                              : 'Prestasi akan ditambahkan oleh pengurus.',
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
        color: Colors.white.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                            color: medalColor.withValues(alpha: 0.2),
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
                          DateFormat(
                            'dd MMMM yyyy',
                            'id_ID',
                          ).format(achievement.date),
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
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
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
                  achievement.category.isNotEmpty ? achievement.category : '-',
                ),
                _buildDetailRow(
                  'Pemenang',
                  achievement.winners.isNotEmpty
                      ? _formatWinnerNames(achievement.winners)
                      : '-',
                ),
                _buildDetailRow(
                  'Tanggal',
                  DateFormat('dd MMMM yyyy', 'id_ID').format(achievement.date),
                ),
                _buildDetailRow('Lokasi', achievement.location),
                if (achievement.ranking > 0 &&
                    achievement.totalParticipants > 0)
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

  CompetitionAchievement _mapCompetitionNews(DbLatestCompetitionNewsView news) {
    final competitionName = (news.competitionName ?? news.title).trim();
    final date = news.competitionDate ?? news.publishedAt ?? DateTime.now();
    final location = (news.location ?? '').trim().isEmpty
        ? 'Lokasi belum ditentukan'
        : news.location!.trim();
    final category = (news.category ?? '').trim().isNotEmpty
        ? news.category!.trim()
        : _extractCategory(news.content);
    final ranking = _extractRanking(news.content);
    final totalParticipants =
        news.totalParticipants ?? _extractTotalParticipants(news.content);
    final medal = _inferMedal(
      news.title,
      news.content,
      ranking: ranking,
      medals: news.medals,
    );
    final winners = _cleanWinnerNames(news.winnerNames);

    return CompetitionAchievement(
      id: news.id,
      competitionName: competitionName,
      category: category,
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
    List<String> medals = const [],
  }) {
    final normalizedMedals = medals
        .map((medal) => medal.toLowerCase().trim())
        .where((medal) => medal.isNotEmpty)
        .toSet();
    if (normalizedMedals.contains('gold')) {
      return MedalType.gold;
    }
    if (normalizedMedals.contains('silver')) {
      return MedalType.silver;
    }
    if (normalizedMedals.contains('bronze')) {
      return MedalType.bronze;
    }

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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B982)),
            ),
          ),
        );
      },
    );
  }
}
