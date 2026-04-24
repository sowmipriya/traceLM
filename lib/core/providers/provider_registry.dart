import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';
import 'claude_code_provider.dart';
import 'codex_provider.dart';
import 'copilot_provider.dart';
import 'cursor_provider.dart';
import 'gemini_provider.dart';
import 'openai_api_provider.dart';
import 'usage_provider.dart';

/// Central pluggable list. Adding a new provider only takes: implement
/// [UsageProvider], register it here, and (optionally) wire its service
/// status into [ServiceStatusMonitor].
class ProviderRegistry extends ChangeNotifier {
  ProviderRegistry(this.settings) {
    _providers = [
      ClaudeCodeProvider(settings),
      CodexProvider(settings),
      CursorProvider(settings),
      CopilotProvider(settings),
      GeminiProvider(settings),
      OpenAiApiProvider(settings),
    ];
  }

  final SettingsService settings;
  late final List<UsageProvider> _providers;

  List<UsageProvider> get providers => List.unmodifiable(_providers);

  List<UsageProvider> enabledProviders() =>
      _providers.where((p) => p.isEnabled).toList();

  UsageProvider? find(String id) {
    for (final p in _providers) {
      if (p.identifier == id) return p;
    }
    return null;
  }

  Future<void> setEnabled({required String id, required bool enabled}) async {
    final provider = find(id);
    if (provider == null) return;
    provider.isEnabled = enabled;
    notifyListeners();
  }
}
