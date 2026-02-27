# OneVPN one-line install script (Windows client)
# Usage (PowerShell; run as Administrator recommended):
#   irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
# Or with install dir and version:
#   irm .../install.ps1 | iex -InstallDir "C:\onevpn-client" -Version "1.0.1"

param(
    [string]$InstallDir = "$env:USERPROFILE\onevpn-client",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$RepoRaw = "https://raw.githubusercontent.com/SanYuLee/onevpn_release/main"

# Check admin (for info only; driver install is handled when client starts)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. UAC may prompt when the client installs drivers."
}

function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Green }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

# Use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get system architecture (for client exe: x64 / x86)
function Get-SystemArchitecture {
    if ([Environment]::Is64BitOperatingSystem) {
        return "x64"
    } else {
        return "x86"
    }
}

# Get wintun dir for this platform (amd64 / i386 / arm64), to download only needed wintun.dll
function Get-WintunArch {
    $procArch = $env:PROCESSOR_ARCHITECTURE
    if ($procArch -eq "ARM64") { return "arm64" }
    if ([Environment]::Is64BitOperatingSystem) { return "amd64" }
    return "i386"
}

if (-not $Version) {
    try {
        $Version = (Invoke-WebRequest -Uri "$RepoRaw/LATEST" -UseBasicParsing).Content.Trim()
    } catch {
        Write-Err "Could not get latest version (LATEST)."
        exit 1
    }
}
if ($Version -notmatch "^v") { $Version = "v$Version" }

$Base = "$RepoRaw/$Version/client"

# Choose client file by architecture
$arch = Get-SystemArchitecture

if ($arch -eq "x64") {
    $clientExe = "one_client-amd64.exe"
    Write-Info "64-bit system detected, downloading 64-bit client"
} else {
    $clientExe = "one_client-x86.exe"
    Write-Info "32-bit system detected, downloading 32-bit client"
}

# Base file list (client.yaml is created on first run, not downloaded)
$Files = @($clientExe, "VERSION", "README.md")
# wintun (WireGuard): download only this platform's wintun.dll (skip if local file has same MD5)
$wintunArch = Get-WintunArch
$WintunFiles = @("wintun/$wintunArch/wintun.dll")
Write-Info "Platform wintun arch: $wintunArch, will download wintun.dll as needed"

# All files to download
$allFiles = $Files + $WintunFiles

# Fetch checksums.txt (single file with server/client paths for incremental update)
$Checksums = @{}
try {
    $cs = (Invoke-WebRequest -Uri "$RepoRaw/$Version/checksums.txt" -UseBasicParsing).Content
    foreach ($line in ($cs -split "`n")) {
        if ($line -match '^([a-fA-F0-9]{32})\s+(.+)$') {
            $Checksums[$Matches[2].Trim()] = $Matches[1].ToLower()
        }
    }
} catch { }

# Whether local file needs download (skip if MD5 unchanged)
function Need-Download {
    param([string]$RemoteFile, [string]$LocalPath)
    if (-not $Checksums.ContainsKey($RemoteFile)) { return $true }
    if (-not (Test-Path $LocalPath)) { return $true }
    try {
        $hash = (Get-FileHash -Path $LocalPath -Algorithm MD5).Hash.ToLower()
        return ($hash -ne $Checksums[$RemoteFile])
    } catch { return $true }
}

if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
Set-Location $InstallDir

Write-Info "Downloading OneVPN client $Version to $InstallDir ..."
$tempDir = Join-Path $env:TEMP "onevpn-install"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Phase 1: download all files
$downloadFiles = $allFiles

