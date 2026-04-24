import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/provider_result.dart';
import '../state/providers.dart';
import 'widgets/heatmap.dart';
import 'widgets/window_bar.dart';

class ProviderDetailPage extends ConsumerWidget {
  const ProviderDetailPage({required this.providerId, super.key});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(usageAggregatorProvider).snapshot;
    ProviderResult? provider;
    if (snapshot != null) {
      for (final p in snapshot.providers) {
        if (p.identifier == providerId) {
          provider = p;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(provider?.displayName ?? providerId)),
      body: provider == null
          ? const Center(child: Text('Provider not found in current snapshot.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.warnings.isNotEmpty)
                  _WarningsCard(warnings: provider.warnings),
                for (final window in provider.windows) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: WindowProgressBar(window: window),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activity — last 90 days',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 12),
                        HeatmapWidget(cells: provider.dailyHeatmap),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.models.isNotEmpty) _ModelsCard(provider: provider),
              ],
            ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<ProviderWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(w.level), size: 18, color: _colorFor(w.level)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w.message)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ProviderWarningLevel level) => switch (level) {
        ProviderWarningLevel.info => Icons.info_outline,
        ProviderWarningLevel.warning => Icons.warning_amber_outlined,
        ProviderWarningLevel.critical => Icons.error_outline,
      };

  Color _colorFor(ProviderWarningLevel level) => switch (level) {
        ProviderWarningLevel.info => Colors.blueGrey,
        ProviderWarningLevel.warning => Colors.orange,
        ProviderWarningLevel.critical => Colors.red,
      };
}

class _ModelsCard extends StatelessWidget {
  const _ModelsCard({required this.provider});
  final ProviderResult provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Models used', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final m in provider.models.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(m.model,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text('${m.tokens} tok',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 16),
                    Text('\$${m.costUSD.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

