# Sinoma — Geliştirme Takvimi

Başlangıç: 2026-05-04
Durum güncellemesi: 2026-05-22

> Platform değişikliği: Firebase → **Supabase**, Android/iOS → **Flutter Web (Vercel)**

---

## ✅ Tamamlanan Çalışmalar (2026-05-04 → 2026-05-22)

| Tarih | Yapılan |
|---|---|
| Hf 1 | Flutter projesi kurulumu, Supabase şeması, Dart modelleri |
| Hf 1 | Firebase → Supabase tam geçişi (76 dosya) |
| Hf 1–2 | HSK 1–6 sözlük seed (CC-CEDICT + ~2513 HSK6 kelime) |
| Hf 2 | Python pipeline (yt-dlp + Whisper ASR + altyazı extraction) |
| Hf 2 | YouTube job queue (`pipeline_jobs` + `pipeline_poller.py`) |
| Hf 2 | Hybrid video player (YouTube IFrame + self-hosted + VoScreen) |
| Hf 2 | Quiz overlay + skor sistemi |
| Hf 2–3 | Gemini AI dictionary + SHA256 cache + WordDetailSheet |
| Hf 3 | Kredi sistemi (Supabase RPC) + QuotaExceededModal |
| Hf 3 | Subscription ekranı (paywall UI, plan kartları) |
| Hf 3 | Mandarin Duel + Hanzi Build oyunları |
| Hf 3 | Sosyal feed, leaderboard, takip/takipten çık |
| Hf 3 | Onboarding + HSK yerleştirme testi |
| Hf 3–4 | Admin paneli (import / yönet / sözlük / seed sekmeleri) |
| Hf 4 | Çok boyutlu filtre sistemi (5 filtre + arama) |
| Hf 4 | `life_category` alanı ve filtresi |
| Hf 4 | Admin inline video oynatıcı (400×225 px) |
| Hf 4 | Soft delete + hard delete video yönetimi |
| Hf 4 | Canlı import ilerleme sayacı + elapsed timer |
| Hf 4 | Vercel CI/CD (GitHub Actions) |

---

## Aktif Sprint — Hf 5 (2026-05-22 → 2026-05-29)

### Gün 1–2: Günlük Kredi Yenileme (ADIM 11 — pg_cron)
- [ ] Supabase'de `pg_cron` extension aktifleştir
- [ ] `refresh_daily_credits()` SQL fonksiyonu yaz
- [ ] Cron job: gece 00:00 UTC, `is_premium = false` kullanıcılara 5 kredi
- [ ] Admin panelinden manuel tetikleme butonu ekle

### Gün 3–4: GDPR — Hesap Silme + Veri İndirme (ADIM 21)
- [ ] Settings ekranına "Hesabı Sil" butonu
- [ ] Supabase Edge Function: `delete-user-data` (cascade siler)
- [ ] Settings ekranına "Verilerimi İndir" butonu
- [ ] Supabase Edge Function: `export-user-data` (JSON döner)

### Gün 5: ConnectivityBanner + Offline Fallback (ADIM 14)
- [ ] `ConnectivityBanner` widget — ağ yokken ekran üstünde gösterilir
- [ ] `VideoRepository.loadSegmentsForLevel` → ağ hatasında Hive fallback
- [ ] `DictionaryRepository.findWord` → ağ hatasında Hive fallback

---

## Hf 6 (2026-05-30 → 2026-06-05): Stripe Web Ödeme (ADIM 9)

- [ ] Stripe hesabı aç, web product/price oluştur (monthly $9.99, annual $69.99)
- [ ] Supabase Edge Function: `create-checkout-session` (Stripe Checkout Session yaratır)
- [ ] Flutter: `_SubscribeButton` → Supabase edge function çağır → `launchUrl(checkoutUrl)`
- [ ] Stripe webhook → Supabase Edge Function: `stripe-webhook` → `is_premium = true` yaz
- [ ] Subscription başarı sayfası (`/subscription/success`)
- [ ] Test: Stripe test kartıyla uçtan uca ödeme akışı