foreach ($f in $downloadFiles) {
    # For client exe, rename to one_client.exe after download
    $outputFile = $f
    if ($f -match "one_client-(amd64|x86)\.exe") {
        $outputFile = "one_client.exe"
    }

    # Skip if MD5 unchanged (client and wintun; wintun key is wintun/arch/wintun.dll)
    $checksumKey = if ($f -like "wintun/*") { $f } else { "client/$f" }
    $localPath = Join-Path $InstallDir $outputFile
    if (-not (Need-Download -RemoteFile $checksumKey -LocalPath $localPath)) {
        Write-Info "  Skip $f (MD5 unchanged)"
        $destPath = Join-Path $tempDir $f
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        if (Test-Path $localPath) { Copy-Item -Path $localPath -Destination $destPath -Force }
        continue
    }

    # URL: wintun from repo root, rest from version client dir
    $fileUrl = if ($f -like "wintun/*") { "$RepoRaw/$f" } else { "$Base/$f" }
    $destPath = Join-Path $tempDir $f
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Info "  Downloading $f"
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile $destPath -UseBasicParsing
    } catch {
        if ($f -like "wintun/*") {
            Write-Warn "  Skip $f (not in release or download failed); WireGuard needs wintun.dll, see wintun/README.md or run fetch-wintun.sh and rebuild"
        } else {
            Write-Err "Download $f failed: $_"
            exit 1
        }
    }
}

Write-Info "All files downloaded"

# If client is running, stop it so we can overwrite
$exePath = Join-Path $InstallDir "one_client.exe"
if (Test-Path $exePath) {
    $proc = Get-Process -Name "one_client" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Info "Stopping running OneVPN client..."
        Stop-Process -Name "one_client" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Info "Client stopped, continuing update"
    }
}

# Phase 2: copy wintun to install dir
Write-Host ""
Write-Info "Copying wintun driver..."
foreach ($f in $WintunFiles) {
    $srcFile = Join-Path $tempDir $f
    if (Test-Path $srcFile) {
        $destFile = Join-Path $InstallDir $f
        $destDir = Split-Path $destFile -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $srcFile -Destination $destFile -Force
        Write-Info "  Copied: $f"
    }
}
Write-Info "wintun ready; client will place wintun.dll on startup for WireGuard"

# Phase 3: copy client files to install dir
Write-Host ""
Write-Info "Copying files to install directory..."

foreach ($f in $Files) {
    $outputFile = $f
    if ($f -match "one_client-(amd64|x86)\.exe") {
        $outputFile = "one_client.exe"
    }

    $srcFile = Join-Path $tempDir $f
    $destFile = Join-Path $InstallDir $outputFile

    Copy-Item -Path $srcFile -Destination $destFile -Force
    Write-Info "  Installed: $outputFile"
}

# Clean temp dir
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Info "Client files installed to: $InstallDir"

$ExePath = Join-Path $InstallDir "one_client.exe"

# Create desktop shortcut for easy launch
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "OneVPN Client.lnk"
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Description = "OneVPN Client - double-click to start; right-click tray icon for Web UI or Quit"
    $Shortcut.Save()
    # Set "Run as administrator" via shortcut flag
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20  # Set byte 21 (0x15) bit 6 (0x20) to enable RunAsAdmin
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
    Write-Info "Desktop shortcut created: OneVPN Client"
} catch {
    Write-Host "Desktop shortcut not created (you can run one_client.exe from the install directory)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host ""
Write-Info "Starting client (Web UI will open automatically)..."
try {
    # Start as Administrator (UAC will prompt if not admin)
    Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir -Verb RunAs -WindowStyle Hidden
    Write-Host ""
    Write-Host "OneVPN client started; browser will open the Web UI." -ForegroundColor Green
    Write-Host "First run creates client.yaml in the install directory; no config download needed." -ForegroundColor Cyan
    Write-Host "Client will place wintun.dll on startup if missing (get from wintun.net if needed)." -ForegroundColor Cyan
    Write-Host "Complete config (wg_private_key, wg_server_public_key, server) in the Web UI and click Start VPN." -ForegroundColor Cyan
} catch {
    Write-Host "Auto-start failed; run manually as Administrator: $ExePath" -ForegroundColor Yellow
    Write-Host "Then open http://127.0.0.1:8081 to configure." -ForegroundColor Cyan
}
Write-Host ""
