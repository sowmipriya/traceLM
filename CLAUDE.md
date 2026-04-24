# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# One-time: scaffold the platform folders Flutter needs (not committed)
flutter create --platforms=windows,linux,macos,ios --org com.tracelm .
flutter pub get

# Run
flutter run -d macos | linux | windows | ios

# Tests
flutter test
flutter test test/forecast_calculator_test.dart    # single file
flutter test --name 'flags will-exceed'            # single test

# Lint / analyze
flutter analyze

# Release builds
flutter build macos --release
flutter build linux --release
flutter build windows --release
flutter build ipa --release
```

## Architecture

TraceLM is a Flutter cross-platform desktop app that monitors LLM usage
across providers and fires native notifications on quota threshold
crossings. The Swift reference implementation lives in
`cirrondly-desk-community-master/` — treat it as spec, not source of
truth. Our Dart code restructures its architecture.

### Layers

- **`lib/core/models/`** — pure Dart domain. No Flutter imports. Key
  types: `UsageSnapshot` (the thing the UI reads), `ProviderResult`
  (one provider's full state), `UsageWindow` (a single quota window —
  session / weekly / monthly / custom), `RawSession`, `BurnRate`,
  `Forecast`. `WindowKind` is a sealed hierarchy; matching is done with
  Dart's `switch` on its subclasses, not on an enum.

- **`lib/core/services/`** — stateless calculators and stateful
  singletons.
  - `BurnRateCalculator` builds a `ProviderResult` from a list of
    `RawSession`s using 90th-percentile rolling windows to infer limits
    when the provider doesn't expose one. `ForecastCalculator` extrapolates
    to window end.
  - `UsageAggregator` is a `ChangeNotifier` that fan-outs to every enabled
    provider in parallel via `Future.wait`. Providers that throw are
    downgraded to `ProviderResult.unavailable` instead of blowing up the
    snapshot.
  - `PollingManager` is the clock — adaptive intervals (foreground 30s /
    background 5min / battery-saver 15min) and fires both the notification
    service and statusline exporter after each snapshot.
  - `TraceLMNotificationService` dedupes alerts per `(provider, window,
    threshold, resetAt)` so one crossing doesn't spam across polls.
  - `SettingsService` is SharedPreferences — **plaintext on disk**. For
    API keys in production, swap to `flutter_secure_storage`.

- **`lib/core/providers/`** — pluggable `UsageProvider` implementations.
  Adding a provider:
  1. Implement `UsageProvider` in a new file.
  2. Register in `ProviderRegistry` (`provider_registry.dart`).
  3. Optionally add a status-page entry in `ServiceStatusMonitor` so the
     dashboard shows a health dot.
  - Local-file providers call `HomePaths.supportsLocalFileScanning`
    first — **iOS is sandboxed and must return `false` from
    `isAvailable()`** rather than silently scanning an inaccessible path.
  - JSONL parsing goes through `JsonlReader` which tolerates malformed
    lines (JSONL producers often flush partial writes).

- **`lib/state/providers.dart`** — the only place that wires the core
  layer to Riverpod. The `SettingsService` is injected via
  `overrideWithValue` in `main.dart` because it needs `await` to
  construct. Tests override this same provider.

- **`lib/ui/`** — Flutter widgets. Screens only read/write state through
  Riverpod providers — they never instantiate services directly.

### Flow of a snapshot

`PollingManager._refresh` → `UsageAggregator.refresh` → each
`UsageProvider.probe()` in parallel → `UsageSnapshot.build` computes the
worst-window summary → notification service checks thresholds → exporter
writes `~/.tracelm/usage.json`. The UI reads `UsageAggregator.snapshot`
via `ref.watch(usageAggregatorProvider)`.

### Things that are intentionally NOT ported from the Swift source

- **Native Keychain access.** Swift used `KeychainService` for OAuth
  tokens; traceLM punts API-key storage to SharedPreferences. Drop-in
  `flutter_secure_storage` if you need vault-backed storage.
- **Live OAuth refresh for Codex / Claude subscription.** Both flows
  depend on OS-specific keychains — we keep the local JSONL path only.
- **SQLite reader for Codex `logs_2.sqlite`.** The Dart `sqflite_common_ffi`
  path works on desktop but not iOS — omitted until needed.

### Platform notes that affect code

- Only macOS / Linux / Windows scan `$HOME` for provider footprints
  (`HomePaths.supportsLocalFileScanning`). On iOS every local provider
  returns `isAvailable() == false`, and only `OpenAiApiProvider` works
  meaningfully.
- `window_manager.ensureInitialized()` is guarded by a desktop-only
  platform check in `main.dart` — calling it on iOS throws.
- Notification channel IDs are declared in `TraceLMNotificationService`;
  the Windows toast path requires the app `guid` to be stable across
  builds (changing it invalidates delivered notifications).

### Tests

Tests run against the pure-Dart `core` layer; no widget tests yet.
`forecast_calculator_test.dart` is the canonical example of pinning
deterministic behaviour by passing `now:` explicitly.
