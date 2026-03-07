import 'package:flutter/material.dart';
import 'training_confirmation_screen.dart';
import '../utils/training_data.dart';

class SetupTrainingScreen extends StatefulWidget {
  const SetupTrainingScreen({super.key});

  @override
  State<SetupTrainingScreen> createState() => _SetupTrainingScreenState();
}

class _SetupTrainingScreenState extends State<SetupTrainingScreen> {
  int _numberOfPlayers = 1;
  int _numberOfRounds = 6;
  int _arrowsPerRound = 6;
  String _selectedTarget = 'Default';
  String _inputMethod = 'arrow_values'; // 'arrow_values' or 'target_face'
  final TextEditingController _trainingNameController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  TrainingTemplate? _selectedTemplate;
  List<TrainingTemplate> _templates = [];
  bool _saveToLog = false; // Opsi simpan ke log latihan
  final List<TextEditingController> _playerNameControllers = [
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    await TrainingData().loadData();
    setState(() {
      _templates = TrainingData().getTemplates();
    });
  }

  String _normalizeInputMethod(String? value) {
    return value == 'target_face' ? 'target_face' : 'arrow_values';
  }

  List<String> _targetOptionsForInputMethod(String inputMethod) {
    if (inputMethod == 'target_face') {
      return const ['Face Ring 6', 'Ring Puta', 'Face Mega Mendung'];
    }
    return const ['Default', 'Face Ring 6', 'Ring Puta', 'Face Mega Mendung'];
  }

