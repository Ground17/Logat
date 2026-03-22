import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommendation_settings.dart';
import '../providers/diary_providers.dart';
import 'diary_notification_settings_screen.dart';

class DiarySettingsScreen extends ConsumerWidget {
  const DiarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recommendationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diary Settings')),
      body: ListView(
        children: [
          // ── AI 추천 섹션 ─────────────────────────────────────────────
          _SectionHeader(title: 'AI Diary Recommendations'),
          SwitchListTile(
            title: const Text('Enable AI Recommendations'),
            subtitle: const Text(
                'AI suggests diary topics based on recent photos, frequent locations, and on-this-day memories'),
            value: settings.enabled,
            onChanged: (v) => _update(ref, settings.copyWith(enabled: v)),
          ),
          if (settings.enabled) ...[
            ListTile(
              title: const Text('AI Model'),
              subtitle: Text(settings.model.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickModel(context, ref, settings),
            ),
            ListTile(
              title: const Text('Format'),
              subtitle: Text(settings.format.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickFormat(context, ref, settings),
            ),
            ListTile(
              title: const Text('Style Instruction'),
              subtitle: Text(
                settings.promptStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editPromptStyle(context, ref, settings),
            ),
          ],

          const Divider(),

          // ── Notification settings ──────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          ListTile(
            title: const Text('Notification Settings'),
            subtitle: const Text(
                'On This Day reminders, periodic reminders, AI content'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const DiaryNotificationSettingsScreen()),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, RecommendationSettings settings) {
    ref.read(recommendationSettingsProvider.notifier).update(settings);
  }

  Future<void> _pickModel(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final result = await showDialog<RecommendationModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select AI Model'),
        children: RecommendationModel.values
            .map(
              (m) => ListTile(
                title: Text(m.displayName),
                leading: Icon(
                  m == settings.model
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: m == settings.model
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                onTap: () => Navigator.pop(ctx, m),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) _update(ref, settings.copyWith(model: result));
  }

  Future<void> _pickFormat(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final result = await showDialog<RecommendationFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Format'),
        children: RecommendationFormat.values
            .map(
              (f) => ListTile(
                title: Text(f.displayName),
                subtitle: Text(f.instruction),
                leading: Icon(
                  f == settings.format
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: f == settings.format
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                onTap: () => Navigator.pop(ctx, f),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) _update(ref, settings.copyWith(format: result));
  }

  Future<void> _editPromptStyle(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final ctrl = TextEditingController(text: settings.promptStyle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Style Instruction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Write a style instruction to pass directly to the AI.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'e.g. "In a warm and emotional tone", "Short and witty", "In a poetic style"',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black45),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter style instruction...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      _update(ref, settings.copyWith(promptStyle: result.trim()));
    }
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
