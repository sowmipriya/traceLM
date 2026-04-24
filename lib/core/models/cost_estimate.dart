class CostEstimate {
  const CostEstimate({
    required this.inputPerMillion,
    required this.outputPerMillion,
    this.cacheReadPerMillion = 0,
    this.cacheWritePerMillion = 0,
  });

  final double inputPerMillion;
  final double outputPerMillion;
  final double cacheReadPerMillion;
  final double cacheWritePerMillion;

  double totalCost({
    required int input,
    required int output,
    int cacheRead = 0,
    int cacheWrite = 0,
  }) {
    final inputCost = (input / 1_000_000) * inputPerMillion;
    final outputCost = (output / 1_000_000) * outputPerMillion;
    final cacheReadCost = (cacheRead / 1_000_000) * cacheReadPerMillion;
    final cacheWriteCost = (cacheWrite / 1_000_000) * cacheWritePerMillion;
    return inputCost + outputCost + cacheReadCost + cacheWriteCost;
  }
}

enum ModelFamily {
  claudeSonnet,
  claudeOpus,
  claudeHaiku,
  codex,
  gpt,
  geminiPro,
  geminiFlash,
  cursor,
  unknown;

  static ModelFamily resolve(String model) {
    final m = model.toLowerCase();
    if (m.contains('sonnet')) return ModelFamily.claudeSonnet;
    if (m.contains('opus')) return ModelFamily.claudeOpus;
    if (m.contains('haiku')) return ModelFamily.claudeHaiku;
    if (m.contains('codex')) return ModelFamily.codex;
    if (m.contains('gpt')) return ModelFamily.gpt;
    if (m.contains('gemini') && m.contains('flash')) {
      return ModelFamily.geminiFlash;
    }
    if (m.contains('gemini')) return ModelFamily.geminiPro;
    if (m.contains('cursor')) return ModelFamily.cursor;
    return ModelFamily.unknown;
  }

  CostEstimate get pricing {
    switch (this) {
      case ModelFamily.claudeSonnet:
        return const CostEstimate(
          inputPerMillion: 3.0,
          outputPerMillion: 15.0,
          cacheReadPerMillion: 0.3,
          cacheWritePerMillion: 3.75,
        );
      case ModelFamily.claudeOpus:
        return const CostEstimate(
          inputPerMillion: 15.0,
          outputPerMillion: 75.0,
          cacheReadPerMillion: 1.5,
          cacheWritePerMillion: 18.75,
        );
      case ModelFamily.claudeHaiku:
        return const CostEstimate(
          inputPerMillion: 0.8,
          outputPerMillion: 4.0,
          cacheReadPerMillion: 0.08,
          cacheWritePerMillion: 1.0,
        );
      case ModelFamily.codex:
        return const CostEstimate(inputPerMillion: 1.5, outputPerMillion: 6.0);
      case ModelFamily.gpt:
        return const CostEstimate(inputPerMillion: 5.0, outputPerMillion: 15.0);
      case ModelFamily.geminiPro:
        return const CostEstimate(
            inputPerMillion: 1.25, outputPerMillion: 5.0);
      case ModelFamily.geminiFlash:
        return const CostEstimate(
            inputPerMillion: 0.35, outputPerMillion: 1.05);
      case ModelFamily.cursor:
      case ModelFamily.unknown:
        return const CostEstimate(inputPerMillion: 0, outputPerMillion: 0);
    }
  }
}
