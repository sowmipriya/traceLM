import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.read(settingsServiceProvider);
    final registry = ref.watch(providerRegistryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _section(context, 'Quota alerts'),
          for (final threshold in const [75, 90, 95, 100])
            SwitchListTile(
              title: Text('Notify at $threshold%'),
              value: settings.isThresholdEnabled(threshold),
              onChanged: (v) async {
                await settings.setThreshold(threshold, v);
                setState(() {});
              },
            ),
          SwitchListTile(
            title: const Text('Quiet hours (no notifications overnight)'),
            value: settings.quietHoursEnabled,
            onChanged: (v) async {
              await settings.setQuietHoursEnabled(v);
              setState(() {});
            },
          ),
          if (settings.quietHoursEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _HourPicker(
                      label: 'From',
                      value: settings.quietStartHour,
                      onChanged: (v) async {
                        await settings.setQuietStartHour(v);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HourPicker(
                      label: 'To',
                      value: settings.quietEndHour,
                      onChanged: (v) async {
                        await settings.setQuietEndHour(v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Play sound with notifications'),
            value: settings.notificationSound,
            onChanged: (v) async {
              await settings.setNotificationSound(v);
              setState(() {});
            },
          ),
          _section(context, 'Sources'),
          for (final provider in registry.providers)
            SwitchListTile(
              title: Text(provider.displayName),
              subtitle: Text(provider.category.title),
              value: provider.isEnabled,
              onChanged: (v) async {
                await registry.setEnabled(id: provider.identifier, enabled: v);
                ref.read(usageAggregatorProvider).syncEnabledProviders();
                setState(() {});
              },
            ),
          _section(context, 'API keys'),
          _ApiKeyField(
            label: 'OpenAI API key (enables live usage)',
            keyName: 'openai.apiKey',
          ),
          _ApiKeyField(
            label: 'Cursor export path (.jsonl)',
            keyName: 'cursor.exportPath',
          ),
          _section(context, 'Advanced'),
          SwitchListTile(
            title: const Text('Export statusline file (~/.tracelm/usage.json)'),
            value: settings.statuslineExportEnabled,
            onChanged: (v) async {
              await settings.setStatuslineExportEnabled(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(BuildContext ctx, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(label,
            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w600)),
      );
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: List.generate(
              24,
              (h) => DropdownMenuItem(
                    value: h,
                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                  )),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ApiKeyField extends ConsumerStatefulWidget {
  const _ApiKeyField({required this.label, required this.keyName});
  final String label;
  final String keyName;

  @override
  ConsumerState<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends ConsumerState<_ApiKeyField> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(settingsServiceProvider)
        .secret(widget.keyName);
    _controller = TextEditingController(text: existing ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _controller,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: () async {
                  await ref
                      .read(settingsServiceProvider)
                      .setSecret(widget.keyName, _controller.text.trim());
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
