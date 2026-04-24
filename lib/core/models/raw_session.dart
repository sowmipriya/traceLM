class RawSession {
  RawSession({
    required this.providerIdentifier,
    required this.profile,
    required this.startedAt,
    required this.endedAt,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
    this.requestCount = 1,
    required this.costUSD,
    this.projectHint,
  });

  final String providerIdentifier;
  final String profile;
  final DateTime startedAt;
  final DateTime endedAt;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final int requestCount;
  final double costUSD;
  final String? projectHint;

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens;
}

class SessionWindowPreset {
  static const Duration lastFiveHours = Duration(hours: 5);
  static const Duration lastSevenDays = Duration(days: 7);
  static const Duration lastThirtyDays = Duration(days: 30);
  static const Duration lastThirtyMinutes = Duration(minutes: 30);
}
