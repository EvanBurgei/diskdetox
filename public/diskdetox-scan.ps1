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

  How to run it:
    * Easiest: open PowerShell (Start > type "PowerShell"), paste this whole
      script, and press Enter.
    * Or run the saved file. Windows opens .ps1 in Notepad on double-click and
      blocks downloaded scripts by default, so run it explicitly:
        powershell -ExecutionPolicy Bypass -File .\diskdetox-scan.ps1
    * Add -Redact to strip the machine name and all paths from the output:
        powershell -ExecutionPolicy Bypass -File .\diskdetox-scan.ps1 -Redact
      (When pasting the script instead, set $Redact = $true in the line below.)
#>

param([switch]$Redact)
if (-not $PSBoundParameters.ContainsKey('Redact')) { $Redact = $false }   # when pasting, set $true here to redact

$ErrorActionPreference = 'SilentlyContinue'

$__sw=[System.Diagnostics.Stopwatch]::StartNew()
function El { $e=$__sw.Elapsed; '{0}:{1:00}' -f [int][math]::Floor($e.TotalMinutes), $e.Seconds }
function Step($i,$m){ Write-Host ("[{0}/14] ({1}) {2}" -f $i,(El),$m) -ForegroundColor Cyan }
function Tick($m){ Write-Host ("    - {0}  ({1})" -f $m,(El)) -ForegroundColor DarkGray }
function NotJunk($d){ -not (($d.Attributes -band [IO.FileAttributes]::ReparsePoint) -and ($d.Attributes -band [IO.FileAttributes]::System)) }
Write-Host "DiskDetox is scanning. You'll see each step below as it runs; the slow steps can take a few minutes, so leave this window open until it says Done." -ForegroundColor Cyan

function FolderGB($p) {
  if (Test-Path $p) {
    $sum = (Get-ChildItem $p -Recurse -File -Force -Attributes !Offline | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { return 0 }
    return [math]::Round($sum / 1GB, 2)
  }
  return 0
}

# Pull the executable's bare file name out of a command line, e.g.
#   "C:\Program Files\App\app.exe" --flag   ->   app.exe
function ExeName($cmd) {
  if (-not $cmd) { return $null }
  $c = ([string]$cmd).Trim()
  if ($c.StartsWith('"')) { $c = $c.Substring(1); $i = $c.IndexOf('"'); if ($i -ge 0) { $c = $c.Substring(0, $i) } }
  else { $sp = $c.IndexOf(' '); if ($sp -gt 0) { $c = $c.Substring(0, $sp) } }
  try { return ([System.IO.Path]::GetFileName($c)).ToLowerInvariant() } catch { return $null }
}

# Pull the full executable PATH out of a command line (handles quotes and paths with spaces).
function ExePath($cmd) {
  if (-not $cmd) { return $null }
  $c = ([string]$cmd).Trim()
  if ($c.StartsWith('"')) { $i = $c.IndexOf('"', 1); if ($i -gt 0) { return $c.Substring(1, $i - 1) }; return $c.Trim('"') }
  $m = [regex]::Match($c, '^(.+?\.(exe|com|bat|cmd|scr))\b', 'IgnoreCase')
  if ($m.Success) { return $m.Groups[1].Value }
  return $c
}

# Categorize where an executable lives (powers the "runs from an unusual place" signal).
function LocCat($p) {
  if (-not $p) { return $null }
  $lp = $p.ToLowerInvariant()
  if ($lp -like '*\temp\*' -or $lp -like (($env:TEMP).ToLowerInvariant() + '*')) { return 'temp' }
  if ($lp -like (($env:USERPROFILE).ToLowerInvariant() + '\downloads*')) { return 'downloads' }
  if ($lp -like (($env:LOCALAPPDATA).ToLowerInvariant() + '*') -or $lp -like (($env:APPDATA).ToLowerInvariant() + '*')) { return 'appdata' }
  if ($lp -like 'c:\windows\*') { return 'system' }
  if ($lp -like 'c:\program files*') { return 'programfiles' }
  return 'other'
}

Step 1 'Measuring your drives'
$drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  [PSCustomObject]@{
    id      = $_.DeviceID
    totalGB = [math]::Round($_.Size / 1GB, 1)
    freeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
    pctFree = [math]::Round($_.FreeSpace / $_.Size * 100, 0)
  }
}

Step 2 'Sizing your profile folders (one of the slower steps)'
$profileFolders = Get-ChildItem $env:USERPROFILE -Directory -Force | Where-Object { NotJunk $_ } | ForEach-Object {
  Tick $_.Name
  [PSCustomObject]@{ name = $_.Name; gb = (FolderGB $_.FullName) }
} | Sort-Object gb -Descending | Select-Object -First 15

