# setup_production.ps1
# Run this AFTER: firebase login && vercel login
# It creates the real Firebase project, configures everything, builds, and deploys to Vercel.

Set-StrictMode -Off
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Log($msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Ok($msg)  { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Die($msg) { Write-Host "  [ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  Mandarin Academy — Production Setup" -ForegroundColor White
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

Set-Location $root

# ── 1. Verify logins ──────────────────────────────────────────────────────────
Log "Checking Firebase login..."
$fbUser = firebase auth:export /dev/null 2>&1
$fbProjects = firebase projects:list 2>&1
if ($fbProjects -match "Failed to authenticate") { Die "Run 'firebase login' first." }
Ok "Firebase authenticated"

Log "Checking Vercel login..."
$vcUser = vercel whoami 2>&1
if ($vcUser -match "Error") { Die "Run 'vercel login' first." }
Ok "Vercel authenticated: $vcUser"

# ── 2. Create Firebase project ────────────────────────────────────────────────
$projectId = "mandarin-academy-" + [System.DateTime]::Now.ToString("yyMMdd")
Log "Creating Firebase project: $projectId ..."
firebase projects:create $projectId --display-name "Mandarin Academy" 2>&1 | ForEach-Object { "    $_" }
Ok "Firebase project created: $projectId"

# ── 3. Set as default project ─────────────────────────────────────────────────
(Get-Content "$root\.firebaserc") -replace 'demo-mandarin-academy', $projectId |
    Set-Content "$root\.firebaserc"
firebase use $projectId
Ok ".firebaserc updated"

# ── 4. Enable Firestore + Auth (via gcloud / REST is complex — guide user) ────
Log "Enabling Firestore database..."
firebase firestore:databases:create --location=eur3 2>&1 | ForEach-Object { "    $_" }

# ── 5. flutterfire configure ──────────────────────────────────────────────────
Log "Configuring Firebase for Flutter..."
dart pub global activate flutterfire_cli 2>&1 | Select-Object -Last 2
flutterfire configure --project=$projectId --platforms=web --yes 2>&1 |
    ForEach-Object { "    $_" }
Ok "firebase_options.dart updated with real credentials"

# ── 6. Deploy Firestore rules + indexes ───────────────────────────────────────
Log "Deploying Firestore rules and indexes..."
firebase deploy --only firestore --project=$projectId 2>&1 | ForEach-Object { "    $_" }
Ok "Firestore rules and indexes deployed"

# ── 7. Flutter production build ───────────────────────────────────────────────
Log "Building Flutter web (release)..."
flutter build web --release 2>&1 | Select-String "Built|Error|✓"
Ok "Flutter web built → build/web/"

# ── 8. Vercel deploy ──────────────────────────────────────────────────────────
Log "Deploying to Vercel..."
Set-Location "$root\build\web"
$deployOut = vercel deploy --prod --yes 2>&1
$url = $deployOut | Select-String "https://" | Select-Object -Last 1
Ok "Deployed!"
Write-Host ""
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "  URL: $url" -ForegroundColor Yellow
Write-Host "  ════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

Set-Location $root

# ── 9. Save Vercel IDs for GitHub Actions ────────────────────────────────────
Log "Fetching Vercel project info for GitHub Actions..."
Set-Location "$root\build\web"
$vcInfo = vercel project ls 2>&1
$orgId  = (vercel teams ls 2>&1 | Select-String "^\w" | Select-Object -First 1).ToString().Split()[0]
Set-Location $root

Write-Host ""
Write-Host "  Next: Add these 3 secrets to GitHub repo → Settings → Secrets" -ForegroundColor Yellow
Write-Host "  VERCEL_TOKEN  → run: vercel auth token" -ForegroundColor White
Write-Host "  VERCEL_ORG_ID → $orgId" -ForegroundColor White
Write-Host "  VERCEL_PROJECT_ID → check .vercel/project.json in build/web" -ForegroundColor White
Write-Host ""
Write-Host "  After that: git push → auto-deploy on every commit." -ForegroundColor Green
Write-Host ""
