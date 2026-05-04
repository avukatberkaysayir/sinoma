# Mandarin Academy — Development Schedule

Start date: 2026-05-04
Target MVP release: 2026-08-17 (15 weeks)
Target full V1.0 release: 2026-08-24 (16 weeks)

---

## Week 1 — Days 1–7 | Project Foundation + Data Architecture

### Days 1–2: Project Setup
- [ ] `flutter create mandarin_academy --org com.mandarinacademy`
- [ ] Configure `pubspec.yaml` with all packages (see CLAUDE.md)
- [ ] Create Firebase project: `mandarin-academy-prod`
- [ ] Create Firebase project: `mandarin-academy-dev` (separate for development)
- [ ] Wire FlutterFire CLI, add `google-services.json`
- [ ] Set up folder structure per CLAUDE.md
- [ ] Initialize Git, first commit

**Checkpoint:** `flutter run` on emulator shows blank app. Firebase console shows app connected.

### Days 3–5: ADIM 1 — Firestore Schema + Dart Models
- [ ] Write `UserModel` with freezed
- [ ] Write `VideoSegmentModel` with `sourceType` enum
- [ ] Write `DictionaryModel` with `aiContextCache` map
- [ ] Write `PostModel`
- [ ] Generate `fromJson`/`toJson` via `build_runner`
- [ ] Write `firestore.indexes.json`
- [ ] Seed script: 5 users, 10 words, 5 video segments in emulator

**Checkpoint:** All models serialize correctly. Emulator shows seed data.

### Days 6–7: ADIM 2 — HSK Logic
- [ ] Write `HSKAnalyzer` class and unit tests
- [ ] Write `TranslationHelper` (tr/en/vi)
- [ ] Write `CharacterAnalyzer` (radicals)
- [ ] Python: load CC-CEDICT, inject HSK levels, output JSON for 1000 words

**Checkpoint:** `flutter test` passes for HSK analyzer. Python script outputs valid JSON.

---

## Week 2 — Days 8–14 | Content Pipeline + Video Player Start

### Days 8–10: ADIM 10 — Python Pipeline V1
- [ ] Set up Python environment (`venv`, `requirements.txt`)
- [ ] Implement YouTube Data API v3 caption fetch (official API)
- [ ] Segment captions into 5–10 second chunks
- [ ] HSK level assignment per segment
- [ ] Firestore batch upload
- [ ] Test with 1 CC-licensed YouTube video (manually selected)

**Checkpoint:** Pipeline processes 1 video, uploads ≥ 3 segments to dev Firestore.

### Days 11–14: ADIM 3 & 4 — Video Player (Part 1: Architecture)
- [ ] `VideoProvider` Riverpod state machine (loading/playing/quizActive/completed)
- [ ] `YoutubeNativePlayer` widget: start at `startTime`, listen to position
- [ ] Pause + quiz trigger at `endTime`
- [ ] Seek behavior: reset to `startTime` if out of bounds
- [ ] HSK badge overlay (top-right)
- [ ] Loading animation

**Checkpoint:** YouTube clip plays from defined start time, pauses at end time, no crash.

---

## Week 3 — Days 15–21 | Video Core Completion + Quiz System

### Days 15–17: ADIM 3 & 4 — Video Player (Part 2: Self-hosted + Quiz)
- [ ] `SelfHostedPlayer` widget (video_player + chewie)
- [ ] Player router: reads `sourceType`, renders correct widget
- [ ] `QuizOverlay` widget: animates up, shows 2 options
- [ ] Correct/wrong answer handlers
- [ ] `ScoreMultiplier` (combo logic)
- [ ] Score write to Firestore `users/{uid}.stats`
- [ ] AdMob banner placeholder below player (free users)

**Checkpoint:** Both YouTube and self-hosted paths play and quiz correctly. Score writes to Firestore.

### Days 18–21: ADIM 5 — AI Dictionary (Part 1)
- [ ] `GeminiService`: API call with prompt template
- [ ] Cache check: SHA256 hash lookup in Firestore
- [ ] `WordDetailSheet` bottom sheet UI
- [ ] Subtitle word tap detection (overlay)
- [ ] Credit gate check (reads `aiCredits`, shows modal if zero)

**Checkpoint:** Tap word in subtitle → see Gemini explanation. Tap same word again → cached response (no API call).

---

## Week 4 — Days 22–28 | AI Layer + Credit System

### Days 22–23: ADIM 5 — AI Dictionary (Part 2)
- [ ] `QuotaExceededModal` with three options
- [ ] "Use Basic Dictionary" fallback path (no AI, standard definition from Firestore)
- [ ] Error handling for Gemini API failures

**Checkpoint:** Full dictionary flow works end-to-end including credit gate.

