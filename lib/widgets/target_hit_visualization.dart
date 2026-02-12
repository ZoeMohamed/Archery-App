import 'package:flutter/material.dart';

class TargetHitVisualization extends StatelessWidget {
  final String targetType;
  final List<Map<String, double>> hits; // List of {x, y} coordinates
  final bool showLabels;

  const TargetHitVisualization({
    super.key,
    required this.targetType,
    required this.hits,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: TargetHitPainter(
          targetType: targetType,
          hits: hits,
          showLabels: showLabels,
        ),
        child: Container(),
      ),
    );
  }
}

class TargetHitPainter extends CustomPainter {
  final String targetType;
  final List<Map<String, double>> hits;
  final bool showLabels;

  TargetHitPainter({
    required this.targetType,
    required this.hits,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw target face
    _paintTargetFace(canvas, center, radius);

    // Draw hit markers
    _paintHits(canvas, center, radius);
  }

  void _paintTargetFace(Canvas canvas, Offset center, double radius) {
    if (targetType == 'Face Ring 6') {
      // Face Ring 6: 6,5,4 (Gold), 3 (Red), 2 (White), 1 (Blue)
      final colors = [
        const Color(0xFF3B82F6), // Ring 1 (outer) - Blue
        Colors.white, // Ring 2 - White
        const Color(0xFFEF4444), // Ring 3 - Red
        const Color(0xFFFBBF24), // Ring 4 (Gold)
        const Color(0xFFFBBF24), // Ring 5 (Gold)
        const Color(0xFFFBBF24), // Ring 6 (center) - Gold
      ];

      final scores = ['1', '2', '3', '4', '5', '6'];

      // Draw rings from outside to inside
      for (int i = 0; i < 6; i++) {
        final ringRadius = radius * (6 - i) / 6;
        final paint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill;

        canvas.drawCircle(center, ringRadius, paint);

        // Draw border for each ring
        final borderPaint = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(center, ringRadius, borderPaint);

        // Draw score labels if enabled
        if (showLabels && i < 5) {
          final labelRadius = radius * (6 - i - 0.5) / 6;
          final textPainter = TextPainter(
            text: TextSpan(
              text: scores[i],
              style: TextStyle(
                color:
                    (colors[i] == Colors.white ||
                        colors[i] == const Color(0xFFFBBF24))
                    ? Colors.black87
                    : Colors.white,
                fontSize: radius * 0.1,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          textPainter.paint(
            canvas,
            Offset(
              center.dx + labelRadius - textPainter.width / 2,
              center.dy - textPainter.height / 2,
            ),
          );
        }
      }

      // Draw center score '6'
      if (showLabels) {
        final centerTextPainter = TextPainter(
          text: TextSpan(
            text: '6',
            style: TextStyle(
              color: Colors.black87,
              fontSize: radius * 0.12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        centerTextPainter.layout();
        centerTextPainter.paint(
          canvas,
          Offset(
            center.dx - centerTextPainter.width / 2,
            center.dy - centerTextPainter.height / 2,
          ),
        );
      }
    } else if (targetType == 'Ring Puta') {
      // Ring Puta: 2 (White center 40%), 1 (Reddish Brown outer 100%)
      
      // Draw outer ring (Reddish Brown) - full radius
      final outerPaint = Paint()
        ..color = const Color(0xFF7C2D2D)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, outerPaint);

      // Draw border for outer ring
      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius, borderPaint);

      // Draw score label for outer ring (1) if enabled
      if (showLabels) {
        final labelRadius = radius * 0.7; // Position at 70% of radius
        final outerTextPainter = TextPainter(
          text: TextSpan(
            text: '1',
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        outerTextPainter.layout();
        outerTextPainter.paint(
          canvas,
          Offset(
            center.dx + labelRadius - outerTextPainter.width / 2,
            center.dy - outerTextPainter.height / 2,
          ),
        );
      }

      // Draw center circle (White) - 40% of radius
      final centerRadius = radius * 0.4;
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, centerRadius, centerPaint);

      // Draw border for center circle
      canvas.drawCircle(center, centerRadius, borderPaint);

      // Draw center score '2'
      if (showLabels) {
        final centerTextPainter = TextPainter(
          text: TextSpan(
            text: '2',
            style: TextStyle(
              color: Colors.black87,
              fontSize: radius * 0.12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        centerTextPainter.layout();
        centerTextPainter.paint(
          canvas,
          Offset(
            center.dx - centerTextPainter.width / 2,
            center.dy - centerTextPainter.height / 2,
          ),
        );
      }
    } else if (targetType == 'Face Mega Mendung') {
      // Face Mega Mendung: 2 prisma + background circle
      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Draw background white circle (1 point)
      final bgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, bgPaint);
      canvas.drawCircle(center, radius, borderPaint);

      // Draw Prisma Bawah (lower diamond) - sedikit lebih besar
      final lowerCenter = Offset(center.dx, center.dy + radius * 0.3);
      _drawPrismaVisualization(canvas, lowerCenter, radius, true, borderPaint);

      // Draw Prisma Atas (upper diamond)
      final upperCenter = Offset(center.dx, center.dy - radius * 0.35);
      _drawPrismaVisualization(canvas, upperCenter, radius, false, borderPaint);
    }
  }

  void _drawPrismaVisualization(Canvas canvas, Offset center, double radius, bool isLower, Paint borderPaint) {
    if (isLower) {
      // Prisma Bawah: 5 layers (dibuat lebih besar)
      final layers = [
        {'size': 0.65, 'color': const Color(0xFF1E3A8A)},  // Dark blue - 2
        {'size': 0.55, 'color': const Color(0xFF60A5FA)},  // Light blue - 3
        {'size': 0.45, 'color': Colors.white},              // White - 4
        {'size': 0.33, 'color': const Color(0xFFEF4444)},  // Red - 5
      ];
      
      // Draw diamond layers (tanpa layer yellow di tengah)
      for (var layer in layers) {
        final size = (layer['size'] as double) * radius;
        final color = layer['color'] as Color;
        _drawDiamondVisualization(canvas, center, size, color, borderPaint);
      }
      
      // Draw center circle (poin 6) - LINGKARAN bukan diamond
      final circlePaint = Paint()
        ..color = const Color(0xFFFBBF24) // Yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.14, circlePaint);
      canvas.drawCircle(center, radius * 0.14, borderPaint);
      
      // Draw center label '6' if enabled
      if (showLabels) {
        _drawLabel(canvas, center, '6', radius * 0.09, Colors.black87);
      }
    } else {
      // Prisma Atas: 4 layers
      final layers = [
        {'size': 0.45, 'color': const Color(0xFF60A5FA)},  // Light blue - 7
        {'size': 0.35, 'color': Colors.white},              // White - 8
        {'size': 0.25, 'color': const Color(0xFFEF4444)},  // Red - 9
      ];
      
      // Draw diamond layers (tanpa layer yellow di tengah)
      for (var layer in layers) {
        final size = (layer['size'] as double) * radius;
        final color = layer['color'] as Color;
        _drawDiamondVisualization(canvas, center, size, color, borderPaint);
      }
      
      // Draw center circle (poin 10) - LINGKARAN bukan diamond
      final circlePaint = Paint()
        ..color = const Color(0xFFFBBF24) // Yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.11, circlePaint);
      canvas.drawCircle(center, radius * 0.11, borderPaint);
      
      // Draw center label '10' if enabled
      if (showLabels) {
        _drawLabel(canvas, center, '10', radius * 0.07, Colors.black87);
      }
    }
  }

  void _drawDiamondVisualization(Canvas canvas, Offset center, double size, Color color, Paint borderPaint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);           // Top
    path.lineTo(center.dx + size, center.dy);           // Right
    path.lineTo(center.dx, center.dy + size);           // Bottom
    path.lineTo(center.dx - size, center.dy);           // Left
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawLabel(Canvas canvas, Offset position, String text, double fontSize, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _paintHits(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < hits.length; i++) {
      final hit = hits[i];
      final x = hit['x'] ?? 0.0;
      final y = hit['y'] ?? 0.0;

      // Skip if no hit recorded (0,0)
      if (x == 0.0 && y == 0.0) continue;

      // Convert normalized coordinates to canvas coordinates
      final hitX = center.dx + x * radius;
      final hitY = center.dy + y * radius;

      // Draw hit marker (circle with border)
      final hitPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(Offset(hitX, hitY), 6, hitPaint);
      canvas.drawCircle(Offset(hitX, hitY), 6, borderPaint);

      // Draw arrow number
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      numberPainter.layout();
      numberPainter.paint(
        canvas,
        Offset(hitX - numberPainter.width / 2, hitY - numberPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
