import 'package:flutter/material.dart';
import 'dart:math' as math;

String _resolveTargetFaceType(String targetType) {
  final normalized = targetType.trim();
  if (normalized == 'Face Ring 6' ||
      normalized == 'Ring Puta' ||
      normalized == 'Face Mega Mendung') {
    return normalized;
  }
  if (normalized.isEmpty || normalized.toLowerCase() == 'default') {
    return 'Face Ring 6';
  }
  return normalized;
}

class TargetFaceInput extends StatelessWidget {
  final Function(int score, double x, double y) onTap;
  final String targetType;
  final List<Map<String, double>> hits; // List of hit coordinates
  final double targetSize; // Size multiplier (0.3 to 0.9)

  const TargetFaceInput({
    super.key,
    required this.onTap,
    required this.targetType,
    this.hits = const [],
    this.targetSize = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    // Use a larger tap area (90% of screen) to allow miss detection outside target
    final screenWidth = MediaQuery.of(context).size.width;
    final tapAreaSize = screenWidth * 0.9;
    final targetVisualSize = screenWidth * targetSize;
    final resolvedType = _resolveTargetFaceType(targetType);
    // Make container height responsive to target size for better space usage
    final containerHeight =
        tapAreaSize *
        (0.4 + (targetSize * 0.6)); // Scales from 40% to 100% of tap area

    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final size = box.size;

        // Calculate the actual target radius (the visual target size)
        final targetRadius = targetVisualSize / 2;

        // Normalize to target radius range (center is 0,0)
        final centerX = size.width / 2;
        final centerY = size.height / 2;
        final dx = localPosition.dx - centerX;
        final dy = localPosition.dy - centerY;

        // Calculate distance from center in pixels
        final distanceInPixels = math.sqrt(dx * dx + dy * dy);

        // Normalize distance relative to target radius (not tap area)
        final normalizedDistance = distanceInPixels / targetRadius;

        // Calculate normalized coordinates for hit position (-1 to 1 range based on target size)
        final normalizedX = dx / targetRadius;
        final normalizedY = dy / targetRadius;

        // Determine score based on distance or position (for complex targets)
        int score;
        if (resolvedType == 'Face Mega Mendung') {
          score = _calculateScoreMegaMendung(normalizedX, normalizedY);
        } else {
          score = _calculateScore(normalizedDistance, resolvedType);
        }

        // Call callback with score and normalized position
        onTap(score, normalizedX, normalizedY);
      },
      child: Container(
        width: tapAreaSize,
        height: containerHeight,
        color: Colors.transparent, // Transparent but still receives taps
        child: Center(
          child: SizedBox(
            width: targetVisualSize,
            height: targetVisualSize,
            child: CustomPaint(
              painter: TargetFacePainter(targetType: resolvedType, hits: hits),
              child: Container(),
            ),
          ),
        ),
      ),
    );
  }

  int _calculateScore(double distance, String resolvedType) {
    // Face Ring 6: 6,5,4 (Gold), 3 (Red), 2 (White), 1 (Blue)
    // Each ring is approximately 1/6 of the radius
    if (resolvedType == 'Face Ring 6') {
      if (distance <= 0.167) return 6; // Innermost circle (Gold)
      if (distance <= 0.334) return 5; // Second ring (Gold)
      if (distance <= 0.501) return 4; // Third ring (Gold)
      if (distance <= 0.668) return 3; // Fourth ring (Red)
      if (distance <= 0.835) return 2; // Fifth ring (White)
      if (distance <= 1.0) return 1; // Outermost ring (Blue)
      return 0; // Miss
    }
    // Ring Puta: 2 (White center), 1 (Reddish Brown outer)
    // White center is 40% of radius, outer ring extends to 100%
    if (resolvedType == 'Ring Puta') {
      if (distance <= 0.4) return 2; // Innermost circle (White)
      if (distance <= 1.0) return 1; // Outermost ring (Reddish Brown)
      return 0; // Miss
    }
    // Unknown type fallback to Face Ring 6 so target-face never returns blank scoring.
    if (distance <= 0.167) return 6;
    if (distance <= 0.334) return 5;
    if (distance <= 0.501) return 4;
    if (distance <= 0.668) return 3;
    if (distance <= 0.835) return 2;
    if (distance <= 1.0) return 1;
    return 0;
  }

  int _calculateScoreMegaMendung(double x, double y) {
    // Face Mega Mendung: 2 prisma (atas & bawah) + background circle
    // Check if inside background circle first (白 circle = 1 point)
    final distFromCenter = math.sqrt(x * x + y * y);

    // Check prisma atas (upper diamond) - centered higher
    // Prisma atas: 10 (yellow), 9 (red), 8 (white), 7 (light blue)
    final upperScore = _checkPrismaAtas(x, y);
    if (upperScore > 0) return upperScore;

    // Check prisma bawah (lower diamond) - centered lower
    // Prisma bawah: 6 (yellow), 5 (red), 4 (white), 3 (light blue), 2 (dark blue)
    final lowerScore = _checkPrismaBawah(x, y);
    if (lowerScore > 0) return lowerScore;

    // Check background white circle (1 point)
    if (distFromCenter <= 1.0) return 1;

    return 0; // Miss
  }

  int _checkPrismaAtas(double x, double y) {
    // Upper prisma centered at y = -0.35
    final dy = y + 0.35;
    final dx = x;

    // Check center circle first (poin 10) - LINGKARAN
    final distFromPrismaCenter = math.sqrt(dx * dx + dy * dy);
    if (distFromPrismaCenter <= 0.11) return 10; // Yellow circle center

    // Check if inside diamond shape (rotated 45 degrees)
    final dist = (dx.abs() + dy.abs());

    // Layers from center outward (tanpa poin 10 karena sudah di circle)
    if (dist <= 0.25) return 9; // Red
    if (dist <= 0.35) return 8; // White
    if (dist <= 0.45) return 7; // Light blue

    return 0;
  }

  int _checkPrismaBawah(double x, double y) {
    // Lower prisma centered at y = 0.3 (lebih dekat ke tengah)
    final dy = y - 0.3;
    final dx = x;

    // Check center circle first (poin 6) - LINGKARAN
    final distFromPrismaCenter = math.sqrt(dx * dx + dy * dy);
    if (distFromPrismaCenter <= 0.14) return 6; // Yellow circle center

    // Check if inside diamond shape (rotated 45 degrees)
    final dist = (dx.abs() + dy.abs());

    // Layers from center outward (tanpa poin 6 karena sudah di circle) - dibuat lebih besar
    if (dist <= 0.33) return 5; // Red
    if (dist <= 0.45) return 4; // White
    if (dist <= 0.55) return 3; // Light blue
    if (dist <= 0.65) return 2; // Dark blue

    return 0;
  }
}

