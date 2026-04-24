import '../models/usage_window.dart';

class ForecastCalculator {
  ForecastCalculator._();

  static Forecast? forecastUsage({
    required double used,
    required double? limit,
    required DateTime? windowStart,
    required DateTime? windowEnd,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    if (used < 0 ||
        limit == null ||
        limit <= 0 ||
        windowStart == null ||
        windowEnd == null ||
        !windowEnd.isAfter(now)) {
      return null;
    }

    final totalWindowSeconds =
        windowEnd.difference(windowStart).inSeconds.toDouble();
    final elapsedSeconds = now.difference(windowStart).inSeconds.toDouble();
    if (totalWindowSeconds <= 0 || elapsedSeconds < 60) return null;

    final pace = used / elapsedSeconds;
    final projectedAtReset = pace * totalWindowSeconds;
    final projectedPercentage = (projectedAtReset / limit) * 100;

    final ForecastStatus status;
    if (projectedPercentage <= 80) {
      status = ForecastStatus.onTrack;
    } else if (projectedPercentage <= 100) {
      status = ForecastStatus.tight;
    } else {
      status = ForecastStatus.willExceed;
    }

    Duration? timeToDepletion;
    final remainingSeconds = windowEnd.difference(now).inSeconds;
    if (pace > 0) {
      final remaining = (limit - used).clamp(0, double.infinity);
      final secondsToDepletion = remaining / pace;
      if (secondsToDepletion < remainingSeconds) {
        timeToDepletion = Duration(seconds: secondsToDepletion.round());
      }
    }

    return Forecast(
      projectedUsageAtReset: projectedAtReset,
      projectedPercentageAtReset: projectedPercentage,
      status: status,
      timeToDepletion: timeToDepletion,
    );
  }

  static DateTime? inferredWindowStart({
    required WindowKind kind,
    required DateTime? resetAt,
  }) {
    if (resetAt == null) return null;
    return switch (kind) {
      FiveHourWindow() => resetAt.subtract(const Duration(hours: 5)),
      WeeklyWindow() => resetAt.subtract(const Duration(days: 7)),
      MonthlyWindow() => DateTime(
          resetAt.year,
          resetAt.month - 1,
          resetAt.day,
          resetAt.hour,
          resetAt.minute,
        ),
      CustomWindow() => null,
    };
  }
}
