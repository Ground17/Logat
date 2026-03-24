# Logat - Photo Diary

사진 기록을 자동으로 인덱싱하고, AI가 다이어리 작성을 추천해 주는 개인 포토 다이어리 앱.

## 주요 기능

### 다이어리 (Photo Diary)
- **자동 사진 인덱싱**: 기기 사진첩을 스캔해 날짜·위치·태그 기반으로 이벤트를 자동 그룹핑
- **리스트 / 지도 뷰**: 이벤트 목록과 지도 마커 뷰를 토글로 전환, 마지막 설정 유지
- **위치 필터**: 반경 지도 피커로 특정 지역 이벤트만 필터링
- **수동 기록 추가**: 사진 없이도 텍스트·날짜·위치로 직접 기록 생성
- **폴더 관리**: 최대 5단계 중첩 폴더로 기록 분류 및 즐겨찾기
- **N년 전 오늘**: 같은 날짜의 과거 기억 카드 표시

### AI 다이어리 추천
- 최근 사진, 자주 방문한 장소(위치 클러스터), N년 전 오늘 이벤트를 기반으로 AI가 다이어리 소재 추천
- 추천 형식 선택: 간결한 한두 문장 / 3~5문장 / 시적 표현
- AI 모델 선택: Gemini 2.0 Flash / Gemini 2.5 Pro
- 추천 문구 스타일 직접 입력 (예: "감성적이고 따뜻한 말투로", "짧고 위트 있게")
- 매일 지정한 시간에 다이어리 추천 알림

### 알림
- **AI 추천 알림**: 매일 지정 시간에 다이어리 소재 추천
- **N년 전 오늘 알림**: 오늘 날짜와 가까운 과거 기억 알림

### 포스트 피드
- 사진·영상 최대 20개 멀티미디어 포스트
- 위치, 날짜, 태그 지원
- 댓글·좋아요

## 설정

### 필수 조건
- Flutter SDK (^3.29.0)
- Dart SDK
- API 키:
  - Google Gemini API key (AI 다이어리 추천)
  - Google Maps API key (지도 기능)

### 설치

1. 의존성 설치
```bash
flutter pub get
```

2. API 키 설정 — `lib/key.dart` 편집:
```dart
const String GEMINI_KEYS = 'your-gemini-api-key';
const String MAPS_API_KEY = 'your-maps-api-key';
```

3. 실행
```bash
flutter run
```

## 프로젝트 구조

```
lib/
├── main.dart                              # 앱 진입점
├── database/
│   └── database_helper.dart              # Drift DB (posts, comments, likes, tasks 등)
├── diary/                                 # 다이어리 기능 모듈
│   ├── database/
│   │   └── app_database.dart             # Drift DB (events, folders, photo metadata)
│   ├── models/
│   │   ├── event_summary.dart            # 이벤트 요약 모델
│   │   ├── folder.dart                   # 폴더 모델
│   │   ├── recommendation_settings.dart  # AI 추천 설정 모델
│   │   └── ...
│   ├── providers/
│   │   └── diary_providers.dart          # Riverpod 프로바이더
│   ├── repositories/
│   │   ├── diary_repository.dart         # 이벤트 조회/생성
│   │   ├── folder_repository.dart        # 폴더 CRUD
│   │   └── photo_library_repository.dart # 사진첩 접근
│   ├── screens/
│   │   ├── diary_home_screen.dart        # 탭 네비게이션 (회상/지도/태그/폴더)
│   │   ├── recap_screen.dart             # 메인 회상 화면
│   │   ├── event_map_screen.dart         # 지도 뷰
│   │   ├── diary_settings_screen.dart    # AI 추천 및 알림 설정
│   │   ├── manual_record_screen.dart     # 수동 기록 생성
│   │   ├── folder_browser_screen.dart    # 폴더 탐색
│   │   ├── event_detail_screen.dart      # 이벤트 상세
│   │   ├── radius_picker_screen.dart     # 반경 위치 필터 피커
│   │   └── ...
│   └── services/
│       ├── ai_recommendation_service.dart    # Gemini API 기반 AI 추천
│       ├── memories_notification_service.dart # 로컬 알림 스케줄링
│       ├── photo_indexing_service.dart       # 사진 인덱싱
│       └── ...
├── models/
│   ├── post.dart
│   ├── comment.dart
│   └── ...
└── screens/
    ├── feed_screen.dart
    ├── create_post_screen.dart
    └── ...
```

## 데이터베이스

Drift (SQLite) 기반, 두 개의 DB 파일로 분리:

| DB | 테이블 | 설명 |
|---|---|---|
| `legacy_logat` | posts, comments, likes, ai_tasks, scheduled_notifications, tasks, tag_settings | 피드·포스트 관련 |
| `diary_logat` | photo_metadata, events, event_assets, folders, folder_items | 다이어리 관련 |

다이어리 DB 스키마 버전: **3** (events 컬럼 확장 + folders/folder_items 추가)

## 주요 의존성

| 패키지 | 용도 |
|---|---|
| `flutter_riverpod` | 상태 관리 |
| `drift` / `drift_flutter` | 로컬 SQLite DB |
| `photo_manager` | 기기 사진첩 접근 |
| `google_maps_flutter` | 지도 |
| `flutter_local_notifications` | 로컬 알림 |
| `http` | Gemini API 통신 |
| `shared_preferences` | 설정 영속화 |
| `image_picker` | 미디어 선택 |

## 라이선스

Private project — All rights reserved

## 기본 색깔
#B48EAD, #5E81AC, #88C0D0, #A3BE8C, #EBCB8B, #BF616A  