### Days 24–26: ADIM 11 — Cloud Functions (Core)
- [ ] Set up Firebase Functions project (Node.js)
- [ ] `decrementAiCredits(uid)` function
- [ ] `grantAiCredits(uid, amount)` function
- [ ] `refreshDailyCredits()` scheduled function
- [ ] Deploy to dev Firebase project

**Checkpoint:** Client calls Cloud Function to decrement credits. Direct Firestore write to `aiCredits` blocked by security rules.

### Days 27–28: ADIM 6 — Credit System + Rewarded Ads
- [ ] `CreditController` Riverpod (real-time listener)
- [ ] `RewardAdWidget`: AdMob Rewarded Ad integration (test unit IDs)
- [ ] On reward callback → call `grantAiCredits` Cloud Function
- [ ] Wire `QuotaExceededModal` to `RewardAdWidget`

**Checkpoint:** Watch rewarded ad → credits go from 0 to 10 → AI dictionary works again.

---

## Week 5 — Days 29–35 | Monetization

### Days 29–32: ADIM 9 — AdMob + Premium
- [ ] `AdManager` singleton with interstitial counter logic
- [ ] `AdBannerWidget` (free users only)
- [ ] `SubscriptionProvider` (real-time `isPremium` listener)
- [ ] All ads disabled when `isPremium == true`
- [ ] `SubscriptionScreen` UI (plan cards)
- [ ] `PremiumGuard` wrapper widget
- [ ] `payWithStore()` stub

**Checkpoint:** Toggle `isPremium` in Firestore → all ads disappear across app within seconds.

### Days 33–35: Integration + Buffer
- [ ] End-to-end test: free user journey (video → quiz → AI dictionary → rewarded ad → credits → AI again)
- [ ] End-to-end test: premium user journey (no ads, no credit limit)
- [ ] Fix any integration issues found

---

## Week 6 — Days 36–42 | Gamification

### Days 36–39: ADIM 7 — Mandarin Duel
- [ ] `MandarinDuelScreen` layout
- [ ] `GameLogic` class: hearts, score, combo multiplier
- [ ] `AnimationController` countdown timer bar (5 seconds)
- [ ] Video plays, timer runs, quiz appears at end
- [ ] Score write to Firestore on game over
- [ ] "Share Score" button (posts to social feed stub)
- [ ] End-game screen with stats

**Checkpoint:** Full Duel game round completes, score written to Firestore.

### Days 40–42: ADIM 7 — Hanzi Build
- [ ] `HanziBuildScreen` layout
- [ ] Radical tile generation (correct + decoys from dictionary)
- [ ] Tap-to-select mechanism
- [ ] Correct combination detection
- [ ] Character assembly animation (simple scale/fade)
- [ ] XP award

**Checkpoint:** User selects correct radicals for a character, animation plays, XP awarded.

---

## Week 7 — Days 43–49 | Social Layer

### Days 43–46: ADIM 8 — Social Feed + Follow
- [ ] `SocialRepository`: `followUser()`, `unfollowUser()` with batched writes
- [ ] `FeedScreen` with paginated `ListView.builder`
- [ ] `AutoPostService`: triggers on HSK level up, high score
- [ ] Post card widget with like button
- [ ] `UserProfileScreen`

**Checkpoint:** Follow a user → their posts appear in feed.

### Days 47–49: ADIM 8 — Leaderboard
- [ ] `aggregateLeaderboard` Cloud Function (ADIM 11 extension)
- [ ] `LeaderboardScreen`: Global tab + Friends tab
- [ ] Rank card widget

**Checkpoint:** Leaderboard shows correct top 10. Updates within 30 minutes of score change.

---

## Week 8 — Days 50–56 | Infrastructure Block 1

### Days 50–52: ADIM 12 — FCM Notifications
- [ ] FCM token registration + storage
- [ ] Streak reminder (scheduled Cloud Function)
- [ ] Foreground notification banner
- [ ] Deep link routing via go_router
- [ ] Notification permission in onboarding flow (prep for ADIM 13)

**Checkpoint:** Streak reminder received on test device. Tap opens correct screen.

### Days 53–56: ADIM 13 — Onboarding
- [ ] 3-screen PageView onboarding
- [ ] 10-word HSK placement test
- [ ] Goal setting (daily minutes)
- [ ] Notification permission request
- [ ] User document creation on completion
- [ ] Skip flow

**Checkpoint:** New user completes onboarding. `users/{uid}` document created with correct initial values.

---

## Week 9 — Days 57–63 | Infrastructure Block 2

### Days 57–59: ADIM 14 — Offline Mode
- [ ] Hive setup (dictionary box, video box, user box)
- [ ] `OfflineRepository` wrapper with Firestore fallback
- [ ] `ConnectivityBanner` widget

**Checkpoint:** App in airplane mode shows cached dictionary and user profile.

