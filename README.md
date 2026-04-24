# TraceLM

TraceLM is an open-source desktop app that watches your LLM usage across the
tools you already use and nudges you before you blow through a quota or
leave a session idling. It runs on **Windows**, **Ubuntu / Linux**,
**macOS**, and **iOS** from a single Flutter codebase.

## What it does

- **Tracks usage locally.** Reads `~/.claude/**`, `~/.codex/**`, Gemini CLI
  logs, and (optionally) Cursor exports. No account required.
- **Live API usage.** Paste an OpenAI API key to pull the official usage
  numbers.
- **Burn rate + forecasts.** 30-minute rolling burn rate, plus a forecast
  status (`on track` / `tight` / `will exceed`) with time-to-depletion.
- **Quota alerts.** Native notifications when a provider crosses 75 / 90 /
  95 / 100%. Configurable per-threshold with quiet-hours support.
- **Poor-usage nudges.** Notifies you when a session is active but
  burn-rate is near zero — reclaim quota you're not using.
- **Service health.** Polls each vendor's public statuspage so you know
  whether the problem is your end or theirs.
- **Statusline export.** Writes `~/.tracelm/usage.json` atomically so
  tmux / shell prompts / Claude Code `statusLine` can pick it up.

## Architecture at a glance

```
lib/
├── main.dart                   entry + window chrome
├── state/providers.dart        Riverpod wiring (single source of DI)
├── core/
│   ├── models/                 pure Dart domain models (no Flutter)
│   ├── services/               calculators, aggregator, polling, notifications
│   ├── providers/              UsageProvider interface + registry
│   │                           ClaudeCodeProvider, CodexProvider, CursorProvider,
│   │                           GeminiProvider, CopilotProvider, OpenAiApiProvider
│   └── utils/                  JSONL reader, time helpers, cross-platform home paths
└── ui/
    ├── app.dart                Material theme
    ├── dashboard_page.dart     provider cards, heatmap, summary
    ├── provider_detail_page.dart
    ├── settings_page.dart      thresholds, quiet hours, sources, API keys
    └── widgets/                heatmap, window progress bar
```

All non-UI code lives under `lib/core`. The UI never constructs services
directly — everything flows through `lib/state/providers.dart`, so swapping
providers or mocking services in tests is trivial.

### Adding a new LLM provider

1. Create `lib/core/providers/<name>_provider.dart` implementing
   `UsageProvider`.
2. Register it in `ProviderRegistry` (`lib/core/providers/provider_registry.dart`).
3. (Optional) Add a vendor status entry in
   `lib/core/services/service_status_monitor.dart` so health dots appear on
   the dashboard card.

## First-time setup

This repo ships the Flutter `lib/`, `assets/`, `test/`, and `pubspec.yaml` —
the platform-specific scaffolds (`windows/`, `linux/`, `macos/`, `ios/`) are
generated on demand so the repo stays small. Run once after cloning:

```bash
flutter create --platforms=windows,linux,macos,ios --org com.tracelm .
flutter pub get
```

## Run

```bash
# macOS
flutter run -d macos

# Linux / Ubuntu
flutter run -d linux

# Windows (PowerShell)
flutter run -d windows

# iOS simulator
flutter run -d ios
```

### First-launch notes

- **macOS**: the app requests Notifications permission on first run.
- **Linux**: install `libnotify` (`sudo apt install libnotify-bin`) for
  popup notifications.
- **Windows**: notifications use the native toast pipeline — the GUID in
  `lib/core/services/notification_service.dart` is stable, change it if you
  fork the app.
- **iOS**: the app reads no filesystem data (iOS sandbox). Use the OpenAI
  API provider or import logs into the app's Documents folder.

## Build release artifacts

```bash
flutter build macos --release
flutter build linux --release
flutter build windows --release
flutter build ipa     --release   # requires an Apple developer account
```

## Tests

```bash
flutter test                       # run the full suite
flutter test test/forecast_calculator_test.dart   # single file
```

## Open-source dependencies

All dependencies are permissively licensed (BSD / MIT / Apache 2.0):

| Package | Purpose | License |
|---|---|---|
| `flutter_riverpod` | DI + state | Apache 2.0 |
| `shared_preferences` | settings storage | BSD-3 |
| `path_provider` / `path` | cross-platform paths | BSD-3 |
| `http` | status page polling, OpenAI API | BSD-3 |
| `intl` | date formatting | BSD-3 |
| `flutter_local_notifications` | quota alerts on every platform | BSD-3 |
| `window_manager` | desktop window chrome | MIT |
| `tray_manager` | system-tray icon hook | MIT |
| `launch_at_startup` | optional launch-at-login | MIT |
| `url_launcher` | open vendor status pages | BSD-3 |
| `package_info_plus` | version display in settings | BSD-3 |

## Privacy

All tokenized session data stays on your machine. The only network calls
traceLM makes by default are:

- Each vendor's **public** `status.<vendor>.com/api/v2/status.json`
  summary (no auth, no identifiers).
- **Only if** you've pasted an API key, the vendor's own usage API (e.g.
  `api.openai.com/v1/usage`) with your key.

No telemetry, no account, no cloud backend.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
