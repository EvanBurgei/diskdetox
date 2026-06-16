<#
  DiskDetox Scan  ->  JSON   (diskdetox.com)
  --------------------------------------------------------------------------
  READ-ONLY. This script DELETES NOTHING. It only measures sizes and reads
  folder/program NAMES. It never reads file contents.

  It writes a JSON file to your Desktop AND copies the JSON to your clipboard
  so you can paste it straight into the Disk Health Dashboard.

  Privacy:
    * Run normally  -> includes machine name + full folder paths.
    * Run with -Redact -> strips machine name and all file-system paths,
      leaving only generic folder names + sizes. Use this if you might paste
      the output anywhere other than your own browser.

  Usage (PowerShell):
    Normal:   .\disk-health-scan.ps1
    Redacted: .\disk-health-scan.ps1 -Redact

  If you prefer to paste the whole script inline instead of saving the file,
  set the redaction flag on the next line ($true = redacted) and paste away.
#>

param([switch]$Redact)
if (-not $PSBoundParameters.ContainsKey('Redact')) { $Redact = $false }   # <-- inline toggle

$ErrorActionPreference = 'SilentlyContinue'

function FolderGB($p) {
  if (Test-Path $p) {
    $sum = (Get-ChildItem $p -Recurse -File -Force -Attributes !Offline | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { return 0 }
    return [math]::Round($sum / 1GB, 2)
  }
  return 0
}

Write-Host "Scanning drives..." -ForegroundColor Cyan
$drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  [PSCustomObject]@{
    id      = $_.DeviceID
    totalGB = [math]::Round($_.Size / 1GB, 1)
    freeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
    pctFree = [math]::Round($_.FreeSpace / $_.Size * 100, 0)
  }
}

Write-Host "Scanning profile folders (this is the slow part - up to a couple minutes)..." -ForegroundColor Cyan
$profileFolders = Get-ChildItem $env:USERPROFILE -Directory -Force | ForEach-Object {
  [PSCustomObject]@{ name = $_.Name; gb = (FolderGB $_.FullName) }
} | Sort-Object gb -Descending | Select-Object -First 15

Write-Host "Scanning AppData caches..." -ForegroundColor Cyan
$appLocal = Get-ChildItem $env:LOCALAPPDATA -Directory -Force | ForEach-Object {
  [PSCustomObject]@{ name = $_.Name; gb = (FolderGB $_.FullName) }
} | Sort-Object gb -Descending | Select-Object -First 12

Write-Host "Reading installed programs..." -ForegroundColor Cyan
$regPaths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$programs = Get-ItemProperty $regPaths |
  Where-Object { $_.DisplayName -and $_.EstimatedSize } |
  Select-Object @{n='name';e={$_.DisplayName}}, @{n='mb';e={[math]::Round($_.EstimatedSize/1024,0)}} |
  Sort-Object mb -Descending | Select-Object -First 30

