# Logat - Personal Photo Diary

A personal photo diary app that automatically indexes your photo library and uses AI to suggest diary entries.

## Features

### Tabs

| Tab | Description |
|---|---|
| **Loop** | Infinite scroll reel of past memories with video playback and media reordering |
| **List** | Chronological event list with search, tag, and date filters |
| **Gallery** | Photo grid view of all events |
| **Activity** | Daily stats, tag summaries, and monthly recap |
| **Map** | Map view of events with location-based radius filtering |

### Diary

- **Auto photo indexing**: Scans the device photo library and groups photos into events by date, location, and tags
- **Manual entry**: Create entries with text, date, and location — no photo required
- **Folder management**: Organize entries in up to 5 levels of nested folders
- **On This Day**: Surfaces past memories from the same calendar date in previous years
- **N×100 Day milestones**: Highlights events whose day count is a multiple of 100
- **Media reordering**: Drag to reorder photos/videos within an entry; first item becomes the cover

### Filters

- **Date range**: Relative mode (e.g. "3 months ago") recomputed from today on every launch; absolute mode persists the exact range; All Time shows everything
- **Search**: Full-text search across titles and notes
- **Location**: Radius-based location filter with a map picker
- **Folder**: Filter entries by folder
- **Favorites / Has photo / Has video / Similar date / Milestone day**

### AI

- Suggests diary topics based on recent photos, frequently visited locations, and On This Day events
- Style options: concise (1–2 sentences), narrative (3–5 sentences), or poetic
- Custom prompt style input (e.g. "warm and nostalgic", "short and witty")
- Models: Gemini 2.0 Flash / Gemini 2.5 Pro

### Notifications

- **Periodic reminders**: Fully configurable rules — daily, every N days, or specific weekdays; AI-generated or custom title/subtitle/body; tapping opens the entry creation screen
- **On This Day**: Schedules notifications only for upcoming days that have past-year memories; AI-generated or default copy; tapping applies the Similar Date filter and switches to the List tab
- **N×100 Day milestones**: Notifies on the day a tracked event hits a milestone; tapping applies the Milestone Day filter and switches to the List tab
- **Notification history**: Full log of scheduled and delivered notifications

### Sharing

- Share individual entries as images with customizable layout and an app icon watermark

## Setup

### Requirements

- Flutter SDK (^3.29.0)
- Dart SDK
- API keys:
  - Google Gemini API key (AI suggestions and notification copy)
  - Google Maps API key (map view)

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Set API keys in `lib/key.dart`:
```dart
const String GEMINI_KEYS = 'your-gemini-api-key';
const String MAPS_API_KEY = 'your-maps-api-key';
```

3. Run:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── diary/
│   ├── database/
│   │   └── app_database.dart          # Drift DB (events, folders, photo metadata) — schema v6
│   ├── models/
│   │   ├── event_summary.dart
│   │   ├── folder.dart
│   │   ├── date_range_filter.dart     # Relative / absolute / all-time date filter
│   │   ├── diary_notification_settings.dart
│   │   └── ...
│   ├── providers/
│   │   └── diary_providers.dart       # Riverpod providers
│   ├── repositories/
│   │   ├── diary_repository.dart
│   │   ├── folder_repository.dart
│   │   └── photo_library_repository.dart
│   ├── screens/
│   │   ├── diary_home_screen.dart     # Tab navigation + filter sheet
│   │   ├── memory_reel_view.dart      # Loop tab
│   │   ├── recap_screen.dart          # List tab
│   │   ├── photo_grid_screen.dart     # Gallery tab
│   │   ├── activity_screen.dart       # Activity tab
│   │   ├── event_map_screen.dart      # Map tab
│   │   ├── event_detail_screen.dart   # Entry detail + media reorder
│   │   ├── manual_record_screen.dart  # Create / edit entry
│   │   ├── folder_browser_screen.dart
│   │   ├── diary_notification_settings_screen.dart
│   │   ├── notification_history_screen.dart
│   │   └── share_customize_screen.dart
│   └── services/
│       ├── ai_recommendation_service.dart
│       ├── diary_notification_manager.dart
│       ├── notification_ai_generator.dart
│       ├── notification_background_refresh.dart
│       ├── photo_indexing_service.dart
│       └── ...
└── ...
```

## Database

Drift (SQLite), two separate DB files:

| DB | Tables |
|---|---|
| `legacy_logat` | posts, comments, likes, ai_tasks, scheduled_notifications, tasks, tag_settings |
| `diary_logat` | photo_metadata, events, event_assets, folders, folder_items |

Diary DB schema version: **6**

## Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `drift` / `drift_flutter` | Local SQLite DB |
| `photo_manager` | Device photo library access |
| `google_maps_flutter` | Map view |
| `flutter_local_notifications` | Local notification scheduling |
| `http` | Gemini API calls |
| `shared_preferences` | Settings persistence |
| `reorderable_grid_view` | Drag-to-reorder media grid |
| `image_picker` | Media selection |

## License

Private project — All rights reserved

## Brand Colors

`#B48EAD` `#5E81AC` `#88C0D0` `#A3BE8C` `#EBCB8B` `#BF616A`
