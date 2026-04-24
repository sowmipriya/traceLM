import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/services/service_status_monitor.dart';
import '../state/providers.dart';
import 'provider_detail_page.dart';
import 'settings_page.dart';
import 'widgets/heatmap.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pollingManagerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(usageAggregatorProvider).snapshot;
    final isRefreshing = ref.watch(usageAggregatorProvider).isRefreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TraceLM'),
        actions: [
          IconButton(
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: isRefreshing
                ? null
                : () => ref.read(pollingManagerProvider).forceRefresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: snapshot == null
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () => ref.read(pollingManagerProvider).forceRefresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  for (final provider in snapshot.providers) ...[
                    _ProviderCard(provider: provider),
                    const SizedBox(height: 12),
                  ],
                  if (snapshot.providers.isEmpty) const _NoProvidersNotice(),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final UsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _metric(context, '\$${summary.totalCostTodayUSD.toStringAsFixed(2)}',
                    'Cost'),
                _metric(context, _compact(summary.totalTokensToday), 'Tokens'),
                _metric(context, '${summary.totalRequestsToday}', 'Requests'),
                _metric(
                    context,
                    summary.worstPercentage <= 0
                        ? '—'
                        : '${summary.worstPercentage.round()}%',
                    'Worst window'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext ctx, String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: Theme.of(ctx).textTheme.bodySmall),
        ],
      );

  String _compact(int n) {
    if (n < 1000) return '$n';
    if (n < 1_000_000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1_000_000).toStringAsFixed(2)}M';
  }
}

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard({required this.provider});

  final ProviderResult provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(serviceStatusMonitorProvider).statusFor(provider.identifier);
    final primary = provider.primaryWindow;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProviderDetailPage(providerId: provider.identifier),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.displayName,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${provider.category.title} · ${provider.profile}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              if (primary != null)
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (primary.percentage / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${primary.percentage.round()}%',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                )
              else
                Text(
                  provider.warnings.isNotEmpty
                      ? provider.warnings.first.message
                      : 'No active window data.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Today: \$${provider.today.costUSD.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (provider.burnRate != null)
                    Text(
                      '${provider.burnRate!.tokensPerMinute.toStringAsFixed(0)} tok/min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              HeatmapWidget(cells: provider.dailyHeatmap),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ProviderServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status.health) {
      ProviderServiceHealth.operational => Colors.green,
      ProviderServiceHealth.degraded => Colors.orange,
      ProviderServiceHealth.outage => Colors.red,
      ProviderServiceHealth.checking => Colors.blueGrey,
      ProviderServiceHealth.unknown => Colors.grey,
    };
    return Tooltip(
      message: status.message,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status.health.label,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats, size: 48),
              SizedBox(height: 12),
              Text(
                'Collecting your first usage snapshot…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _NoProvidersNotice extends StatelessWidget {
  const _NoProvidersNotice();
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'No providers enabled yet. Open Settings → Sources to turn providers on.'),
            ],
          ),
        ),
      );
}
