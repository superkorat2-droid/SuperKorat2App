# restore-storage.ps1
# Upload the storage/ folder of a backup back into Supabase buckets.
#
#   powershell -File scripts\restore-storage.ps1 -BackupDir "D:\SupabaseBackup\superkorat2app\2026-08-03_2301" -Local
#   powershell -File scripts\restore-storage.ps1 -BackupDir "..." -Linked
#
# Run AFTER data.sql is loaded (buckets come from data.sql) and AFTER clearing the
# object rows it brought along, otherwise every upload fails as a duplicate:
#   TRUNCATE storage.objects CASCADE;
#
# Why file-by-file instead of `storage cp -r`: on Windows the recursive form
#   (a) nests the folder name -> /images/images/...
#   (b) sends sub-folders with backslashes -> HTTP 400 InvalidKey
# so each file is uploaded with its own explicit forward-slash key.

param(
  [Parameter(Mandatory = $true)][string]$BackupDir,
  [switch]$Local,
  [switch]$Linked
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot

if (-not $Local -and -not $Linked) { throw "pick a target: -Local or -Linked" }
if ($Local -and $Linked) { throw "pick only one target" }
$target = if ($Local) { "--local" } else { "--linked" }

$StorageRoot = if ((Split-Path -Leaf $BackupDir) -eq "storage") { $BackupDir } else { Join-Path $BackupDir "storage" }
if (-not (Test-Path $StorageRoot)) { throw "no storage folder in $BackupDir" }

$files = @(Get-ChildItem $StorageRoot -Recurse -File)
Write-Host "uploading $($files.Count) files -> $target" -ForegroundColor Cyan

$ok = 0; $failed = @()
# the CLI resolves a relative source against the project dir, so run from there
Push-Location $ProjectDir
try {
  foreach ($f in $files) {
    $key = $f.FullName.Substring($StorageRoot.Length + 1) -replace '\\', '/'
    $src = Resolve-Path -Relative $f.FullName
    $out = supabase storage cp $src "ss:///$key" $target --experimental 2>&1
    if ($LASTEXITCODE -eq 0 -and $out -notmatch "Error|failed") {
      $ok++
    } else {
      $failed += $key
      Write-Host "  FAIL $key" -ForegroundColor Red
    }
  }
} finally {
  Pop-Location
}

Write-Host "uploaded $ok / $($files.Count)" -ForegroundColor Green
if ($failed.Count) {
  Write-Host "failed: $($failed -join ', ')" -ForegroundColor Red
  exit 1
}