Write-Host "Measuring cleanable caches..." -ForegroundColor Cyan
$cacheDefs = @(
  @{ name='User Temp';            path=$env:TEMP;                                                  safe=$true  },
  @{ name='Windows Temp';         path='C:\Windows\Temp';                                          safe=$true  },
  @{ name='Windows Update Cache'; path='C:\Windows\SoftwareDistribution\Download';                 safe=$true  },
  @{ name='Chrome cache';         path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache";  safe=$true  },
  @{ name='Edge cache';           path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; safe=$true  },
  @{ name='Downloads';            path="$env:USERPROFILE\Downloads";                               safe=$false },
  @{ name='Recycle Bin';          path='C:\$Recycle.Bin';                                          safe=$true  },
  @{ name='Windows.old (previous Windows)'; path='C:\Windows.old';                                 safe=$false }
)
$caches = foreach ($c in $cacheDefs) {
  [PSCustomObject]@{ name=$c.name; gb=(FolderGB $c.path); path=$c.path; safe=$c.safe }
}

Write-Host "Looking for installed games..." -ForegroundColor Cyan
$gameRoots = 'C:\Program Files (x86)\Steam\steamapps\common',
             'C:\Program Files\Epic Games',
             'C:\Program Files (x86)\Origin Games',
             'C:\Program Files\EA Games',
             'C:\Program Files (x86)\EA Games',
             'C:\Program Files (x86)\GOG Galaxy\Games',
             'C:\Games'
$games = foreach ($r in $gameRoots) {
  if (Test-Path $r) {
    Get-ChildItem $r -Directory -Force | ForEach-Object {
      [PSCustomObject]@{ name=$_.Name; gb=(FolderGB $_.FullName); path=$_.FullName }
    }
  }
}
$games = $games | Sort-Object gb -Descending

Write-Host "Finding your largest individual files (skips AppData; one more pass)..." -ForegroundColor Cyan
$largestFiles = & {
  Get-ChildItem $env:USERPROFILE -File -Force -Attributes !Offline
  Get-ChildItem $env:USERPROFILE -Directory -Force | Where-Object { $_.Name -ne 'AppData' } | ForEach-Object {
    Get-ChildItem $_.FullName -Recurse -File -Force -Attributes !Offline
  }
} | Where-Object { $_.Length -ge 100MB } |
  Sort-Object Length -Descending | Select-Object -First 20 | ForEach-Object {
    [PSCustomObject]@{
      name = $_.Name
      gb   = [math]::Round($_.Length / 1GB, 2)
      path = $_.DirectoryName
      ext  = $_.Extension.TrimStart('.').ToLowerInvariant()
    }
  }

Write-Host "Sizing top-level folders on every drive (adds some time)..." -ForegroundColor Cyan
$skipRoot = '$Recycle.Bin','System Volume Information','Config.Msi','Recovery','$WinREAgent','$SysReset'
$driveFolders = foreach ($d in $drives) {
  $folders = Get-ChildItem ($d.id + '\') -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $skipRoot -notcontains $_.Name -and -not $_.Name.StartsWith('$') } |
    ForEach-Object { [PSCustomObject]@{ name=$_.Name; gb=(FolderGB $_.FullName) } } |
    Sort-Object gb -Descending | Select-Object -First 12
  [PSCustomObject]@{ drive=$d.id; folders=@($folders) }
}

Write-Host "Measuring system files (DriverStore can take a moment)..." -ForegroundColor Cyan
$system = [PSCustomObject]@{
  hiberfilGB    = [math]::Round(((Get-Item C:\hiberfil.sys -Force).Length) / 1GB, 2)
  pagefileGB    = [math]::Round(((Get-Item C:\pagefile.sys -Force).Length) / 1GB, 2)
  driverStoreGB = (FolderGB 'C:\Windows\System32\DriverStore\FileRepository')
}

# ---- Redaction ----
$machine = if ($Redact) { $null } else { $env:COMPUTERNAME }
if ($Redact) {
  foreach ($c in $caches) { $c.path = $null }
  foreach ($g in $games)  { $g.path = $null }
  foreach ($f in $largestFiles) {
    $f.path = $null
    $f.name = if ($f.ext) { "(a .$($f.ext) file)" } else { "(a large file)" }
  }
}

$out = [PSCustomObject]@{
  schema         = 'disk-health/v1'
  generated      = (Get-Date).ToString('s')
  machine        = $machine
  redacted       = [bool]$Redact
  drives         = @($drives)
  profileFolders = @($profileFolders)
  appDataLocal   = @($appLocal)
  programs       = @($programs)
  caches         = @($caches)
  games          = @($games)
  largestFiles   = @($largestFiles)
  driveFolders   = @($driveFolders)
  system         = $system
}

$json = $out | ConvertTo-Json -Depth 6
$dest = "$env:USERPROFILE\Desktop\disk-health.json"
$json | Out-File -FilePath $dest -Encoding utf8
try { $json | Set-Clipboard } catch {}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Done. JSON saved to: $dest" -ForegroundColor Green
Write-Host " It was also copied to your clipboard." -ForegroundColor Green
Write-Host " Open DiskDetox (diskdetox.com), click 'Paste data', and paste (Ctrl+V)" -ForegroundColor Green
Write-Host " - or use 'Load file' and pick disk-health.json from your Desktop." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
