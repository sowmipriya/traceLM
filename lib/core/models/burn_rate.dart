class BurnRate {
  const BurnRate({
    required this.tokensPerMinute,
    required this.costPerHour,
    this.projectedTotalTokens,
    this.projectedTotalCost,
    this.remainingMinutes,
  });

  final double tokensPerMinute;
  final double costPerHour;
  final int? projectedTotalTokens;
  final double? projectedTotalCost;
  final int? remainingMinutes;

  bool get isSafeToStartHeavyTask =>
      remainingMinutes != null && remainingMinutes! > 30;
}
