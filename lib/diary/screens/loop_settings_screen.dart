import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/loop_algorithm_settings.dart';
import '../providers/diary_providers.dart';

class LoopSettingsScreen extends ConsumerWidget {
  const LoopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(loopAlgorithmSettingsProvider);
    final notifier = ref.read(loopAlgorithmSettingsProvider.notifier);

    void update(LoopAlgorithmSettings next) {
      notifier.update(next);
      ref.invalidate(loopItemsProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Loop Algorithm')),
      body: ListView(
        children: [
          // ── Weight section ────────────────────────────────────────────
          _SectionHeader(title: 'Exposure Weights'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Higher weights appear more frequently in Loop.\n'
              'Base weight is the minimum applied to all posts.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          _WeightTile(
            icon: Icons.tune_outlined,
            label: 'Base Weight',
            description: 'Minimum exposure probability for all posts',
            value: s.baseWeight,
            min: 1,
            max: 10,
            onChanged: (v) => update(s.copyWith(baseWeight: v)),
          ),
          _WeightTile(
            icon: Icons.favorite_outline,
            label: 'Favorites Weight',
            description: 'Extra weight added for favorited posts',
            value: s.favoriteWeight,
            onChanged: (v) => update(s.copyWith(favoriteWeight: v)),
          ),
          _WeightTile(
            icon: Icons.history,
            label: 'On This Day / N×100 Day Weight',
            description: 'Extra weight for anniversary and milestone posts',
            value: s.onThisDayWeight,
            onChanged: (v) => update(s.copyWith(onThisDayWeight: v)),
          ),
          _WeightTile(
            icon: Icons.schedule_outlined,
            label: 'Recent 30 Days Weight',
            description: 'Extra weight for posts within the last 30 days',
            value: s.recentWeight,
            onChanged: (v) => update(s.copyWith(recentWeight: v)),
          ),
          const Divider(),

          // ── View count section ────────────────────────────────────────
          _SectionHeader(title: 'View Count Mode'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'View count increases by 1 each time you open a post.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          for (final mode in LoopViewCountMode.values)
            ListTile(
              leading: Icon(
                _modeIcon(mode),
                color: s.viewCountMode == mode
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(mode.label),
              subtitle: Text(mode.description),
              trailing: s.viewCountMode == mode
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => update(s.copyWith(viewCountMode: mode)),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  IconData _modeIcon(LoopViewCountMode mode) {
    switch (mode) {
      case LoopViewCountMode.ignore:
        return Icons.block_outlined;
      case LoopViewCountMode.boostUnwatched:
        return Icons.fiber_new_outlined;
      case LoopViewCountMode.boostWatched:
        return Icons.trending_up_outlined;
    }
  }
}

// ─── Weight slider tile ────────────────────────────────────────────────────

class _WeightTile extends StatelessWidget {
  const _WeightTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 10,
  });

  final IconData icon;
  final String label;
  final String description;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            )),
                  ],
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$value',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
