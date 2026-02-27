import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TargetPreset {
  String name;
  double diameterCm;

  TargetPreset({required this.name, required this.diameterCm});

  Map<String, dynamic> toJson() => {'name': name, 'diameterCm': diameterCm};

  factory TargetPreset.fromJson(Map<String, dynamic> json) =>
      TargetPreset(name: json['name'], diameterCm: json['diameterCm']);
}

class RangeFinderScreen extends StatefulWidget {
  const RangeFinderScreen({super.key});

  @override
  State<RangeFinderScreen> createState() => _RangeFinderScreenState();
}

class _RangeFinderScreenState extends State<RangeFinderScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0;

  // Target settings
  double _distanceMeters = 5.0;
  double _targetDiameterCm = 45.0;
  Offset _targetPosition = const Offset(0.5, 0.4);
  double _targetScaleAdjustment = 0.6; // Scale adjustment 0.2x to 2.0x

  // Presets
  List<TargetPreset> _presets = [];
  bool _showPresetPanel = false;
  final TextEditingController _presetNameController = TextEditingController();
  final TextEditingController _diameterController = TextEditingController(
    text: '30',
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadPresets();
    _diameterController.text = _targetDiameterCm.toString();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        _minZoom = await _cameraController!.getMinZoomLevel();
        _maxZoom = await _cameraController!.getMaxZoomLevel();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString('target_presets');
    if (presetsJson != null) {
      final List<dynamic> decoded = json.decode(presetsJson);
      setState(() {
        _presets = decoded.map((p) => TargetPreset.fromJson(p)).toList();
      });
    }

    // Load scale adjustment
    final savedScale = prefs.getDouble('target_scale_adjustment');
    if (savedScale != null) {
      setState(() {
        _targetScaleAdjustment = savedScale;
      });
    }
  }

  Future<void> _saveScaleAdjustment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('target_scale_adjustment', _targetScaleAdjustment);
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = json.encode(_presets.map((p) => p.toJson()).toList());
    await prefs.setString('target_presets', presetsJson);
  }

  void _addPreset() {
    if (_presetNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama preset!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _presets.add(
        TargetPreset(
          name: _presetNameController.text.trim(),
          diameterCm: _targetDiameterCm,
        ),
      );
      _presetNameController.clear();
    });
    _savePresets();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preset disimpan!'),
        backgroundColor: Color(0xFF10B982),
      ),
    );
  }

  void _loadPreset(TargetPreset preset) {
    setState(() {
      _targetDiameterCm = preset.diameterCm;
      _diameterController.text = preset.diameterCm.toString();
      _showPresetPanel = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset "${preset.name}" dimuat!'),
        backgroundColor: const Color(0xFF10B982),
      ),
    );
  }

  void _deletePreset(int index) {
    setState(() {
      _presets.removeAt(index);
    });
    _savePresets();
  }

  double _calculateTargetSize() {
    // Calculate target size based on distance, diameter, and zoom level
    // Using angular size formula for accurate perspective
    // Reference: 45cm diameter at 5m distance = base pixel size
    final baseDistanceM = 5.0;
    final baseDiameterCm = 45.0;
    final basePixelSize = 120.0; // pixels for 45cm at 5m

    // Angular size calculation: size on screen is proportional to diameter/distance
    // targetSize = baseSize * (targetDiameter / baseDiameter) * (baseDistance / targetDistance)
    final scaleFactor =
        (_targetDiameterCm / baseDiameterCm) *
        (baseDistanceM / _distanceMeters);

    // Target size increases proportionally with zoom level and scale adjustment
    return basePixelSize * scaleFactor * _currentZoom * _targetScaleAdjustment;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _presetNameController.dispose();
    _diameterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Range Finder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                // Camera Preview with correct aspect ratio
                Positioned.fill(
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _baseZoom = _currentZoom;
                    },
                    onScaleUpdate: (details) {
                      // Pinch to zoom
                      final newZoom = _baseZoom * details.scale;
                      if (newZoom >= _minZoom && newZoom <= _maxZoom) {
                        _cameraController?.setZoomLevel(newZoom);
                        setState(() {
                          _currentZoom = newZoom;
                        });
                      }
                    },
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize!.height,
                        height: _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),

                // Distance Display
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B982),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_distanceMeters.toStringAsFixed(0)} M',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Target Face (Draggable)
                Positioned(
                  left:
                      MediaQuery.of(context).size.width * _targetPosition.dx -
                      _calculateTargetSize() / 2,
                  top:
                      MediaQuery.of(context).size.height * _targetPosition.dy -
                      _calculateTargetSize() / 2,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final dx =
                            _targetPosition.dx +
                            details.delta.dx /
                                MediaQuery.of(context).size.width;
                        final dy =
                            _targetPosition.dy +
                            details.delta.dy /
                                MediaQuery.of(context).size.height;
                        _targetPosition = Offset(
                          dx.clamp(0.0, 1.0),
                          dy.clamp(0.0, 1.0),
                        );
                      });
                    },
                    child: _buildTargetFace(_calculateTargetSize()),
                  ),
                ),

                // Diameter Display
                Positioned(
                  right: 20,
                  top: MediaQuery.of(context).size.height * 0.15,
                  child: Column(
                    children: [
                      // Zoom Slider
                      Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Stack(
                          children: [
                            // Slider track
                            Positioned(
                              left: 27,
                              top: 20,
                              bottom: 20,
                              child: Container(
                                width: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            // Slider
                            Positioned.fill(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 6,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 20,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 28,
                                  ),
                                  activeTrackColor: const Color(0xFF10B982),
                                  inactiveTrackColor: Colors.white.withOpacity(
                                    0.3,
                                  ),
                                  thumbColor: const Color(0xFF10B982),
                                  overlayColor: const Color(
                                    0xFF10B982,
                                  ).withOpacity(0.3),
                                ),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: _currentZoom,
                                    min: _minZoom,
                                    max: _maxZoom,
                                    onChanged: (value) {
                                      setState(() {
                                        _currentZoom = value;
                                      });
                                      _cameraController?.setZoomLevel(value);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            // Zoom level text
                            Positioned(
                              bottom: 5,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B982),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_currentZoom.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B982),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_targetDiameterCm.toStringAsFixed(0)} cm',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTargetFace(40),
                    ],
                  ),
                ),

                // Settings Panel (Toggle)
                if (_showPresetPanel)
                  Positioned(
                    left: 20,
                    top: 60,
                    child: Container(
                      width: MediaQuery.of(context).size.width - 100,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B982),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Diameter Target Face :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _diameterController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixText: 'cm',
                            ),
                            onChanged: (value) {
                              final diameter = double.tryParse(value);
                              if (diameter != null && diameter > 0) {
                                setState(() {
                                  _targetDiameterCm = diameter;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Preset Lingkaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.white,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _targetScaleAdjustment,
                                  min: 0.2,
                                  max: 2.0,
                                  divisions: 36,
                                  label:
                                      '${(_targetScaleAdjustment * 100).toStringAsFixed(0)}%',
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                  onChanged: (value) {
                                    setState(() {
                                      _targetScaleAdjustment = value;
                                    });
                                    _saveScaleAdjustment();
                                  },
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(_targetScaleAdjustment * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Color(0xFF10B982),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nama Target',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _presetNameController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Target A',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: false,
                                onChanged: (value) {},
                                fillColor: MaterialStateProperty.all(
                                  Colors.white,
                                ),
                              ),
                              const Text(
                                'Save Preset',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: _addPreset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Color(0xFF10B982),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Load Preset',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._presets.asMap().entries.map((entry) {
                            final index = entry.key;
                            final preset = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _loadPreset(preset),
                                      child: Text(
                                        '${preset.name} (${preset.diameterCm} cm)',
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _deletePreset(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          _buildTargetFace(60),
                        ],
                      ),
                    ),
                  ),

                // Distance Meter (Bottom) - Horizontal Ruler
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B982),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header with title and settings button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jarak (Meter)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _showPresetPanel
                                      ? Icons.close
                                      : Icons.settings,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPresetPanel = !_showPresetPanel;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        // Horizontal Ruler with Swipe Gesture
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                // Swipe sensitivity: 1 pixel = 0.1 meters
                                final delta = -details.delta.dx * 0.1;
                                _distanceMeters = (_distanceMeters + delta)
                                    .clamp(5.0, 150.0);
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Stack(
                                children: [
                                  // Ruler
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: HorizontalRulerPainter(
                                        currentDistance: _distanceMeters,
                                      ),
                                    ),
                                  ),
                                  // Center indicator (pointer)
                                  Positioned(
                                    left: MediaQuery.of(context).size.width / 2 -
                                        2,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Triangle indicator at top
                                  Positioned(
                                    left: MediaQuery.of(context).size.width / 2 -
                                        10,
                                    top: 0,
                                    child: CustomPaint(
                                      size: const Size(20, 15),
                                      painter: TrianglePointerPainter(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Darker green rectangular space at bottom
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B982)),
            ),
    );
  }

  Widget _buildTargetFace(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withOpacity(0.7),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        children: [
          // Yellow center
          Center(
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.yellow,
              ),
            ),
          ),
          // Red ring
          Center(
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: Colors.red, width: size * 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HorizontalRulerPainter extends CustomPainter {
  final double currentDistance;

  HorizontalRulerPainter({required this.currentDistance});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final baseY = size.height - 10;

    // Pixels per meter
    final pixelsPerMeter = 20.0;

    // Calculate offset based on current distance
    final offset = currentDistance * pixelsPerMeter;

    // Draw ruler marks from 5m to 150m
    for (int i = 5; i <= 150; i++) {
      final x = centerX + (i * pixelsPerMeter) - offset;

      // Only draw if visible on screen
      if (x >= -50 && x <= size.width + 50) {
        final isMainTick = i % 10 == 0;
        final isSubTick = i % 5 == 0;

        double tickHeight;
        if (isMainTick) {
          tickHeight = 35;
        } else if (isSubTick) {
          tickHeight = 25;
        } else {
          tickHeight = 15;
        }

        // Draw tick
        canvas.drawLine(
          Offset(x, baseY),
          Offset(x, baseY - tickHeight),
          paint..strokeWidth = isMainTick ? 2.5 : 1.5,
        );

        // Draw numbers at main ticks (every 10 meters)
        if (isMainTick) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: i.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, baseY - tickHeight - 20),
          );
        }
      }
    }

    // Draw horizontal base line
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      paint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(HorizontalRulerPainter oldDelegate) =>
      currentDistance != oldDelegate.currentDistance;
}

class TrianglePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height); // Bottom center
    path.lineTo(0, 0); // Top left
    path.lineTo(size.width, 0); // Top right
    path.close();

    canvas.drawPath(path, paint);

    // Add shadow/border
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(TrianglePointerPainter oldDelegate) => false;
}
