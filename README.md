# Logat - Personal Photo Diary

A personal photo diary app that automatically indexes your photo library and uses AI to suggest diary entries.

## Features

### Tabs

| Tab | Description |
|---|---|
| **Loop** | Infinite scroll reel of past memories; pull-to-refresh at the top; YouTube-Shorts-style seek bar for videos |
| **List** | Chronological event list with search, tag, and date filters |
| **Gallery** | Photo grid view of all events |
| **Activity** | Annual heatmap, frequent locations, tag summaries, and monthly/yearly recap |
| **Map** | Map view of events with location-based radius filtering |

All tabs show an indexing prompt if the photo library has not been indexed yet.

### Onboarding

- **Consent screen**: Shown on first launch; requires the user to agree to both the Terms of Service and the Privacy Policy before accessing the app. Agreement is stored in `SharedPreferences` and is not shown again on subsequent launches.

### Diary

- **Auto photo indexing**: Scans the device photo library and groups photos into events by date, location, and tags
- **Manual entry**: Create entries with text, date, and location — no photo required; accepts photos shared directly from the system share sheet
- **Folder management**: Organize entries in up to 5 levels of nested folders
- **On This Day**: Surfaces past memories from the same calendar date in previous years
- **N×100 Day milestones**: Highlights events whose day count is a multiple of 100
- **Media reordering**: Drag to reorder photos/videos within an entry; first item becomes the cover

### Loop Tab

- Vertical swipe between events
- Horizontal swipe between multiple media items within an event
- Video playback with a thin seek bar at the bottom that expands on drag
- Favorite toggle, speed selector, event detail shortcut
- "N days/weeks/months/years ago" label with milestone badges

### Filters

- **Date range**: Relative mode (e.g. "3 months ago") recomputed from today on every launch; absolute mode persists the exact range; All Time shows everything. The Frequent Locations card in the Activity tab respects the same filter.
- **Search**: Full-text search across titles and notes
- **Location**: Radius-based location filter with a map picker
- **Folder**: Filter entries by folder
- **Favorites / Has photo / Has video / Similar date / Milestone day**

### AI

- Suggests diary topics based on recent photos, frequently visited locations, and On This Day events
- Style options: concise (1–2 sentences), narrative (3–5 sentences), or poetic
- Custom prompt style input (e.g. "warm and nostalgic", "short and witty")
- Model: Gemini Flash (`gemini-3-flash-preview`)

### Notifications

- **Periodic reminders**: Fully configurable rules — daily, every N days, or specific weekdays; AI-generated or custom title/subtitle/body; tapping opens the entry creation screen
- **On This Day**: Schedules notifications only for upcoming days that have past-year memories; AI-generated or default copy; tapping applies the Similar Date filter and switches to the List tab
- **N×100 Day milestones**: Notifies on the day a tracked event hits a milestone (`N Milestones Today` / `See memories that have reached a milestone today`); tapping applies the Milestone Day filter and switches to the List tab
- **Notification history**: Full log of scheduled and delivered notifications

### Sharing

- Share individual entries as images with a fully customizable layout (collage, text elements, background color, aspect ratio) and `assets/logo.png` watermark
- Monthly and yearly recap screens can be shared as a screenshot with the logo watermark in the bottom-right corner

## Setup

### Requirements

- Flutter SDK (Dart SDK ^3.2.0)
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
│   │   ├── consent_screen.dart        # First-launch ToS + Privacy Policy consent gate
│   │   ├── diary_home_screen.dart     # Tab navigation + filter sheet
│   │   ├── memory_reel_view.dart      # Loop tab + Shorts-style seek bar
│   │   ├── recap_screen.dart          # List tab
│   │   ├── photo_grid_screen.dart     # Gallery tab
│   │   ├── activity_screen.dart       # Activity tab
│   │   ├── event_map_screen.dart      # Map tab
│   │   ├── event_detail_screen.dart   # Entry detail + media reorder
│   │   ├── manual_record_screen.dart  # Create / edit entry (supports share intent)
│   │   ├── folder_browser_screen.dart
│   │   ├── diary_notification_settings_screen.dart
│   │   ├── notification_history_screen.dart
│   │   ├── share_customize_screen.dart
│   │   ├── monthly_recap_screen.dart
│   │   └── yearly_recap_screen.dart
│   ├── widgets/
│   │   ├── indexing_prompt_view.dart  # Shared "start indexing" prompt used by all tabs
│   │   └── heatmap_widget.dart
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

Drift (SQLite), single file: `diary_mvp.sqlite`

| Table | Description |
|---|---|
| `assets` | Photo/video metadata indexed from the device library |
| `indexing_state` | Singleton row tracking current indexing progress and resume cursor |
| `events` | Diary events (auto-grouped or manual); holds title, memo, location, favorite, color |
| `event_assets` | Many-to-many join between events and assets, with sort order |
| `tags` | Heuristic tags (name, type, confidence) |
| `asset_tags` | Many-to-many join between assets and tags |
| `event_tags` | Many-to-many join between events and tags |
| `folders` | Nested folders (up to 5 levels deep) |
| `folder_items` | Many-to-many join between folders and events |

## Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `drift` / `drift_flutter` | Local SQLite DB |
| `photo_manager` | Device photo library access |
| `google_maps_flutter` | Map view |
| `flutter_local_notifications` | Local notification scheduling |
| `http` | Gemini API calls |
| `shared_preferences` | Settings & consent state persistence |
| `reorderable_grid_view` | Drag-to-reorder media grid |
| `receive_sharing_intent` | Receive photos/videos shared from other apps |
| `video_player` | In-app video playback |
| `image_picker` | Media selection |
| `webview_flutter` | In-app web view (Terms of Service / Privacy Policy) |

## License

Private project — All rights reserved

## Brand Colors

`#B48EAD` `#5E81AC` `#88C0D0` `#A3BE8C` `#EBCB8B` `#BF616A`
