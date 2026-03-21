import '../database/app_database.dart';
import '../models/event_summary.dart';
import '../models/folder.dart';

class FolderRepository {
  const FolderRepository(this._database);

  final AppDatabase _database;

  Future<List<DiaryFolder>> listFolders({String? parentId}) {
    return _database.queryFolders(parentId: parentId);
  }

  Future<void> createFolder({required String name, String? parentId}) {
    final folderId =
        '${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}';
    return _database.insertFolder(
      folderId: folderId,
      name: name,
      parentId: parentId,
    );
  }

  Future<void> renameFolder(String folderId, String newName) {
    return _database.renameFolder(folderId, newName);
  }

  Future<void> deleteFolder(String folderId) {
    return _database.deleteFolder(folderId);
  }

  Future<void> addRecord(String folderId, String eventId) {
    return _database.addEventToFolder(folderId, eventId);
  }

  Future<void> removeRecord(String folderId, String eventId) {
    return _database.removeEventFromFolder(folderId, eventId);
  }

  Future<List<EventSummary>> folderContents(String folderId) {
    return _database.queryFolderContents(folderId);
  }

  Future<void> toggleFolderFavorite(String folderId, bool value) {
    return _database.updateFolderFavorite(folderId, value);
  }

  Future<int> computeDepth(String folderId) {
    return _database.computeFolderDepth(folderId);
  }
}
