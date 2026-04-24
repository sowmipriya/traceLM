import '../services/forecast_calculator.dart';

enum UsageUnit { tokens, requests, credits, dollars }

enum ForecastStatus { onTrack, tight, willExceed }

class Forecast {
  const Forecast({
    required this.projectedUsageAtReset,
    required this.projectedPercentageAtReset,
    required this.status,
    this.timeToDepletion,
  });

  final double projectedUsageAtReset;
  final double projectedPercentageAtReset;
  final ForecastStatus status;
  final Duration? timeToDepletion;
}

sealed class WindowKind {
  const WindowKind();

  const factory WindowKind.fiveHour() = FiveHourWindow;
  const factory WindowKind.weekly() = WeeklyWindow;
  const factory WindowKind.monthly() = MonthlyWindow;
  const factory WindowKind.custom(String name) = CustomWindow;

  String get title;
  String get reportingKey;
}

class FiveHourWindow extends WindowKind {
  const FiveHourWindow();
  @override
  String get title => 'Session';
  @override
  String get reportingKey => 'session';
  @override
  bool operator ==(Object other) => other is FiveHourWindow;
  @override
  int get hashCode => 'fiveHour'.hashCode;
}

class WeeklyWindow extends WindowKind {
  const WeeklyWindow();
  @override
  String get title => 'Weekly';
  @override
  String get reportingKey => 'weekly';
  @override
  bool operator ==(Object other) => other is WeeklyWindow;
  @override
  int get hashCode => 'weekly'.hashCode;
}

class MonthlyWindow extends WindowKind {
  const MonthlyWindow();
  @override
  String get title => 'Monthly';
  @override
  String get reportingKey => 'monthly';
  @override
  bool operator ==(Object other) => other is MonthlyWindow;
  @override
  int get hashCode => 'monthly'.hashCode;
}

class CustomWindow extends WindowKind {
  const CustomWindow(this.name);
  final String name;
  @override
  String get title => name;
  @override
  String get reportingKey =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  @override
  bool operator ==(Object other) =>
      other is CustomWindow && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

class UsageWindow {
  UsageWindow({
    required this.kind,
    required this.used,
    required this.limit,
    required this.unit,
    required this.percentage,
    required this.resetAt,
    DateTime? windowStart,
    Forecast? forecast,
  })  : windowStart = windowStart ??
            ForecastCalculator.inferredWindowStart(
                kind: kind, resetAt: resetAt),
        forecast = forecast ??
            ForecastCalculator.forecastUsage(
              used: used,
              limit: limit,
              windowStart: windowStart ??
                  ForecastCalculator.inferredWindowStart(
                      kind: kind, resetAt: resetAt),
              windowEnd: resetAt,
            );

  final WindowKind kind;
  final double used;
  final double? limit;
  final UsageUnit unit;
  final double percentage;
  final DateTime? resetAt;
  final DateTime? windowStart;
  final Forecast? forecast;
}
