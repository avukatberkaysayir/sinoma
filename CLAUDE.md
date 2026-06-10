# Sinoma — Mandarin learning platform (Flutter Web · Riverpod · Supabase · Python pipeline). Web-only.

Yanıtlar kısa. Active-voice isimler. Yorum yok (WHY apaçık değilse). Detay → `docs/reference.md`, geçmiş → MEMORY.md.

## Bozma-yasak kurallar
- **Deploy elle:** `git push origin master:main` (pre-push → deploy.ps1 → Vercel). GH Actions kapalı. Edge fn: `npx supabase functions deploy <fn> --project-ref pqyceostpukueydwuiut`.
- **aiCredits / service_role:** asla Flutter client'tan yazma — sadece edge/cloud fn.
- **Localhost yasak:** HTTPS siteden localhost çağırma → job queue (`pipeline_jobs`) + yerel worker (`dev_server.py`).
- **freezed yok** (Dart 3.11): elle fromJson/toJson.
- **L10n:** her yeni UI string → AppL10n TR + EN.
- **Seek:** seekbar'ı engelleme (YouTube ToS); segment dışına çıkınca pozisyonu `startTime`'a al.
- **Dev:** `flutter run -d web-server --web-port 9300`. Dev için `flutter build web` YOK.
