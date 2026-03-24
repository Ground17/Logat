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
      appBar: AppBar(title: const Text('Loop 알고리즘 설정')),
      body: ListView(
        children: [
          // ── 가중치 섹션 ──────────────────────────────────────────────
          _SectionHeader(title: '노출 가중치'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '가중치가 높을수록 Loop에서 더 자주 먼저 나타납니다.\n'
              '기본 가중치는 모든 게시물에 적용되는 최소값입니다.',
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
            label: '기본 가중치',
            description: '모든 게시물의 기본 노출 확률',
            value: s.baseWeight,
            min: 1,
            max: 10,
            onChanged: (v) => update(s.copyWith(baseWeight: v)),
          ),
          _WeightTile(
            icon: Icons.favorite_outline,
            label: '즐겨찾기 가중치',
            description: '즐겨찾기한 게시물에 추가되는 가중치',
            value: s.favoriteWeight,
            onChanged: (v) => update(s.copyWith(favoriteWeight: v)),
          ),
          _WeightTile(
            icon: Icons.history,
            label: 'N년 전 오늘 / N×100일 가중치',
            description: '오늘과 날짜가 같거나 N×100일인 게시물에 추가',
            value: s.onThisDayWeight,
            onChanged: (v) => update(s.copyWith(onThisDayWeight: v)),
          ),
          _WeightTile(
            icon: Icons.schedule_outlined,
            label: '최근 30일 가중치',
            description: '최근 30일 이내 게시물에 추가되는 가중치',
            value: s.recentWeight,
            onChanged: (v) => update(s.copyWith(recentWeight: v)),
          ),
          const Divider(),

          // ── 조회수 섹션 ───────────────────────────────────────────────
          _SectionHeader(title: '조회수 반영 방식'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '게시물 상세 화면을 열 때마다 조회수가 1씩 증가합니다.',
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
