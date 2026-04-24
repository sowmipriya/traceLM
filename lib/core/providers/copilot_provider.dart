import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/settings_service.dart';
import '../utils/home_paths.dart';
import 'usage_provider.dart';

/// GitHub Copilot does not expose a user-level usage API. We detect the
/// presence of the Copilot hosts config and surface a link to the GitHub
/// dashboard rather than inventing numbers.
class CopilotProvider implements UsageProvider {
  CopilotProvider(this.settings);

  static const String id = 'copilot';
  final SettingsService settings;

  @override
  String get identifier => id;
  @override
  String get displayName => 'GitHub Copilot';
  @override
  ProviderCategory get category => ProviderCategory.subscription;

  @override
  bool get isEnabled => settings.providerEnabled(id, defaultValue: false);
  @override
  set isEnabled(bool value) => settings.setProviderEnabled(id, value);

  @override
  List<ProviderProfile> get profiles =>
      const [ProviderProfile(name: 'Default')];
  @override
  ProviderProfile? activeProfile = const ProviderProfile(name: 'Default');

  List<File> get _hostsFiles {
    if (!HomePaths.supportsLocalFileScanning) return const [];
    final home = HomePaths.home;
    if (home == null) return const [];
    return [
      File(p.join(home, '.config', 'github-copilot', 'hosts.json')),
      File(p.join(home, 'AppData', 'Local', 'github-copilot', 'hosts.json')),
      File(p.join(home, 'Library', 'Application Support', 'GitHub Copilot',
          'hosts.json')),
    ];
  }

  @override
  Future<bool> isAvailable() async {
    for (final f in _hostsFiles) {
      if (await f.exists()) return true;
    }
    return false;
  }

  @override
  Future<ProviderResult> probe() async {
    return ProviderResult(
      identifier: id,
      displayName: displayName,
      category: category,
      profile: activeProfile?.name ?? 'Default',
      windows: const [],
      today: DailyUsage.zero,
      burnRate: null,
      dailyHeatmap: const [],
      models: const [],
      source: DataSource.local,
      freshness: DateTime.now(),
      warnings: [
        ProviderWarning(
          level: ProviderWarningLevel.info,
          message:
              'Copilot does not publish a local usage file. Open the GitHub Copilot dashboard for live numbers.',
        ),
      ],
    );
  }
}
