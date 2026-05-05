# MANDARIN ACADEMY — PROJECT REFERENCE SNAPSHOT

Updated: 2026-05-05 | Flutter 3.41.9 / Dart 3.11.5 | 0 analyze issues | 3/3 tests pass
ALL 21 ADIM COMPLETE + POST-LAUNCH WORK COMPLETE. Flutter Web platform added for fast iteration.
NO freezed/build_runner — Dart 3.11 incompatibility. All models are pure Dart.

════════════════════════════════════════════════════════════════
FILE TREE
════════════════════════════════════════════════════════════════
lib/
  main.dart                          Firebase.initializeApp + Crashlytics + ProviderScope
  app.dart                           GoRouter(router) + MandarinAcademyApp(ConsumerWidget) + buildTheme()
  firebase_options.dart              PLACEHOLDER — run: flutterfire configure --project=YOUR_PROJECT_ID
  core/
    constants/
      app_colors.dart                AppColors (primary, surface, surfaceVariant, hsk1-6, correctAnswer, wrongAnswer, premiumGold)
      app_config.dart                AppConfig.geminiApiKey (--dart-define=GEMINI_API_KEY=...) + hasGeminiKey
      app_strings.dart               i18n keys
      hsk_constants.dart             HSK level word counts, thresholds
    errors/
      app_exception.dart             sealed AppException → NetworkException, FirestoreException, AiQuotaExceededException, GeminiApiException, AuthException, VideoLoadException
    extensions/
      string_extensions.dart
    utils/
      hsk_analyzer.dart              HskAnalyzer(Map<String,int>)
      translation_helper.dart        TranslationHelper.getDefinition(word, locale)
      character_analyzer.dart        CharacterAnalyzer(Map<String,List[String]>)
      sentence_hash.dart             SentenceHash.buildAiCacheKey(wordId, transcription) → SHA-256
  data/
    models/
      user_model.dart                UserModel + UserStats  (fcmToken: String? added ADIM 12)
      video_segment_model.dart       VideoSegmentModel + QuizData + enum VideoSourceType
      dictionary_model.dart          DictionaryModel + WordDefinitions + AiContextCache
      post_model.dart                PostModel + enum PostType
      game_request_model.dart        GameRequestModel + enum GameRequestStatus
    repositories/
      user_repository.dart           UserRepository
      video_repository.dart          VideoRepository
      dictionary_repository.dart     DictionaryRepository
      social_repository.dart         SocialRepository
    services/
      gemini_service.dart            GeminiService
      ad_service.dart                conditional export: `_ad_service_mobile.dart` | `_ad_service_web.dart` (js_interop)
      `_ad_service_mobile.dart`      AdService — real google_mobile_ads implementation
      `_ad_service_web.dart`         AdService — no-op stub (google_mobile_ads not supported on web)
      credit_service.dart            CreditService
      notification_service.dart      NotificationService — FCM init, token save, deep-link routing
      cache_service.dart             CacheService — Hive boxes for dictionary + video feed offline cache
      analytics_service.dart         AnalyticsService — typed events + Crashlytics identity
      remote_config_service.dart     RemoteConfigService — Firebase Remote Config wrapper with typed getters
    utils/
      responsive_layout.dart         ResponsiveLayout.isTablet/isWide/feedColumnCount/pagePadding
                                     ConstrainedPage widget — centers + constrains to maxContentWidth(960)
  presentation/
    providers/
      auth_provider.dart             authStateProvider, currentUidProvider, isSignedInProvider
      user_provider.dart             userRepositoryProvider, currentUserProvider, isPremiumProvider, currentHskLevelProvider
      video_provider.dart            videoRepositoryProvider, videoFeedProvider, videoPlaybackProvider
      subscription_provider.dart     subscriptionProvider + sealed SubscriptionState
      credit_provider.dart           aiCreditsProvider, canUseAiProvider
      dictionary_provider.dart       dictionaryRepositoryProvider, cacheServiceProvider (overridden in main.dart)
      ai_provider.dart               geminiServiceProvider, creditServiceProvider, remoteConfigProvider,
                                     adServiceProvider, analyticsServiceProvider, fcmInitProvider
      game_provider.dart             mandarinDuelProvider(hskLevel), hanziBuildProvider(hskLevel)
      social_provider.dart           socialRepositoryProvider, feedProvider, leaderboardProvider(hskLevel?),
                                     incomingRequestsProvider, userSearchProvider, socialActionsProvider
      purchase_provider.dart         purchaseProvider — PurchaseNotifier + PurchaseState + PurchasePlan enum
      onboarding_provider.dart       onboardingProvider — OnboardingNotifier + OnboardingState + PlacementQuestion
      connectivity_provider.dart     isOnlineProvider — StreamProvider[bool] via connectivity_plus
    screens/
      home/
        home_screen.dart             HomeScreen — video feed; phone=ListView, tablet=2-col grid, wide=3-col grid
      video_player/
        video_player_screen.dart     VideoPlayerScreen(videoId) — full playback + quiz + subtitle + word detail
                                     Wide: Row(player 3/5 | side word-detail panel 2/5)
      onboarding/
        onboarding_screen.dart       OnboardingScreen — 5-step PageView: Welcome→SignIn→Profile→Test→Results
      dictionary/                    PLACEHOLDER — standalone search screen (ADIM 5 UI done in sheet)
      games/mandarin_duel/
        mandarin_duel_screen.dart    MandarinDuelScreen — 10-question quiz, 10s timer, 3 lives + rewarded-ad life restore
      games/hanzi_build/
        hanzi_build_screen.dart      HanziBuildScreen — tap radical tiles to build a character
      social/
        social_screen.dart           SocialScreen — phone: 3 tabs; wide: Feed(3/5) | Leaderboard+Friends(2/5)
      subscription/
        subscription_screen.dart     SubscriptionScreen — paywall (feature table, plan selector) + PremiumActiveView
      legal/
        terms_screen.dart            TermsScreen — ToS (12 sections, route: /legal/terms)
        privacy_policy_screen.dart   PrivacyPolicyScreen — GDPR policy (10 sections, route: /legal/privacy)
      settings/                      PLACEHOLDER
    widgets/
      video/
        hybrid_video_player.dart     HybridVideoPlayer(segment, onVideoCompleted)
        youtube_section_player.dart  YoutubeNativePlayer(segment, onSegmentEnded)
        self_hosted_player.dart      SelfHostedPlayer(segment, onSegmentEnded)
      quiz/
        quiz_overlay.dart            QuizOverlay(quiz, onAnswered)
      ads/
        ad_banner_widget.dart        conditional export: `_ad_banner_mobile.dart` | `_ad_banner_web.dart`
        `_ad_banner_mobile.dart`     AdBannerWidget — BannerAd (google_mobile_ads)
        `_ad_banner_web.dart`        AdBannerWidget — SizedBox.shrink() stub
        reward_ad_widget.dart        RewardAdWidget() — rewarded ad + CF credit grant
      common/
        score_hud.dart               ScoreHud(state) — hearts/score/combo row
        subtitle_bar.dart            SubtitleBar(transcription, pinyin, targetWords, onWordTapped)
        word_detail_sheet.dart       WordDetailSheet(wordId, transcription, hskLevel) — draggable bottom sheet
