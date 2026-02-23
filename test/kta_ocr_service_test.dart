import 'package:al_ihsan_archery/services/kta_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractFromImagePath is safe when OCR plugin is unavailable', () async {
    final service = KtaOcrService();
    final result = await service.extractFromImagePath('/tmp/not-found-kta.jpg');
    expect(result.rawText, isEmpty);
    expect(result.memberNumber, isNull);
    expect(result.validFrom, isNull);
    expect(result.validUntil, isNull);
  });

  group('KtaOcrService.extractFromText', () {
    test('extracts member number and expiry date with derived valid from', () {
      const sample = '''
KORMI FEDERASI SENI PANAHAN
No Anggota: 811107299
Berlaku Sampai: 30/06/2026
''';

      final result = KtaOcrService.extractFromText(sample);

      expect(result.memberNumber, '811107299');
      expect(result.validUntil, DateTime(2026, 6, 30));
      expect(result.validFrom, DateTime(2025, 6, 30));
    });

    test('supports Indonesian month names for expiry date parsing', () {
      const sample = '''
NOMOR ANGGOTA 811107299
MASA BERLAKU SAMPAI 7 Juli 2027
''';

      final result = KtaOcrService.extractFromText(sample);

      expect(result.memberNumber, '811107299');
      expect(result.validUntil, DateTime(2027, 7, 7));
      expect(result.validFrom, DateTime(2026, 7, 7));
    });

    test('prefers expiry date over earlier dates', () {
      const sample = '''
No KTA 811107299
Diterbitkan 21/02/2025
Berlaku sampai 21/03/2026
''';

      final result = KtaOcrService.extractFromText(sample);

      expect(result.validUntil, DateTime(2026, 3, 21));
      expect(result.validFrom, DateTime(2025, 3, 21));
    });
  });
}
