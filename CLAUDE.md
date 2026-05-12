# Sinoma — Claude Project Guide

## Role
You are the Lead Software Architect and Full-Stack Developer for Sinoma. You write all Flutter Web (Dart), Firebase (backend), and Python (data pipeline) code. Always use Active Voice in function/variable names. Write modular, clean, scalable code. Default to writing no comments unless the WHY is non-obvious.

## Project Vision
A Mandarin Chinese learning platform that fuses:
- **Video-based learning** (YouTube-style clips with quiz overlay)
- **AI contextual dictionary** (Gemini API explains words in video context)
- **Gamification** (Mandarin Duel + Hanzi Build games)
- **Social layer** (achievements, leaderboard, challenges)
- **Web monetization** (Premium subscription — mobile IAP removed, web payments coming)

Target audience: Mandarin learners **outside mainland China** (expats, students, global learners).
Platform: **Web-only** (Flutter Web deployed on Vercel). No Android/iOS at this stage.

---

## Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| Frontend | Flutter Web (Dart) | Single-codebase web app |
| Hosting | **Vercel** | Git-integrated, instant previews, no caching issues |
| State Management | Riverpod | Less boilerplate than Bloc, good for this scale |
| Database | Firebase Firestore | Real-time, scales well, offline support |
| Auth | Firebase Auth | Google/Email sign-in |
| File Storage | Firebase Storage | Profile photos stored as base64 in Firestore |
| Push Notifications | Firebase Cloud Messaging (FCM) | |
| AI Dictionary | Gemini 1.5 Flash API | Cost-effective, context-aware |
| Analytics | Firebase Analytics + Crashlytics | |
| Feature Flags | Firebase Remote Config | A/B testing, ad frequency control |
| Video (YouTube) | youtube_player_iframe | Official IFrame embed |
| Video (self-hosted) | video_player + chewie | Full control, seek restriction possible |
| Local Cache | Hive | Offline mode, dictionary cache |
| Navigation | go_router | Declarative, deep-link ready |
| Python Pipeline | Python 3.11+ | Content mining, HSK analysis, Firestore upload |
| CI/CD | GitHub Actions → Vercel CLI | Auto-deploy on every `git push` |

---

## Key Packages (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod: ^2.x
  cloud_firestore: ^5.x
  firebase_auth: ^5.x
  firebase_storage: ^12.x
  firebase_messaging: ^15.x
  firebase_analytics: ^11.x
  firebase_crashlytics: ^4.x
  firebase_remote_config: ^5.x
  google_mobile_ads: ^5.x
  youtube_player_iframe: ^4.x
  video_player: ^2.x
  chewie: ^1.x
  google_generative_ai: ^0.4.x
  hive_flutter: ^1.x
  freezed_annotation: ^2.x
  json_annotation: ^4.x
  go_router: ^14.x
  cached_network_image: ^3.x
  intl: ^0.19.x

dev_dependencies:
  freezed: ^2.x
  json_serializable: ^6.x
  build_runner: ^2.x
```

---

## Architecture: Clean Architecture (3 Layers)

```
lib/
├── main.dart
├── app.dart                        # MaterialApp, GoRouter, ProviderScope
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart        # i18n keys
│   │   └── hsk_constants.dart      # HSK level word counts, thresholds
│   ├── errors/
│   │   └── app_exception.dart
│   ├── extensions/
│   │   └── string_extensions.dart
│   └── utils/
│       ├── hsk_analyzer.dart       # Sentence-level HSK scoring
│       └── translation_helper.dart # tr/en/vi definition picker
├── data/
│   ├── models/                     # freezed models with fromJson/toJson
│   │   ├── user_model.dart
│   │   ├── video_segment_model.dart
│   │   ├── dictionary_model.dart
│   │   └── post_model.dart
│   ├── repositories/
│   │   ├── user_repository.dart
│   │   ├── video_repository.dart
│   │   ├── dictionary_repository.dart
│   │   └── social_repository.dart
│   └── services/
│       ├── gemini_service.dart
│       ├── ad_service.dart
│       └── credit_service.dart
├── presentation/
│   ├── providers/                  # All Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── user_provider.dart
│   │   ├── video_provider.dart
│   │   ├── dictionary_provider.dart
│   │   ├── credit_provider.dart
│   │   ├── subscription_provider.dart
│   │   └── game_provider.dart
│   ├── screens/
│   │   ├── onboarding/             # ADIM 13
│   │   ├── home/
│   │   ├── video_player/           # ADIM 3 & 4
│   │   ├── dictionary/             # ADIM 5
│   │   ├── games/
│   │   │   ├── mandarin_duel/      # ADIM 7
│   │   │   └── hanzi_build/        # ADIM 7
│   │   ├── social/                 # ADIM 8
│   │   ├── subscription/           # ADIM 9
│   │   └── settings/
│   └── widgets/
│       ├── video/
│       │   ├── youtube_section_player.dart
│       │   ├── self_hosted_player.dart
│       │   └── quiz_overlay.dart
│       ├── ads/
│       │   ├── ad_banner_widget.dart
│       │   └── reward_ad_widget.dart
│       └── common/
├── l10n/                           # Localization (tr, en, vi)
python/
├── pipeline/
│   ├── youtube_miner.py            # ADIM 10: subtitle extraction
│   ├── hsk_analyzer.py             # ADIM 2: CC-CEDICT + HSK injection
│   └── firestore_uploader.py       # ADIM 10: Firestore batch upload
└── requirements.txt
firebase/
├── firestore.rules                 # ADIM 21: security rules
├── firestore.indexes.json
└── functions/
    ├── index.js                    # ADIM 11: Cloud Functions
    └── package.json
