import 'package:flutter_test/flutter_test.dart';
import 'package:tracelm/core/models/usage_window.dart';
import 'package:tracelm/core/services/forecast_calculator.dart';

void main() {
  group('ForecastCalculator.forecastUsage', () {
    test('returns null when the window has not started', () {
      final now = DateTime(2026, 1, 1, 12);
      final result = ForecastCalculator.forecastUsage(
        used: 100,
        limit: 1000,
        windowStart: now.subtract(const Duration(seconds: 30)),
        windowEnd: now.add(const Duration(hours: 1)),
        now: now,
      );
      expect(result, isNull);
    });

    test('flags on-track when projected usage stays under 80%', () {
      final now = DateTime(2026, 1, 1, 12);
      final result = ForecastCalculator.forecastUsage(
        used: 100,
        limit: 1000,
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 4)),
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.status, ForecastStatus.onTrack);
    });

    test('flags will-exceed when projection blows past the limit', () {
      final now = DateTime(2026, 1, 1, 12);
      final result = ForecastCalculator.forecastUsage(
        used: 800,
        limit: 1000,
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 4)),
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.status, ForecastStatus.willExceed);
      expect(result.timeToDepletion, isNotNull);
    });
  });

  group('ForecastCalculator.inferredWindowStart', () {
    test('five-hour windows subtract 5h', () {
      final reset = DateTime(2026, 1, 1, 17);
      final start = ForecastCalculator.inferredWindowStart(
        kind: const WindowKind.fiveHour(),
        resetAt: reset,
      );
      expect(start, reset.subtract(const Duration(hours: 5)));
    });

    test('weekly windows subtract 7 days', () {
      final reset = DateTime(2026, 1, 8);
      final start = ForecastCalculator.inferredWindowStart(
        kind: const WindowKind.weekly(),
        resetAt: reset,
      );
      expect(start, reset.subtract(const Duration(days: 7)));
    });

    test('custom windows return null', () {
      final reset = DateTime(2026, 1, 1);
      final start = ForecastCalculator.inferredWindowStart(
        kind: const WindowKind.custom('Reviews'),
        resetAt: reset,
      );
      expect(start, isNull);
    });
  });
}
