import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/event_summary.dart';
import '../models/folder.dart';
import '../providers/diary_providers.dart';
import 'event_detail_screen.dart';
import 'folder_journal_screen.dart';

class FolderBrowserScreen extends ConsumerStatefulWidget {
  const FolderBrowserScreen({
    super.key,
    this.parentFolderId,
    this.breadcrumbs = const ['Folders'],
    this.isEmbedded = false,
  });

  final String? parentFolderId;
  final List<String> breadcrumbs;
  /// When true (used as a tab), the inner FAB is suppressed so the
  /// parent Scaffold can provide its own FAB with correct positioning.
  final bool isEmbedded;

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  Future<void> _createFolder() async {
    final name = await _askName(context, 'New Folder');
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(folderRepositoryProvider).createFolder(
            name: name,
            parentId: widget.parentFolderId,
          );
      ref.invalidate(folderListProvider(widget.parentFolderId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _renameFolder(DiaryFolder folder) async {
    final name = await _askName(context, 'Rename', initial: folder.name);
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).renameFolder(folder.folderId, name);
    ref.invalidate(folderListProvider(widget.parentFolderId));
  }

  Future<void> _deleteFolder(DiaryFolder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Delete "${folder.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(folderRepositoryProvider).deleteFolder(folder.folderId);
    ref.invalidate(folderListProvider(widget.parentFolderId));
  }

  Future<String?> _askName(BuildContext ctx, String label,
      {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dlgCtx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync =
        ref.watch(folderListProvider(widget.parentFolderId));
    final contentsAsync = widget.parentFolderId != null
        ? ref.watch(folderContentsProvider(widget.parentFolderId!))
        : const AsyncValue<List<EventSummary>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.breadcrumbs.last),
        actions: [
          if (widget.parentFolderId != null)
            IconButton(
              icon: const Icon(Icons.auto_stories_outlined),
              tooltip: 'View as journal',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FolderJournalScreen(
                    folderId: widget.parentFolderId!,
                    folderName: widget.breadcrumbs.last,
                  ),
                ),
              ),
            ),
        ],
        bottom: widget.breadcrumbs.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      widget.breadcrumbs.join(' > '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: widget.isEmbedded
          ? null
          : FloatingActionButton(
              heroTag: 'createFolder',
              onPressed: _createFolder,
              tooltip: 'New folder',
              child: const Icon(Icons.create_new_folder_outlined),
            ),
      body: CustomScrollView(
        slivers: [
          foldersAsync.when(
            data: (folders) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _FolderListTile(
                  folder: folders[i],
                  breadcrumbs: widget.breadcrumbs,
                  onRename: () => _renameFolder(folders[i]),
                  onDelete: () => _deleteFolder(folders[i]),
                  onToggleFavorite: () async {
                    await ref
                        .read(folderRepositoryProvider)
                        .toggleFolderFavorite(
                            folders[i].folderId, !folders[i].isFavorite);
                    ref.invalidate(folderListProvider(widget.parentFolderId));
                  },
                ),
                childCount: folders.length,
              ),
            ),
            loading: () => const SliverToBoxAdapter(
                child: LinearProgressIndicator()),
            error: (e, _) =>
                SliverToBoxAdapter(child: Text('Failed to load folders: $e')),
          ),
          if (widget.parentFolderId != null)
            contentsAsync.when(
              data: (events) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RecordListTile(
                    event: events[i],
                    folderId: widget.parentFolderId!,
                    onRemove: () async {
                      await ref
                          .read(folderRepositoryProvider)
                          .removeRecord(
                              widget.parentFolderId!, events[i].eventId);
                      ref.invalidate(
                          folderContentsProvider(widget.parentFolderId!));
                    },
                  ),
                  childCount: events.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Text('Failed to load records: $e')),
            ),
        ],
      ),
    );
  }
}

class _FolderListTile extends ConsumerWidget {
  const _FolderListTile({
    required this.folder,
    required this.breadcrumbs,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final DiaryFolder folder;
  final List<String> breadcrumbs;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      FutureProvider.autoDispose((r) =>
          r.watch(appDatabaseProvider).countFolderItems(folder.folderId)),
    );
    final countLabel = countAsync.maybeWhen(
      data: (n) => '$n items',
      orElse: () => '',
    );
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name),
      subtitle: countLabel.isNotEmpty ? Text(countLabel) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              folder.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: folder.isFavorite ? Colors.red : null,
            ),
            onPressed: onToggleFavorite,
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderBrowserScreen(
            parentFolderId: folder.folderId,
            breadcrumbs: [...breadcrumbs, folder.name],
          ),
        ),
      ),
      onLongPress: () => _showContextMenu(context),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                onRename();
              },
            ),
            ListTile(
              leading: Icon(
                folder.isFavorite ? Icons.favorite_border : Icons.favorite,
              ),
              title: Text(folder.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () {
                Navigator.pop(ctx);
                onToggleFavorite();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordListTile extends StatelessWidget {
  const _RecordListTile({
    required this.event,
    required this.folderId,
    required this.onRemove,
  });

  final EventSummary event;
  final String folderId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy.M.d HH:mm');
    return ListTile(
      leading: const Icon(Icons.photo_outlined),
      title: Text(event.title ?? '${event.assetCount} photos'),
      subtitle: Text(formatter.format(event.startAt.toLocal())),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
            title: const Text('Remove from folder',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              onRemove();
            },
          ),
        ),
      ),
    );
  }
}

