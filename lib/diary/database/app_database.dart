import 'dart:math' as math;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/daily_stats.dart';
import '../models/event_summary.dart';
import '../models/folder.dart';
import '../models/heuristic_tag.dart';
import '../models/indexing_state.dart';
import '../models/location_cluster.dart';
import '../models/location_filter.dart';
import '../models/photo_asset_metadata.dart';
import '../models/tag_summary.dart';

const String diarySchemaSql = '''
CREATE TABLE assets (
  asset_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  latitude REAL,
  longitude REAL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  media_type TEXT NOT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  album_id TEXT,
  album_name TEXT,
  indexed_at INTEGER NOT NULL,
  analyzed_at INTEGER,
  content_hash TEXT,
  is_locally_available INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX idx_assets_created_at ON assets(created_at);
CREATE INDEX idx_assets_location ON assets(latitude, longitude);
CREATE INDEX idx_assets_album_created_at ON assets(album_id, created_at);
CREATE TABLE indexing_state (
  singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
  status TEXT NOT NULL,
  last_completed_created_at INTEGER,
  last_completed_asset_id TEXT,
  resume_page INTEGER NOT NULL DEFAULT 0,
  scanned_count INTEGER NOT NULL DEFAULT 0,
  inserted_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER,
  completed_at INTEGER,
  updated_at INTEGER NOT NULL
);
CREATE TABLE events (
  event_id TEXT PRIMARY KEY,
  start_at INTEGER NOT NULL,
  end_at INTEGER NOT NULL,
  latitude REAL,
  longitude REAL,
  asset_count INTEGER NOT NULL,
  representative_asset_id TEXT NOT NULL,
  quality_score REAL NOT NULL,
  is_moving INTEGER NOT NULL DEFAULT 0,
  is_manual INTEGER NOT NULL DEFAULT 0,
  title TEXT,
  user_memo TEXT,
  is_favorite INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_events_start_at ON events(start_at);
CREATE INDEX idx_events_location ON events(latitude, longitude);
CREATE TABLE event_assets (
  event_id TEXT NOT NULL,
  asset_id TEXT NOT NULL,
  PRIMARY KEY (event_id, asset_id)
);
CREATE INDEX idx_event_assets_asset_id ON event_assets(asset_id);
CREATE TABLE tags (
  tag_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  confidence REAL NOT NULL
);
CREATE TABLE asset_tags (
  asset_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (asset_id, tag_id)
);
CREATE TABLE event_tags (
  event_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (event_id, tag_id)
);
CREATE TABLE folders (
  folder_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id TEXT,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES folders(folder_id) ON DELETE CASCADE
);
CREATE INDEX idx_folders_parent_id ON folders(parent_id);
CREATE TABLE folder_items (
  folder_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  PRIMARY KEY (folder_id, event_id),
  FOREIGN KEY (folder_id) REFERENCES folders(folder_id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);
INSERT INTO indexing_state (
  singleton_id,
  status,
  resume_page,
  scanned_count,
  inserted_count,
  skipped_count,
  updated_at
) VALUES (1, 'idle', 0, 0, 0, 0, strftime('%s', 'now') * 1000);
''';

class FolderDepthException implements Exception {
  const FolderDepthException();

  @override
  String toString() => '폴더 깊이는 최대 5단계까지 허용됩니다.';
}

class PersistedEventRecord {
  const PersistedEventRecord({
    required this.eventId,
    required this.startAt,
    required this.endAt,
    required this.assetCount,
    required this.representativeAssetId,
    required this.qualityScore,
    required this.isMoving,
    required this.assetIds,
    required this.tags,
    this.latitude,
    this.longitude,
  });

