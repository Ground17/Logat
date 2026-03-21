import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/diary_providers.dart';

class TagSearchScreen extends ConsumerWidget {
  const TagSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags & Search')),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(
              child: Text('No event tags yet. Run indexing first.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => Chip(
                        label: Text('${tag.name} · ${tag.count}'),
                        avatar: CircleAvatar(
                          child: Text(tag.type.characters.first.toUpperCase()),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Ideas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...tags.take(8).map(
                            (tag) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(tag.name),
                              subtitle: Text(
                                '${tag.type} · confidence ${(tag.confidence * 100).toStringAsFixed(0)}%',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Tag load failed: $error')),
      ),
    );
  }
}
