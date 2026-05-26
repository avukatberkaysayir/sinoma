# Sinoma — Master Roadmap

> Platform: **Flutter Web** → Vercel | Backend: **Supabase** (Postgres + Auth + Edge Functions)
> Live: https://sinoma-two.vercel.app

## Legend
- ✅ Tamamlandı
- 🔶 Kısmen tamamlandı (stub veya eksik parçası var)
- ⬜ Yapılmadı

---

## Phase 0 — Project Foundation ✅

### Pre-Step: Flutter Project + Infrastructure
- ✅ Flutter Web projesi (`sinoma`)
- ✅ `pubspec.yaml` — tüm paketler
- ✅ Supabase projesi (`pqyceostpukueydwuiut.supabase.co`)
- ✅ `supabase/schema.sql` — Postgres schema + RLS + RPC fonksiyonları
- ✅ Vercel deployment (CI/CD: GitHub Actions → `vercel deploy --prod`)
- ✅ `.deploy.env` credential yönetimi
- ✅ Hive offline cache başlatma

---

## Phase 1 — Data Architecture ✅

### ADIM 1: Supabase Schema + Dart Models ✅
- ✅ `UserModel`, `VideoSegmentModel`, `DictionaryModel`, `PostModel`
- ✅ `fromMap` / `toMap` (snake_case ↔ camelCase)
- ✅ Supabase tabloları: `users`, `videos`, `dictionary`, `posts`, `game_requests`, `gdpr_consent`, `pipeline_jobs`
- ✅ RLS politikaları (admin-only write, authenticated read)
- ✅ Composite index'ler (`idx_videos_hsk_active`, `idx_videos_category` vb.)

### ADIM 2: HSK Logic + Multilingual Dictionary ✅
- ✅ `HSKAnalyzer` — cümle HSK skoru (en yüksek kelimeden)
- ✅ `TranslationHelper` — tr/en/vi tanım seçici
- ✅ Admin panel: CC-CEDICT + HSK 1–6 sözlük seed (2513 HSK6 kelime dahil)
- ✅ `hsk_level` tüm dictionary kayıtlarında atanmış

---

## Phase 2 — Content Pipeline ✅

