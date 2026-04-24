enum UsageIntensity { zero, low, medium, high, peak }

class DailyCell {
  const DailyCell({
    required this.date,
    required this.value,
    required this.intensity,
  });

  final DateTime date;
  final double value;
  final UsageIntensity intensity;

  static UsageIntensity intensityFor(double value, double max) {
    if (value <= 0 || max <= 0) return UsageIntensity.zero;
    final ratio = value / max;
    if (ratio < 0.25) return UsageIntensity.low;
    if (ratio < 0.5) return UsageIntensity.medium;
    if (ratio < 0.8) return UsageIntensity.high;
    return UsageIntensity.peak;
  }
}
