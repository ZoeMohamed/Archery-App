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
  String _selectedTarget = 'Target A';
  final List<TextEditingController> _playerNameControllers = [
    TextEditingController(),
  ];

  @override
  void dispose() {
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

  void _startTraining() {
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
      targetType: _selectedTarget,
      scores: {},
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

  @override
  Widget build(BuildContext context) {
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
                          value: _selectedTarget,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF10B982),
                          ),
                          items: ['Target A'].map((String value) {
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
                            children: const [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Color(0xFF10B982),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Scoring Target A',
                                style: TextStyle(
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
                            children: [
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color == Colors.grey[200] ? Colors.grey : color,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color == Colors.grey[200] || color == Colors.yellow[700]
              ? Colors.black
              : Colors.white,
        ),
      ),
    );
  }
}
