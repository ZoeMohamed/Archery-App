import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_ocr/flutter_native_ocr.dart';

class KtaOcrExtraction {
  final String rawText;
  final String? memberNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;

  const KtaOcrExtraction({
    required this.rawText,
    this.memberNumber,
    this.validFrom,
    this.validUntil,
  });

  bool get hasAnySuggestion =>
      (memberNumber != null && memberNumber!.isNotEmpty) ||
      validFrom != null ||
      validUntil != null;
}

class KtaOcrService {
  final FlutterNativeOcr _nativeOcr;

  KtaOcrService({FlutterNativeOcr? nativeOcr})
    : _nativeOcr = nativeOcr ?? FlutterNativeOcr();

  bool get _supportsNativeOcr {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<KtaOcrExtraction> extractFromImagePath(String imagePath) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty || !_supportsNativeOcr) {
      return const KtaOcrExtraction(rawText: '');
    }

    try {
      final rawText = await _nativeOcr.recognizeText(normalizedPath);
      final trimmed = rawText.trim();
      if (trimmed.isEmpty) {
        return const KtaOcrExtraction(rawText: '');
      }
      return extractFromText(trimmed);
    } on MissingPluginException {
      return const KtaOcrExtraction(rawText: '');
    } on PlatformException {
      return const KtaOcrExtraction(rawText: '');
    } catch (_) {
      return const KtaOcrExtraction(rawText: '');
    }
  }

  static KtaOcrExtraction extractFromText(
    String rawText, {
    List<String>? lines,
  }) {
    final extractedLines = (lines != null && lines.isNotEmpty)
        ? lines
        : rawText
              .split(RegExp(r'[\r\n]+'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();

    final memberNumber = _extractMemberNumber(extractedLines);
    final validUntil = _extractValidUntil(extractedLines, rawText);
    final validFrom = validUntil == null ? null : _subtractOneYear(validUntil);

    return KtaOcrExtraction(
      rawText: rawText,
      memberNumber: memberNumber,
      validFrom: validFrom,
      validUntil: validUntil,
    );
  }

  void dispose() {
    // no-op while OCR is disabled
  }

  static String? _extractMemberNumber(List<String> lines) {
    final keywordPattern = RegExp(
      r'(NOMOR\s*ANGGOTA|NO\.?\s*ANGGOTA|NO\.?\s*KTA|MEMBER\s*NUMBER|ID\s*ANGGOTA)',
      caseSensitive: false,
    );

    final candidateScores = <String, int>{};

    for (final line in lines) {
      final normalized = _normalizeLine(line);
      final hasKeyword = keywordPattern.hasMatch(normalized);
      final candidates = _extractNumberTokens(normalized);

      for (final candidate in candidates) {
        final sanitized = _sanitizeMemberToken(candidate);
        if (sanitized == null) {
          continue;
        }
        var score = 0;
        if (RegExp(r'^\d+$').hasMatch(sanitized)) {
          score += 4;
        }
        if (sanitized.length >= 8 && sanitized.length <= 12) {
          score += 4;
        } else if (sanitized.length >= 6 && sanitized.length <= 16) {
          score += 2;
        }
        if (sanitized.length == 16) {
          score -= 3;
        }
        if (hasKeyword) {
          score += 7;
        }
        if (RegExp(r'^(19|20)\d{2}$').hasMatch(sanitized)) {
          score -= 5;
        }

        final existingScore = candidateScores[sanitized] ?? -999;
        if (score > existingScore) {
          candidateScores[sanitized] = score;
        }
      }
    }

    if (candidateScores.isEmpty) {
      return null;
    }

    final bestEntry = candidateScores.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );
    return bestEntry.value > 0 ? bestEntry.key : null;
  }

  static DateTime? _extractValidUntil(List<String> lines, String rawText) {
    final keywordPattern = RegExp(
      r'(BERLAKU\s*(SAMPAI|HINGGA)|VALID\s*UNTIL|MASA\s*BERLAKU|EXPIRE|EXP|S\/D|SAMPAI)',
      caseSensitive: false,
    );

    final scoredDates = <_ScoredDate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final datesInLine = _extractDates(line);
      final hasKeyword = keywordPattern.hasMatch(line);
      if (hasKeyword) {
        for (final date in datesInLine) {
          scoredDates.add(_ScoredDate(date: date, score: 15));
        }
        if (datesInLine.isEmpty && i + 1 < lines.length) {
          final nextLineDates = _extractDates(lines[i + 1]);
          for (final date in nextLineDates) {
            scoredDates.add(_ScoredDate(date: date, score: 11));
          }
        }
      } else {
        for (final date in datesInLine) {
          scoredDates.add(_ScoredDate(date: date, score: _baseDateScore(date)));
        }
      }
    }

    if (scoredDates.isEmpty) {
      final fallbackDates = _extractDates(rawText);
      for (final date in fallbackDates) {
        scoredDates.add(_ScoredDate(date: date, score: _baseDateScore(date)));
      }
    }

    if (scoredDates.isEmpty) {
      return null;
    }

    scoredDates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return b.date.compareTo(a.date);
    });

    return scoredDates.first.date;
  }

  static int _baseDateScore(DateTime date) {
    final now = DateTime.now();
    var score = 0;
    if (date.year >= 2000 && date.year <= 2100) {
      score += 4;
    }
    if (date.isAfter(DateTime(now.year - 1, 1, 1)) &&
        date.isBefore(DateTime(now.year + 11, 1, 1))) {
      score += 4;
    }
    return score;
  }

  static List<DateTime> _extractDates(String text) {
    final output = <DateTime>[];
    final seenKeys = <String>{};

    void addDate(DateTime? value) {
      if (value == null) {
        return;
      }
      final normalized = DateTime(value.year, value.month, value.day);
      final key = '${normalized.year}-${normalized.month}-${normalized.day}';
      if (seenKeys.add(key)) {
        output.add(normalized);
      }
    }

    final numericDayFirst = RegExp(
      r'(?<!\d)(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})(?!\d)',
    );
    for (final match in numericDayFirst.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = _normalizeYear(match.group(3));
      addDate(_safeDate(year: year, month: month, day: day));
    }

    final numericYearFirst = RegExp(
      r'(?<!\d)(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})(?!\d)',
    );
    for (final match in numericYearFirst.allMatches(text)) {
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final day = int.tryParse(match.group(3) ?? '');
      addDate(_safeDate(year: year, month: month, day: day));
    }

    final monthNamePattern = RegExp(
      r'(?<!\d)(\d{1,2})\s+([A-Za-z]{3,12})\s+(\d{2,4})(?!\d)',
      caseSensitive: false,
    );
    for (final match in monthNamePattern.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = _monthFromName(match.group(2) ?? '');
      final year = _normalizeYear(match.group(3));
      addDate(_safeDate(year: year, month: month, day: day));
    }

    return output;
  }

  static int? _normalizeYear(String? rawYear) {
    if (rawYear == null || rawYear.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(rawYear);
    if (parsed == null) {
      return null;
    }
    if (rawYear.length == 2) {
      return parsed >= 70 ? 1900 + parsed : 2000 + parsed;
    }
    return parsed;
  }

  static int? _monthFromName(String raw) {
    final value = raw.trim().toUpperCase();
    const monthMap = <String, int>{
      'JAN': 1,
      'JANUARI': 1,
      'JANUARY': 1,
      'FEB': 2,
      'FEBRUARI': 2,
      'FEBRUARY': 2,
      'MAR': 3,
      'MARET': 3,
      'MARCH': 3,
      'APR': 4,
      'APRIL': 4,
      'MEI': 5,
      'MAY': 5,
      'JUN': 6,
      'JUNI': 6,
      'JUNE': 6,
      'JUL': 7,
      'JULI': 7,
      'JULY': 7,
      'AGU': 8,
      'AGUSTUS': 8,
      'AUG': 8,
      'AUGUST': 8,
      'SEP': 9,
      'SEPT': 9,
      'SEPTEMBER': 9,
      'OKT': 10,
      'OKTOBER': 10,
      'OCT': 10,
      'OCTOBER': 10,
      'NOV': 11,
      'NOVEMBER': 11,
      'DES': 12,
      'DESEMBER': 12,
      'DEC': 12,
      'DECEMBER': 12,
    };
    return monthMap[value];
  }

  static DateTime? _safeDate({
    required int? year,
    required int? month,
    required int? day,
  }) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (year < 1900 || year > 2100) {
      return null;
    }
    if (month < 1 || month > 12) {
      return null;
    }
    if (day < 1 || day > 31) {
      return null;
    }
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  static DateTime _subtractOneYear(DateTime value) {
    final targetYear = value.year - 1;
    final maxDayInMonth = DateTime(targetYear, value.month + 1, 0).day;
    final safeDay = value.day > maxDayInMonth ? maxDayInMonth : value.day;
    return DateTime(targetYear, value.month, safeDay);
  }

  static String _normalizeLine(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _extractNumberTokens(String line) {
    final tokens = <String>{};

    final numericWithSeparators = RegExp(r'\d[\d\s\-]{4,}\d');
    for (final match in numericWithSeparators.allMatches(line)) {
      final compact = (match.group(0) ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (compact.length >= 6 && compact.length <= 20) {
        tokens.add(compact);
      }
    }

    final alphaNumeric = RegExp(r'\b[A-Z]{2,6}\d{4,16}\b');
    for (final match in alphaNumeric.allMatches(line)) {
      final token = (match.group(0) ?? '').trim();
      if (token.length >= 6 && token.length <= 20) {
        tokens.add(token);
      }
    }

    return tokens.toList();
  }

  static String? _sanitizeMemberToken(String token) {
    if (token.isEmpty) {
      return null;
    }
    final value = token.toUpperCase().replaceAll('O', '0').replaceAll('I', '1');
    if (value.length < 6 || value.length > 20) {
      return null;
    }
    return value;
  }
}

class _ScoredDate {
  final DateTime date;
  final int score;

  const _ScoredDate({required this.date, required this.score});
}
