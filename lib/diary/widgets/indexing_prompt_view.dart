import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../providers/diary_providers.dart';

/// Full-screen prompt shown when no photos have been indexed yet.
/// Displays progress while indexing is running, and a Start button otherwise.
class IndexingPromptView extends ConsumerStatefulWidget {
  const IndexingPromptView({super.key});

  @override
  ConsumerState<IndexingPromptView> createState() => _IndexingPromptViewState();
}

class _IndexingPromptViewState extends ConsumerState<IndexingPromptView> {
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

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto Background Indexing'),
        content: const Text(
            'Automatically index photos every day?\nYou can change this anytime in Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (enable == true) {
      final settings = ref.read(recommendationSettingsProvider);
      ref
          .read(recommendationSettingsProvider.notifier)
          .update(settings.copyWith(backgroundIndexingEnabled: true));
      Workmanager().registerPeriodicTask(
        'bg_indexing',
        'bgIndexTask',
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indexing = ref.watch(indexingControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Relive Your Memories',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Index your photo library\nto turn your photos into diary entries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            if (indexing.isRunning) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: indexing.fraction,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                indexing.message ?? 'Indexing...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _runIndex,
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Start Indexing'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