**Checkpoint:** Stripe test kartıyla ödeme → `is_premium` Supabase'de `true` → tüm reklamlar kapanır.

---

## Hf 7 (2026-06-06 → 2026-06-12): Tablet Layout (ADIM 18)

- [ ] `ResponsiveLayout` helper widget (`phone` / `tablet` factory)
- [ ] Ana navigasyon: tablet'te sol sidebar, telefonda alt bar
- [ ] Home: tablet'te iki sütun video grid
- [ ] Dictionary: tablet'te liste + detay yan yana
- [ ] Video player: tablet'te maks 480px yükseklik, içerik yanına sığar

**Checkpoint:** 1024px genişlikte layout doğru çalışır, taşma yoktur.

---

## Hf 8 (2026-06-13 → 2026-06-19): Admin Panel Tamamlama

- [ ] Admin sosyal sekmesi — `_PlaceholderSection` yerine gerçek içerik
  - Post listesi, moderasyon (sil/pinle)
  - Kullanıcı arama + premium toggle
- [ ] Admin oyun sekmesi — istatistikler (en yüksek skorlar, oyun sayıları)
- [ ] CI'ya `flutter analyze` + `flutter test` adımları ekle (ADIM 19 tamamlama)

---

## Hf 9 (2026-06-20 → 2026-06-26): Polish + Yayın Hazırlığı (ADIM 20)

- [ ] `RepaintBoundary` — video player, oyun skoru widget'larına ekle
- [ ] Büyük ekranda performans profili çalıştır
- [ ] `flutter analyze` → 0 warning (dart:html → package:web geçişi)
- [ ] Error ekranları: `NoConnectionScreen`, `GenericErrorScreen`
- [ ] Tüm route'larda loading state + error state denetimi

---

## Hf 10+ — Gelecek (Öncelik Sırasıyla)

| Görev | Tahmini Efor |
|---|---|
| Self-hosted video pipeline V2 (ADIM 17) — Cloudflare R2 | 1 hafta |
| Vercel Analytics custom events → gerçek event tracking | 2–3 gün |
| Supabase tabanlı Remote Config (ADIM 16) | 1 gün |
| E-posta bildirimleri (Supabase Auth emails + Resend) | 3 gün |
| Python Pipeline V2 — toplu playlist import | 1 hafta |

---

## Milestone Özeti

| Milestone | Hedef Tarih | Durum |
|---|---|---|
| Veri katmanı + pipeline | 2026-05-18 | ✅ Tamamlandı |
| Video oynatıcı + quiz | 2026-05-25 | ✅ Tamamlandı |
| AI dictionary + kredi | 2026-05-25 | ✅ Tamamlandı |
| Oyunlar + sosyal | 2026-05-25 | ✅ Tamamlandı |
| Web ödeme (Stripe) | 2026-06-05 | ⬜ Planlandı |
| Tablet layout | 2026-06-12 | ⬜ Planlandı |
| Tam GDPR uyumu | 2026-05-29 | ⬜ Sprint'te |
| Vercel'de canlıya alım | 2026-05-04~ | ✅ Zaten canlı |

---

## Risk Kaydı

| Risk | Olasılık | Etki | Önlem |
|---|---|---|---|
| Stripe web ödeme entegrasyonu gecikebilir | Orta | Yüksek | Geçici "ilginizi belirtin" form alternatifi |
| YouTube IFrame ToS değişikliği | Düşük | Yüksek | Self-hosted (R2) yedek yolu var |
| Gemini API hız limiti | Orta | Orta | Agresif cache + kredi kısıtlama |
| yt-dlp anti-bot engellemesi | Yüksek | Orta | 19-strateji matrisi + probe mekanizması var |
| Supabase free tier limiti | Düşük | Düşük | 500MB DB + 2GB bant genişliği ücretsiz |