web/
  index.html                         Flutter Web entry point — loading spinner, Firebase SDK, flutter_bootstrap.js
  manifest.json                      PWA manifest (standalone, theme #121212)
  firebase-messaging-sw.js           FCM service worker — handles background push on web
firebase/
  firestore.rules
  firestore.indexes.json
  functions/index.js                 Cloud Functions v2 (Node.js)
  functions/package.json
python/pipeline/
  hsk_analyzer.py       CC-CEDICT loader + HSK level injection → dictionary_seed.json
  youtube_miner.py      yt-dlp subtitle download → VTT/SRT parse → segment → enrich → JSON
  grammar_tagger.py     regex rule-set → QuizCategory (culture/conversation/grammar/listening/characters/vocabulary)
  pinyin_helper.py      pypinyin wrapper → tone-marked pinyin string
  pipeline.py           batch orchestrator: --source youtube|cc; YouTube loop + CC single-video mode
  firestore_uploader.py batch-writes JSON docs to Firestore; createdAt=None → SERVER_TIMESTAMP
  cc_video_finder.py    Internet Archive search → CC-BY/CC-BY-SA Chinese videos → metadata JSON
  cc_video_processor.py download video → upload to Firebase Storage/R2 → subtitle/Whisper → segments
requirements.txt        firebase-admin, yt-dlp, jieba, pypinyin, internetarchive, faster-whisper, boto3, ruff, mypy

════════════════════════════════════════════════════════════════
MODELS
════════════════════════════════════════════════════════════════

── UserModel ──────────────────────────────────────────────────
fields: uid, displayName, email, photoUrl, hskLevel(int), isPremium(bool),
        aiCredits(int), followers(List[String]), following(List[String]),
        learnedWords(List[String]), stats(UserStats), isOnline(bool,default false),
        fcmToken(String?, optional — only written if non-null), createdAt(DateTime)
factory: fromFirestore(DocumentSnapshot)
methods: toFirestore(), copyWith(...)
getters: canUseAiDictionary → isPremium||aiCredits>0 | stretchLevel → (hskLevel+1).clamp(1,6)

── UserStats ──────────────────────────────────────────────────
fields: totalScore, videosWatched, questionsAnswered, currentStreak (all int, default 0)
factory: fromMap(Map) | methods: toMap(), copyWith(...)

── VideoSegmentModel ──────────────────────────────────────────
enum VideoSourceType { youtube, selfHosted }
fields: videoId, sourceType(VideoSourceType), youtubeId?(String), videoUrl?(String),
        startTime(double), endTime(double), hskLevel(int), transcription, pinyin,
        targetWords(List[String]), quiz(QuizData), isActive(bool), createdAt(DateTime)
factory: fromFirestore(DocumentSnapshot) — 'self_hosted' string maps to .selfHosted
methods: toFirestore()
getters: durationSeconds | isYouTube | isSelfHosted

── QuizData ───────────────────────────────────────────────────
fields: question, correctAnswer, wrongAnswer (all String)
factory: fromMap(Map) | methods: toMap()

── DictionaryModel ────────────────────────────────────────────
fields: wordId, simplified, traditional, pinyin, hskLevel(int),
        definitions(WordDefinitions), aiContextCache(Map<String,AiContextCache>),
        radicals(List[String]), strokeCount(int)
factory: fromFirestore(DocumentSnapshot)
methods: toFirestore(), hasCachedContext(hash), buildCachedContext(hash)→AiContextCache?,
         copyWithCache(hash, AiContextCache)

── WordDefinitions ────────────────────────────────────────────
fields: tr(String), en(String), vi(String, default '')
factory: fromMap(Map) | methods: toMap()

── AiContextCache ─────────────────────────────────────────────
fields: explanation(String), grammarNote(String), cachedAt(DateTime)
factory: fromMap(Map) | methods: toFirestoreMap()
NOTE: uses toFirestoreMap() NOT toFirestore() (different from all other models)

── PostModel ──────────────────────────────────────────────────
enum PostType { achievement, score, challenge, text }
fields: postId, authorId, content, attachmentUrl?(String), likes(List[String]),
        postType(PostType), metadata(Map<String,dynamic>), timestamp(DateTime)
factory: fromFirestore(DocumentSnapshot) — uses switch on postType string
methods: toFirestore()
getters: likeCount | hasLiked(uid)

── GameRequestModel ───────────────────────────────────────────
enum GameRequestStatus { pending, accepted, declined, expired }
fields: requestId, fromUid, toUid, hskLevel(int), status(GameRequestStatus), createdAt(DateTime)
factory: fromFirestore(DocumentSnapshot)
methods: toFirestore()
Firestore collection: gameRequests/{requestId}

════════════════════════════════════════════════════════════════
REPOSITORIES
════════════════════════════════════════════════════════════════

── UserRepository(firestore?, auth?) ─────────────────────────
watchCurrentUser() → Stream[UserModel?]
loadUser(uid) → Future[UserModel?]
createUser(UserModel) → Future[void]
updateUserStats(uid, UserStats) → Future[void]        stats.toMap() ← NOT toJson()
markWordLearned(uid, wordId) → Future[void]           FieldValue.arrayUnion
updateHskLevel(uid, newLevel) → Future[void]

── VideoRepository(firestore?) ───────────────────────────────
loadSegmentsForLevel(hskLevel) → Future[List[VideoSegmentModel]]
  query: hskLevel<=level+1, isActive==true, orderBy createdAt desc, limit 20
loadSegment(videoId) → Future[VideoSegmentModel?]
loadSegmentsForGame(hskLevel, {limit:10}) → Future[List[VideoSegmentModel]]
  query: hskLevel==level, isActive==true, shuffled

── DictionaryRepository(firestore?, cache) ──────────────────────
loadWord(wordId) → try Firestore → cache result; catch: return _cache.loadCachedWord()
loadWordsForIds(wordIds) → try Firestore; catch: return `_cache`.loadCachedWordsForIds()
saveAiContextCache(wordId, sentenceHash, AiContextCache) → Future[void]
  uses: cache.toFirestoreMap() ← NOT toFirestore()
searchWords(query, {limit:20}) → Firestore prefix query; caches results
loadWordsForLevel(hskLevel, {limit:20}) → single-char, radicals non-empty, shuffled; caches

── SocialRepository(firestore?, auth?) ───────────────────────
watchFeed(followingIds) → Stream[List[PostModel]]
  NOTE: Firestore 'in' max 30 → takes(30)
generatePostId() → String               Firestore auto-ID for new post doc
createPost(PostModel) → Future[void]
toggleLike(postId) → Future[void]       arrayUnion/Remove based on current likes
followUser(targetUid) → Future[void]    batch: add to following + followers
unfollowUser(targetUid) → Future[void]  batch: remove from following + followers
searchUsers(query) → Future[List[UserModel]]
  Firestore prefix query: displayName>=q AND displayName<q+'', limit 20, excludes self
loadLeaderboard({hskLevel?, limit:20}) → Future[List[UserModel]]
  orderBy stats.totalScore desc; optional hskLevel filter
updateOnlineStatus(isOnline) → Future[void]
sendGameRequest(toUid, hskLevel) → Future[void]
  writes gameRequests/{autoId}: fromUid, toUid, hskLevel, status=pending, createdAt
respondToGameRequest(requestId, accepted) → Future[void]
  updates status to accepted|declined
watchIncomingRequests() → Stream[List[GameRequestModel]]
  where toUid==_uid AND status==pending, orderBy createdAt desc

════════════════════════════════════════════════════════════════
SERVICES
════════════════════════════════════════════════════════════════

── GeminiService({required String apiKey}) ───────────────────
model: 'gemini-1.5-flash'
explainWordInContext({simplified, transcription, hskLevel, userLanguage}) → Future[AiContextCache]
  throws: GeminiApiException
  prompt format: EXPLANATION: ... \n GRAMMAR: ...
  languages: tr→Turkish, vi→Vietnamese, _→English

── AdService({required RemoteConfigService}) ────────────────
PLATFORM SPLIT: ad_service.dart is a conditional export.
  Mobile: `_ad_service_mobile.dart` — real google_mobile_ads implementation
  Web:    `_ad_service_web.dart`    — no-op stubs (google_mobile_ads fails to compile on web)
initialize() → Future[void]   MobileAds.initialize() + preloads interstitial + rewarded
recordVideoCompleted()
shouldShowInterstitial → bool   first:>=remoteConfig.interstitialFrequencyFirst, repeat:>=...Repeat
showInterstitialIfEligible() → Future[void]
  GOTCHA: fullScreenContentCallback set BEFORE show(); `_interstitialAd`=null after show()
isRewardedAdReady → bool
showRewardedAd({onReward: Future[void] Function(), onDismissed: VoidCallback}) → Future[void]
  onReward has NO AdMob params (callers don't need AdWithoutView/RewardItem)
dispose()
TEST IDs: interstitial=1033173712, rewarded=5224354917, banner=6300978111
AdBannerWidget: also conditional export (`_ad_banner_mobile.dart` | `_ad_banner_web.dart`)
adServiceProvider: Provider(AdService) — injected remoteConfigProvider; preloads on first access

── RemoteConfigService ───────────────────────────────────────
initialize(): setDefaults + setConfigSettings(10s timeout, 1h interval) + fetchAndActivate (silent fail)
defaults: interstitial_frequency_first=20, interstitial_frequency_repeat=10,
          ai_credits_daily_free=5, max_ai_credits=50,
          min_hsk_videos_required=20, min_learned_words_required=50,
          placement_test_enabled=true, rewarded_ad_credits_amount=10,
          hanzi_build_enabled=true, social_feed_enabled=true
getters: interstitialFrequencyFirst, interstitialFrequencyRepeat, aiCreditsDailyFree,
         maxAiCredits, minHskVideosRequired, minLearnedWordsRequired,
         placementTestEnabled, rewardedAdCreditsAmount, hanziBuildEnabled, socialFeedEnabled
remoteConfigProvider: Provider stub overridden via ProviderScope.overrides in main.dart
  initialize() called in main() before runApp() — fetches live values, falls back to defaults

── CreditService({functions?}) ───────────────────────────────
spendOneCredit() → Future[int]          calls CF 'decrementAiCredits', returns new balance
  throws: AiQuotaExceededException on 'resource-exhausted'
grantCreditsFromAd({amount:10}) → Future[int]  calls CF 'grantAiCredits'
RULE: Client NEVER writes aiCredits to Firestore. Always through Cloud Functions.

════════════════════════════════════════════════════════════════
PROVIDERS (Riverpod — traditional API, NO @riverpod generator)
════════════════════════════════════════════════════════════════
authStateProvider        StreamProvider[User?]           FirebaseAuth.authStateChanges()
currentUidProvider       Provider[String?]               authStateProvider.valueOrNull?.uid
isSignedInProvider       Provider[bool]                  currentUidProvider != null
userRepositoryProvider   Provider[UserRepository]
currentUserProvider      StreamProvider[UserModel?]      watchCurrentUser()
isPremiumProvider        Provider[bool]                  currentUserProvider.valueOrNull?.isPremium
currentHskLevelProvider  Provider[int]                   ...?.hskLevel ?? 1
subscriptionProvider     Provider[SubscriptionState]     loading|free|premium
  sealed SubscriptionState: .loading() | .free() | .premium()
  ext: .showAds→_Free | .isPremium→_Premium | .isLoading→_Loading
aiCreditsProvider        Provider[int]                   ...?.aiCredits ?? 0
canUseAiProvider         Provider[bool]                  isPremium || credits > 0
videoRepositoryProvider  Provider[VideoRepository]
videoFeedProvider        FutureProvider[List[VideoSegmentModel]]
videoPlaybackProvider    StateNotifierProvider[VideoPlaybackNotifier, VideoPlaybackState]
mandarinDuelProvider     StateNotifierProvider.autoDispose.family[MandarinDuelNotifier, DuelState, int](hskLevel)
hanziBuildProvider       StateNotifierProvider.autoDispose.family[HanziBuildNotifier, HanziBuildState, int](hskLevel)
purchaseProvider         StateNotifierProvider.autoDispose[PurchaseNotifier, PurchaseState]

PurchasePlan: monthly | annual
PurchaseStatus: idle | loading | success | error
PurchaseState: selectedPlan(default annual), status, errorMessage?
PurchaseNotifier: selectPlan(plan) | initiatePurchase() | restorePurchases() | clearError()
  REAL IAP: uses in_app_purchase: ^3.2.0; all guarded with kIsWeb (no-op on web)
  init: isAvailable() → listen purchaseStream → queryProductDetails({monthly,annual})
  initiatePurchase(): buyNonConsumable(PurchaseParam) → result via purchaseStream
  restorePurchases(): InAppPurchase.instance.restorePurchases() → result via purchaseStream
  `_handlePurchaseUpdates`: pending→skip; error→state.error; purchased|restored→_verifyAndActivate()
  `_verifyAndActivate()`: calls CF 'verifyPurchase' → CF sets isPremium=true → stream auto-updates
  CONFLICT: import in_app_purchase as `iap` to avoid PurchaseStatus enum clash with our enum
  Product IDs: kProductMonthly='mandarin_academy_premium_monthly'
               kProductAnnual='mandarin_academy_premium_annual'

QuizCategory enum: vocabulary|grammar|listening|characters|conversation|culture
  .fromString(str) | .displayName | .emoji
  stored in VideoSegmentModel.quizCategory (Firestore field: 'quizCategory', default 'vocabulary')

DuelStatus: loading | wheelSpinning | playing | answered | finished | error
DuelState: status, rounds(List[DuelRound]), currentRoundIndex, selectedAnswer?(null=unanswered/''=timeout),
           score, botScore(simulated opponent), combo, livesRemaining(3), secondsRemaining(10),
           wordsSavedForCurrentRound(bool), error?
  currentRound→DuelRound? | wasCorrect→bool? | isLastRound | totalRounds
DuelRound: videoId, question, choices(pre-shuffled at .fromSegment()), correctAnswer, category, targetWords
MandarinDuelNotifier: startGame() | beginQuestion() | submitAnswer(answer) | advanceRound() | saveTargetWords() | restoreOneLife()
  Wheel flow: startGame()→wheelSpinning; UI animates wheel; UI calls beginQuestion()→playing
  Timer.periodic(1s) ticks secondsRemaining; cancel in dispose()
  timeout: selectedAnswer='', lives-1, status=answered|finished; bot score increments randomly
  saveTargetWords(): calls userRepository.markWordLearned per targetWord (best-effort); sets wordsSavedForCurrentRound=true
  restoreOneLife(): only valid when status==finished && livesRemaining<=0; resets to answered+1 life, combo=0
  UI: WheelSection(CustomPainter+AnimationController) → CategoryBadge + AnswerButton + SaveWordButton
  FinishedView: shows "Watch Ad — Restore 1 Life" button when !survived && adService.isRewardedAdReady && !isPremium

HanziBuildStatus: loading | playing | answered | finished | error
HanziBuildState: status, rounds(List[HanziRound]), currentRoundIndex, selectedTiles(List[String]),
                 wasCorrect(bool?), score, combo, secondsRemaining(20), showingHint(bool), error?
  currentRound→HanziRound? | totalRounds
HanziRound: wordId, simplified, pinyin, definitions(WordDefinitions), tiles(pre-shuffled, 4 decoys), correctRadicals
HanziBuildNotifier: startGame() | toggleTile(tile) | submitAnswer() | advanceRound() | requestHint() | dismissHint()
  submitAnswer: sorts selected+correct lists, element-by-element comparison (order-independent); cancels timer
  startMoveTimer(): 20s countdown; timeout → wasCorrect=false, combo=0
  requestHint(): showingHint=true → HintOverlay appears with pinyin+definition in user's locale
  loadWordsForLevel → builds CharacterAnalyzer from radicalMap → buildShuffledTiles(char, 4 decoys)

VideoPlaybackStatus: loading | playing | quizActive | completed
VideoPlaybackState: segment?, status, wasCorrect, combo, hearts(3), score(0)
  comboMultiplier=combo.clamp(1,3) | isAlive=hearts>0 | basePoints=100
VideoPlaybackNotifier:
  loadSegment(segment) | activateQuiz() | recordCorrectAnswer() | recordWrongAnswer() | reset()
  recordCorrectAnswer: combo++, score+=basePoints*multiplier, status=completed
  recordWrongAnswer: combo=0, hearts-1.clamp(0,3), status=completed

════════════════════════════════════════════════════════════════
WIDGETS
════════════════════════════════════════════════════════════════
VideoPlayerScreen(videoId) [ConsumerStatefulWidget]
  initState: loadSegment(videoId) via videoRepositoryProvider → loadSegment(segment) on notifier
  Column (SafeArea): ScoreHud + HybridVideoPlayer + SubtitleBar + Spacer + _CompletionBanner?
  _onVideoCompleted: recordVideoCompleted() + showInterstitialIfEligible() (free users only) → pop after 2s
  _showWordDetail(word): showModalBottomSheet → WordDetailSheet
  _CompletionBanner: green if wasCorrect, red if wrong; shows 正确/再试试

SocialScreen [ConsumerStatefulWidget]
  TabController(3): Feed | Leaderboard | Friends
  AppBar action: IncomingRequestsBadge — dot indicator + bottom sheet for pending challenges
  Feed tab: feedProvider stream, PostCard (like/type icon/metadata chips), CreatePostSheet (FAB)
  Leaderboard tab: HskFilterBar(FilterChip 1-6), LeaderboardRow (rank medal, online dot, totalScore)
  Friends tab: SearchBar → UserSearchNotifier.search(); FollowingList (FutureBuilder loadUser)
    UserTile: online dot, follow/unfollow button, challenge button (online only) → sendGameRequest dialog
  RequestsSheet: accept(✓)/decline(✗) buttons → respondToGameRequest

HomeScreen [ConsumerWidget]  (minimal stub)
  reads: videoFeedProvider, currentHskLevelProvider
  ref.read(adServiceProvider) warm-up call in build → triggers ad preloading early
  ListView of _VideoCard → context.push('/video/${segment.videoId}')

ScoreHud(state) [StatelessWidget]
  Row: hearts(3 icons) | score(text) | combo badge (visible if combo>=2)

SubtitleBar(transcription, pinyin, targetWords, onWordTapped) [StatelessWidget]
  pinyin (muted, 13px) + tappable transcription (22px)
  targetWords sorted by indexOf position → underlined primary-colored GestureDetector
  plain text segments between target words are non-tappable

WordDetailSheet(wordId, transcription, hskLevel) [ConsumerStatefulWidget]
  DraggableScrollableSheet(initial:0.5, min:0.35, max:0.9)
  loadWord(): loads DictionaryModel + auto-detects cache hit (sets aiStatus=cached if found)
  shows: simplified(44px) + traditional + HSK chip + pinyin + definition via TranslationHelper
  AI section driven by _AiStatus enum { idle, loading, cached, fresh, error }
  AI FLOW:
    idle + canUseAi=true  → "Explain (1 credit)" FilledButton → requestExplanation()
    idle + canUseAi=false → "Watch Ad" OutlinedButton (disabled stub, wired in ADIM 6)
    loading  → CircularProgressIndicator + "Generating…"
    cached   → explanation + grammarNote + green "cached" chip (free, no credit used)
    fresh    → explanation + grammarNote + red "fresh" chip
    error    → error message + "Try again" TextButton (resets to idle)
  _requestExplanation(): call Gemini FIRST → spendOneCredit() → saveAiContextCache()
    order prevents credit loss on Gemini failure
    guards: AppConfig.hasGeminiKey check; AiQuotaExceededException resets to idle
  reads: canUseAiProvider (watched), geminiServiceProvider, creditServiceProvider,
         dictionaryRepositoryProvider, SentenceHash.buildAiCacheKey

HybridVideoPlayer(segment, onVideoCompleted) [ConsumerWidget]
  reads: videoPlaybackProvider, subscriptionProvider
  Stack: player + dark overlay if quizActive + QuizOverlay(bottom)
  Column: stack + AdBannerWidget() if showAds
  routes: .youtube→YoutubeNativePlayer | .selfHosted→SelfHostedPlayer

YoutubeNativePlayer(segment, onSegmentEnded) [StatefulWidget]
  CRITICAL API (youtube_player_iframe 4.x):
    controller.loadVideoById(videoId, startSeconds, endSeconds) — NOT params.startAt/endAt
    await controller.currentTime — NOT .value.position (async poll via Timer.periodic 500ms)
  seek deterrent: seconds < startTime-1 → seekTo(startTime)  [ToS compliant, not a block]
  end trigger: seconds >= endTime → pauseVideo() + onSegmentEnded()
  UI: AspectRatio(16/9) + _HskBadge(top-right)

SelfHostedPlayer(segment, onSegmentEnded) [StatefulWidget]
  VideoPlayerController.networkUrl + seekTo(startTime) + ChewieController
  listener: position >= endTime → pause() + onSegmentEnded()

QuizOverlay(quiz, onAnswered) [ConsumerStatefulWidget]
  SlideTransition from bottom (350ms easeOutCubic)
  shuffled answers on init; color feedback after selection
  800ms delay then widget.onAnswered()

AdBannerWidget() — BannerAd listener set IN constructor (listener is final)

RewardAdWidget() [ConsumerStatefulWidget]
  enum: idle | watching | granted | noAd
  idle: "Watch Ad for +10 credits" FilledButton (dark blue)
  watching: disabled button with spinner (ad is full-screen, widget is behind it)
  noAd: text message, auto-reset to idle after 3s
  granted: green "+10 credits added!" — Firestore stream auto-updates canUseAiProvider → widget disappears
  FLOW: isRewardedAdReady? → showRewardedAd() → onReward: grantCreditsFromAd(10) → setState(granted)
  _rewardEarned flag prevents onDismissed from resetting state while CF call is in-flight

════════════════════════════════════════════════════════════════
CORE UTILITIES
════════════════════════════════════════════════════════════════
HskAnalyzer(Map<String,int>): computeSentenceLevel, lookupWordLevel, extractWordsAtLevel, extractAllKnownWords
TranslationHelper.getDefinition(word, locale): tr|vi|en
CharacterAnalyzer(Map<String,List[String]>): buildRadicalList, buildDecoyRadicals, buildShuffledTiles
SentenceHash.buildAiCacheKey(wordId, transcription): SHA-256 of "$wordId|$transcription"

AppColors hex: primary=#E63946 surface=#1A1A2E surfaceVariant=#16213E onSurface=#EEEEEE
  hsk1=#4CAF50 hsk2=#8BC34A hsk3=#FFC107 hsk4=#FF9800 hsk5=#F44336 hsk6=#9C27B0
  correctAnswer=#4CAF50 wrongAnswer=#E63946 premiumGold=#FFD700

════════════════════════════════════════════════════════════════
PYTHON PIPELINE (python/pipeline/)
════════════════════════════════════════════════════════════════

── youtube_miner.py ──────────────────────────────────────────
download_subtitles(url, output_dir) → Path|None
  yt-dlp subprocess: --write-auto-sub --sub-lang zh-Hans,zh --sub-format vtt
  returns first .vtt file found; falls back to .srt
extract_video_id_from_path(sub_path) → str
  parses bracketed [11-char-id] or bare 11-char prefix from yt-dlp filename
parse_vtt(content) → list[dict]
  strips inline timestamps `<00:00:01.234>`, VTT tags `<c>`/`<b>`/etc., collapses whitespace
  deduplicates consecutive identical cues; skips non-Han entries
parse_srt(content) → list[dict]
  regex-based SRT parser; same Han-only filter
build_segments(entries, min_sec=5, max_sec=10) → list[dict]
  merges caption cues into 5-10s windows; force-flushes if duration exceeds max
  drops segments with <3 chars
compute_hsk_level(text, hsk_map) → int
  returns max HSK level of any word found in text
extract_target_words(text, hsk_map, max_words=3) → list[str]
  jieba tokenisation → filter by hsk_map → sort by level desc → top N
  fallback (no jieba): substring scan length 1-4
build_firestore_segment(youtube_id, segment, hsk_map, index) → dict
  fields: videoId, sourceType='youtube', youtubeId, videoUrl=None,
          startTime, endTime, hskLevel, transcription, pinyin,
          targetWords, quizCategory, quiz(empty), isActive=False, createdAt=None
run(url, hsk_map, output_path, sub_file?, min_sec, max_sec)
  full pipeline; prints QuizCategory + HSK breakdown; writes JSON

── grammar_tagger.py ─────────────────────────────────────────
tag_grammar(text) → str (QuizCategory)
  Priority: characters(≤5 Han) → culture → conversation → grammar → listening → vocabulary
  _CULTURE_RE: 节日,春节,长城,孔子,etc.
  _CONVERSATION_RE: 你好,谢谢,请问,etc.
  _GRAMMAR_RE: 把…放/拿/给, 被…了/过, 虽然…但是, 越来越, 一边…一边, etc.
  _LISTENING_RE: 吗/呢/吧 sentence-final, 为什么,什么时候,哪里,多少钱,etc.

── pinyin_helper.py ──────────────────────────────────────────
get_pinyin(text) → str   space-separated tone-marked pinyin via pypinyin

── pipeline.py ───────────────────────────────────────────────
run_pipeline(urls, hsk_map, merged_output, sub_files?, min_sec, max_sec, upload, credentials, collection)
  loops mine_video() per URL → accumulates docs → writes merged JSON → optional upload()
  tmp files `_tmp_pipeline_NNNN.json` cleaned up per URL
run_cc_pipeline(video_url, identifier, hsk_map, merged_output, storage, bucket, ...)
  delegates to cc_video_processor.process_cc_video(), then optionally uploads to Firestore
_upload(docs, credentials, collection)
  inline firebase-admin upload; sets createdAt=SERVER_TIMESTAMP where None
CLI flags: --source youtube|cc (default youtube)
  youtube: --url|--urls-file, --sub-files
  cc: --url (video URL), --identifier, --storage firebase|r2, --bucket, --sub-url,
      --r2-endpoint, --r2-access-key, --r2-secret-key, --whisper-model tiny|base|small|medium|large
  shared: --hsk-map, --output, --min-sec, --max-sec, --upload, --credentials, --collection

── cc_video_finder.py ────────────────────────────────────────
search_ia_videos(query, limit, language_filter) → list[CcVideoMetadata]
  Internet Archive advanced search: mediatype:movies, language:chi, licenseurl CC-BY/CC-BY-SA
  Per result: fetches file listing → picks best video (mp4>webm>ogv) + subtitle (vtt>srt) file
  Filters: ONLY CC-BY and CC-BY-SA (commercial use required for AdMob)
CcVideoMetadata: identifier, title, description, license, language,
                 video_url, subtitle_url?, duration_seconds?, subject
CLI: --query, --limit, --language (ISO 639-2, default 'chi'), --output

── cc_video_processor.py ─────────────────────────────────────
process_cc_video(video_url, identifier, hsk_map, output_path, storage, bucket, ...) → list[dict]
  Steps: (1) download video to tempdir; (2) upload to Firebase Storage or R2; (3) get subtitles or
  run Whisper; (4) build_segments() → build_self_hosted_segment() per segment.
  Returns Firestore-ready docs with sourceType='self_hosted', videoUrl=<hosted_url>, createdAt=None
transcribe_with_whisper(video_path, model_size, language) → list[{start, end, text}]
  faster-whisper: int8 on CPU, VAD filter (300ms silence), Chinese only filter
build_self_hosted_segment(identifier, video_url, segment, hsk_map, index) → dict
  same structure as build_firestore_segment() but sourceType='self_hosted', youtubeId=None

── firestore_uploader.py ─────────────────────────────────────
upload_collection(db, collection, documents, id_field)
  batch.set(merge=True) in chunks of 500
  createdAt=None → SERVER_TIMESTAMP replacement
CLI: --input, --collection, --id-field, --credentials

════════════════════════════════════════════════════════════════
FIRESTORE
════════════════════════════════════════════════════════════════
users/{uid}:       owner read/create/update; doesNotWriteCredits() blocks direct aiCredits write
dictionary/{id}:   authenticated read only
videos/{id}:       authenticated read only
posts/{id}:        authenticated read; owner create/update/delete; create checks authorId==uid
leaderboard/{id}:  authenticated read only (written by CF only)

INDEXES:
  videos: [hskLevel ASC, isActive ASC, createdAt DESC]
  videos: [sourceType ASC, hskLevel ASC, isActive ASC]
  posts:  [authorId ASC, timestamp DESC]
  users:  [hskLevel ASC, stats.totalScore DESC]

CLOUD FUNCTIONS (callable):
  grantAiCredits(amount)         validates <=50, increments
  decrementAiCredits()           transaction, throws resource-exhausted if 0
  deleteUserData()               GDPR — deletes user doc + posts
  exportUserData()               GDPR — returns profile + posts inline
  verifyPurchase(productId, purchaseToken, source)
    verifies Google Play subscription via androidpublisher API (googleapis npm)
    checks paymentState==1|2 AND expiryTimeMillis > now → sets users/{uid}.isPremium=true
    packageName: app.mandarinacademy | requires 'Financial data viewer' role in Play Console
  matchGame(hskLevel)            matchmaking: find opponent ±1 HSK in matchQueue
    → matched=true: creates matches/{id}, removes both from queue, returns {matchId,opponentId,hskLevel}
    → matched=false: adds caller to matchQueue, returns {matched:false}
    resolvedHskLevel = round((callerLevel + opponentLevel) / 2)
  updateHskLevel(newLevel)       advances user 1 level (currentLevel+1 only)
    prerequisites: stats.videosWatched>=20 AND learnedWords.length>=50
    runs in transaction; client NEVER writes hskLevel directly
SCHEDULED:
  refreshDailyCredits        daily midnight — free users aiCredits→5
  aggregateLeaderboard       every 30min — top 50 → leaderboard/global

NEW COLLECTIONS (ADIM 11):
  matchQueue/{uid}: { uid, hskLevel, joinedAt }   — ephemeral; CF manages lifecycle
  matches/{matchId}: { matchId, player1Uid, player2Uid, hskLevel, status, createdAt }

FIRESTORE RULES (updated):
  gameRequests/{id}: fromUid creates; toUid updates (status field only); both can read
  matchQueue/{uid}: owner read/write only
  matches/{matchId}: player1Uid or player2Uid can read; CF writes only

INDEXES (updated):
  matchQueue: [hskLevel ASC, joinedAt ASC]
  gameRequests: [toUid ASC, status ASC, createdAt DESC]

════════════════════════════════════════════════════════════════
CRITICAL GOTCHAS
════════════════════════════════════════════════════════════════

1. Dart 3.11 + freezed crash: "Missing implementation of visitDotShorthandInvocation"
   → NO freezed/build_runner/json_serializable. Pure Dart models only. Permanent decision.

2. youtube_player_iframe 4.x: startAt/endAt REMOVED from params
   → loadVideoById(videoId, startSeconds, endSeconds)
   → position via await controller.currentTime (not .value.position)

3. AiContextCache: toFirestoreMap() NOT toFirestore()
4. UserStats: toMap() NOT toJson()
5. BannerAd.listener is final — must pass to constructor, not set after
6. SocialRepository watchFeed: Firestore 'in' max 30 — always takes(30)
7. YouTube ToS: no technical seek block. Use gamification deterrent (seek → reset + penalize)
8. AdService.showInterstitialIfEligible(): fullScreenContentCallback MUST be set before show(), not after
9. Gemini API key: pass via --dart-define=GEMINI_API_KEY=... (never hardcode). AppConfig.hasGeminiKey guards calls.
10. RewardAdWidget: use _rewardEarned bool flag to prevent onDismissed from overriding granted state during async CF
11. adServiceProvider warm-up: read it in HomeScreen.build() to preload ads before user needs them

════════════════════════════════════════════════════════════════
PUBSPEC DEPENDENCIES
════════════════════════════════════════════════════════════════
flutter_riverpod: ^2.5.1   firebase_core: ^3.3.0      cloud_firestore: ^5.3.0
firebase_auth: ^5.2.0      firebase_storage: ^12.2.0  firebase_messaging: ^15.1.0
firebase_analytics: ^11.2.0 firebase_crashlytics: ^4.1.0 firebase_remote_config: ^5.1.0
cloud_functions: ^5.1.0    google_mobile_ads: ^5.1.0  youtube_player_iframe: ^4.0.3
video_player: ^2.9.1       chewie: ^1.8.3             google_generative_ai: ^0.4.6
hive_flutter: ^1.1.0       go_router: ^14.2.7         cached_network_image: ^3.4.1
crypto: ^3.0.5             intl: ^0.19.0              connectivity_plus: ^6.0.3
shared_preferences: ^2.3.2 url_launcher: ^6.3.0
dev: flutter_test, flutter_lints: ^4.0.0

════════════════════════════════════════════════════════════════
MASTER PLAN STATUS
════════════════════════════════════════════════════════════════
ADIM 1   Firestore Schema + Dart Models           ✅ COMPLETE
ADIM 2   HSK Logic + Multilingual Dictionary      ✅ COMPLETE
ADIM 3&4 Hybrid Video Player + Quiz Overlay       ✅ COMPLETE
ADIM 5   Gemini AI Dictionary                     ✅ COMPLETE
         SPEC UPDATE: Add RAG layer (vector DB — Pinecone/Weaviate) so AI answers
         from CC-CEDICT first, only calls Gemini for synthesis. Eliminates hallucination.
         Grammar analysis (tokenise sentence, label each part) and pronunciation feedback
         (Whisper AI) are future scope on top of this ADIM.
ADIM 6   Credit System + Rewarded Ads             ✅ COMPLETE
         SPEC UPDATE: Also trigger rewarded ads for game lives in MandarinDuel/HanziBuild
         (show "Watch ad to restore 1 life" after lives=0). Wire in ADIM 7 polish pass.
ADIM 7   Mandarin Duel + Hanzi Build              ✅ COMPLETE
         Implemented: 6-category wheel (CustomPainter+AnimationController), bot opponent
         (simulated score), dictionary linking (saveTargetWords on wrong answer),
         HanziBuild timer (20s), multilingual hint overlay, QuizCategory on VideoSegmentModel.
         SPEC UPDATE (future): Real multiplayer matchmaking needs ADIM 8 + 11 first.
         Contextual Scrabble (arrange video characters in order) is a separate game mode.
ADIM 8   Social Feed + Friends + Leaderboard      ✅ COMPLETE
         Implemented: Feed tab (post/like), Leaderboard tab (HSK filter, ranked list, medals),
         Friends tab (search, follow/unfollow, challenge button), incoming requests badge+sheet.
         UserModel.isOnline added. GameRequestModel + gameRequests collection foundation.
         Matchmaking CF (match within ±1 HSK) and FCM game invites deferred to ADIM 11/12.
ADIM 9   AdMob + Premium Subscription             ✅ COMPLETE
         SubscriptionScreen: paywall (feature table Free vs Premium, monthly $9.99/annual $69.99),
         PremiumActiveView for existing premium users, PurchaseNotifier (IAP stub — ADIM 21).
         Rewarded ad for game lives: FinishedView shows "Watch Ad → Restore 1 Life" when
         lives==0 AND isRewardedAdReady AND !isPremium. MandarinDuelNotifier.restoreOneLife() added.
         Remaining ad placements (interstitial cadence, banner Z-index) already done in ADIM 6.
         IAP real wiring (in_app_purchase package + receipt verification CF) deferred to ADIM 21.
ADIM 10  Python YouTube Content Pipeline          ✅ COMPLETE
         grammar_tagger.py: 6-category regex tagger (culture/conversation/grammar/listening/characters/vocabulary)
         pinyin_helper.py: pypinyin tone-marked output
         youtube_miner.py: yt-dlp subprocess (no OAuth), VTT inline-tag stripping, jieba tokenisation,
           deduplication, 5-10s segmentation with force-flush, SERVER_TIMESTAMP sentinel (createdAt=None)
         pipeline.py: multi-URL batch orchestrator; merges all segment JSON; optional Firestore upload
         firestore_uploader.py: SERVER_TIMESTAMP for createdAt=None docs; batch.set(merge=True)
         requirements.txt: added yt-dlp==2024.11.18, jieba==0.42.1, pypinyin==0.51.0
         Channel strategy: Mandarin Corner, Everyday Chinese, ChinesePod, CCTV (embed only).
         Legal note: embed via YouTube IFrame only — never download and re-host.
         Capacity: 800-1000 sentences per 1-hour video → weeks of content from one channel.
ADIM 11  Firebase Cloud Functions                 ✅ COMPLETE
         matchGame(hskLevel): matchQueue lookup ±1 HSK → batch create matches/{id} + delete queue entries
           OR upsert caller into matchQueue. Resolved hskLevel = average of both players (rounded).
         updateHskLevel(newLevel): transaction — validates currentLevel+1, checks videosWatched>=20
           AND learnedWords.length>=50, then updates. Client NEVER writes hskLevel directly.
         Firestore rules extended: gameRequests (create/update guards), matchQueue (owner only), matches (read only)
         Indexes added: matchQueue[hskLevel,joinedAt], gameRequests[toUid,status,createdAt]
         Deploy: firebase deploy --only functions (from firebase/functions/)
ADIM 12  FCM Push Notifications                   ✅ COMPLETE
         NotificationService: registerBackgroundHandler() in main(); initialize(uid, firestore) on sign-in
           saves/refreshes fcmToken to users/{uid}; onMessage→foregroundMessages stream;
           onMessageOpenedApp + getInitialMessage → GoRouter deep-link via setNavigationCallback()
         UserModel.fcmToken: String? field added; written only when non-null; copyWith uses _unset sentinel
         fcmInitProvider: watches currentUidProvider → calls initialize() once on sign-in (read in HomeScreen)
         app.dart: NotificationService.setNavigationCallback(_router.go) wired in build()
         Cloud Functions triggers:
           onMatchCreated (matches/{matchId}): notifies both players via FCM sendEach
           onGameRequestCreated (gameRequests/{requestId}): notifies challenged player
           sendStreakReminder (cron `0 18 * * *`): daily 18:00 UTC, batched 500/call
         Notification data payload: { route: '/games/duel'|'/social'|'/home' }
ADIM 13  Onboarding + HSK Level Test              ✅ COMPLETE
         google_sign_in: ^6.2.1 added to pubspec.
         OnboardingScreen: 5-step AnimatedSwitcher flow
           welcome → signIn → profile → test (20 q) → results → context.go('/home')
         Sign-in options: Google (GoogleSignIn().signIn() → FirebaseAuth credential) + Anonymous
         _handlePostSignIn: checks existing Firestore doc → skips test if user already exists
         Placement test: 20 static questions across HSK 1-6 (4-4 per level approximately)
           Scoring: 0-3→HSK1 | 4-6→HSK2 | 7-9→HSK3 | 10-13→HSK4 | 14-17→HSK5 | 18-20→HSK6
         completeOnboarding(): creates UserModel in Firestore (aiCredits=5, isPremium=false)
         GoRouter auth guard: `_AuthRefreshStream`(FirebaseAuth.authStateChanges()) as refreshListenable
           redirect: !isSignedIn && !isOnboarding → '/onboarding'
           loading state guard: authAsync.isLoading → null (no redirect)
         UserModel.fcmToken copyWith uses `_unset` sentinel (Object? type, identical() check)
ADIM 14   Offline Mode (Hive cache)               ✅ COMPLETE
         CacheService: Hive.initFlutter() + openBoxes() in main.dart (before runApp)
           Box[String] dictionary_cache — key: wordId, value: JSON (toCacheMap, dates as millis)
           Box[String] video_feed_cache — key: hsk_N (feed) or seg_VIDEO_ID (individual)
         VideoSegmentModel/DictionaryModel: fromCache(id, map) + toCacheMap() factories
           createdAt serialized as millisecondsSinceEpoch (not Timestamp)
           DictionaryModel.fromCache: aiContextCache always empty (not needed offline)
         Repositories: try Firestore first → cache on success; catch any error → return cached
         cacheServiceProvider: Provider stub overridden via ProviderScope.overrides in main.dart
         isOnlineProvider: StreamProvider[bool] via connectivity_plus onConnectivityChanged
ADIM 15   Analytics + Crashlytics                 ✅ COMPLETE
         AnalyticsService: identifyUser (Crashlytics UID + Analytics userId + user properties)
           logSignIn(method) | logOnboardingCompleted(hskLevel)
           logVideoStarted(videoId, hskLevel) | logVideoCompleted(videoId, hskLevel, wasCorrect, quizCategory)
           logAiExplanationRequested(wordId, hskLevel, wasCached)
           logGameStarted(gameType, hskLevel) | logGameCompleted(gameType, hskLevel, score, rounds, survived)
           logRewardedAdWatched(reason) | logSubscriptionScreenViewed()
           logLevelUp(newLevel) | recordNonFatalError(error, stack, reason?)
         analyticsServiceProvider: Provider[AnalyticsService] in ai_provider.dart
         fcmInitProvider extended: calls identifyUser() on sign-in (once per session)
         Event wiring: OnboardingNotifier (logSignIn + logOnboardingCompleted)
           VideoPlaybackNotifier injected with AnalyticsService → logVideoStarted/Completed
           MandarinDuelNotifier → logGameStarted + logGameCompleted in advanceRound()
           HanziBuildNotifier → same pattern
           RewardAdWidget.onReward → logRewardedAdWatched('ai_credits')
           SubscriptionScreen.build → logSubscriptionScreenViewed()
ADIM 16   Firebase Remote Config                  ✅ COMPLETE
         RemoteConfigService: 10 typed flags; fetchAndActivate (silent fail → defaults remain)
         Defaults bundled in-app (setDefaults) so app works before first network fetch
         AdService refactored: now injected with RemoteConfigService; reads frequency from RC
         remoteConfigProvider: stub overridden via ProviderScope.overrides (same pattern as cacheServiceProvider)
         initialize() in main() before runApp(); A/B testing via Firebase Console
ADIM 17   Python CC Content Pipeline V2           ✅ COMPLETE
         cc_video_finder.py: Internet Archive search → CC-BY/CC-BY-SA filter → CcVideoMetadata list
           Only CC-BY and CC-BY-SA licenses accepted (commercial use required for AdMob)
         cc_video_processor.py: download video → upload Firebase Storage or R2 (boto3) →
           subtitles from URL or Whisper transcription → self_hosted segments
           transcribe_with_whisper: faster-whisper int8/CPU + VAD filter
         pipeline.py extended: --source youtube|cc flag; run_cc_pipeline() delegates to cc_video_processor
         requirements.txt: added internetarchive==5.1.0, faster-whisper==1.0.3, boto3==1.35.0
ADIM 18   Tablet / Wide-screen Layout             ✅ COMPLETE
         ResponsiveLayout utility: isTablet(>=600), isWide(>=900), feedColumnCount(1|2|3), pagePadding
         ConstrainedPage widget: centers + constrains child to maxContentWidth=960
         HomeScreen: phone=ListView, tablet=2-col GridView, wide=3-col GridView (childAspectRatio 3.2)
         VideoPlayerScreen: isWide → Row(player | side word-detail panel); `_activeWordId` drives panel
           `_SideWordDetail` inline widget; phone/tablet keeps existing bottom-sheet flow
         SocialScreen: isWide → Feed(3/5) + local TabBar(Leaderboard|Friends)(2/5); phone keeps 3 tabs
ADIM 19   CI/CD (GitHub Actions + Fastlane)       ✅ COMPLETE
         .github/workflows/ci.yml: analyze + test on every push/PR; build AAB on main/master push
           Secrets: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD, GEMINI_API_KEY
         .github/workflows/deploy.yml: manual dispatch; track=internal|alpha|beta|production
           Uses r0adkll/upload-google-play action; Secrets: + PLAY_SERVICE_ACCOUNT_JSON
         fastlane/Fastfile: internal lane (100% rollout) + production lane (10% staged rollout)
         fastlane/Appfile: package=com.mandarin.academy, json_key_file from env
ADIM 20   Active Voice Revision + Performance      ✅ COMPLETE
         const constructors added: `_PremiumHeader`, `_FeatureTable`, `_FeatureTableHeader`, `_Footer`
           + all their call sites updated to const instantiation
         SubscriptionScreen.build: switched from ref.watch(currentUserProvider)→isPremium
           to ref.watch(isPremiumProvider) — avoids re-rendering full UserModel stream
         SubscriptionScreen body: wrapped in ConstrainedPage(maxWidth:640) for wide screens
         Naming: all identifiers verified against Active Voice convention; no renames required
ADIM 21   Play Store Release + Security Rules + GDPR ✅ COMPLETE
         Firestore rules hardened:
           users: create validates required fields, uid==auth.uid, isPremium==false, types correct
                  update blocks direct writes to aiCredits, hskLevel, uid
           posts: non-anonymous create only; content 1-500 chars; postType enum validated
                  likes-only update allowed for any authenticated user (toggle)
           gameRequests: create validates status=='pending'; update only status (accepted|declined)
           gdprConsent/{uid}: new collection — owner create/update; consentGiven+consentTimestamp required
         GDPR: completeOnboarding() now calls `_recordGdprConsent(uid)`
           writes gdprConsent/{uid}: consentGiven, consentTimestamp, appVersion, consentVersion
           Firestore rules enforce: owner-only read, bool+timestamp types required
         Existing CF GDPR functions: deleteUserData() (Art. 17) + exportUserData() (Art. 20)
         IAP real wiring (in_app_purchase + receipt CF): deferred post-launch;
           PurchaseNotifier stub has product IDs (mandarin_academy_premium_monthly/annual)
         Android project not yet generated → run: flutter create --platforms android .
           Release signing: STORE_FILE/STORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD env vars in CI

ALL 21 ADIM COMPLETE. 0 analyze issues.
BLOCKER: firebase_options.dart is placeholder → run: flutterfire configure --project=YOUR_ID