### ADIM 10: Python YouTube Pipeline V1 ✅
- ✅ `youtube_miner.py` — yt-dlp 19-strateji matrisi (TV embedded / mweb / web / android)
- ✅ `youtube_asr_pipeline.py` — Whisper ASR + HSK analizi + Supabase insert
- ✅ `pipeline_poller.py` — Supabase `pipeline_jobs` tablosunu poll eder (5s)
- ✅ Altyazı öncelikli, Whisper fallback
- ✅ Batch insert (10'luk) + anlık ilerleme güncellemesi
- ✅ `_probe_accessible()` — IP bloğu vs gerçek erişilemezlik ayırt eder
- ✅ Windows Task Scheduler — `KandaoPipelineServer` oturum açılınca başlar
- ✅ Admin panel: YouTube import sekmesi (elapsed timer, canlı video listesi, HSK filtresi)

### ADIM 17: Python Pipeline V2 — Self-hosted ⬜
- ⬜ Cloudflare R2 bucket kurulumu
- ⬜ Video indirme + R2 yükleme
- ⬜ `sourceType: 'self_hosted'` uçtan uca test

---

## Phase 3 — Video Core ✅

### ADIM 3 & 4: Hybrid Video Player + Quiz Overlay ✅
- ✅ `VideoSegmentModel.sourceType` — `youtube` | `self_hosted`
- ✅ `YoutubeNativePlayer` (IFrame) — startTime'dan başlar, endTime'da durur
- ✅ `SelfHostedPlayer` (video_player + chewie)
- ✅ Seek koruması — segment dışına çıkılırsa startTime'a sıfırlama
- ✅ `QuizOverlay` — 2 seçenek, animasyonlu, skor + combo mantığı
- ✅ `VideoProvider` state machine (loading / playing / quizActive / completed)
- ✅ HSK rozeti (sağ üst)
- ✅ Skor → `users.stats` Supabase'e yazılır
- ✅ VoScreen+YouGlish hybrid inline player (`inline_player_section.dart`)
- ✅ Admin inline video önizleme oynatıcısı (400×225 px)

---

## Phase 4 — AI Dictionary Layer ✅

### ADIM 5: Gemini AI Dictionary + Caching ✅
- ✅ `GeminiService` — Gemini 1.5 Flash, bağlam odaklı açıklama
- ✅ SHA256 cache: `dictionary.ai_context_cache` JSONB alanı
- ✅ `WordDetailSheet` — karakter, pinyin, tanım, AI açıklama, HSK rozeti
- ✅ Kredi kapısı — 0 kredi → `QuotaExceededModal`
- ✅ Temel sözlük fallback (AI olmadan)

---

## Phase 5 — Monetization 🔶

### ADIM 6: Credit System + Rewarded Ads 🔶
- ✅ `CreditService` — Supabase RPC (`decrement_ai_credits`, `grant_ai_credits`)
- ✅ `CreditController` Riverpod (gerçek zamanlı)
- ✅ `QuotaExceededModal` — "Reklam İzle / Premium Ol / Temel Sözlük" üç seçenek
- ✅ `refresh_daily_credits()` Postgres RPC fonksiyonu (migration 001)
- 🔶 `RewardAdWidget` — AdMob stub (web'de gerçek reklam yok)
- ⬜ Günlük kredi yenileme cron — pg_cron etkinleştirilmedi (Supabase Dashboard → Database → Extensions)

### ADIM 9: Web Abonelik + Ödeme 🔶
- ✅ `SubscriptionScreen` — plan kartları, özellik tablosu, fiyatlandırma ($9.99/ay, $69.99/yıl)
- ✅ `SubscriptionProvider` — `isPremium` gerçek zamanlı izlenir
- ✅ Premium kullanıcıda tüm reklamlar kapalı
- ✅ `PremiumGuard` widget
- ✅ `create-checkout-session` Supabase edge function — deploy edildi
- ✅ `stripe-webhook` Supabase edge function — deploy edildi
- ✅ `create-portal-session` Supabase edge function — deploy edildi
- ✅ `migration 002` — `stripe_customer_id` kolonu
- ✅ Admin panel Kullanıcılar sekmesi — premium toggle + AI kredi düzenleme
- 🔶 Stripe API anahtarları Supabase'e girilmedi (Secrets ayarlanmadı)
- ⬜ Stripe Dashboard'da ürün + fiyat oluşturma ($9.99/ay, $69.99/yıl)
- ⬜ Webhook endpoint kaydı: `https://pqyceostpukueydwuiut.supabase.co/functions/v1/stripe-webhook`

---

## Phase 6 — Gamification ✅

### ADIM 7: Mandarin Duel + Hanzi Build ✅
- ✅ `MandarinDuelScreen` — 5 saniyelik geri sayım, can sistemi, combo
- ✅ `HanziBuildScreen` — radikal seçimi, yanlış seçenekler, karakter animasyonu
- ✅ `GameProvider` Riverpod state machine
- ✅ Oyun sonu skoru → Supabase stats güncelleme
- ✅ Sosyal paylaşım post'u (otomatik)

---

## Phase 7 — Social Layer ✅

### ADIM 8: Social Feed + Friends + Leaderboard ✅
- ✅ `SocialRepository` — `followUser`, `unfollowUser` (atomik)
- ✅ `FeedScreen` — sayfalandırılmış `ListView.builder`, takip edilenler filtrelenmiş
- ✅ `AutoPostService` — HSK seviye atlaması, skor rekoru → otomatik post
- ✅ Like / comment mekanizması
- ✅ `LeaderboardScreen` — Global + Arkadaşlar sekmeleri
- ✅ `UserProfileScreen`
- ✅ Admin sosyal yönetim sekmesi — post moderasyon, kullanıcı sayıları
- ✅ Admin oyun yönetim sekmesi — game requests + leaderboard

---

## Phase 8 — Infrastructure ✅

### ADIM 11: Supabase Backend Functions ✅
- ✅ `decrement_ai_credits()` — Supabase RPC
- ✅ `grant_ai_credits(p_amount)` — Supabase RPC
- ✅ `refresh_daily_credits()` — Supabase RPC (migration 001)
- ✅ `remove_user_from_social_arrays()` — GDPR temizleme RPC
- ✅ RLS — `aiCredits` client'tan doğrudan yazılamaz
- ✅ `delete-user` edge function — GDPR hesap silme
- ✅ `export-user-data` edge function — GDPR veri dışa aktarma
- ⬜ Günlük kredi yenileme cron (pg_cron: `0 0 * * *` → `refresh_daily_credits()`)

### ADIM 12: Push Notifications ⬜
- Kapsam dışı bırakıldı — web-native push API (ileride)

### ADIM 13: Onboarding + HSK Level Test ✅
- ✅ 3-ekranlı PageView onboarding
- ✅ 10-soruluk HSK yerleştirme testi
- ✅ Dil seçimi (tr/en/vi)
- ✅ Kullanıcı dokümanı oluşturma
- ✅ HSK yeniden test ekranı (`hsk_retest_screen.dart`)

### ADIM 14: Offline Mode ✅
- ✅ Hive cache — dictionary (son 200 kelime) + video feed (HSK başına)
- ✅ `CacheService` — `cacheWord`, `cacheVideoFeed`, `loadCachedVideoFeed`
- ✅ `ConnectivityBanner` — çevrimdışıyken ekranda kırmızı banner
- ✅ `app.dart` — `ConnectivityBanner` ile sarıldı

### ADIM 15: Analytics ✅
- ✅ Vercel Analytics (index.html'de inject edilmiş — sayfa görüntüleme otomatik)
- ✅ `AnalyticsService` — `dart:js` → `window.va('event', ...)` custom event tracking
- ✅ 9 event: sign_in, onboarding_completed, video_started, video_completed, ai_explanation, game_started, game_completed, rewarded_ad, subscription_screen_viewed

### ADIM 16: Remote Config ✅
- ✅ `app_config` Supabase tablosu (migration 003) — 10 varsayılan değer
- ✅ `RemoteConfigService` — Supabase'den fetch eder, 5s timeout, offline fallback
- ✅ Erişilebilir değerler: interstitialFrequency, aiCreditsDaily, maxAiCredits, placementTestEnabled, hanziBuildEnabled, socialFeedEnabled vb.

---

## Phase 9 — Platform & DevOps ✅

### ADIM 18: Tablet / Wide-Screen Layout ✅
- ✅ `SectionNavRail` widget (`NavigationRail`, ikon + etiket, ≥900px)
- ✅ `_AppShell` — geniş ekranda NavRail + `VerticalDivider` + içerik
- ✅ `ResponsiveLayout.isWide(context)` — 900px breakpoint

### ADIM 19: CI/CD ✅
- ✅ GitHub Actions — push'ta `flutter analyze --no-fatal-infos` + build + Vercel deploy
- ✅ GitHub Secrets — `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`
- ✅ Android build job kaldırıldı (web-only proje)
- ✅ `pages.yml` silindi (GitHub Pages kullanılmıyor)

---

## Phase 10 — Polish & Launch

### ADIM 20: Performance + Code Quality ✅
- ✅ Active voice isimlendirme
- ✅ `flutter analyze` — 0 hata, sadece `dart:html` info uyarıları (web-only, beklenen)
- ✅ `dispose()` denetimi (`YoutubePlayerController`, `Timer`, `TabController` vb.)

### ADIM 21: GDPR + Güvenlik ✅
- ✅ `gdpr_consent` Supabase tablosu
- ✅ Privacy Policy ekranı (`/legal/privacy`)
- ✅ Kulüp koşulları ekranı (`/legal/terms`)
- ✅ Supabase RLS — yetkisiz yazma engellendi
- ✅ Admin RLS policy (migration 004) — admin e-posta herhangi bir users satırını güncelleyebilir
- ✅ "Hesabı Sil" butonu Settings ekranında → `delete-user` edge function
- ✅ "Verilerimi İndir" butonu Settings ekranında → `export-user-data` edge function
- ✅ `delete-user` + `export-user-data` Supabase edge function'ları deploy edildi

---

## Yeni — Roadmap'te Olmayan Tamamlananlar

| Özellik | Durum |
|---|---|
| Firebase → Supabase tam geçişi | ✅ |
| Admin paneli (import / yönet / sözlük / seed / kullanıcılar / sosyal / oyun) | ✅ |
| Admin kullanıcı yönetimi — premium toggle + AI kredi düzenleme | ✅ |
| YouTube job queue + pipeline_poller | ✅ |
| VoScreen+YouGlish hybrid inline player | ✅ |
| Çok boyutlu filtre sistemi (HSK / seviye / kategori / yaşam / uzunluk / arama) | ✅ |
| `life_category` alanı (daily_life / business / children) | ✅ |
| Admin inline video önizleme oynatıcısı | ✅ |
| Soft delete + hard delete video yönetimi | ✅ |
| Canlı import ilerleme sayacı | ✅ |
| Stripe edge functions (checkout / webhook / portal) | ✅ deploy edildi |
| Kelime öneri sistemi (posts tablosu + admin sekmesi) | ✅ |

---

## Öncelik Sırası — Kalan Yapılacaklar

| # | Görev | Etki | Efor |
|---|---|---|---|
| 1 | pg_cron etkinleştirme — günlük 5 kredi yenileme | Yüksek (kullanıcı tutma) | Çok Düşük |
| 2 | Stripe API anahtarları Supabase Secrets'e girme | Yüksek (gelir) | Çok Düşük |
| 3 | Self-hosted video pipeline (R2) | Orta | Yüksek |
| 4 | Web push bildirimleri | Düşük | Yüksek |

---

## Özet

| Phase | ADIMLar | Durum |
|---|---|---|
| 0 — Foundation | Pre-step | ✅ Tamam |
| 1 — Data Architecture | ADIM 1, 2 | ✅ Tamam |
| 2 — Content Pipeline | ADIM 10 | ✅ Tamam · ADIM 17 ⬜ |
| 3 — Video Core | ADIM 3 & 4 | ✅ Tamam |
| 4 — AI Dictionary | ADIM 5 | ✅ Tamam |
| 5 — Monetization | ADIM 6, 9 | 🔶 Kredi ✅ · Stripe API anahtarı eksik |
| 6 — Gamification | ADIM 7 | ✅ Tamam |
| 7 — Social Layer | ADIM 8 | ✅ Tamam |
| 8 — Infrastructure | ADIM 11–16 | ✅ Tamam · pg_cron ⬜ |
| 9 — Platform & DevOps | ADIM 18, 19 | ✅ Tamam |
| 10 — Polish & Launch | ADIM 20, 21 | ✅ Tamam |
