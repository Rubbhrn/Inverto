import 'package:flutter_test/flutter_test.dart';
import 'package:inverto/main.dart';

void main() {
  group('DailyRecord', () {
    test('excludes contributions from the daily gain', () {
      const record = DailyRecord(
        dateKey: '2026-11-08',
        openingValue: 11000,
        closingValue: 11800,
        contributions: 500,
      );

      expect(record.gain, 300);
      expect(record.returnPercentage, closeTo(300 / 11000 * 100, 0.0001));
    });

    test('reports a following-day loss against that day opening value', () {
      const record = DailyRecord(
        dateKey: '2026-11-09',
        openingValue: 11300,
        closingValue: 11200,
        contributions: 0,
      );

      expect(record.gain, -100);
      expect(record.returnPercentage, closeTo(-100 / 11300 * 100, 0.0001));
      expect(11200 - 11000, 200);
    });
  });
}
