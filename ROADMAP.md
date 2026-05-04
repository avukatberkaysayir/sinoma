# Mandarin Academy — Master Roadmap

## Overview
21-step plan across 7 phases. Each step is a Git branch. Steps within the same phase can sometimes overlap but should generally complete in order.

---

## Phase 0 — Project Foundation
*Flutter project scaffold, Firebase setup, package wiring. No features yet.*

### Pre-Step: Flutter Project Initialization
- Create Flutter project: `flutter create mandarin_academy`
- Configure `pubspec.yaml` with all required packages
- Initialize Firebase project (Firestore, Auth, Storage, Analytics, Crashlytics, Remote Config, FCM)
- Wire `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Set up folder structure per CLAUDE.md architecture
- Initialize Git repository with `.gitignore`

**Exit Criteria:** `flutter run` launches a blank app connected to Firebase. `FlutterFire CLI` config passes.

---

## Phase 1 — Data Architecture
*Build the data backbone. No UI yet.*

### ADIM 1: Firestore Schema + Dart Models
**Branch:** `feature/adim-01-schema`

Deliverables:
- `freezed` models: `UserModel`, `VideoSegmentModel`, `DictionaryModel`, `PostModel`
- All `fromJson` / `toJson` methods generated via `json_serializable`
- `firestore.indexes.json` with all required composite indexes
- Firestore emulator seed script with sample data (5 users, 10 words, 5 video segments)

Key design decision: `VideoSegmentModel.sourceType` field (`youtube` | `self_hosted`) enables hybrid player (ADIM 3&4).

**Exit Criteria:** All models serialize/deserialize without error. Emulator shows correct data structure.

---

### ADIM 2: HSK Logic + Multilingual Dictionary
**Branch:** `feature/adim-02-hsk-logic`

Deliverables:
- `HSKAnalyzer` class: computes sentence HSK level from constituent words
- `TranslationHelper`: returns correct definition (tr/en/vi) based on device locale
- `CharacterAnalyzer`: splits a character into its radicals (data-driven, from CEDICT radicals dataset)
- `SynonymGrouper`: clusters semantically related words (simple frequency-based approach)
- Python script `hsk_analyzer.py`: loads CC-CEDICT + HSK lists, injects `hskLevel` into each entry, outputs Firestore-ready JSON

**Exit Criteria:** Unit tests pass for `HSKAnalyzer` (sample sentences at known levels). Python script outputs valid JSON for 500+ words.

---

## Phase 2 — Content Pipeline
*Automated content generation. Runs offline, feeds Firestore.*

### ADIM 10: Python YouTube Content Pipeline V1
**Branch:** `feature/adim-10-python-pipeline`

Deliverables:
- `youtube_miner.py`: Given a YouTube URL, calls YouTube Data API v3 to fetch captions (official API, not scraping). Segments captions into 5–10 second windows. Filters by sentence completeness.
- `hsk_level_injector.py`: Runs `HSKAnalyzer` logic on each segment, assigns `hskLevel`.
- `firestore_uploader.py`: Batch-uploads processed segments to `videos` collection.
- `requirements.txt` with pinned versions.
- `.env.example` file documenting required env vars (YouTube API key, Firebase service account).

Content strategy:
1. Use YouTube Data API v3 with `license=creativeCommon` filter to find CC-licensed Mandarin content.
2. Channels to prioritize: HSK exam prep channels, Mandarin Corner, ChinesePod (where CC licensed).
3. Manually curate first 100 clips before automating pipeline.

**Exit Criteria:** Pipeline successfully processes 1 YouTube video and uploads ≥ 3 valid segments to Firestore emulator.

---

### ADIM 17: Python CC Content Pipeline V2 (Self-Hosted)
**Branch:** `feature/adim-17-pipeline-v2`

Deliverables:
- Enhanced pipeline that downloads CC-licensed video clips (not just captions) and uploads to Cloudflare R2.
- Sets `sourceType: 'self_hosted'` and `videoUrl` pointing to R2 CDN URL.
- Bulk processing mode: process entire YouTube channel or playlist.
- Duplicate detection: checks Firestore before uploading.

**Exit Criteria:** Pipeline downloads 1 CC clip, uploads to R2, writes Firestore record with correct `videoUrl`. App plays the clip via self-hosted path.

---

## Phase 3 — Video Core
*The heart of the product. Most complex phase.*

### ADIM 3 & 4: Hybrid Video Player + Quiz Overlay
**Branch:** `feature/adim-03-video-player`

Deliverables:

**A. VideoSegmentModel-driven player router:**
- If `sourceType == 'youtube'` → renders `YoutubeNativePlayer` (IFrame)
- If `sourceType == 'self_hosted'` → renders `SelfHostedPlayer` (video_player + chewie)

**B. `YoutubeNativePlayer` widget:**
- Parameters: `VideoSegmentModel`
- Starts at `startTime`, listens to position stream
- At `position >= endTime`: calls `pause()`, triggers `QuizOverlay`
- Seek behavior: if user seeks outside segment range, reset to `startTime` and flag attempt as "seeked" (reduces reward). No technical seek block (ToS compliance).
- Displays HSK level badge (top-right)
- `isPremium == false`: leaves space below player for AdMob banner

**C. `SelfHostedPlayer` widget:**
- Same interface as `YoutubeNativePlayer`
- Full seek control: `VideoPlayerController.seekTo(startTime)` enforced at segment boundaries
- `BackdropFilter` blur when `QuizOverlay` is active

**D. `QuizOverlay` widget:**
- Animates up from bottom when triggered
- Two answer buttons (correct + wrong, shuffled)
- On correct: `+points`, `learnedWords` updated, next video queued
- On wrong: heart deducted, explanation shown, replay option
- `ScoreMultiplier`: consecutive correct answers build a combo (x1 → x2 → x3)

**E. `VideoProvider` (Riverpod):**
- States: `loading` | `playing` | `quizActive` | `completed`
- Tracks current segment, score, combo, hearts

**Exit Criteria:** App plays a YouTube clip, stops at `endTime`, shows quiz, records score to Firestore. Self-hosted clip plays identically.

---

## Phase 4 — AI Dictionary Layer

### ADIM 5: Gemini AI Dictionary + Caching
**Branch:** `feature/adim-05-ai-dictionary`

Deliverables:
- `GeminiService`: sends `(word, transcription)` to Gemini 1.5 Flash. Prompt template:
  ```
  You are a Mandarin Chinese teacher. Explain the word "{word}" as used in this sentence: "{sentence}".
  Include: 1) meaning in this specific context, 2) grammar pattern, 3) HSK level, 4) one example sentence.
  Respond in {userLanguage}. Be concise (max 120 words).
  ```
- Cache check: SHA256 of `(wordId + transcription)` → checks `dictionary/{wordId}.aiContextCache`. On hit, returns cached result without API call.
- On cache miss: calls Gemini, stores result in `aiContextCache` map, returns to user.
- `WordDetailSheet`: Bottom sheet that appears when user taps a word in the subtitle overlay. Shows: characters, pinyin, definition, AI context explanation, HSK badge.
- Credit gate: before calling Gemini, checks `creditProvider.currentCredits > 0`. On zero, shows `QuotaExceededModal`.

**Exit Criteria:** Tapping a word shows AI explanation. Tapping the same word+sentence a second time returns cached result (verified by checking Gemini API call count).

---

## Phase 5 — Monetization

### ADIM 6: Credit System + Rewarded Ads
**Branch:** `feature/adim-06-credits`

Deliverables:
- `CreditController` (Riverpod): listens to `users/{uid}.aiCredits` in real time
- `CreditService`: ONLY reads credits client-side. All mutations go through Cloud Function (see ADIM 11).
- `RewardAdWidget`: loads AdMob Rewarded Ad. On `onUserEarnedReward` callback, calls Cloud Function `grantAiCredits(uid, amount: 10)`.
- `QuotaExceededModal`: Three-option bottom sheet:
  - "Watch Ad → Earn 10 Credits" (triggers RewardAdWidget)
  - "Upgrade to Academy Pro" (routes to SubscriptionScreen)
  - "Use Basic Dictionary" (dismisses modal, shows standard Firestore-only definition)
- Daily credit refresh: Cloud Function scheduled at midnight UTC resets free users' credits to 5.

**Exit Criteria:** Free user with 0 credits sees modal. Watches rewarded ad. Credits become 10. AI dictionary works again.

---

### ADIM 9: AdMob + Premium Subscription
**Branch:** `feature/adim-09-monetization`

Deliverables:
- `AdManager`: central singleton managing interstitial and banner ad lifecycle
  - `showInterstitialIfEligible()`: checks free user counter (20 clips → first ad, then every 10)
  - Counter resets on app restart, persisted in Hive locally
- `AdBannerWidget`: displays banner below video player, only when `isPremium == false`
- `SubscriptionProvider` (Riverpod): listens to `users/{uid}.isPremium` in real time. Disables all ads when `true`.
- `SubscriptionScreen`: modern card-based UI with "Academy Pro" plan details
- `payWithStore()`: stub function ready for `in_app_purchase` package integration
- `PremiumGuard` widget: wraps premium-only screens, redirects to SubscriptionScreen if not premium

**Exit Criteria:** Premium user sees zero ads. Free user sees banner below video and interstitial after threshold. `PremiumGuard` blocks premium-only screens.

---

## Phase 6 — Gamification

### ADIM 7: Mandarin Duel + Hanzi Build
**Branch:** `feature/adim-07-games`

Deliverables:

**A. Mandarin Duel:**
- `MandarinDuelScreen`: loads random video at user's HSK level, plays clip, shows 5-second countdown timer with `AnimationController`
- `GameLogic` class: manages hearts (3 lives), score, combo multiplier
- On correct answer: score += `basePoints * comboMultiplier`, combo++
- On wrong answer: hearts--, combo resets
- On game over: writes score to `users/{uid}.stats.totalScore`, triggers `AutoPostService` to create achievement post
- "Share Score" button → pre-fills social post

**B. Hanzi Build:**
- `HanziBuildScreen`: shows target character's meaning + pinyin, displays shuffled radical tiles
- Tiles: correct radicals + 2–3 decoy radicals (pulled from other dictionary entries)
- Selection mechanism: tap-to-select (no drag required for MVP, drag-and-drop in V2)
- On correct combination: character animates into place, XP awarded
- Data source: `dictionary/{wordId}.radicals` field

**Exit Criteria:** Both game modes complete full round, write score to Firestore, show end-game screen.

---

## Phase 7 — Social Layer

### ADIM 8: Social Feed + Friends + Leaderboard
**Branch:** `feature/adim-08-social`

Deliverables:
- `SocialRepository`: `followUser()`, `unfollowUser()` — atomically updates both `followers` and `following` lists using Firestore batched writes
- `FeedScreen`: paginated `ListView.builder` reading `posts` collection, ordered by timestamp. Shows posts from followed users only (client-side filter on MVP, Cloud Function fan-out in V2).
- `AutoPostService`: creates Firestore `posts` document automatically when:
  - User reaches a new HSK level
  - User beats personal high score in Duel
  - User completes Hanzi Build streak of 10
- `LeaderboardScreen`: two tabs — Global (top 50 by `stats.totalScore`) and Friends. Uses scheduled aggregation (Cloud Function, see ADIM 11) rather than real-time query on full collection.
- `UserProfileScreen`: shows stats, recent posts, follow/unfollow button

**Exit Criteria:** User A follows User B. User B's achievement post appears in User A's feed. Leaderboard shows correct rankings.

---

## Phase 8 — Infrastructure

### ADIM 11: Firebase Cloud Functions
**Branch:** `feature/adim-11-cloud-functions`

Functions to implement:
- `grantAiCredits(uid, amount)` — validates rewarded ad completion server-side, increments `aiCredits`
- `decrementAiCredits(uid)` — called before Gemini query, atomic decrement with floor at 0
- `refreshDailyCredits()` — scheduled daily, resets free users to 5 credits
- `aggregateLeaderboard()` — scheduled every 30 min, writes top 50 to `leaderboard/global` document
- `deleteUserData(uid)` — GDPR: deletes all user documents across collections (ADIM 21)
- `exportUserData(uid)` — GDPR: compiles user data into JSON, stores in Storage for 24h download

**Exit Criteria:** All functions deploy without error. Credit grant/decrement verified via Firebase Console logs.

---

### ADIM 12: FCM Push Notifications
**Branch:** `feature/adim-12-notifications`

Deliverables:
- FCM token registration on app launch, stored in `users/{uid}.fcmToken`
- Notification types:
  - Daily streak reminder (scheduled Cloud Function, 8:00 PM local time)
  - "Friend challenged you" (triggered by ADIM 8 social actions)
  - "New content at your HSK level" (triggered by ADIM 10 pipeline upload)
- Foreground notification handler (shows in-app banner)
- Notification permission request on onboarding (ADIM 13)
- Deep link routing: notification tap navigates to relevant screen via go_router

**Exit Criteria:** Streak reminder notification received on test device. Tap opens app on correct screen.

---

### ADIM 13: Onboarding + HSK Level Test
**Branch:** `feature/adim-13-onboarding`

Deliverables:
- 3-screen onboarding flow (PageView): Value prop → Language selection (tr/en/vi) → HSK level test
- HSK level test: 10 words shown (2 per level, HSK 1–5). User marks known/unknown. Algorithm sets initial `hskLevel`.
- Goal setting: "How many minutes per day?" (5/10/15/20 min) → sets streak reminder time
- Notification permission request (FCM)
- Skip option: defaults to HSK 1
- Writes `hskLevel`, `appLanguage`, `dailyGoalMinutes` to `users/{uid}` on completion

**Exit Criteria:** New user completes onboarding, `users/{uid}` document created with correct `hskLevel`.

---

### ADIM 14: Offline Mode
**Branch:** `feature/adim-14-offline`

Deliverables:
- Hive boxes: `dictionaryBox` (last 200 looked-up words), `videoSegmentBox` (last 10 played segments), `userBox` (current user profile)
- `OfflineRepository` wrapper: tries Firestore first, falls back to Hive on `FirebaseException` or no connectivity
- `ConnectivityBanner`: shown at top of screen when offline
- Dictionary works fully offline for cached words
- Video playback requires connectivity (cannot cache video binary on device)

**Exit Criteria:** App launched in airplane mode shows cached dictionary words and user profile without error.

---

### ADIM 15: Analytics + Crashlytics
**Branch:** `feature/adim-15-analytics`

Deliverables:
- Custom Firebase Analytics events: `video_played`, `quiz_answered`, `word_looked_up`, `game_started`, `game_completed`, `ad_watched`, `premium_purchased`
- User properties: `hsk_level`, `is_premium`, `app_language`
- Crashlytics: enabled for all non-debug builds, custom keys on crash (current screen, user HSK level)
- `AnalyticsService` singleton: wraps all event logging calls

**Exit Criteria:** Events visible in Firebase Console DebugView during test session.

---

### ADIM 16: Firebase Remote Config
**Branch:** `feature/adim-16-remote-config`

Deliverables:
- Remote Config keys:
  - `free_user_interstitial_frequency` (default: 10)
  - `daily_credit_refresh_amount` (default: 5)
  - `max_ai_credits` (default: 20)
  - `enable_hanzi_build` (feature flag, default: true)
  - `onboarding_version` (for A/B test)
- `RemoteConfigService`: fetches and activates on app start (with 1-hour cache)
- All hardcoded thresholds replaced with Remote Config values

**Exit Criteria:** Changing `free_user_interstitial_frequency` in Firebase Console takes effect within 1 hour without app update.

---

## Phase 9 — Platform & DevOps

### ADIM 18: Tablet / Wide-Screen Layout
**Branch:** `feature/adim-18-tablet`

Deliverables:
- Responsive breakpoints: `< 600px` = phone, `≥ 600px` = tablet
- Tablet: two-panel layout on FeedScreen and DictionaryScreen (list + detail side-by-side)
- Video player on tablet: capped at 480px height, centered, with content alongside
- `ResponsiveLayout` helper widget: `phone: Widget, tablet: Widget` factory

**Exit Criteria:** App runs correctly on 10-inch tablet emulator without overflow errors.

---

### ADIM 19: CI/CD Pipeline
**Branch:** `feature/adim-19-cicd`

Deliverables:
- GitHub Actions workflow: on push to `main` — runs `flutter analyze`, `flutter test`, builds APK
- Fastlane `Fastfile`: `beta` lane (uploads to Play Store Internal Testing), `release` lane (promotes to production)
- Secrets management: Firebase credentials and keystore stored in GitHub Secrets
- `flutter test` runs with Firebase emulator (via `firebase-tools` GitHub Action)

**Exit Criteria:** Push to `main` triggers green CI run. Fastlane `beta` lane deploys to Play Store Internal Testing track.

---

## Phase 10 — Polish & Launch

### ADIM 20: Active Voice Revision + Performance
**Branch:** `feature/adim-20-optimization`

Deliverables:
- Full codebase review: rename any passive-voice functions/variables (see naming conventions in CLAUDE.md)
- `dispose()` audit: all `AnimationController`, `VideoPlayerController`, `YoutubePlayerController` properly disposed
- Feed performance: `ListView.builder` confirmed throughout (no `ListView` with pre-built children)
- `RepaintBoundary` around video player and game score widgets
- Image loading: `CachedNetworkImage` everywhere
- `SubscriptionProvider` verified to update across all screens within 1 Firestore write

**Exit Criteria:** `flutter analyze` returns 0 warnings. Profile build shows no jank on mid-range Android device (Pixel 4a class).

---

### ADIM 21: Play Store Release + Security + GDPR
**Branch:** `feature/adim-21-launch`

Deliverables:

**Firestore Security Rules:**
```javascript
// Users can only read/write their own document
match /users/{uid} {
  allow read, write: if request.auth.uid == uid;
  // aiCredits field: read-only from client (writes only via Cloud Functions)
}
// Dictionary and videos: any authenticated user can read, none can write
match /dictionary/{wordId} { allow read: if request.auth != null; }
match /videos/{videoId} { allow read: if request.auth != null; }
// Posts: owner can write, anyone authenticated can read
match /posts/{postId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == resource.data.authorId;
}
```

**GDPR / App Store Compliance:**
- "Delete My Account" button in Settings: calls `deleteUserData` Cloud Function
- "Export My Data" button in Settings: calls `exportUserData` Cloud Function, shows download link
- Privacy Policy screen (WebView to hosted policy URL)
- `android/app/build.gradle`: `minSdkVersion 21`, `targetSdkVersion 34`
- All required AdMob permissions in `AndroidManifest.xml`

**Assets:**
- App icon (1024x1024 source, auto-generated via `flutter_launcher_icons`)
- Splash screen (via `flutter_native_splash`)
- Error screen widget: `NoConnectionScreen`, `GenericErrorScreen`

**Exit Criteria:** App passes Play Store pre-launch report. No policy violations. Firestore rules block unauthorized writes (verified via emulator rule test suite).

---

## Summary

| Phase | Steps | Est. Duration |
|---|---|---|
| 0 — Foundation | Pre-step | 3 days |
| 1 — Data Architecture | ADIM 1, 2 | 1 week |
| 2 — Content Pipeline | ADIM 10, 17 | 1 week |
| 3 — Video Core | ADIM 3 & 4 | 2 weeks |
| 4 — AI Dictionary | ADIM 5 | 1 week |
| 5 — Monetization | ADIM 6, 9 | 1.5 weeks |
| 6 — Gamification | ADIM 7 | 1.5 weeks |
| 7 — Social Layer | ADIM 8 | 1 week |
| 8 — Infrastructure | ADIM 11–16 | 2 weeks |
| 9 — Platform & DevOps | ADIM 18, 19 | 1 week |
| 10 — Polish & Launch | ADIM 20, 21 | 1 week |
| **Total** | | **~14 weeks** |