  final String eventId;
  final DateTime startAt;
  final DateTime endAt;
  final double? latitude;
  final double? longitude;
  final int assetCount;
  final String representativeAssetId;
  final double qualityScore;
  final bool isMoving;
  final List<String> assetIds;
  final List<HeuristicTag> tags;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'diary_mvp.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
        onCreate: (migrator) async {
          for (final statement in diarySchemaSql
              .split(';')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)) {
            await customStatement('$statement;');
          }
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await customStatement(
              'ALTER TABLE events ADD COLUMN is_manual INTEGER NOT NULL DEFAULT 0;',
            );
            await customStatement(
              'ALTER TABLE events ADD COLUMN title TEXT;',
            );
            await customStatement(
              'ALTER TABLE events ADD COLUMN user_memo TEXT;',
            );
            await customStatement(
              'ALTER TABLE events ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;',
            );
          }
          if (from < 3) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS folders (
                folder_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                parent_id TEXT,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (parent_id) REFERENCES folders(folder_id) ON DELETE CASCADE
              );
            ''');
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_folders_parent_id ON folders(parent_id);',
            );
            await customStatement('''
              CREATE TABLE IF NOT EXISTS folder_items (
                folder_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                PRIMARY KEY (folder_id, event_id),
                FOREIGN KEY (folder_id) REFERENCES folders(folder_id) ON DELETE CASCADE,
                FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
              );
            ''');
          }
          if (from < 4) {
            await customStatement(
              'ALTER TABLE events ADD COLUMN color INTEGER;',
            );
          }
          if (from < 5) {
            await customStatement(
              'ALTER TABLE events ADD COLUMN custom_address TEXT;',
            );
          }
        },
      );

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  Future<void> upsertPhotoAssets(List<PhotoAssetMetadata> assets) async {
    if (assets.isEmpty) {
      return;
    }

    final indexedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await transaction(() async {
      await batch((batch) {
        for (final asset in assets) {
          batch.customStatement(
            '''
            INSERT INTO assets (
              asset_id,
              created_at,
              modified_at,
              latitude,
              longitude,
              width,
              height,
              duration_seconds,
              media_type,
              is_favorite,
              album_id,
              album_name,
              indexed_at,
              analyzed_at,
              content_hash,
              is_locally_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(asset_id) DO UPDATE SET
              created_at = excluded.created_at,
              modified_at = excluded.modified_at,
              latitude = excluded.latitude,
              longitude = excluded.longitude,
              width = excluded.width,
              height = excluded.height,
              duration_seconds = excluded.duration_seconds,
              media_type = excluded.media_type,
              is_favorite = excluded.is_favorite,
              album_id = excluded.album_id,
              album_name = excluded.album_name,
              indexed_at = excluded.indexed_at,
              is_locally_available = excluded.is_locally_available
            ''',
            [
              asset.assetId,
              asset.createdAt.millisecondsSinceEpoch,
              asset.modifiedAt.millisecondsSinceEpoch,
              asset.latitude,
              asset.longitude,
              asset.width,
              asset.height,
              asset.durationSeconds,
              asset.mediaTypeName,
              asset.isFavorite ? 1 : 0,
              asset.bucketId,
              asset.bucketName,
              indexedAt,
              null,
              null,
              asset.isLocallyAvailable ? 1 : 0,
            ],
          );
        }
      });
    });
  }

  Future<List<Map<String, Object?>>> loadAssetsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await customSelect(
      '''
      SELECT *
      FROM assets
      WHERE created_at >= ? AND created_at < ?
      ORDER BY created_at ASC, asset_id ASC
      ''',
      variables: [
        Variable<int>(start.millisecondsSinceEpoch),
        Variable<int>(end.millisecondsSinceEpoch),
      ],
    ).get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> replaceEventsInRange({
    required DateTime start,
    required DateTime end,
    required List<PersistedEventRecord> events,
    required Map<String, List<String>> assetTags,
  }) async {
    await transaction(() async {
      final overlapping = await customSelect(
        '''
        SELECT event_id
        FROM events
        WHERE start_at < ? AND end_at >= ? AND is_manual = 0
        ''',
        variables: [
          Variable<int>(end.millisecondsSinceEpoch),
          Variable<int>(start.millisecondsSinceEpoch),
        ],
      ).get();
      final eventIds =
          overlapping.map((row) => row.read<String>('event_id')).toList();

      if (eventIds.isNotEmpty) {
        for (final eventId in eventIds) {
          await customStatement(
            'DELETE FROM event_assets WHERE event_id = ?',
            [eventId],
          );
          await customStatement(
            'DELETE FROM event_tags WHERE event_id = ?',
            [eventId],
          );
          await customStatement(
            'DELETE FROM events WHERE event_id = ?',
            [eventId],
          );
        }
      }

      await customStatement(
        '''
        DELETE FROM asset_tags
        WHERE asset_id IN (
          SELECT asset_id FROM assets WHERE created_at >= ? AND created_at < ?
        )
        ''',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );

      await batch((batch) {
        for (final entry in assetTags.entries) {
          for (final tagId in entry.value) {
            batch.customStatement(
              '''
              INSERT OR IGNORE INTO tags(tag_id, name, type, confidence)
              VALUES (?, ?, ?, ?)
              ''',
              _tagDefinition(tagId),
            );
            batch.customStatement(
              'INSERT OR IGNORE INTO asset_tags(asset_id, tag_id) VALUES (?, ?)',
              [entry.key, tagId],
            );
          }
        }

        for (final event in events) {
          batch.customStatement(
            '''
            INSERT INTO events (
              event_id,
              start_at,
              end_at,
              latitude,
              longitude,
              asset_count,
              representative_asset_id,
              quality_score,
              is_moving
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              event.eventId,
              event.startAt.millisecondsSinceEpoch,
              event.endAt.millisecondsSinceEpoch,
              event.latitude,
              event.longitude,
              event.assetCount,
              event.representativeAssetId,
              event.qualityScore,
              event.isMoving ? 1 : 0,
            ],
          );
          for (final assetId in event.assetIds) {
            batch.customStatement(
              'INSERT INTO event_assets(event_id, asset_id) VALUES (?, ?)',
              [event.eventId, assetId],
            );
          }
          for (final tag in event.tags) {
            batch.customStatement(
              '''
              INSERT OR REPLACE INTO tags(tag_id, name, type, confidence)
              VALUES (?, ?, ?, ?)
              ''',
              [tag.id, tag.name, tag.type, tag.confidence],
            );
            batch.customStatement(
              'INSERT OR IGNORE INTO event_tags(event_id, tag_id) VALUES (?, ?)',
              [event.eventId, tag.id],
            );
          }
        }
      });
    });
  }

  Future<void> insertManualEvent({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
    required String title,
    String? userMemo,
    double? latitude,
    double? longitude,
    List<String> assetIds = const [],
  }) async {
    final representativeAssetId =
        assetIds.isNotEmpty ? assetIds.first : 'manual_no_photo';
    await transaction(() async {
      await customStatement(
        '''
        INSERT INTO events (
          event_id, start_at, end_at, latitude, longitude,
          asset_count, representative_asset_id, quality_score,
          is_moving, is_manual, title, user_memo, is_favorite
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?, ?, 0)
        ''',
        [
          eventId,
          startAt.millisecondsSinceEpoch,
          endAt.millisecondsSinceEpoch,
          latitude,
          longitude,
          assetIds.length,
          representativeAssetId,
          1.0,
          title,
          userMemo,
        ],
      );
      for (final assetId in assetIds) {
        await customStatement(
          'INSERT OR IGNORE INTO event_assets(event_id, asset_id) VALUES (?, ?)',
          [eventId, assetId],
        );
      }
    });
  }

  Future<void> updateEventFavorite(String eventId, bool isFavorite) {
    return customStatement(
      'UPDATE events SET is_favorite = ? WHERE event_id = ?',
      [isFavorite ? 1 : 0, eventId],
    );
  }

  Future<void> updateEventDetails(
    String eventId, {
    String? title,
    String? userMemo,
  }) {
    return customStatement(
      'UPDATE events SET title = ?, user_memo = ? WHERE event_id = ?',
      [title, userMemo, eventId],
    );
  }

  Future<void> updateEventColor(String eventId, int? color) {
    return customStatement(
      'UPDATE events SET color = ? WHERE event_id = ?',
      [color, eventId],
    );
  }

  Future<void> updateEventLocation(
      String eventId, double? latitude, double? longitude) {
    return customStatement(
      'UPDATE events SET latitude = ?, longitude = ? WHERE event_id = ?',
      [latitude, longitude, eventId],
    );
  }

  Future<void> updateEventAddress(String eventId, String? customAddress) {
    return customStatement(
      'UPDATE events SET custom_address = ? WHERE event_id = ?',
      [customAddress, eventId],
    );
  }

  Future<void> updateEventTime(
      String eventId, DateTime startAt, DateTime endAt) {
    return customStatement(
      'UPDATE events SET start_at = ?, end_at = ? WHERE event_id = ?',
      [
        startAt.millisecondsSinceEpoch,
        endAt.millisecondsSinceEpoch,
        eventId,
      ],
    );
  }

  Future<void> addEventTag(
    String eventId,
    String tagId,
    String tagName,
  ) async {
    await customStatement(
      'INSERT OR IGNORE INTO tags(tag_id, name, type, confidence) VALUES (?, ?, ?, ?)',
      [tagId, tagName, 'user', 1.0],
    );
    await customStatement(
      'INSERT OR IGNORE INTO event_tags(event_id, tag_id) VALUES (?, ?)',
      [eventId, tagId],
    );
  }

  Future<void> removeEventTag(String eventId, String tagId) {
    return customStatement(
      'DELETE FROM event_tags WHERE event_id = ? AND tag_id = ?',
      [eventId, tagId],
    );
  }

  Future<IndexingStateModel> loadIndexingState() async {
    final row = await customSelect(
      'SELECT * FROM indexing_state WHERE singleton_id = 1',
    ).getSingle();
    return _mapIndexingState(row.data);
  }

  Future<void> markIndexingStarted({
    required int resumePage,
    required DateTime? anchorCreatedAt,
    required String? anchorAssetId,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return customStatement(
      '''
      UPDATE indexing_state
      SET status = 'running',
          resume_page = ?,
          started_at = COALESCE(started_at, ?),
          completed_at = NULL,
          updated_at = ?
      WHERE singleton_id = 1
      ''',
      [resumePage, now, now],
    );
  }

  Future<void> updateIndexingProgress({
    required int resumePage,
    required int scannedCount,
    required int insertedCount,
    required int skippedCount,
  }) {
    return customStatement(
      '''
      UPDATE indexing_state
      SET resume_page = ?,
          scanned_count = ?,
          inserted_count = ?,
          skipped_count = ?,
          updated_at = ?
      WHERE singleton_id = 1
      ''',
      [
        resumePage,
        scannedCount,
        insertedCount,
        skippedCount,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> markIndexingCompleted({
    required DateTime? lastCompletedCreatedAt,
    required String? lastCompletedAssetId,
    required int scannedCount,
    required int insertedCount,
    required int skippedCount,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return customStatement(
      '''
      UPDATE indexing_state
      SET status = 'idle',
          last_completed_created_at = ?,
          last_completed_asset_id = ?,
          resume_page = 0,
          scanned_count = ?,
          inserted_count = ?,
          skipped_count = ?,
          completed_at = ?,
          started_at = NULL,
          updated_at = ?
      WHERE singleton_id = 1
      ''',
      [
        lastCompletedCreatedAt?.millisecondsSinceEpoch,
        lastCompletedAssetId,
        scannedCount,
        insertedCount,
        skippedCount,
        now,
        now,
      ],
    );
  }

  Future<void> markIndexingFailed() {
    return customStatement(
      '''
      UPDATE indexing_state
      SET status = 'idle',
          updated_at = ?
      WHERE singleton_id = 1
      ''',
      [DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }

  Future<List<DailyStats>> queryDailyStats({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) async {
    final assets = await customSelect(
      _assetWhereSql(locationFilter, groupedByDay: true),
      variables: _rangeVariables(start, end, locationFilter),
    ).get();
    final events = await customSelect(
      _eventWhereSql(locationFilter, groupedByDay: true),
      variables: _rangeVariables(start, end, locationFilter),
    ).get();

    final byDay = <String, DailyStats>{};
    for (final row in assets) {
      final day = row.read<String>('day');
      byDay[day] = DailyStats(
        day: DateTime.parse('${day}T00:00:00Z'),
        assetCount: row.read<int>('asset_count'),
        eventCount: 0,
        photoCount: row.read<int>('photo_count'),
        videoCount: row.read<int>('video_count'),
        nightRatio: row.read<double>('night_ratio'),
        weekendRatio: row.read<double>('weekend_ratio'),
        movingEventRatio: 0,
      );
    }
    for (final row in events) {
      final day = row.read<String>('day');
      final previous = byDay[day];
      if (previous == null) {
        byDay[day] = DailyStats(
          day: DateTime.parse('${day}T00:00:00Z'),
          assetCount: 0,
          eventCount: row.read<int>('event_count'),
          photoCount: 0,
          videoCount: 0,
          nightRatio: 0,
          weekendRatio: 0,
          movingEventRatio: row.read<double>('moving_event_ratio'),
        );
      } else {
        byDay[day] = DailyStats(
          day: previous.day,
          assetCount: previous.assetCount,
          eventCount: row.read<int>('event_count'),
          photoCount: previous.photoCount,
          videoCount: previous.videoCount,
          nightRatio: previous.nightRatio,
          weekendRatio: previous.weekendRatio,
          movingEventRatio: row.read<double>('moving_event_ratio'),
        );
      }
    }

    final items = byDay.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    return items;
  }

  Future<List<EventSummary>> queryEventsForDay({
    required DateTime day,
    LocationFilter? locationFilter,
  }) async {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return queryEventsInRange(
        start: start, end: end, locationFilter: locationFilter);
  }

  Future<List<EventSummary>> queryEventsInRange({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) async {
    final rows = await customSelect(
      _eventWhereSql(locationFilter, groupedByDay: false),
      variables: _rangeVariables(start, end, locationFilter),
    ).get();

    final eventIds = rows.map((row) => row.read<String>('event_id')).toList();
    final assetMap = await _loadEventAssetMap(eventIds);
    final tagMap = await _loadEventTagMap(eventIds);

    return rows
        .map(
          (row) => EventSummary(
            eventId: row.read<String>('event_id'),
            startAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('start_at'),
              isUtc: true,
            ),
            endAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('end_at'),
              isUtc: true,
            ),
            latitude: row.data['latitude'] as double?,
            longitude: row.data['longitude'] as double?,
            assetCount: row.read<int>('asset_count'),
            representativeAssetId: row.read<String>('representative_asset_id'),
            qualityScore: row.read<double>('quality_score'),
            isMoving: row.read<int>('is_moving') == 1,
            assetIds: assetMap[row.read<String>('event_id')] ?? const [],
            tags: tagMap[row.read<String>('event_id')] ?? const [],
            isManual: (row.data['is_manual'] as int? ?? 0) == 1,
            title: row.data['title'] as String?,
            userMemo: row.data['user_memo'] as String?,
            isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
            color: row.data['color'] as int?,
            customAddress: row.data['custom_address'] as String?,
          ),
        )
        .toList();
  }

  Future<List<EventSummary>> queryEventsOnThisDay({
    required int month,
    required int day,
    int windowDays = 7,
    required int currentYear,
  }) async {
    // Build list of (month, day) pairs within the ±windowDays window
    final now = DateTime(currentYear, month, day);
    final pairs = <(int, int)>{};
    for (int i = -windowDays; i <= windowDays; i++) {
      final d = now.add(Duration(days: i));
      pairs.add((d.month, d.day));
    }

    if (pairs.isEmpty) return const [];

    // Build OR conditions for each (month, day) pair
    final conditions = pairs
        .map((_) =>
            "(strftime('%m', start_at/1000, 'unixepoch') = ? AND strftime('%d', start_at/1000, 'unixepoch') = ?)")
        .join(' OR ');

    final variables = <Variable<Object>>[];
    for (final pair in pairs) {
      variables.add(Variable<String>(pair.$1.toString().padLeft(2, '0')));
      variables.add(Variable<String>(pair.$2.toString().padLeft(2, '0')));
    }
    variables.add(Variable<int>(
      DateTime.utc(currentYear).millisecondsSinceEpoch,
    ));

    final rows = await customSelect(
      '''
      SELECT * FROM events
      WHERE ($conditions)
        AND start_at < ?
      ORDER BY start_at DESC
      ''',
      variables: variables,
    ).get();

    final eventIds = rows.map((row) => row.read<String>('event_id')).toList();
    final assetMap = await _loadEventAssetMap(eventIds);
    final tagMap = await _loadEventTagMap(eventIds);

    return rows.map((row) => EventSummary(
          eventId: row.read<String>('event_id'),
          startAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('start_at'),
            isUtc: true,
          ),
          endAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('end_at'),
            isUtc: true,
          ),
          latitude: row.data['latitude'] as double?,
          longitude: row.data['longitude'] as double?,
          assetCount: row.read<int>('asset_count'),
          representativeAssetId: row.read<String>('representative_asset_id'),
          qualityScore: row.read<double>('quality_score'),
          isMoving: row.read<int>('is_moving') == 1,
          assetIds: assetMap[row.read<String>('event_id')] ?? const [],
          tags: tagMap[row.read<String>('event_id')] ?? const [],
          isManual: (row.data['is_manual'] as int? ?? 0) == 1,
          title: row.data['title'] as String?,
          userMemo: row.data['user_memo'] as String?,
          isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
          color: row.data['color'] as int?,
          customAddress: row.data['custom_address'] as String?,
        )).toList();
  }

  // ─── Folder methods ───────────────────────────────────────────────────────

  Future<List<DiaryFolder>> queryFolders({String? parentId}) async {
    final rows = parentId == null
        ? await customSelect(
            'SELECT * FROM folders WHERE parent_id IS NULL ORDER BY created_at ASC',
          ).get()
        : await customSelect(
            'SELECT * FROM folders WHERE parent_id = ? ORDER BY created_at ASC',
            variables: [Variable<String>(parentId)],
          ).get();
    return rows.map(_mapFolder).toList();
  }

  Future<void> insertFolder({
    required String folderId,
    required String name,
    String? parentId,
  }) async {
    if (parentId != null) {
      final depth = await computeFolderDepth(parentId);
      if (depth >= 5) throw const FolderDepthException();
    }
    await customStatement(
      '''
      INSERT INTO folders (folder_id, name, parent_id, is_favorite, created_at)
      VALUES (?, ?, ?, 0, ?)
      ''',
      [folderId, name, parentId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> renameFolder(String folderId, String newName) {
    return customStatement(
      'UPDATE folders SET name = ? WHERE folder_id = ?',
      [newName, folderId],
    );
  }

  Future<void> deleteFolder(String folderId) {
    return customStatement(
      'DELETE FROM folders WHERE folder_id = ?',
      [folderId],
    );
  }

  Future<void> updateFolderFavorite(String folderId, bool isFavorite) {
    return customStatement(
      'UPDATE folders SET is_favorite = ? WHERE folder_id = ?',
      [isFavorite ? 1 : 0, folderId],
    );
  }

  Future<void> addEventToFolder(String folderId, String eventId) {
    return customStatement(
      'INSERT OR IGNORE INTO folder_items(folder_id, event_id) VALUES (?, ?)',
      [folderId, eventId],
    );
  }

  Future<void> removeEventFromFolder(String folderId, String eventId) {
    return customStatement(
      'DELETE FROM folder_items WHERE folder_id = ? AND event_id = ?',
      [folderId, eventId],
    );
  }

  Future<List<EventSummary>> queryFolderContents(String folderId) async {
    final rows = await customSelect(
      '''
      SELECT e.* FROM events e
      JOIN folder_items fi ON fi.event_id = e.event_id
      WHERE fi.folder_id = ?
      ORDER BY e.start_at DESC
      ''',
      variables: [Variable<String>(folderId)],
    ).get();

    final eventIds = rows.map((row) => row.read<String>('event_id')).toList();
    final assetMap = await _loadEventAssetMap(eventIds);
    final tagMap = await _loadEventTagMap(eventIds);

    return rows.map((row) => EventSummary(
          eventId: row.read<String>('event_id'),
          startAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('start_at'),
            isUtc: true,
          ),
          endAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('end_at'),
            isUtc: true,
          ),
          latitude: row.data['latitude'] as double?,
          longitude: row.data['longitude'] as double?,
          assetCount: row.read<int>('asset_count'),
          representativeAssetId: row.read<String>('representative_asset_id'),
          qualityScore: row.read<double>('quality_score'),
          isMoving: row.read<int>('is_moving') == 1,
          assetIds: assetMap[row.read<String>('event_id')] ?? const [],
          tags: tagMap[row.read<String>('event_id')] ?? const [],
          isManual: (row.data['is_manual'] as int? ?? 0) == 1,
          title: row.data['title'] as String?,
          userMemo: row.data['user_memo'] as String?,
          isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
          color: row.data['color'] as int?,
          customAddress: row.data['custom_address'] as String?,
        )).toList();
  }

  Future<List<DiaryFolder>> getFoldersForEvent(String eventId) async {
    final rows = await customSelect(
      '''
      SELECT f.* FROM folders f
      JOIN folder_items fi ON fi.folder_id = f.folder_id
      WHERE fi.event_id = ?
      ORDER BY f.created_at ASC
      ''',
      variables: [Variable<String>(eventId)],
    ).get();
    return rows.map(_mapFolder).toList();
  }

  Future<List<DiaryFolder>> getAllFolders() async {
    final rows = await customSelect(
      'SELECT * FROM folders ORDER BY created_at ASC',
    ).get();
    return rows.map(_mapFolder).toList();
  }

  Future<int> countFolderItems(String folderId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS cnt FROM folder_items WHERE folder_id = ?',
      variables: [Variable<String>(folderId)],
    ).getSingle();
    return row.read<int>('cnt');
  }

  Future<int> computeFolderDepth(String folderId) async {
    final rows = await customSelect(
      '''
      WITH RECURSIVE ancestors AS (
        SELECT folder_id, parent_id, 1 AS depth FROM folders WHERE folder_id = ?
        UNION ALL
        SELECT f.folder_id, f.parent_id, a.depth + 1 FROM folders f
        JOIN ancestors a ON f.folder_id = a.parent_id
      )
      SELECT MAX(depth) AS max_depth FROM ancestors
      ''',
      variables: [Variable<String>(folderId)],
    ).get();
    return rows.first.data['max_depth'] as int? ?? 1;
  }

  // ─── Split / Merge events ─────────────────────────────────────────────────

  /// Splits [assetsForNewEvent] out of [sourceEventId] into a new event.
  /// Returns the new event's ID.
  Future<String> splitEvent(
    String sourceEventId,
    List<String> assetsForNewEvent,
  ) async {
    final newEventId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

    await transaction(() async {
      // Read source row
      final rows = await customSelect(
        'SELECT * FROM events WHERE event_id = ?',
        variables: [Variable<String>(sourceEventId)],
      ).get();
      if (rows.isEmpty) throw StateError('Event not found: $sourceEventId');
      final src = rows.first.data;

      // Validate
      final splitSet = assetsForNewEvent.toSet();
      final allAssets = await customSelect(
        'SELECT asset_id FROM event_assets WHERE event_id = ?',
        variables: [Variable<String>(sourceEventId)],
      ).get();
      final allSet = allAssets.map((r) => r.read<String>('asset_id')).toSet();
      final remaining = allSet.difference(splitSet);

      if (splitSet.isEmpty || remaining.isEmpty) {
        throw ArgumentError('Both halves must be non-empty after split');
      }

      // Insert new event (copy metadata from source)
      await customStatement(
        '''
        INSERT INTO events (
          event_id, start_at, end_at, latitude, longitude,
          asset_count, representative_asset_id, quality_score,
          is_moving, is_manual, title, user_memo, is_favorite,
          color, custom_address
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NULL, NULL, 0, ?, ?)
        ''',
        [
          newEventId,
          src['start_at'],
          src['end_at'],
          src['latitude'],
          src['longitude'],
          assetsForNewEvent.length,
          assetsForNewEvent.first,
          src['quality_score'],
          src['is_moving'],
          src['color'],
          src['custom_address'],
        ],
      );

      // Insert event_assets for new event
      for (final assetId in assetsForNewEvent) {
        await customStatement(
          'INSERT INTO event_assets(event_id, asset_id) VALUES (?, ?)',
          [newEventId, assetId],
        );
      }

      // Remove split assets from source
      for (final assetId in assetsForNewEvent) {
        await customStatement(
          'DELETE FROM event_assets WHERE event_id = ? AND asset_id = ?',
          [sourceEventId, assetId],
        );
      }

      // Update source asset_count and representative
      await customStatement(
        'UPDATE events SET asset_count = ?, representative_asset_id = ? WHERE event_id = ?',
        [remaining.length, remaining.first, sourceEventId],
      );
    });

    return newEventId;
  }

  /// Merges all assets from [sourceEventId] into [targetEventId],
  /// then deletes the source event.
  Future<void> mergeEventsInto(
    String targetEventId,
    String sourceEventId,
  ) async {
    await transaction(() async {
      // Get existing target asset IDs to avoid duplicates
      final targetRows = await customSelect(
        'SELECT asset_id FROM event_assets WHERE event_id = ?',
        variables: [Variable<String>(targetEventId)],
      ).get();
      final targetAssets =
          targetRows.map((r) => r.read<String>('asset_id')).toSet();

      // Get source asset IDs
      final sourceRows = await customSelect(
        'SELECT asset_id FROM event_assets WHERE event_id = ?',
        variables: [Variable<String>(sourceEventId)],
      ).get();
      final sourceAssets =
          sourceRows.map((r) => r.read<String>('asset_id')).toList();

      // Insert non-duplicate assets into target
      for (final assetId in sourceAssets) {
        if (!targetAssets.contains(assetId)) {
          await customStatement(
            'INSERT OR IGNORE INTO event_assets(event_id, asset_id) VALUES (?, ?)',
            [targetEventId, assetId],
          );
          targetAssets.add(assetId);
        }
      }

      // Update target asset_count and representative
      await customStatement(
        'UPDATE events SET asset_count = ?, representative_asset_id = ? WHERE event_id = ?',
        [targetAssets.length, targetAssets.first, targetEventId],
      );

      // Delete source event (cascade removes event_assets)
      await customStatement(
        'DELETE FROM event_assets WHERE event_id = ?',
        [sourceEventId],
      );
      await customStatement(
        'DELETE FROM events WHERE event_id = ?',
        [sourceEventId],
      );
    });
  }

  Future<List<String>> queryAssetIdsForDay(DateTime dayUtc) async {
    final dayStr =
        '${dayUtc.year.toString().padLeft(4, '0')}-'
        '${dayUtc.month.toString().padLeft(2, '0')}-'
        '${dayUtc.day.toString().padLeft(2, '0')}';
    final rows = await customSelect(
      "SELECT asset_id FROM assets "
      "WHERE date(created_at / 1000, 'unixepoch') = ? "
      "ORDER BY created_at DESC LIMIT 50",
      variables: [Variable<String>(dayStr)],
    ).get();
    return rows.map((r) => r.read<String>('asset_id')).toList();
  }

  Future<EventSummary?> getEventById(String eventId) async {
    final rows = await customSelect(
      '''
      SELECT e.event_id, e.start_at, e.end_at, e.latitude, e.longitude,
             e.asset_count, e.representative_asset_id, e.quality_score,
             e.is_moving, e.is_manual, e.title, e.user_memo, e.is_favorite,
             e.color, e.custom_address
      FROM events e
      WHERE e.event_id = ?
      ''',
      variables: [Variable<String>(eventId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    final assetMap = await _loadEventAssetMap([eventId]);
    final tagMap = await _loadEventTagMap([eventId]);
    return EventSummary(
      eventId: row.read<String>('event_id'),
      startAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('start_at'),
        isUtc: true,
      ),
      endAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('end_at'),
        isUtc: true,
      ),
      latitude: row.data['latitude'] as double?,
      longitude: row.data['longitude'] as double?,
      assetCount: row.read<int>('asset_count'),
      representativeAssetId: row.read<String>('representative_asset_id'),
      qualityScore: row.read<double>('quality_score'),
      isMoving: row.read<int>('is_moving') == 1,
      assetIds: assetMap[eventId] ?? const [],
      tags: tagMap[eventId] ?? const [],
      isManual: (row.data['is_manual'] as int? ?? 0) == 1,
      title: row.data['title'] as String?,
      userMemo: row.data['user_memo'] as String?,
      isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
      color: row.data['color'] as int?,
      customAddress: row.data['custom_address'] as String?,
    );
  }

  /// Returns the subset of [assetIds] that are already indexed in the assets table.
  Future<Set<String>> filterIndexedAssetIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return {};
    final placeholders = List.filled(assetIds.length, '?').join(',');
    final rows = await customSelect(
      'SELECT asset_id FROM assets WHERE asset_id IN ($placeholders)',
      variables: assetIds.map((id) => Variable<String>(id)).toList(),
    ).get();
    return rows.map((r) => r.read<String>('asset_id')).toSet();
  }

  Future<void> deleteEvent(String eventId) {
    return transaction(() async {
      await customStatement(
          'DELETE FROM event_assets WHERE event_id = ?', [eventId]);
      await customStatement(
          'DELETE FROM event_tags WHERE event_id = ?', [eventId]);
      await customStatement(
          'DELETE FROM folder_items WHERE event_id = ?', [eventId]);
      await customStatement(
          'DELETE FROM events WHERE event_id = ?', [eventId]);
    });
  }

  // ─── Location clusters ────────────────────────────────────────────────────

  Future<List<LocationCluster>> queryLocationClusters() async {
    final rows = await customSelect(
      '''
      SELECT
        printf('%.2f, %.2f', round(latitude * 100.0) / 100.0, round(longitude * 100.0) / 100.0) AS location_key,
        COUNT(*) AS asset_count,
        AVG(latitude) AS avg_latitude,
        AVG(longitude) AS avg_longitude
      FROM assets
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
      GROUP BY round(latitude * 100.0), round(longitude * 100.0)
      ORDER BY asset_count DESC
      LIMIT 30
      ''',
    ).get();

    return rows
        .map(
          (row) => LocationCluster(
            key: row.read<String>('location_key'),
            label: '${row.read<String>('location_key')} · 2km',
            assetCount: row.read<int>('asset_count'),
            latitude: row.read<double>('avg_latitude'),
            longitude: row.read<double>('avg_longitude'),
          ),
        )
        .toList();
  }

  Future<List<LocationCluster>> queryLocationClustersInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await customSelect(
      '''
      SELECT
        printf('%.2f, %.2f', round(latitude * 100.0) / 100.0, round(longitude * 100.0) / 100.0) AS location_key,
        COUNT(*) AS asset_count,
        AVG(latitude) AS avg_latitude,
        AVG(longitude) AS avg_longitude
      FROM assets
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
        AND created_at >= ? AND created_at < ?
      GROUP BY round(latitude * 100.0), round(longitude * 100.0)
      ORDER BY asset_count DESC
      LIMIT 30
      ''',
      variables: [
        Variable<int>(start.millisecondsSinceEpoch),
        Variable<int>(end.millisecondsSinceEpoch),
      ],
    ).get();

    return rows
        .map(
          (row) => LocationCluster(
            key: row.read<String>('location_key'),
            label: '${row.read<String>('location_key')} · 2km',
            assetCount: row.read<int>('asset_count'),
            latitude: row.read<double>('avg_latitude'),
            longitude: row.read<double>('avg_longitude'),
          ),
        )
        .toList();
  }

  Future<List<TagSummary>> queryTagSummaries({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) async {
    final rows = await customSelect(
      '''
      SELECT
        t.tag_id,
        t.name,
        t.type,
        AVG(t.confidence) AS confidence,
        COUNT(*) AS usage_count
      FROM event_tags et
      JOIN tags t ON t.tag_id = et.tag_id
      JOIN events e ON e.event_id = et.event_id
      WHERE e.start_at >= ? AND e.start_at < ?
      ${locationFilter == null ? '' : 'AND ${_locationCondition('e.latitude', 'e.longitude', locationFilter)}'}
      GROUP BY t.tag_id, t.name, t.type
      ORDER BY usage_count DESC, confidence DESC
      LIMIT 20
      ''',
      variables: _rangeVariables(start, end, locationFilter),
    ).get();

    return rows
        .map(
          (row) => TagSummary(
            tagId: row.read<String>('tag_id'),
            name: row.read<String>('name'),
            type: row.read<String>('type'),
            count: row.read<int>('usage_count'),
            confidence: row.read<double>('confidence'),
          ),
        )
        .toList();
  }

  Future<int> countIndexedAssets() async {
    final row =
        await customSelect('SELECT COUNT(*) AS count FROM assets').getSingle();
    return row.read<int>('count');
  }

  Future<Map<String, List<String>>> _loadEventAssetMap(
      List<String> eventIds) async {
    if (eventIds.isEmpty) {
      return const {};
    }
    final rows = await customSelect(
      '''
      SELECT event_id, asset_id
      FROM event_assets
      WHERE event_id IN (${List.filled(eventIds.length, '?').join(', ')})
      ORDER BY asset_id ASC
      ''',
      variables: eventIds.map((item) => Variable<String>(item)).toList(),
    ).get();
    final map = <String, List<String>>{};
    for (final row in rows) {
      map.putIfAbsent(row.read<String>('event_id'), () => []).add(
            row.read<String>('asset_id'),
          );
    }
    return map;
  }

  Future<Map<String, List<HeuristicTag>>> _loadEventTagMap(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) {
      return const {};
    }
    final rows = await customSelect(
      '''
      SELECT et.event_id, t.tag_id, t.name, t.type, t.confidence
      FROM event_tags et
      JOIN tags t ON t.tag_id = et.tag_id
      WHERE et.event_id IN (${List.filled(eventIds.length, '?').join(', ')})
      ORDER BY t.confidence DESC, t.name ASC
      ''',
      variables: eventIds.map((item) => Variable<String>(item)).toList(),
    ).get();
    final map = <String, List<HeuristicTag>>{};
    for (final row in rows) {
      map.putIfAbsent(row.read<String>('event_id'), () => []).add(
            HeuristicTag(
              id: row.read<String>('tag_id'),
              name: row.read<String>('name'),
              type: row.read<String>('type'),
              confidence: row.read<double>('confidence'),
            ),
          );
    }
    return map;
  }

  String _assetWhereSql(LocationFilter? locationFilter,
      {required bool groupedByDay}) {
    final select = groupedByDay
        ? '''
        SELECT
          date(created_at / 1000, 'unixepoch') AS day,
          COUNT(*) AS asset_count,
          SUM(CASE WHEN media_type = 'image' THEN 1 ELSE 0 END) AS photo_count,
          SUM(CASE WHEN media_type = 'video' THEN 1 ELSE 0 END) AS video_count,
          AVG(CASE
            WHEN CAST(strftime('%H', created_at / 1000, 'unixepoch', 'localtime') AS INTEGER) >= 22
              OR CAST(strftime('%H', created_at / 1000, 'unixepoch', 'localtime') AS INTEGER) < 6
            THEN 1.0 ELSE 0.0 END) AS night_ratio,
          AVG(CASE
            WHEN strftime('%w', created_at / 1000, 'unixepoch', 'localtime') IN ('0', '6')
            THEN 1.0 ELSE 0.0 END) AS weekend_ratio
        '''
        : 'SELECT *';
    final group = groupedByDay
        ? 'GROUP BY day ORDER BY day DESC'
        : 'ORDER BY created_at ASC';

    return '''
      $select
      FROM assets
      WHERE created_at >= ? AND created_at < ?
      ${locationFilter == null ? '' : 'AND ${_locationCondition('latitude', 'longitude', locationFilter)}'}
      $group
    ''';
  }

  String _eventWhereSql(LocationFilter? locationFilter,
      {required bool groupedByDay}) {
    final select = groupedByDay
        ? '''
        SELECT
          date(start_at / 1000, 'unixepoch') AS day,
          COUNT(*) AS event_count,
          AVG(CASE WHEN is_moving = 1 THEN 1.0 ELSE 0.0 END) AS moving_event_ratio
        '''
        : 'SELECT *';
    final group = groupedByDay
        ? 'GROUP BY day ORDER BY day DESC'
        : 'ORDER BY start_at DESC';

    return '''
      $select
      FROM events
      WHERE start_at >= ? AND start_at < ?
      ${locationFilter == null ? '' : 'AND ${_locationCondition('latitude', 'longitude', locationFilter)}'}
      $group
    ''';
  }

  String _locationCondition(
    String latitudeColumn,
    String longitudeColumn,
    LocationFilter filter,
  ) {
    final latRadius = filter.radiusKm / 111.0;
    final safeLatitude = filter.latitude.abs().clamp(0.2, 89.8).toDouble();
    final lngRadius =
        filter.radiusKm / (111.0 * math.cos(safeLatitude * math.pi / 180.0));
    return '''
      $latitudeColumn IS NOT NULL AND $longitudeColumn IS NOT NULL
      AND $latitudeColumn BETWEEN ${filter.latitude - latRadius} AND ${filter.latitude + latRadius}
      AND $longitudeColumn BETWEEN ${filter.longitude - lngRadius} AND ${filter.longitude + lngRadius}
    ''';
  }

  List<Variable<Object>> _rangeVariables(
    DateTime start,
    DateTime end,
    LocationFilter? locationFilter,
  ) {
    return [
      Variable<int>(start.millisecondsSinceEpoch),
      Variable<int>(end.millisecondsSinceEpoch),
    ];
  }

  List<Object?> _tagDefinition(String tagId) {
    switch (tagId) {
      case 'favorite':
        return ['favorite', 'Favorite', 'emotion', 0.95];
      case 'video':
        return ['video', 'Video', 'activity', 0.8];
      case 'night':
        return ['night', 'Night', 'activity', 0.82];
      case 'weekend':
        return ['weekend', 'Weekend', 'activity', 0.9];
      case 'travel':
        return ['travel', 'Movement', 'activity', 0.88];
      case 'dense':
        return ['dense', 'Busy day', 'activity', 0.74];
      default:
        return [tagId, tagId, 'activity', 0.5];
    }
  }

  IndexingStateModel _mapIndexingState(Map<String, Object?> data) {
    DateTime? readDate(String key) {
      final value = data[key] as int?;
      if (value == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    return IndexingStateModel(
      status: data['status']! as String,
      resumePage: data['resume_page']! as int,
      scannedCount: data['scanned_count']! as int,
      insertedCount: data['inserted_count']! as int,
      skippedCount: data['skipped_count']! as int,
      updatedAt: readDate('updated_at')!,
      lastCompletedCreatedAt: readDate('last_completed_created_at'),
      lastCompletedAssetId: data['last_completed_asset_id'] as String?,
      anchorCreatedAt: null,
      anchorAssetId: null,
      startedAt: readDate('started_at'),
      completedAt: readDate('completed_at'),
    );
  }

  DiaryFolder _mapFolder(QueryRow row) {
    return DiaryFolder(
      folderId: row.read<String>('folder_id'),
      name: row.read<String>('name'),
      parentId: row.data['parent_id'] as String?,
      isFavorite: row.read<int>('is_favorite') == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
    );
  }
}