```

---

## Firestore Collections

### `users/{uid}`
```
uid: String
displayName: String
email: String
photoUrl: String
hskLevel: Int (1–6)
isPremium: Boolean
aiCredits: Int
followers: List<String>
following: List<String>
learnedWords: List<String>
stats: {
  totalScore: Int
  videosWatched: Int
  questionsAnswered: Int
  currentStreak: Int
}
createdAt: Timestamp
```

### `dictionary/{wordId}`
```
wordId: String
simplified: String
traditional: String
pinyin: String
hskLevel: Int
definitions: {
  tr: String
  en: String
  vi: String
}
aiContextCache: {
  [sentenceHash]: {
    explanation: String
    grammarNote: String
    cachedAt: Timestamp
  }
}
radicals: List<String>
strokeCount: Int
```

### `videos/{videoId}`
```
videoId: String
sourceType: String ('youtube' | 'self_hosted')
youtubeId: String?          # only for YouTube source
videoUrl: String?           # only for self-hosted source
startTime: Double
endTime: Double
hskLevel: Int
transcription: String       # Chinese sentence
pinyin: String
targetWords: List<String>   # dictionary wordIds
quiz: {
  question: String
  correctAnswer: String
  wrongAnswer: String
}
isActive: Boolean
createdAt: Timestamp
```

### `posts/{postId}`
```
postId: String
authorId: String
content: String
attachmentUrl: String?
likes: List<String>
postType: String ('achievement' | 'score' | 'challenge' | 'text')
metadata: Map             # game score, HSK level reached, etc.
timestamp: Timestamp
```

---

## Firestore Indexes (Required)

```json
[
  { "collectionGroup": "videos", "fields": [{"fieldPath": "hskLevel"}, {"fieldPath": "isActive"}, {"fieldPath": "createdAt", "order": "DESCENDING"}] },
  { "collectionGroup": "videos", "fields": [{"fieldPath": "sourceType"}, {"fieldPath": "hskLevel"}, {"fieldPath": "isActive"}] },
  { "collectionGroup": "posts", "fields": [{"fieldPath": "authorId"}, {"fieldPath": "timestamp", "order": "DESCENDING"}] },
  { "collectionGroup": "users", "fields": [{"fieldPath": "hskLevel"}, {"fieldPath": "stats.totalScore", "order": "DESCENDING"}] }
]
```

---

## Critical Architecture Decisions

### 1. Hybrid Video Player
The `VideoSegmentModel` has a `sourceType` field (`youtube` | `self_hosted`). The player widget reads this and renders either `YoutubePlayerIframe` or Flutter's `VideoPlayer`. This allows seamless migration from YouTube-embedded content to self-hosted content without touching any UI code.

### 2. Seek Restriction Strategy
**Do NOT block the seek bar technically** — this violates YouTube IFrame ToS.
**Instead:** If user seeks outside the defined segment, immediately reset position to `startTime` and deduct quiz attempt. This achieves the same UX goal while remaining ToS-compliant.

### 3. AI Credit Security
**CRITICAL:** `aiCredits` in Firestore must ONLY be modified by Firebase Cloud Functions (ADIM 11). The Flutter client reads the value but never writes to it directly. All increment/decrement operations go through a Cloud Function that validates the request. This prevents client-side manipulation.

### 4. AdMob Placement Rules
- Banner ads: OUTSIDE the video player frame (below it), never overlapping
- Interstitial: Triggered after every 20 clips for free users, then every 10
- Rewarded Ads: User-initiated only (for AI credits)
- Premium (`isPremium == true`): All ads disabled at app launch via `SubscriptionProvider`

### 5. Gemini Caching
Before calling Gemini API, check `dictionary/{wordId}.aiContextCache[sentenceHash]`. Hash = SHA256 of (wordId + transcription). If cache hit, return stored result. Cache reduces Gemini costs toward zero for popular content.

### 6. Cloudflare R2 (Self-hosted video)
For MVP, Firebase Storage is acceptable. At scale, migrate to Cloudflare R2 (no egress fees). The `videoUrl` field in `VideoSegmentModel` stores the full CDN URL, so the migration is a data-only operation with no code changes.

### 7. Content Licensing
- YouTube content: Only embed via IFrame (never download). Prefer Creative Commons licensed videos (filter: `license=creativecommon` in YouTube Data API v3).
- Self-hosted content: Must be CC-BY or CC-BY-SA licensed, or original content.
- Running AdMob ads alongside self-hosted CC content is legally fine (CC-BY and CC-BY-SA allow commercial use).

---

## Naming Conventions (Active Voice)

| Bad (Passive) | Good (Active) |
|---|---|
| `fetchData()` | `loadUserStats()` |
| `processVideo()` | `analyzeVideoSegment()` |
| `getWords()` | `buildWordList()` |
| `isDataLoaded` | `hasLoadedData` |
| `userData` | `currentUser` |
| `videoProcessor` | `videoSegmentAnalyzer` |

---

## HSK System
- HSK 1–6: Standard levels (1 = beginner, 6 = advanced)
- Sentence HSK level = HSK level of the HIGHEST-level word in the sentence
- `hskLevel` stored on both `videos` and `dictionary` documents
- Users only see videos at or below their `hskLevel + 1` (stretch zone)

---

## Localization (3 Languages)
- `tr` — Turkish (primary market)
- `en` — English
- `vi` — Vietnamese (future market)
- Dictionary definitions stored in Firestore with all 3 keys
- App UI strings in `lib/l10n/` using Flutter's `intl` package
- `TranslationHelper.getDefinition(wordModel, locale)` returns the correct definition

---

## Python Pipeline Overview
Located in `python/pipeline/`:
1. `youtube_miner.py` — Takes YouTube URL, fetches captions via YouTube Data API v3 (official, not scraping), segments into 5–10 second chunks, filters by HSK level
2. `hsk_analyzer.py` — Loads CC-CEDICT + HSK word lists, assigns `hskLevel` to each dictionary entry and video segment
3. `firestore_uploader.py` — Batch uploads processed segments to Firestore `videos` collection

CC-CEDICT source: https://www.mdbg.net/chinese/dictionary?page=cc-cedict (public domain)
HSK word lists: Official HANBAN/Confucius Institute lists (public domain)

---

## Development Workflow

### Local dev
- Start: `start_dev.bat` — launches Firebase emulators (auth+firestore) + Flutter web server on port 9300
- Flutter dev: `flutter run -d web-server --web-port 9300 --web-hostname localhost`
- **NEVER use `flutter build web` + Firebase hosting emulator for dev** — use `flutter run -d web-server` only

### Deployment (fully automated)
- `git push` → GitHub Actions → `flutter build web --release` → `vercel deploy --prod`
- First-time setup: run `.\setup_production.ps1` locally, then add 3 secrets to GitHub
- Preview URLs: every pull request gets an automatic Vercel preview deployment

### Firebase backend (separate from hosting)
- Deploy rules/functions when changed: `firebase deploy --only firestore,storage,functions --project=sinoma`
- Test rules locally: `firebase emulators:start --only auth,firestore --project sinoma`

### Code quality
1. Each feature: separate Git branch (`feature/adim-01-schema`, etc.)
2. Dart: `dart fix --apply` and `flutter analyze` before merging
3. Python: `mypy` + `ruff` before merging

---

## Master Plan Steps Reference

| # | Title | Phase | Status |
|---|---|---|---|
| 1 | Firestore Schema + Dart Models | Foundation | Pending |
| 2 | HSK Logic + Multilingual Dictionary | Foundation | Pending |
| 3 & 4 | Hybrid Video Player + Quiz Overlay | Video Core | Pending |
| 5 | Gemini AI Dictionary + RAG | AI Layer | Pending |
| 6 | Credit System + Rewarded Ads | Monetization | Pending |
| 7 | Mandarin Duel + Hanzi Build | Gamification | Pending |
| 8 | Social Feed + Friends + Leaderboard | Social | Pending |
| 9 | AdMob + Premium Subscription | Monetization | Pending |
| 10 | Python YouTube Content Pipeline | Data Pipeline | Pending |
| 11 | Firebase Cloud Functions (secure backend) | Infrastructure | Pending |
| 12 | FCM Push Notifications | Infrastructure | Pending |
| 13 | Onboarding + HSK Level Test | UX | Pending |
| 14 | Offline Mode (Hive cache) | Infrastructure | Pending |
| 15 | Analytics + Crashlytics | Infrastructure | Pending |
| 16 | Firebase Remote Config (A/B, feature flags) | Infrastructure | Pending |
| 17 | Python CC Content Pipeline V2 | Data Pipeline | Pending |
| 18 | Tablet / Wide-screen Layout | Platform | Pending |
| 19 | CI/CD (GitHub Actions + Fastlane) | DevOps | Pending |
| 20 | Active Voice Revision + Performance Optimization | Polish | Pending |
| 21 | Play Store Release + Firestore Security Rules + GDPR | Launch | Pending |
