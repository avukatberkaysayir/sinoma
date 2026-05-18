$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Vercel token: set as env var or pass as argument
# Usage: .\deploy.ps1                         (reads $env:VERCEL_TOKEN)
#        .\deploy.ps1 -Token "vcp_..."
param([string]$Token = $env:VERCEL_TOKEN)
if (-not $Token) {
  Write-Error "VERCEL_TOKEN not set. Run: `$env:VERCEL_TOKEN='vcp_...' ; .\deploy.ps1"
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
