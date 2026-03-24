import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/diary_providers.dart';

/// Tab labels, outline icons, and selected icon definitions (by logical tab ID)
const Map<int, String> kTabLabels = {
  0: 'Loop',
  1: 'List',
  2: 'Grid',
  3: 'Activity',
  4: 'Map',
};

const Map<int, IconData> kTabIcons = {
  0: Icons.loop_outlined,
  1: Icons.auto_stories_outlined,
  2: Icons.grid_view_outlined,
  3: Icons.bar_chart_outlined,
  4: Icons.map_outlined,
};

class TabOrderSettingsScreen extends ConsumerWidget {
  const TabOrderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(tabOrderProvider);
    final notifier = ref.read(tabOrderProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tab Order'),
        actions: [
          TextButton(
            onPressed: () async {
              await notifier.setOrder([0, 1, 2, 3, 4]);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Drag to reorder tabs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) async {
                final updated = List<int>.from(order);
                if (newIndex > oldIndex) newIndex--;
                updated.insert(newIndex, updated.removeAt(oldIndex));
                await notifier.setOrder(updated);
              },
              children: [
                for (final tabId in order)
                  ListTile(
                    key: ValueKey(tabId),
                    leading: Icon(kTabIcons[tabId]),
                    title: Text(kTabLabels[tabId] ?? ''),
                    trailing: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
