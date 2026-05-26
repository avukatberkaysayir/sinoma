# Sinoma — Geliştirme Takvimi

Başlangıç: 2026-05-04
Durum güncellemesi: 2026-05-26

> Platform: Firebase → **Supabase** | Android/iOS → **Flutter Web (Vercel)**
> Live: https://sinoma-two.vercel.app

---

## ✅ Tamamlanan Çalışmalar (2026-05-04 → 2026-05-26)

| Tarih | Yapılan |
|---|---|
| Hf 1 | Flutter projesi kurulumu, Supabase şeması, Dart modelleri |
| Hf 1 | Firebase → Supabase tam geçişi (76 dosya) |
| Hf 1–2 | HSK 1–6 sözlük seed (CC-CEDICT + ~2513 HSK6 kelime + TR çeviriler) |
| Hf 2 | Python pipeline (yt-dlp + Whisper ASR + altyazı extraction) |
| Hf 2 | YouTube job queue (`pipeline_jobs` + `pipeline_poller.py`) |
| Hf 2 | Hybrid video player (YouTube IFrame + VoScreen+YouGlish inline) |
| Hf 2 | Quiz overlay + skor sistemi |
| Hf 2–3 | Gemini AI dictionary + SHA256 cache + WordDetailSheet |
| Hf 3 | Kredi sistemi (Supabase RPC) + QuotaExceededModal |
| Hf 3 | Subscription ekranı (paywall UI, plan kartları) |
| Hf 3 | Mandarin Duel + Hanzi Build oyunları |
| Hf 3 | Sosyal feed, leaderboard, takip/takipten çık |
| Hf 3 | Onboarding + HSK yerleştirme testi |
| Hf 3–4 | Admin paneli (import / yönet / sözlük / seed / kullanıcılar / sosyal / oyun) |
| Hf 4 | Çok boyutlu filtre sistemi (5 filtre + arama) |
| Hf 4 | Admin inline video oynatıcı + soft/hard delete |
| Hf 4 | Vercel CI/CD (GitHub Actions + flutter analyze) |
| Hf 5 | ConnectivityBanner + GDPR edge functions (delete-user, export-user-data) |
| Hf 5 | Stripe edge functions (checkout / webhook / portal) |
| Hf 5 | Tablet layout (SectionNavRail, ≥900px) |
| Hf 5 | Analytics (Vercel Analytics + AnalyticsService) |
| Hf 5 | Remote Config (app_config Supabase tablosu + RemoteConfigService) |
| Hf 5 | Admin kullanıcı yönetimi (premium toggle + kredi düzenleme) |
| Hf 5 | pg_cron: gece 00:00 UTC günlük kredi yenileme aktif |

---

## Aktif Sprint — Hf 6 (2026-05-26 → 2026-06-01): Polish (ADIM 20)

### Gün 1–2: Kod Kalitesi + Deprecation Temizliği
- [ ] `dart:html` → `package:web` migrasyonu (admin_screen, settings_screen)
- [ ] `dart:js` → `dart:js_interop` migrasyonu (analytics_service)
- [ ] Hedef: `flutter analyze` → 0 info uyarısı

### Gün 3: Hata Ekranları
- [ ] `NoConnectionScreen` — internet yokken gösterilir
- [ ] `GenericErrorScreen` — beklenmedik hata yakalandığında
- [ ] Tüm route'larda loading + error state denetimi

### Gün 4: Performans
- [ ] `RepaintBoundary` — video player + quiz overlay + oyun skor widget'larına
- [ ] `const` konstruktörler denetimi (flutter analyze önerileri)

### Gün 5: Stripe Hazırlığı (kullanıcı)
- [ ] Stripe Dashboard → Products → Monthly ($9.99) + Annual ($69.99) oluştur
- [ ] STRIPE_SECRET_KEY, STRIPE_MONTHLY_PRICE_ID, STRIPE_ANNUAL_PRICE_ID, STRIPE_WEBHOOK_SECRET
- [ ] Supabase Dashboard → Edge Functions → Secrets → 4 secret ekle

---

## Hf 7+ — Gelecek (Öncelik Sırasıyla)

| Görev | Tahmini Efor |
|---|---|
| Stripe API anahtarları + uçtan uca test | 1 gün (Stripe hesabı gerekli) |
| Self-hosted video pipeline V2 (ADIM 17) — Cloudflare R2 | 1 hafta |
| Web push bildirimleri | Yüksek efor, düşük öncelik |

---

## Milestone Özeti

| Milestone | Hedef Tarih | Durum |
|---|---|---|
| Veri katmanı + pipeline | 2026-05-18 | ✅ Tamamlandı |
| Video oynatıcı + quiz | 2026-05-25 | ✅ Tamamlandı |
| AI dictionary + kredi | 2026-05-25 | ✅ Tamamlandı |
| Oyunlar + sosyal | 2026-05-25 | ✅ Tamamlandı |
| GDPR + ConnectivityBanner | 2026-05-26 | ✅ Tamamlandı |
| Tablet layout | 2026-05-26 | ✅ Tamamlandı |
| Analytics + Remote Config | 2026-05-26 | ✅ Tamamlandı |
| Admin paneli (tam) | 2026-05-26 | ✅ Tamamlandı |
| pg_cron günlük kredi | 2026-05-26 | ✅ Tamamlandı |
| Polish (ADIM 20) | 2026-06-01 | 🔶 Devam ediyor |
| Web ödeme (Stripe) | Stripe hesabı sonrası | ⬜ Bekliyor |
| Vercel'de canlı | 2026-05-04~ | ✅ Zaten canlı |