### Days 60–61: ADIM 15 — Analytics + Crashlytics
- [ ] Custom events wired at key user actions
- [ ] User properties set on auth
- [ ] Crashlytics enabled for non-debug builds
- [ ] `AnalyticsService` singleton

**Checkpoint:** Events visible in Firebase DebugView.

### Days 62–63: ADIM 16 — Remote Config
- [ ] Remote Config keys defined in Firebase Console
- [ ] `RemoteConfigService` fetches on startup
- [ ] Hardcoded thresholds replaced with Remote Config values

**Checkpoint:** Changing ad frequency in Firebase Console takes effect.

---

## Week 10 — Days 64–70 | Platform + Content Pipeline V2

### Days 64–66: ADIM 17 — Python Pipeline V2
- [ ] Cloudflare R2 bucket setup
- [ ] Video download + R2 upload flow
- [ ] `sourceType: 'self_hosted'` path verified end-to-end

**Checkpoint:** Self-hosted video uploaded to R2, plays in app.

### Days 67–70: ADIM 18 — Tablet Layout
- [ ] `ResponsiveLayout` helper
- [ ] Tablet two-panel layouts for Feed and Dictionary
- [ ] Video player sizing on tablet
- [ ] Test on 10-inch emulator

**Checkpoint:** No overflow errors on tablet. Two-panel layout works.

---

## Week 11 — Days 71–77 | Cloud Functions Completion + CI/CD

### Days 71–73: ADIM 11 — Cloud Functions (GDPR)
- [ ] `deleteUserData` function
- [ ] `exportUserData` function
- [ ] All Cloud Functions deployed to prod Firebase project

### Days 74–77: ADIM 19 — CI/CD
- [ ] GitHub Actions: analyze + test + build on push to main
- [ ] Fastlane `Fastfile` with `beta` and `release` lanes
- [ ] GitHub Secrets configured (Firebase credentials, keystore)
- [ ] Firebase emulator in CI pipeline

**Checkpoint:** Push to `main` → green CI run. Fastlane `beta` deploys to Play Store Internal Testing.

---

## Week 12 — Days 78–84 | Polish + Launch Prep

### Days 78–81: ADIM 20 — Optimization
- [ ] Active Voice naming audit across codebase
- [ ] `dispose()` audit (no memory leaks)
- [ ] `RepaintBoundary` on heavy widgets
- [ ] `flutter analyze` → 0 warnings
- [ ] Profile build on mid-range device — no jank

### Days 82–84: ADIM 21 — Security + GDPR (Part 1)
- [ ] Firestore Security Rules written
- [ ] Security rules tested against emulator rule test suite
- [ ] "Delete Account" and "Export Data" buttons in Settings

---

## Week 13 — Days 85–91 | Launch

### Days 85–87: ADIM 21 — Launch Assets + Store Listing
- [ ] App icon (1024x1024) + `flutter_launcher_icons`
- [ ] Splash screen + `flutter_native_splash`
- [ ] `NoConnectionScreen`, `GenericErrorScreen` widgets
- [ ] `android/app/build.gradle` final configuration
- [ ] `AndroidManifest.xml` permissions

### Days 88–91: Play Store Submission
- [ ] Generate signed release APK / AAB
- [ ] Play Store listing: screenshots, description (tr + en), feature graphic
- [ ] Privacy Policy hosted and linked
- [ ] Submit to Internal Testing track
- [ ] Address pre-launch report findings

**MVP Release: Week 13 End (2026-08-03)**

---

## Week 14–15 — Days 92–105 | Beta Feedback + V1.0

- Collect Internal Testing feedback
- Fix critical bugs
- Polish animations and edge cases
- Submit to Production track

**V1.0 Public Release: 2026-08-17**

---

## Milestones Summary

| Milestone | Target Date | Criteria |
|---|---|---|
| Data layer complete | 2026-05-18 | Models + HSK logic tested |
| Video plays + quiz works | 2026-05-31 | Full video flow end-to-end |
| AI dictionary live | 2026-06-07 | Gemini + cache + credit gate |
| Monetization complete | 2026-06-21 | Ads + premium verified |
| Games complete | 2026-06-28 | Both game modes working |
| Social layer complete | 2026-07-05 | Feed + leaderboard working |
| Infrastructure complete | 2026-07-26 | All 21 adım done |
| MVP submitted to Play Store | 2026-08-03 | Internal testing track |
| V1.0 public release | 2026-08-17 | Production track |

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| YouTube IFrame ToS change | Low | High | Hybrid player already handles self-hosted fallback |
| Gemini API rate limits | Medium | Medium | Aggressive caching, credit throttling |
| CC-CEDICT data quality gaps | Medium | Low | Manual curation for HSK 1–3 words first |
| Play Store review rejection | Medium | Medium | 2-week buffer before target release date |
| Cloudflare R2 migration complexity | Low | Low | MVP uses Firebase Storage; R2 migration is data-only |