  String _normalizedTargetForInputMethod(String target, String inputMethod) {
    final options = _targetOptionsForInputMethod(inputMethod);
    final trimmed = target.trim();
    if (options.contains(trimmed)) {
      return trimmed;
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    const knownMappings = <String, String>{
      'default': 'Default',
      'face ring 6': 'Face Ring 6',
      'ring puta': 'Ring Puta',
      'face mega mendung': 'Face Mega Mendung',
      // Legacy labels from older presets.
      'target a': 'Default',
      'target b': 'Default',
      'target c': 'Default',
    };

    final mapped = knownMappings[normalized];
    if (mapped != null && options.contains(mapped)) {
      return mapped;
    }

    return options.first;
  }

  String _currentTargetValue() {
    return _normalizedTargetForInputMethod(_selectedTarget, _inputMethod);
  }

  void _loadFromTemplate(TrainingTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _numberOfPlayers = template.numberOfPlayers;
      _numberOfRounds = template.numberOfRounds;
      _arrowsPerRound = template.arrowsPerRound;
      _inputMethod = _normalizeInputMethod(template.inputMethod);
      _selectedTarget = _normalizedTargetForInputMethod(
        template.targetType,
        _inputMethod,
      );
      _trainingNameController.text = template.name;
      _distanceController.text = template.distance ?? '';

      // Update player controllers
      _updatePlayerControllers(_numberOfPlayers);

      // Fill player names
      for (
        int i = 0;
        i < _numberOfPlayers && i < template.playerNames.length;
        i++
      ) {
        _playerNameControllers[i].text = template.playerNames[i];
      }
    });
  }

  @override
  void dispose() {
    _trainingNameController.dispose();
    _distanceController.dispose();
    for (var controller in _playerNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updatePlayerControllers(int count) {
    if (count > _playerNameControllers.length) {
      for (int i = _playerNameControllers.length; i < count; i++) {
        _playerNameControllers.add(TextEditingController());
      }
    } else if (count < _playerNameControllers.length) {
      for (int i = _playerNameControllers.length - 1; i >= count; i--) {
        _playerNameControllers[i].dispose();
        _playerNameControllers.removeAt(i);
      }
    }
  }

  Future<void> _saveAsTemplate() async {
    final targetValue = _currentTargetValue();

    List<String> playerNames = [];
    if (_numberOfPlayers == 1) {
      playerNames.add('Saya');
    } else {
      playerNames = _playerNameControllers
          .take(_numberOfPlayers)
          .map((c) => c.text.trim())
          .toList();
    }

    final template = TrainingTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _trainingNameController.text.trim(),
      numberOfPlayers: _numberOfPlayers,
      playerNames: playerNames,
      numberOfRounds: _numberOfRounds,
      arrowsPerRound: _arrowsPerRound,
      targetType: targetValue,
      inputMethod: _inputMethod,
      distance: _distanceController.text.trim().isNotEmpty
          ? _distanceController.text.trim()
          : null,
    );

    await TrainingData().addTemplate(template);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template berhasil disimpan ke Log Latihan!'),
          backgroundColor: Color(0xFF10B982),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startTraining() async {
    final targetValue = _currentTargetValue();

    // Validate
    if (_numberOfPlayers > 1) {
      bool hasEmptyName = _playerNameControllers
          .take(_numberOfPlayers)
          .any((c) => c.text.trim().isEmpty);
      if (hasEmptyName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan isi nama semua pemain!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Save as template if requested
    if (_saveToLog && _trainingNameController.text.trim().isNotEmpty) {
      await _saveAsTemplate();
    }

    // Create training session
    List<String> playerNames = [];
    if (_numberOfPlayers == 1) {
      playerNames.add('Saya');
    } else {
      playerNames = _playerNameControllers
          .take(_numberOfPlayers)
          .map((c) => c.text.trim())
          .toList();
    }

    final session = TrainingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      numberOfPlayers: _numberOfPlayers,
      playerNames: playerNames,
      numberOfRounds: _numberOfRounds,
      arrowsPerRound: _arrowsPerRound,
      targetType: targetValue,
      inputMethod: _inputMethod,
      distance: _distanceController.text.trim().isNotEmpty
          ? _distanceController.text.trim()
          : null,
      scores: {},
      trainingName: _trainingNameController.text.trim().isNotEmpty
          ? _trainingNameController.text.trim()
          : null,
    );

    // Initialize scores
    for (var name in playerNames) {
      session.scores[name] = [];
    }

    // Navigate to confirmation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingConfirmationScreen(session: session),
      ),
    );
  }

  void _manageTemplates() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kelola Log Latihan'),
        content: SizedBox(
          width: double.maxFinite,
          child: _templates.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada log latihan tersimpan',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          template.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${template.numberOfPlayers} pemain • ${template.numberOfRounds} rambahan • ${template.arrowsPerRound} arrow',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await TrainingData().removeTemplate(template);
                            setState(() {
                              _templates = TrainingData().getTemplates();
                              if (_selectedTemplate?.id == template.id) {
                                _selectedTemplate = null;
                              }
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Log latihan dihapus'),
                                backgroundColor: Color(0xFF10B982),
                              ),
                            );
                            // Reopen dialog if there are still templates
                            if (_templates.isNotEmpty) {
                              _manageTemplates();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetOptions = _targetOptionsForInputMethod(_inputMethod);
    final selectedTarget = _currentTargetValue();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Setup Training',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B982),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.settings,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              // Log Latihan Selector
              if (_templates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B982),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.history,
                                color: Color(0xFF10B982),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Log Latihan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _manageTemplates,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Kelola'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF10B982),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B982)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TrainingTemplate?>(
                            value: _selectedTemplate,
                            isExpanded: true,
                            hint: const Text('Pilih log untuk auto-fill'),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF10B982),
                            ),
                            items: [
                              const DropdownMenuItem<TrainingTemplate?>(
                                value: null,
                                child: Text('Tidak ada'),
                              ),
                              ..._templates.map((template) {
                                return DropdownMenuItem<TrainingTemplate?>(
                                  value: template,
                                  child: Text(template.name),
                                );
                              }).toList(),
                            ],
                            onChanged: (TrainingTemplate? newValue) {
                              if (newValue != null) {
                                _loadFromTemplate(newValue);
                              } else {
                                setState(() {
                                  _selectedTemplate = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_templates.isNotEmpty) const SizedBox(height: 16),
              // Nama Latihan Field
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B982), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.label, color: Color(0xFF10B982)),
                        const SizedBox(width: 12),
                        const Text(
                          'Nama Latihan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _trainingNameController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Latihan 50M, Tournament Prep',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Jarak Field
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B982), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, color: Color(0xFF10B982)),
                        const SizedBox(width: 12),
                        const Text(
                          'Jarak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _distanceController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 30m, 50m, 70m',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B982),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Jumlah Pemain
              _buildNumberSelector(
                label: 'Jumlah Pemain',
                value: _numberOfPlayers,
                min: 1,
                max: 10,
                onChanged: (value) {
                  setState(() {
                    _numberOfPlayers = value;
                    _updatePlayerControllers(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              // Player Names (if more than 1)
              if (_numberOfPlayers > 1)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B982),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nama Pemain',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_numberOfPlayers, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _playerNameControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Pemain ${index + 1}',
                              hintText: 'Masukkan nama pemain',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B982),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B982),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B982),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              if (_numberOfPlayers > 1) const SizedBox(height: 16),
              // Jumlah Rambahan
              _buildNumberSelector(
                label: 'Jumlah Rambahan',
                value: _numberOfRounds,
                min: 1,
                max: 20,
                onChanged: (value) {
                  setState(() {
                    _numberOfRounds = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Jumlah Arrow per Rambahan
              _buildNumberSelector(
                label: 'Jumlah Arrow per Rambahan',
                value: _arrowsPerRound,
                min: 1,
                max: 12,
                onChanged: (value) {
                  setState(() {
                    _arrowsPerRound = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Metode Input Scoring
              _buildInputMethodSelector(),
              const SizedBox(height: 16),
              // Jenis Target
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B982), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.adjust, color: Color(0xFF10B982)),
                        const SizedBox(width: 12),
                        const Text(
                          'Jenis Target',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B982)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTarget,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF10B982),
                          ),
                          items: targetOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTarget = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Scoring info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Color(0xFF10B982),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedTarget == 'Face Ring 6'
                                    ? 'Scoring Face Ring 6'
                                    : selectedTarget == 'Ring Puta'
                                    ? 'Scoring Ring Puta'
                                    : selectedTarget == 'Face Mega Mendung'
                                    ? 'Scoring Face Mega Mendung'
                                    : 'Scoring Default',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B982),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedTarget == 'Face Ring 6'
                                ? [
                                    // Face Ring 6: 6,5,4 (Gold), 3 (Red), 2 (White), 1 (Blue)
                                    _buildScoreChip(
                                      '6',
                                      const Color(0xFFFBBF24),
                                    ), // Gold
                                    _buildScoreChip(
                                      '5',
                                      const Color(0xFFFBBF24),
                                    ), // Gold
                                    _buildScoreChip(
                                      '4',
                                      const Color(0xFFFBBF24),
                                    ), // Gold
                                    _buildScoreChip(
                                      '3',
                                      const Color(0xFFEF4444),
                                    ), // Red
                                    _buildScoreChip('2', Colors.white), // White
                                    _buildScoreChip(
                                      '1',
                                      const Color(0xFF3B82F6),
                                    ), // Blue
                                  ]
                                : selectedTarget == 'Ring Puta'
                                ? [
                                    // Ring Puta: 2 (White), 1 (Reddish Brown)
                                    _buildScoreChip('2', Colors.white), // White
                                    _buildScoreChip(
                                      '1',
                                      const Color(0xFF7C2D2D),
                                    ), // Reddish Brown
                                  ]
                                : selectedTarget == 'Face Mega Mendung'
                                ? [
                                    // Face Mega Mendung: 10-1 points
                                    _buildScoreChip(
                                      '10',
                                      const Color(0xFFFBBF24),
                                    ), // Yellow
                                    _buildScoreChip(
                                      '9',
                                      const Color(0xFFEF4444),
                                    ), // Red
                                    _buildScoreChip('8', Colors.white), // White
                                    _buildScoreChip(
                                      '7',
                                      const Color(0xFF60A5FA),
                                    ), // Lt Blue
                                    _buildScoreChip(
                                      '6',
                                      const Color(0xFFFBBF24),
                                    ), // Yellow
                                    _buildScoreChip(
                                      '5',
                                      const Color(0xFFEF4444),
                                    ), // Red
                                    _buildScoreChip('4', Colors.white), // White
                                    _buildScoreChip(
                                      '3',
                                      const Color(0xFF60A5FA),
                                    ), // Lt Blue
                                    _buildScoreChip(
                                      '2',
                                      const Color(0xFF1E3A8A),
                                    ), // Dk Blue
                                    _buildScoreChip('1', Colors.white), // White
                                  ]
                                : [
                                    // Default
                                    _buildScoreChip('X', Colors.yellow[700]!),
                                    _buildScoreChip('9', Colors.yellow[700]!),
                                    _buildScoreChip('8', Colors.red),
                                    _buildScoreChip('7', Colors.red),
                                    _buildScoreChip('6', Colors.blue),
                                    _buildScoreChip('5', Colors.blue),
                                    _buildScoreChip('4', Colors.black),
                                    _buildScoreChip('3', Colors.black),
                                    _buildScoreChip('2', Colors.grey[200]!),
                                    _buildScoreChip('1', Colors.grey[200]!),
                                  ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Simpan ke Log Latihan Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B982), width: 2),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _saveToLog,
                      onChanged: (value) {
                        setState(() {
                          _saveToLog = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF10B982),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Simpan ke Log Latihan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Simpan konfigurasi ini untuk digunakan lagi',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Start Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startTraining,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B982),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Lanjutkan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberSelector({
    required String label,
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B982), width: 2),
      ),
      child: Row(
        children: [
          Icon(
            label.contains('Pemain')
                ? Icons.people
                : label.contains('Rambahan')
                ? Icons.repeat
                : Icons.arrow_forward,
            color: const Color(0xFF10B982),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: const Color(0xFF10B982),
            disabledColor: Colors.grey,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B982),
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF10B982),
            disabledColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String label, Color color) {
    // Determine text color based on background color brightness
    bool isLightBackground =
        color == Colors.white ||
        color == Colors.grey[200] ||
        color == Colors.yellow[700] ||
        color == const Color(0xFFFBBF24); // Gold color

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color == Colors.grey[200] || color == Colors.white
              ? Colors.grey
              : color,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isLightBackground ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildInputMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B982), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF10B982)),
              const SizedBox(width: 12),
              const Text(
                'Metode Input Scoring',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _inputMethod = 'arrow_values';
                      _selectedTarget = 'Default';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _inputMethod == 'arrow_values'
                          ? const Color(0xFF10B982)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B982),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            Icons.grid_3x3,
                            size: 40,
                            color: _inputMethod == 'arrow_values'
                                ? Colors.white
                                : const Color(0xFF10B982),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _inputMethod == 'arrow_values'
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFE8F5E9),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Arrow Values',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _inputMethod == 'arrow_values'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _inputMethod = 'target_face';
                      _selectedTarget = 'Ring Puta';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _inputMethod == 'target_face'
                          ? const Color(0xFF10B982)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B982),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            Icons.adjust,
                            size: 40,
                            color: _inputMethod == 'target_face'
                                ? Colors.white
                                : const Color(0xFF10B982),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _inputMethod == 'target_face'
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFE8F5E9),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Target Face',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _inputMethod == 'target_face'
                                    ? Colors.white
                                    : Colors.black87,
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
        ],
      ),
    );
  }
}