class TargetFacePainter extends CustomPainter {
  final String targetType;
  final List<Map<String, double>> hits;

  TargetFacePainter({required this.targetType, this.hits = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final resolvedType = _resolveTargetFaceType(targetType);

    if (resolvedType == 'Face Ring 6') {
      _paintFaceRing6(canvas, center, radius);
    } else if (resolvedType == 'Ring Puta') {
      _paintRingPuta(canvas, center, radius);
    } else if (resolvedType == 'Face Mega Mendung') {
      _paintMegaMendung(canvas, center, radius);
    } else {
      // Fallback so visual target still renders for legacy/unknown labels.
      _paintFaceRing6(canvas, center, radius);
    }

    // Draw hit markers
    _paintHits(canvas, center, radius);
  }

  void _paintFaceRing6(Canvas canvas, Offset center, double radius) {
    // Face Ring 6: 6,5,4 (Gold/Yellow), 3 (Red), 2 (White), 1 (Blue)
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
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, ringRadius, borderPaint);

      // Draw score label
      if (i < 5) {
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
              fontSize: radius * 0.12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Position label at right side of ring
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
    final centerTextPainter = TextPainter(
      text: TextSpan(
        text: '6',
        style: TextStyle(
          color: Colors.black87,
          fontSize: radius * 0.15,
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

  void _paintRingPuta(Canvas canvas, Offset center, double radius) {
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
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw score label for outer ring (1)
    final labelRadius = radius * 0.7; // Position at 70% of radius
    final outerTextPainter = TextPainter(
      text: TextSpan(
        text: '1',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.12,
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

    // Draw center circle (White) - 40% of radius
    final centerRadius = radius * 0.4;
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerRadius, centerPaint);

    // Draw border for center circle
    canvas.drawCircle(center, centerRadius, borderPaint);

    // Draw center score '2'
    final centerTextPainter = TextPainter(
      text: TextSpan(
        text: '2',
        style: TextStyle(
          color: Colors.black87,
          fontSize: radius * 0.15,
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

  void _paintMegaMendung(Canvas canvas, Offset center, double radius) {
    // Face Mega Mendung: kompleks dengan 2 prisma + background circle
    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 1. Draw background white circle (1 point)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawCircle(center, radius, borderPaint);

    // 2. Draw Prisma Bawah (lower diamond) - sedikit lebih besar
    final lowerCenter = Offset(center.dx, center.dy + radius * 0.3);
    _drawPrisma(canvas, lowerCenter, radius, true, borderPaint);

    // 3. Draw Prisma Atas (upper diamond)
    final upperCenter = Offset(center.dx, center.dy - radius * 0.35);
    _drawPrisma(canvas, upperCenter, radius, false, borderPaint);
  }

  void _drawPrisma(
    Canvas canvas,
    Offset center,
    double radius,
    bool isLower,
    Paint borderPaint,
  ) {
    if (isLower) {
      // Prisma Bawah: 5 layers (6,5,4,3,2) - dibuat lebih besar
      final layers = [
        {
          'size': 0.65,
          'color': const Color(0xFF1E3A8A),
          'score': '2',
        }, // Dark blue
        {
          'size': 0.55,
          'color': const Color(0xFF60A5FA),
          'score': '3',
        }, // Light blue
        {'size': 0.45, 'color': Colors.white, 'score': '4'}, // White
        {'size': 0.33, 'color': const Color(0xFFEF4444), 'score': '5'}, // Red
      ];

      // Draw diamond layers (tanpa layer yellow di tengah)
      for (var layer in layers) {
        final size = (layer['size'] as double) * radius;
        final color = layer['color'] as Color;
        _drawDiamond(canvas, center, size, color, borderPaint);
      }

      // Draw center circle (poin 6) - LINGKARAN bukan diamond
      final circlePaint = Paint()
        ..color =
            const Color(0xFFFBBF24) // Yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.14, circlePaint);
      canvas.drawCircle(center, radius * 0.14, borderPaint);

      // Draw center label '6'
      _drawLabel(canvas, center, '6', radius * 0.09, Colors.black87);
    } else {
      // Prisma Atas: 4 layers (10,9,8,7)
      final layers = [
        {
          'size': 0.45,
          'color': const Color(0xFF60A5FA),
          'score': '7',
        }, // Light blue
        {'size': 0.35, 'color': Colors.white, 'score': '8'}, // White
        {'size': 0.25, 'color': const Color(0xFFEF4444), 'score': '9'}, // Red
      ];

      // Draw diamond layers (tanpa layer yellow di tengah)
      for (var layer in layers) {
        final size = (layer['size'] as double) * radius;
        final color = layer['color'] as Color;
        _drawDiamond(canvas, center, size, color, borderPaint);
      }

      // Draw center circle (poin 10) - LINGKARAN bukan diamond
      final circlePaint = Paint()
        ..color =
            const Color(0xFFFBBF24) // Yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.11, circlePaint);
      canvas.drawCircle(center, radius * 0.11, borderPaint);

      // Draw center label '10'
      _drawLabel(canvas, center, '10', radius * 0.07, Colors.black87);
    }
  }

  void _drawDiamond(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    Paint borderPaint,
  ) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size); // Top
    path.lineTo(center.dx + size, center.dy); // Right
    path.lineTo(center.dx, center.dy + size); // Bottom
    path.lineTo(center.dx - size, center.dy); // Left
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawLabel(
    Canvas canvas,
    Offset position,
    String text,
    double fontSize,
    Color color,
  ) {
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

      // Skip unrecorded hits (0,0)
      if (x == 0.0 && y == 0.0) continue;

      // Convert normalized coordinates (-1 to 1) to canvas position
      final hitX = center.dx + (x * radius);
      final hitY = center.dy + (y * radius);
      final hitPosition = Offset(hitX, hitY);

      // Draw hit marker (red circle with white border)
      final hitPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hitPosition, radius * 0.05, hitPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(hitPosition, radius * 0.05, borderPaint);

      // Draw arrow number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(hitX - textPainter.width / 2, hitY - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