Step 3 'Checking AppData caches'
$appLocal = Get-ChildItem $env:LOCALAPPDATA -Directory -Force | ForEach-Object {
  [PSCustomObject]@{ name = $_.Name; gb = (FolderGB $_.FullName) }
} | Sort-Object gb -Descending | Select-Object -First 12

Step 4 'Reading your installed programs'
$regPaths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$programs = Get-ItemProperty $regPaths |
  Where-Object { $_.DisplayName -and $_.EstimatedSize } |
  Select-Object @{n='name';e={$_.DisplayName}}, @{n='mb';e={[math]::Round($_.EstimatedSize/1024,0)}} |
  Group-Object name | ForEach-Object { $_.Group | Sort-Object mb -Descending | Select-Object -First 1 } |
  Sort-Object mb -Descending | Select-Object -First 30

Step 5 'Measuring cleanable caches'
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

Step 6 'Looking for installed games'
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

Step 7 'Finding your largest files (the slowest step; can take a few minutes on a full drive)'
$largestFiles = & {
  Get-ChildItem $env:USERPROFILE -File -Force -Attributes !Offline
  Get-ChildItem $env:USERPROFILE -Directory -Force | Where-Object { $_.Name -ne 'AppData' -and (NotJunk $_) } | ForEach-Object {
    Tick $_.Name
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

Step 8 'Sizing the top folders on every drive (also slow on big drives)'
$skipRoot = '$Recycle.Bin','System Volume Information','Config.Msi','Recovery','$WinREAgent','$SysReset'
$driveFolders = foreach ($d in $drives) {
  $folders = Get-ChildItem ($d.id + '\') -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $skipRoot -notcontains $_.Name -and -not $_.Name.StartsWith('$') -and (NotJunk $_) } |
    ForEach-Object { Tick ($d.id + '\' + $_.Name); [PSCustomObject]@{ name=$_.Name; gb=(FolderGB $_.FullName) } } |
    Sort-Object gb -Descending | Select-Object -First 12
  [PSCustomObject]@{ drive=$d.id; folders=@($folders) }
}

Step 9 'Measuring Windows system files'
$system = [PSCustomObject]@{
  hiberfilGB    = [math]::Round(((Get-Item C:\hiberfil.sys -Force).Length) / 1GB, 2)
  pagefileGB    = [math]::Round(((Get-Item C:\pagefile.sys -Force).Length) / 1GB, 2)
  driverStoreGB = (FolderGB 'C:\Windows\System32\DriverStore\FileRepository')
}

Step 10 'Listing what starts up with Windows'
$startup = @()
$runKeys = @(
  @{ src='Run (user)';   path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
  @{ src='Run (system)'; path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
  @{ src='Run (system)'; path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
)
foreach ($rk in $runKeys) {
  if (Test-Path $rk.path) {
    $key = Get-Item $rk.path
    foreach ($n in $key.Property) {
      $val = [string]$key.GetValue($n)
      $startup += [PSCustomObject]@{ name=$n; source=$rk.src; command=$val; exe=(ExeName $val) }
    }
  }
}
$startupFolders = @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")
foreach ($sf in $startupFolders) {
  if (Test-Path $sf) {
    Get-ChildItem $sf -File -Force | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
      $startup += [PSCustomObject]@{ name=$_.BaseName; source='Startup folder'; command=$_.FullName; exe=(ExeName $_.Name) }
    }
  }
}
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
  $_.State -ne 'Disabled' -and $_.TaskPath -notlike '\Microsoft\*' -and
  (@($_.Triggers) | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' })
} | ForEach-Object {
  $act = [string](@($_.Actions) | Select-Object -First 1).Execute
  $startup += [PSCustomObject]@{ name=$_.TaskName; source='Scheduled task'; command=$act; exe=(ExeName $act); taskPath=$_.TaskPath }
}
Get-CimInstance Win32_Service -Filter "StartMode='Auto'" |
  Where-Object { $_.PathName -and $_.PathName -notmatch 'C:\\Windows\\' } | ForEach-Object {
    $startup += [PSCustomObject]@{ name=$_.DisplayName; source='Service'; command=$_.PathName; exe=(ExeName $_.PathName); svc=$_.Name }
  }

Step 11 'Checking signatures on those startup items'
foreach ($s in $startup) {
  $p = ExePath $s.command
  $signed = $null; $signer = $null; $sha = $null; $loc = $null
  if ($p -and [System.IO.Path]::IsPathRooted($p) -and (Test-Path -LiteralPath $p -PathType Leaf)) {
    $loc = LocCat $p
    try { $sig = Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop; $signed = ($sig.Status -eq 'Valid'); if ($sig.SignerCertificate) { $signer = (($sig.SignerCertificate.Subject -split ',')[0]) -replace '^CN=','' } } catch {}
    try { $sha = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
  }
  $s | Add-Member -NotePropertyName signed -NotePropertyValue $signed -Force
  $s | Add-Member -NotePropertyName signer -NotePropertyValue $signer -Force
  $s | Add-Member -NotePropertyName sha256 -NotePropertyValue $sha    -Force
  $s | Add-Member -NotePropertyName loc    -NotePropertyValue $loc    -Force
}

Step 12 'Seeing what is using memory right now'
$processes = Get-Process | Group-Object ProcessName | ForEach-Object {
  [PSCustomObject]@{ name=$_.Name; ramMB=[math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum)/1MB,0); count=$_.Count }
} | Sort-Object ramMB -Descending | Select-Object -First 20

Step 13 'Reading your Windows security status'
try {
  $mp = Get-MpComputerStatus
  $sigAge = if ($mp.AntivirusSignatureLastUpdated) { [int]((Get-Date) - $mp.AntivirusSignatureLastUpdated).TotalDays } else { $null }
  $qa = if ($mp.QuickScanAge -gt 36500) { $null } else { [int]$mp.QuickScanAge }   # UInt32-max sentinel => never scanned
  $fa = if ($mp.FullScanAge  -gt 36500) { $null } else { [int]$mp.FullScanAge }
  $defender = [PSCustomObject]@{ present=$true; realtime=[bool]$mp.RealTimeProtectionEnabled; avEnabled=[bool]$mp.AntivirusEnabled; sigAgeDays=$sigAge; quickScanAgeDays=$qa; fullScanAgeDays=$fa; tamper=[bool]$mp.IsTamperProtected }
} catch { $defender = [PSCustomObject]@{ present=$false } }
$firewall = @()
try { $firewall = Get-NetFirewallProfile | ForEach-Object { [PSCustomObject]@{ name=$_.Name; enabled=[bool]$_.Enabled } } } catch {}
$bitlocker = $null
try { $b = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop; if ($b) { $bitlocker = [string]$b.ProtectionStatus } } catch {}
$lastUpdate = $null
try { $lastUpdate = ('{0:yyyy-MM-dd}' -f (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn) } catch {}
$threats = @()
try {
  $sevMap = @{ 1='Low'; 2='Moderate'; 4='High'; 5='Severe' }
  $threats = Get-MpThreat -ErrorAction SilentlyContinue | Select-Object -First 12 | ForEach-Object {
    $sev = $sevMap[[int]$_.SeverityID]; if (-not $sev) { $sev = "$($_.SeverityID)" }
    [PSCustomObject]@{ name=$_.ThreatName; severity=$sev; status='handled by Defender' }
  }
} catch {}
$security = [PSCustomObject]@{ defender=$defender; firewall=@($firewall); bitlocker=$bitlocker; lastUpdate=$lastUpdate; threats=@($threats) }

# ---- Redaction ----
$machine = if ($Redact) { $null } else { $env:COMPUTERNAME }
if ($Redact) {
  foreach ($c in $caches) { $c.path = $null }
  foreach ($g in $games)  { $g.path = $null }
  foreach ($s in $startup) { $s.command = $null }   # drop full exe paths; keep name/source/exe
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
  startup        = @($startup)
  processes      = @($processes)
  security       = $security
  system         = $system
}

Step 14 'Saving your results'
$json = $out | ConvertTo-Json -Depth 6
$desk = [Environment]::GetFolderPath('Desktop')                              # respects OneDrive Desktop redirection
if (-not $desk -or -not (Test-Path $desk)) { $desk = "$env:USERPROFILE\Desktop" }
$dest = Join-Path $desk 'disk-health.json'
$json | Out-File -FilePath $dest -Encoding utf8
try { $json | Set-Clipboard } catch {}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Done. JSON saved to: $dest" -ForegroundColor Green
Write-Host " It was also copied to your clipboard." -ForegroundColor Green
Write-Host " Open DiskDetox (diskdetox.com), click 'Paste data', and paste (Ctrl+V)" -ForegroundColor Green
Write-Host " - or use 'Load file' and pick disk-health.json from your Desktop." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
