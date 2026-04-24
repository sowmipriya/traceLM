import '../models/models.dart';

/// Contract every usage source must honor. Keeps traceLM open to Claude Code,
/// Codex, Cursor, Copilot, custom internal APIs — anything that can report
/// tokens/requests.
abstract class UsageProvider {
  String get identifier;
  String get displayName;
  ProviderCategory get category;

  bool get isEnabled;
  set isEnabled(bool value);

  List<ProviderProfile> get profiles;
  ProviderProfile? get activeProfile;
  set activeProfile(ProviderProfile? profile);

  Future<bool> isAvailable();

  /// Produce a complete snapshot for a single provider, including windows,
  /// burn rate, today's usage, model breakdown and warnings.
  Future<ProviderResult> probe();

  /// Optional — expose raw sessions for UIs that want to chart history.
  Future<List<RawSession>> sessions({required DateTime since}) async => const [];
}
