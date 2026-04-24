import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ProviderServiceHealth {
  checking,
  operational,
  degraded,
  outage,
  unknown;

  String get label => switch (this) {
        ProviderServiceHealth.checking => 'Checking',
        ProviderServiceHealth.operational => 'Operational',
        ProviderServiceHealth.degraded => 'Degraded',
        ProviderServiceHealth.outage => 'Outage',
        ProviderServiceHealth.unknown => 'Unknown',
      };

  bool get showsAlert =>
      this == ProviderServiceHealth.degraded ||
      this == ProviderServiceHealth.outage;

  static ProviderServiceHealth fromIndicator(String indicator) {
    switch (indicator.toLowerCase()) {
      case 'none':
        return ProviderServiceHealth.operational;
      case 'minor':
      case 'maintenance':
        return ProviderServiceHealth.degraded;
      case 'major':
      case 'critical':
        return ProviderServiceHealth.outage;
      default:
        return ProviderServiceHealth.unknown;
    }
  }
}

class ProviderServiceStatus {
  const ProviderServiceStatus({
    required this.serviceName,
    required this.statusPageUrl,
    required this.health,
    required this.message,
    required this.checkedAt,
  });

  final String serviceName;
  final Uri? statusPageUrl;
  final ProviderServiceHealth health;
  final String message;
  final DateTime? checkedAt;

  bool get hasStatusPage => statusPageUrl != null;
}

class _ServiceDescriptor {
  const _ServiceDescriptor({
    required this.id,
    required this.name,
    required this.providerIds,
    this.statusPageUrl,
    this.summaryUrl,
  });

  final String id;
  final String name;
  final List<String> providerIds;
  final Uri? statusPageUrl;
  final Uri? summaryUrl;
}

/// Polls the public `statuspage.io`-style summary endpoints that each vendor
/// publishes. Ported from CirrondlyDesk/Core/Services/ServiceStatusMonitor.swift.
class ServiceStatusMonitor extends ChangeNotifier {
  ServiceStatusMonitor({http.Client? client})
      : _client = client ?? http.Client() {
    _statuses = _bootstrap();
  }

  final http.Client _client;
  late Map<String, ProviderServiceStatus> _statuses;
  DateTime? _lastRefreshAt;
  Future<void>? _inflight;

  Map<String, ProviderServiceStatus> get statuses => _statuses;

  static const _refreshTtl = Duration(minutes: 15);

  static final List<_ServiceDescriptor> _descriptors = [
    _ServiceDescriptor(
      id: 'anthropic',
      name: 'Anthropic',
      providerIds: const ['claude-code', 'claude-subscription'],
      statusPageUrl: Uri.parse('https://status.anthropic.com'),
      summaryUrl: Uri.parse('https://status.anthropic.com/api/v2/status.json'),
    ),
    _ServiceDescriptor(
      id: 'openai',
      name: 'OpenAI',
      providerIds: const ['codex', 'openai-api'],
      statusPageUrl: Uri.parse('https://status.openai.com'),
      summaryUrl: Uri.parse('https://status.openai.com/api/v2/status.json'),
    ),
    _ServiceDescriptor(
      id: 'cursor',
      name: 'Cursor',
      providerIds: const ['cursor'],
      statusPageUrl: Uri.parse('https://status.cursor.com'),
      summaryUrl: Uri.parse('https://status.cursor.com/api/v2/status.json'),
    ),
    _ServiceDescriptor(
      id: 'github',
      name: 'GitHub',
      providerIds: const ['copilot'],
      statusPageUrl: Uri.parse('https://www.githubstatus.com'),
      summaryUrl:
          Uri.parse('https://www.githubstatus.com/api/v2/status.json'),
    ),
    _ServiceDescriptor(
      id: 'google-cloud',
      name: 'Google Cloud',
      providerIds: const ['gemini'],
      statusPageUrl: Uri.parse('https://status.cloud.google.com'),
    ),
  ];

  ProviderServiceStatus statusFor(String providerId) =>
      _statuses[providerId] ?? _fallback(providerId);

  Future<void> refresh({bool force = false}) async {
    final inflight = _inflight;
    if (inflight != null) {
      await inflight;
      if (!force) return;
    }

    if (!force &&
        _lastRefreshAt != null &&
        DateTime.now().difference(_lastRefreshAt!) < _refreshTtl) {
      return;
    }

    final task = _refresh();
    _inflight = task;
    try {
      await task;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _refresh() async {
    final next = Map<String, ProviderServiceStatus>.from(_statuses);
    final results = await Future.wait(_descriptors.map(_fetch));
    for (var i = 0; i < _descriptors.length; i++) {
      final d = _descriptors[i];
      final status = results[i];
      for (final pid in d.providerIds) {
        next[pid] = status;
      }
    }
    _statuses = next;
    _lastRefreshAt = DateTime.now();
    notifyListeners();
  }

  Future<ProviderServiceStatus> _fetch(_ServiceDescriptor d) async {
    final summary = d.summaryUrl;
    if (summary == null) return _statusWithoutFetch(d);
    try {
      final res =
          await _client.get(summary).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return _unknownStatus(d);
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final status = body['status'] as Map<String, dynamic>?;
      final indicator = status?['indicator'] as String? ?? 'unknown';
      final description = status?['description'] as String? ?? '';
      return ProviderServiceStatus(
        serviceName: d.name,
        statusPageUrl: d.statusPageUrl,
        health: ProviderServiceHealth.fromIndicator(indicator),
        message: description,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      return _unknownStatus(d);
    }
  }

  ProviderServiceStatus _fallback(String providerId) {
    final d = _descriptors.firstWhere(
      (desc) => desc.providerIds.contains(providerId),
      orElse: () => _ServiceDescriptor(
        id: providerId,
        name: providerId,
        providerIds: [providerId],
      ),
    );
    return _statusWithoutFetch(d);
  }

  Map<String, ProviderServiceStatus> _bootstrap() {
    final out = <String, ProviderServiceStatus>{};
    for (final d in _descriptors) {
      final status = ProviderServiceStatus(
        serviceName: d.name,
        statusPageUrl: d.statusPageUrl,
        health: d.summaryUrl == null
            ? ProviderServiceHealth.unknown
            : ProviderServiceHealth.checking,
        message: d.summaryUrl == null
            ? 'No public status page configured yet.'
            : 'Checking the provider status page.',
        checkedAt: null,
      );
      for (final pid in d.providerIds) {
        out[pid] = status;
      }
    }
    return out;
  }

  ProviderServiceStatus _statusWithoutFetch(_ServiceDescriptor d) =>
      ProviderServiceStatus(
        serviceName: d.name,
        statusPageUrl: d.statusPageUrl,
        health: ProviderServiceHealth.unknown,
        message: d.statusPageUrl == null
            ? 'No public status page configured yet.'
            : 'Open the public status page to inspect current service health.',
        checkedAt: null,
      );

  ProviderServiceStatus _unknownStatus(_ServiceDescriptor d) =>
      ProviderServiceStatus(
        serviceName: d.name,
        statusPageUrl: d.statusPageUrl,
        health: ProviderServiceHealth.unknown,
        message: 'Could not verify the public status page right now.',
        checkedAt: DateTime.now(),
      );
}
