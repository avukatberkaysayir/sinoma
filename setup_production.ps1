# setup_production.ps1
# Run once to do the initial Vercel project setup and first production deploy.
# After this, every `git push` triggers the GitHub Actions CI/CD pipeline automatically.
#
# Prerequisites:
#   - vercel login  (run once in terminal)
#   - flutterfire configure --project=sinoma --platforms=web --yes  (if credentials changed)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Log($msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Ok($msg)  { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Die($msg) { Write-Host "  [ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  Sinoma — Production Deploy" -ForegroundColor White
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

Set-Location $root

# ── 1. Verify Vercel login ────────────────────────────────────────────────────
Log "Checking Vercel login..."
$vcUser = vercel whoami 2>&1
if ($vcUser -match "Error") { Die "Run 'vercel login' first." }
Ok "Vercel: $vcUser"

# ── 2. Flutter web build ──────────────────────────────────────────────────────
Log "Building Flutter web (release, CanvasKit)..."
flutter build web --release --web-renderer canvaskit 2>&1 | Select-String "Built|Error|✓|warning"
Ok "Built → build/web/"

# ── 3. Deploy to Vercel ───────────────────────────────────────────────────────
Log "Deploying to Vercel..."
Set-Location "$root\build\web"
$deployOut = vercel deploy --prod --yes 2>&1
$url = ($deployOut | Select-String "https://") | Select-Object -Last 1
Set-Location $root
Ok "Deployed!"

Write-Host ""
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "  URL: $url" -ForegroundColor Yellow
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Next steps for GitHub Actions auto-deploy:" -ForegroundColor White
Write-Host "  1. Check build/web/.vercel/project.json for ORG_ID and PROJECT_ID" -ForegroundColor Gray
Write-Host "  2. Add these 3 secrets to GitHub: Settings → Secrets → Actions:" -ForegroundColor Gray
Write-Host "     VERCEL_TOKEN   → vercel auth token (from vercel.com/account/tokens)" -ForegroundColor Gray
Write-Host "     VERCEL_ORG_ID → from build/web/.vercel/project.json (orgId)" -ForegroundColor Gray
Write-Host "     VERCEL_PROJECT_ID → from build/web/.vercel/project.json (projectId)" -ForegroundColor Gray
Write-Host "  3. git push → auto-deploy on every commit." -ForegroundColor Green
Write-Host ""

# ── 4. (Optional) Deploy Firebase backend rules/functions ─────────────────────
Write-Host "  Firebase backend (Firestore rules, Storage rules, Cloud Functions):" -ForegroundColor White
Write-Host "  Deploy separately when needed:" -ForegroundColor Gray
Write-Host "  firebase deploy --only firestore,storage,functions --project=sinoma" -ForegroundColor Gray
Write-Host ""
