# Reads tokens from .deploy.env (gitignored)
param([string]$Token = "")

$ErrorActionPreference = "Stop"
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
flutter build web --release `
  "--dart-define=SUPABASE_URL=https://pqyceostpukueydwuiut.supabase.co" `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxeWNlb3N0cHVrdWV5ZHd1aXV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1OTU3OTMsImV4cCI6MjA5NDE3MTc5M30.RwDlw5fTlNYZtI5wHyjLSmCKTvr97MCcOlKQZY1GrBQ" `
  "--dart-define=GEMINI_API_KEY="

Write-Host "Deploying to Vercel..." -ForegroundColor Cyan
Set-Location build\web
npx vercel deploy --prod --yes --token $Token
Set-Location $PSScriptRoot

Write-Host "Done! https://sinoma-two.vercel.app" -ForegroundColor Green
