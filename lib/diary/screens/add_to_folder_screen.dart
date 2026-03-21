import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/folder.dart';
import '../providers/diary_providers.dart';

class AddToFolderScreen extends ConsumerWidget {
  const AddToFolderScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _FolderPicker(
      eventId: eventId,
      parentId: null,
      breadcrumbs: const ['Select Folder'],
    );
  }
}

class _FolderPicker extends ConsumerWidget {
  const _FolderPicker({
    required this.eventId,
    required this.parentId,
    required this.breadcrumbs,
  });

  final String eventId;
  final String? parentId;
  final List<String> breadcrumbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(folderListProvider(parentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(breadcrumbs.last),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                breadcrumbs.join(' > '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ),
      body: foldersAsync.when(
        data: (folders) => folders.isEmpty
            ? const Center(child: Text('No folders yet.'))
            : ListView.builder(
                itemCount: folders.length,
                itemBuilder: (ctx, i) => _FolderTile(
                  folder: folders[i],
                  eventId: eventId,
                  breadcrumbs: breadcrumbs,
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({
    required this.folder,
    required this.eventId,
    required this.breadcrumbs,
  });

  final DiaryFolder folder;
  final String eventId;
  final List<String> breadcrumbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add to this folder',
            onPressed: () async {
              await ref
                  .read(folderRepositoryProvider)
                  .addRecord(folder.folderId, eventId);
              ref.invalidate(folderContentsProvider(folder.folderId));
              if (context.mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to "${folder.name}".')),
                );
              }
            },
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FolderPicker(
              eventId: eventId,
              parentId: folder.folderId,
              breadcrumbs: [...breadcrumbs, folder.name],
            ),
          ),
        );
      },
    );
  }
}
