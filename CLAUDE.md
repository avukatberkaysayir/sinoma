# Sinoma — Claude Project Guide

## Role
Lead Software Architect for Sinoma — a Mandarin learning platform (Flutter Web + Supabase backend + Python pipeline). Web-only, no mobile. Active voice in all names. No comments unless WHY is non-obvious. Minimal tokens in responses.

## Stack (quick ref)
Flutter Web · Riverpod · Supabase (not Firebase — see memory) · go_router · Gemini 1.5 Flash · Python 3.11+
Detail → read `docs/reference.md`

## Critical Rules (non-obvious)
1. **aiCredits** — NEVER write from Flutter client. Only Cloud/Edge Functions.
2. **Seek restriction** — Do NOT block seekbar (YouTube ToS). Reset position to `startTime` on out-of-segment seek.
3. **Hybrid player** — `sourceType` field: `'youtube'` → YoutubePlayerIframe, `'self_hosted'` → VideoPlayer.
4. **Gemini cache** — Check `aiContextCache[SHA256(wordId+transcription)]` before calling API.
5. **Ads** — Banner BELOW player, never overlapping. Premium disables all ads at launch.
6. **Deploy** — GitHub Actions KAPALI. Her zaman `deploy.ps1` / vercel CLI ile elle deploy et.
7. **Dev server** — `flutter run -d web-server --web-port 9300`. NEVER `flutter build web` for dev.
8. **Localhost yasak** — HTTPS siteden localhost çağırma.
9. **L10n** — Her yeni UI string → AppL10n'a TR + EN ekle.
10. **freezed yok** — Dart 3.11, manuel fromJson/toJson kullan.

## Naming (active voice)
`fetchData` → `loadUserStats` · `processVideo` → `analyzeVideoSegment` · `isDataLoaded` → `hasLoadedData`

## Dev Commands
```
flutter run -d web-server --web-port 9300 --web-hostname localhost
dart fix --apply && flutter analyze
firebase deploy --only firestore,storage,functions --project=sinoma
```
