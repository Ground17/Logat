import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../models/recommendation_settings.dart';
import '../providers/diary_providers.dart';
import 'diary_notification_settings_screen.dart';
import 'loop_settings_screen.dart';
import 'tab_order_settings_screen.dart';

class DiarySettingsScreen extends ConsumerStatefulWidget {
  const DiarySettingsScreen({super.key});

  @override
  ConsumerState<DiarySettingsScreen> createState() =>
      _DiarySettingsScreenState();
}

class _DiarySettingsScreenState extends ConsumerState<DiarySettingsScreen> {
  void _update(RecommendationSettings settings) {
    ref.read(recommendationSettingsProvider.notifier).update(settings);
  }

  Future<void> _runIndex() async {
    await ref
        .read(indexingControllerProvider.notifier)
        .requestPermissionAndIndex();
    ref.invalidate(permissionStateProvider);
    ref.invalidate(indexedAssetCountProvider);
    ref.invalidate(dailyStatsProvider);
    ref.invalidate(diaryCandidatesProvider);
    ref.invalidate(locationClustersProvider);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(tagSummariesProvider);
    ref.invalidate(onThisDayProvider);
    ref.invalidate(yearlyDailyStatsProvider);
    ref.invalidate(filteredJournalEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(recommendationSettingsProvider);
    final indexing = ref.watch(indexingControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Diary Settings')),
      body: ListView(
        children: [
          // ── 사진 인덱싱 섹션 ───────────────────────────────────────────
          _SectionHeader(title: '사진 인덱싱'),
          SwitchListTile(
            title: const Text('백그라운드 자동 인덱싱'),
            subtitle: const Text('하루에 한 번 자동으로 사진을 인덱싱합니다'),
            value: settings.backgroundIndexingEnabled,
            onChanged: (v) {
              _update(settings.copyWith(backgroundIndexingEnabled: v));
              if (v) {
                Workmanager().registerPeriodicTask(
                  'bg_indexing',
                  'bgIndexTask',
                  frequency: const Duration(hours: 24),
                  existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
                );
              } else {
                Workmanager().cancelByUniqueName('bg_indexing');
              }
            },
          ),
          if (indexing.isRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: indexing.fraction,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    indexing.message ?? '인덱싱 중...',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            ListTile(
              title: const Text('지금 인덱싱'),
              subtitle: const Text('사진 라이브러리를 지금 바로 인덱싱합니다'),
              trailing: const Icon(Icons.bolt_outlined),
              onTap: _runIndex,
            ),
          const Divider(),

          // ── AI 추천 섹션 ─────────────────────────────────────────────
          _SectionHeader(title: 'AI Diary Recommendations'),
          SwitchListTile(
            title: const Text('Enable AI Recommendations'),
            subtitle: const Text(
                'AI suggests diary topics based on recent photos, frequent locations, and on-this-day memories'),
            value: settings.enabled,
            onChanged: (v) => _update(settings.copyWith(enabled: v)),
          ),
          if (settings.enabled) ...[
            ListTile(
              title: const Text('AI Model'),
              subtitle: Text(settings.model.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickModel(context, settings),
            ),
            ListTile(
              title: const Text('Format'),
              subtitle: Text(settings.format.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickFormat(context, settings),
            ),
            ListTile(
              title: const Text('Style Instruction'),
              subtitle: Text(
                settings.promptStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editPromptStyle(context, settings),
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

          const Divider(),

          // ── 탭 순서 섹션 ─────────────────────────────────────────────
          _SectionHeader(title: '탭 순서'),
          ListTile(
            title: const Text('탭 순서 설정'),
            subtitle: const Text('하단 네비게이션 탭의 순서를 변경합니다'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TabOrderSettingsScreen()),
            ),
          ),

          const Divider(),

          // ── Loop 알고리즘 섹션 ────────────────────────────────────────
          _SectionHeader(title: 'Loop 알고리즘'),
          ListTile(
            title: const Text('Loop 노출 설정'),
            subtitle: const Text(
                '즐겨찾기, N년 전 오늘, 최근 게시물 가중치 및 조회수 반영 방식'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoopSettingsScreen()),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _pickModel(
    BuildContext context,
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
    if (result != null) _update(settings.copyWith(model: result));
  }

  Future<void> _pickFormat(
    BuildContext context,
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
    if (result != null) _update(settings.copyWith(format: result));
  }

  Future<void> _editPromptStyle(
    BuildContext context,
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
      _update(settings.copyWith(promptStyle: result.trim()));
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
