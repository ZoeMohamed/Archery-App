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
                    top: 100,
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
                            'Ukuran Lingkaran di Kamera',
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

                // Distance Meter (Bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 150,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B982),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Meter gauge
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: CustomPaint(
                            size: const Size(double.infinity, 150),
                            painter: MeterGaugePainter(
                              currentDistance: _distanceMeters,
                            ),
                          ),
                        ),
                        // Slider
                        Positioned(
                          top: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'meter',
                                    style: TextStyle(
                                      fontSize: 18,
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
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPresetPanel = !_showPresetPanel;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Slider(
                                value: _distanceMeters,
                                min: 5.0,
                                max: 150.0,
                                divisions: 145,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white30,
                                onChanged: (value) {
                                  setState(() {
                                    _distanceMeters = value;
                                  });
                                },
                              ),
                            ],
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

class MeterGaugePainter extends CustomPainter {
  final double currentDistance;

  MeterGaugePainter({required this.currentDistance});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.4;

    // Draw arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paint,
    );

    // Draw ticks
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 150; i += 5) {
      final angle = math.pi + (i / 150) * math.pi;
      final tickLength = i % 10 == 0 ? 15.0 : 8.0;

      final startX = center.dx + radius * math.cos(angle);
      final startY = center.dy + radius * math.sin(angle);
      final endX = center.dx + (radius - tickLength) * math.cos(angle);
      final endY = center.dy + (radius - tickLength) * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

      // Draw numbers at major ticks
      if (i % 10 == 0 && i <= 150) {
        textPainter.text = TextSpan(
          text: i.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        final textX =
            center.dx + (radius - 30) * math.cos(angle) - textPainter.width / 2;
        final textY =
            center.dy +
            (radius - 30) * math.sin(angle) -
            textPainter.height / 2;
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }

    // Draw pointer
    final pointerAngle = math.pi + (currentDistance / 150) * math.pi;
    final pointerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    pointerPath.moveTo(center.dx, center.dy);
    pointerPath.lineTo(
      center.dx + (radius - 20) * math.cos(pointerAngle),
      center.dy + (radius - 20) * math.sin(pointerAngle),
    );

    canvas.drawPath(pointerPath, pointerPaint..style = PaintingStyle.stroke);

    // Draw center circle
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF10B982));
  }

  @override
  bool shouldRepaint(MeterGaugePainter oldDelegate) =>
      currentDistance != oldDelegate.currentDistance;
}
