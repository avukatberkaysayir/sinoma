# Sinoma HSK-5 drain supervisor (no-admin model).
# Called in a loop by hsk5_keepalive.cmd (which itself auto-runs at logon via the
# Startup folder). One tick:
#   - pool empty  -> write done sentinel, remove Startup entry, exit 2 (stop loop)
#   - neither driver nor hsk_integrate running -> start the driver detached
#   - else                                     -> do nothing
# The driver (hsk5_drain.py) is idempotent and resumes from the cloud DB, so
# starting it after a reboot never loses or double-processes work.

$ErrorActionPreference = 'Stop'
$batch   = 'D:\github\Sinoma\tools\batch'
$py      = 'C:\Users\berka\AppData\Local\Python\pythoncore-3.14-64\python.exe'
$deploy  = 'D:\github\Sinoma\.deploy.env'
$project = 'pqyceostpukueydwuiut'
$startupCmd = [Environment]::GetFolderPath('Startup') + '\sinoma_hsk5_keepalive.cmd'
$doneFlag   = 'd:\tmp\hsk5_done.flag'

$tok = (Get-Content $deploy | Where-Object { $_ -like 'SUPABASE_ACCESS_TOKEN=*' }) -replace '^SUPABASE_ACCESS_TOKEN=','' -replace '"',''
$tok = $tok.Trim()

$body = @{ query = "select count(*) as n from videos where hsk_level=5 and status='pending' and backup_kind is null and backup_level is null;" } | ConvertTo-Json
try {
  $res  = Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$project/database/query" -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json' -Body $body -TimeoutSec 60
  $pool = [int]$res[0].n
} catch {
  Write-Output "pool sorgusu basarisiz (ag?) — sonraki tikte tekrar"
  exit 0
}

if ($pool -le 0) {
  Write-Output "HSK5 pending bos — bitti, keepalive kaldiriliyor"
  New-Item -ItemType File -Path $doneFlag -Force | Out-Null
  if (Test-Path $startupCmd) { Remove-Item $startupCmd -Force }
  exit 2
}

$running = Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object {
  $_.CommandLine -match 'hsk5_drain\.py' -or $_.CommandLine -match 'hsk_integrate\.py'
}
if ($running) { Write-Output "drain/hsk_integrate zaten calisiyor — dokunulmadi"; exit 0 }

Write-Output "drain baslatiliyor (pool=$pool)"
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Start-Process -FilePath $py -ArgumentList '-u','hsk5_drain.py' -WorkingDirectory $batch `
  -RedirectStandardOutput "d:\tmp\hsk5_drain_$stamp.log" -RedirectStandardError "d:\tmp\hsk5_drain_$stamp.err" `
  -WindowStyle Hidden
exit 0
