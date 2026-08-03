# backup-supabase.ps1
# Full local backup of the linked Supabase project (database + storage + project files).
# Usage:  npm run backup
#         powershell -ExecutionPolicy Bypass -File scripts\backup-supabase.ps1 -OutRoot "E:\MyBackups"
# Output is written OUTSIDE the git repo on purpose: data.sql contains auth users
# and password hashes and must never be committed.

param(
  [string]$OutRoot = "D:\SupabaseBackup\superkorat2app"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$Dest = Join-Path $OutRoot $stamp

foreach ($sub in @("db", "storage", "project")) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Dest $sub) | Out-Null
}

$refFile = Join-Path $ProjectDir "supabase\.temp\project-ref"
$ref = if (Test-Path $refFile) { (Get-Content $refFile -Raw).Trim() } else { "unknown" }

Write-Host "=== Supabase backup ===" -ForegroundColor Cyan
Write-Host "project ref : $ref"
Write-Host "destination : $Dest"

# ---------- 1. database ----------
Write-Host "`n[1/4] database dump" -ForegroundColor Cyan
supabase db dump --linked --role-only -f "$Dest\db\roles.sql"  --workdir $ProjectDir
supabase db dump --linked             -f "$Dest\db\schema.sql" --workdir $ProjectDir
supabase db dump --linked --data-only --use-copy -f "$Dest\db\data.sql" --workdir $ProjectDir

# ---------- 2. storage ----------
Write-Host "`n[2/4] storage buckets" -ForegroundColor Cyan
$buckets = supabase storage ls --experimental --workdir $ProjectDir |
  Where-Object { $_ -match '^\s*\S+/\s*$' } |
  ForEach-Object { $_.Trim().TrimEnd('/') }

Push-Location (Join-Path $Dest "storage")
try {
  foreach ($b in $buckets) {
    Write-Host "  - $b"
    # dst must be relative ('.'), the CLI cannot parse a Windows absolute path here
    supabase storage cp -r "ss:///$b" "." --experimental --workdir $ProjectDir | Out-Null
  }
} finally {
  Pop-Location
}

# ---------- 3. project files ----------
Write-Host "`n[3/4] migrations / edge functions / config" -ForegroundColor Cyan
Copy-Item "$ProjectDir\supabase\migrations"  "$Dest\project\migrations" -Recurse -Force
Copy-Item "$ProjectDir\supabase\functions"   "$Dest\project\functions"  -Recurse -Force
Copy-Item "$ProjectDir\supabase\config.toml" "$Dest\project\config.toml" -Force
if (Test-Path "$ProjectDir\docs\backup-restore.md") {
  Copy-Item "$ProjectDir\docs\backup-restore.md" "$Dest\HOW-TO-RESTORE.md" -Force
}

# ---------- 4. manifest ----------
Write-Host "`n[4/4] manifest" -ForegroundColor Cyan
$commit = & git -C $ProjectDir rev-parse --short HEAD
$storageFiles = @(Get-ChildItem (Join-Path $Dest "storage") -Recurse -File)
$totalMB = [math]::Round(((Get-ChildItem $Dest -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 2)
$rowCount = (Select-String -Path "$Dest\db\data.sql" -Pattern '^COPY ' -AllMatches).Count

$manifest = @"
Supabase backup
===============
project ref   : $ref
created       : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
git commit    : $commit
migrations    : $(@(Get-ChildItem "$Dest\project\migrations" -File).Count) files
storage files : $($storageFiles.Count) files
copy blocks   : $rowCount tables in data.sql
total size    : $totalMB MB

contents
  db/roles.sql   custom roles
  db/schema.sql  full schema (tables, RLS, functions, triggers)
  db/data.sql    all data incl. auth.users  <-- SECRET, never commit / never share
  storage/       every file from every bucket
  project/       migrations, edge functions, config.toml at commit $commit

NOT included (must be re-entered by hand after a restore):
  - edge function secret VALUES (supabase secrets set ...)
  - dashboard auth settings (providers, redirect urls, email templates)
  - files hosted outside Supabase (PHP host uploads, Google Drive)
"@
$manifest | Out-File "$Dest\MANIFEST.txt" -Encoding utf8

Write-Host "`nDone. $($storageFiles.Count) storage files, $totalMB MB total" -ForegroundColor Green
Write-Host $Dest -ForegroundColor Green
