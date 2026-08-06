# DESIGN.md — Sinoma

> Tasarım kaynağı. Claude Code arayüz üretmeden/değiştirmeden ÖNCE bunu okur.
> Değerler `lib/core/constants/app_colors.dart` ve `lib/app.dart`'tan türetilmiştir;
> orası değişirse burayı da güncelle. Mevcut stack/konvansiyonu bozma.

## Product intent
Flutter Web üzerinde Mandarin öğrenme platformu: YouTube klipleri + altyazı +
quiz + Duolingo tarzı HSK yolu. Web-only.

## Visual direction — "mürekkep + mühür" (de-Duolingo, 2026-06)
- Tone: editorial + sakin; klasik Çin kaligrafisi/mühür dili. PLAYFUL değil.
- Density: orta. Dekorasyon değil, hiyerarşi.
- İki tema, **light (pirinç kâğıdı) varsayılan**, dark (mürekkep) opt-in. Renkler
  `AppColors` getter'larından gelir (`AppColors.dark` ile çözülür) — ham HEX gömme.

### Palet (dark / light)
- Surface (zemin):     `0xFF0E1414` / `0xFFF6F2E8`
- Surface variant (panel): `0xFF161E1D` / `0xFFFFFFFF`
- Border:              `0xFF263230` / `0xFFE3DDD0`
- Locked:             `0xFF2E3A38` / `0xFFD8D2C4`
- onSurface (metin):   `0xFFEEEEEE` / `0xFF1A2422`
- Muted metin:         `0xFF9E9E9E` / `0xFF6B6B5E`
- Accent turkuaz (primary): `0xFF2EC4B6` (koyu `0xFF21968B`)
- Vermilyon (mühür / aktif nav / 开始 damgası): `0xFFE0442C`
- Altın: `0xFFD4A33D` · Yeşim: `0xFF3FB58E`
- HSK 1→6 renk skalası: yeşil→mor (`AppColors.forHskLevel`)
- **Yasak:** eski duo lacivertleri (131F2A/1C2A35/24333D/2C3B45/37464F) GERİ GELMESİN.
  Jenerik AI gradient'leri, rastgele ikon, stock-dashboard kartları yok.

## Typography
- Display / headline / title: **ZCOOL XiaoWei** (`GoogleFonts.zcoolXiaoWei…`).
- Body: **Figtree** (yuvarlak font DEĞİL).
- Player altyazı/şıklar: Comic Sans. Admin: varsayılan font.
- Skala için Theme TextTheme'i kullan; elle fontSize dağıtma.

## Layout rules
- Radius ölçeği: chip/pill ~20, kart/panel ~12-14, küçük rozet ~6-8. Yeni değer uydurma.
- Bölümleri görsel olarak ayır; gölge yerine border + surfaceVariant tercih et.
- İlerleme çubukları **BrushBar** (`path_sections.dart`) ile — kendi bar'ını yazma.
- Mühür-karesi düğüm dili (path), kesikli kervan rotası `_RoutePainter`.
- Gereksiz kart/gradient/badge ekleme. Her blok bir amaca hizmet etsin.

## Components
- Nav: normal harf, tek soluk ikon rengi, aktif = vermilyon sol bar + tint.
  Adlar: Rütbeler (ligler), Çayevi (görevler), Çarşı (mağaza).
- Sayaçlar (sağ rail `_Stat`): 🏮 seri / 🪙 altın / 🟢 yeşim can.
- Mascot **Orni** + günlük chengyu balonu (`_kOrniLines`).
- Buttons / forms: durumları gerçek yap — hover/focus, disabled, validation,
  hata mesajı alanın altında. Placeholder ise açıkça işaretle.
- Ses: `lib/core/utils/web_sfx.dart` (dart:js_interop WebAudio) — correct/wrong/gong.

## Responsive behavior
- Mobilde ana eylem (CTA) ve hiyerarşi görünür kalır; "her şeyi küçült" YASAK.
- Seekbar'ı engelleme (YouTube ToS); segment dışına çıkınca pozisyonu startTime'a al.
- Embed oynatıcı üstüne overlay YASAK — kontroller altta; atıf linki zorunlu.

## Non-negotiables
- Her yeni UI string → AppL10n'a TR + EN (gerekiyorsa 14 dil).
- aiCredits / service_role asla Flutter client'tan yazılmaz — sadece edge/cloud fn.
- HTTPS siteden localhost çağrısı yok → job queue (`pipeline_jobs`) + yerel worker.
- freezed yok (Dart 3.11): elle fromJson/toJson.
- Mevcut routing / state / paket yöneticisini değiştirme; yeni UI kütüphanesi ekleme.
