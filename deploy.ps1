# Reads tokens from .deploy.env (gitignored)
param([string]$Token = "")

# Continue (not Stop): native tools (flutter) write progress to stderr; under
# Stop that aborts the script mid-build. Failures are caught via $LASTEXITCODE.
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot ".deploy.env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match "^VERCEL_TOKEN=(.+)$") { $Token = $Matches[1] }
    if ($_ -match "^SUPABASE_ACCESS_TOKEN=(.+)$") { $env:SUPABASE_ACCESS_TOKEN = $Matches[1] }
  }
}
if (-not $Token) { $Token = $env:VERCEL_TOKEN }
if (-not $Token) {
  Write-Error "Token bulunamadı. .deploy.env dosyasına VERCEL_TOKEN= satırı ekle."
  exit 1
}

Write-Host "Building Flutter web..." -ForegroundColor Cyan
# --no-wasm-dry-run: dart:html (YouTube player) is intentional; suppress the
# wasm-incompatibility stderr that otherwise looks like a build failure.
flutter build web --release --no-wasm-dry-run `
  "--dart-define=SUPABASE_URL=https://pqyceostpukueydwuiut.supabase.co" `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxeWNlb3N0cHVrdWV5ZHd1aXV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1OTU3OTMsImV4cCI6MjA5NDE3MTc5M30.RwDlw5fTlNYZtI5wHyjLSmCKTvr97MCcOlKQZY1GrBQ" `
  "--dart-define=GEMINI_API_KEY="
if ($LASTEXITCODE -ne 0) { Write-Error "Flutter build basarisiz (exit $LASTEXITCODE)."; exit 1 }

# Target the existing 'sinoma' project explicitly via env vars. Without this the
# CLI names a new project after the output dir ("web") and deploys to the wrong
# place. (Copying .vercel into build/web is unreliable — nests on re-runs.)
$proj = Get-Content "$PSScriptRoot\.vercel\project.json" -Raw | ConvertFrom-Json
$env:VERCEL_ORG_ID = $proj.orgId
$env:VERCEL_PROJECT_ID = $proj.projectId
Copy-Item "$PSScriptRoot\web\vercel.json" "$PSScriptRoot\build\web\vercel.json" -Force -ErrorAction SilentlyContinue
Remove-Item "$PSScriptRoot\build\web\.vercel" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Deploying to Vercel (production)..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot\build\web"
npx vercel deploy --prod --yes --token $Token
$deployCode = $LASTEXITCODE
Set-Location $PSScriptRoot
if ($deployCode -ne 0) { Write-Error "Vercel deploy basarisiz (exit $deployCode)."; exit 1 }

Write-Host "Done! https://sinoma-two.vercel.app" -ForegroundColor Green
