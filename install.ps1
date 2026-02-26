# OneVPN 客户端一键安装脚本（Windows）
# 用法（PowerShell，以管理员身份打开更佳）：
#   irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
# 或指定安装目录、版本号：
#   irm .../install.ps1 | iex -InstallDir "C:\onevpn-client" -Version "1.0.1"

param(
    [string]$InstallDir = "$env:USERPROFILE\onevpn-client",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$RepoRaw = "https://raw.githubusercontent.com/SanYuLee/onevpn_release/main"

# 检测管理员权限（仅用于提示；驱动安装由客户端启动时处理）
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "当前未以管理员权限运行。稍后启动客户端安装驱动时会触发 UAC 提示。"
}

function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Green }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

# 使用 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 获取系统架构（用于选择客户端 exe：x64 / x86）
function Get-SystemArchitecture {
    if ([Environment]::Is64BitOperatingSystem) {
        return "x64"
    } else {
        return "x86"
    }
}

# 获取当前平台对应的 wintun 目录名（amd64 / i386 / arm64），用于只下载本机所需的 wintun.dll
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
        Write-Err "无法获取最新版本号（LATEST）。"
        exit 1
    }
}
if ($Version -notmatch "^v") { $Version = "v$Version" }

$Base = "$RepoRaw/$Version/client"

# 根据系统架构选择对应的客户端文件
$arch = Get-SystemArchitecture

if ($arch -eq "x64") {
    $clientExe = "one_client-amd64.exe"
    Write-Info "检测到 64位系统，将下载 64位客户端"
} else {
    $clientExe = "one_client-x86.exe"
    Write-Info "检测到 32位系统，将下载 32位客户端"
}

# 基础下载文件列表（配置 client.yaml 由程序首次运行自动生成，不再下载）
$Files = @($clientExe, "VERSION", "README.md")
# 驱动文件（全量下载，客户端启动时自动选择并安装）
$DriverFiles = @(
    "tap/README.md",
    "tap/win10/include/tap-windows.h",
    "tap/win10/amd64/OemVista.inf",
    "tap/win10/amd64/tap0901.cat",
    "tap/win10/amd64/tap0901.sys",
    "tap/win10/amd64/devcon.exe",
    "tap/win10/i386/OemVista.inf",
    "tap/win10/i386/tap0901.cat",
    "tap/win10/i386/tap0901.sys",
    "tap/win10/i386/devcon.exe",
    "tap/win10/arm64/OemVista.inf",
    "tap/win10/arm64/tap0901.cat",
    "tap/win10/arm64/tap0901.sys",
    "tap/win10/arm64/devcon.exe",
    "tap/win7/include/tap-windows.h",
    "tap/win7/amd64/OemVista.inf",
    "tap/win7/amd64/tap0901.cat",
    "tap/win7/amd64/tap0901.sys",
    "tap/win7/amd64/tapinstall.exe",
    "tap/win7/i386/OemVista.inf",
    "tap/win7/i386/tap0901.cat",
    "tap/win7/i386/tap0901.sys",
    "tap/win7/i386/tapinstall.exe",
    "tap/win7/arm64/OemVista.inf",
    "tap/win7/arm64/tap0901.cat",
    "tap/win7/arm64/tap0901.sys",
    "tap/win7/arm64/tapinstall.exe"
)
# wintun（WireGuard 模式）：按当前平台架构只下载本机所需的 wintun.dll（若本地已有且 MD5 一致会跳过）
$wintunArch = Get-WintunArch
$WintunFiles = @("wintun/$wintunArch/wintun.dll")
Write-Info "当前平台 wintun 架构: $wintunArch，将按需下载 wintun.dll"

# 合并所有下载文件
$allFiles = $Files + $DriverFiles + $WintunFiles

# 获取 checksums.txt（单文件含 server/client/tap 全部路径，用于增量更新）
$Checksums = @{}
try {
    $cs = (Invoke-WebRequest -Uri "$RepoRaw/$Version/checksums.txt" -UseBasicParsing).Content
    foreach ($line in ($cs -split "`n")) {
        if ($line -match '^([a-fA-F0-9]{32})\s+(.+)$') {
            $Checksums[$Matches[2].Trim()] = $Matches[1].ToLower()
        }
    }
} catch { }

# 判断本地文件是否需要下载（MD5 未变化则跳过）
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

Write-Info "正在下载 OneVPN 客户端 $Version 到 $InstallDir ..."
$tempDir = Join-Path $env:TEMP "onevpn-install"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 第一阶段：下载所有文件
$downloadFiles = $allFiles

foreach ($f in $downloadFiles) {
    # 对于客户端 exe，下载后重命名为 one_client.exe
    $outputFile = $f
    if ($f -match "one_client-(amd64|x86)\.exe") {
        $outputFile = "one_client.exe"
    }

    # MD5 未变化则跳过下载（客户端主文件与驱动均支持）
    $checksumKey = if ($f -like "tap/*") { $f } elseif ($f -like "wintun/*") { "client/$f" } else { "client/$f" }
    $localPath = Join-Path $InstallDir $outputFile
    if (-not (Need-Download -RemoteFile $checksumKey -LocalPath $localPath)) {
        Write-Info "  跳过 $f（MD5 未变化）"
        $destPath = Join-Path $tempDir $f
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        if (Test-Path $localPath) { Copy-Item -Path $localPath -Destination $destPath -Force }
        continue
    }

    # 判断文件来源（客户端文件 vs tap 根目录 vs client 下 wintun）
    if ($f -like "tap/*") {
        $fileUrl = "$RepoRaw/$f"
    } elseif ($f -like "wintun/*") {
        $fileUrl = "$Base/$f"
    } else {
        $fileUrl = "$Base/$f"
    }
    $destPath = Join-Path $tempDir $f
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Info "  下载 $f"
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile $destPath -UseBasicParsing
    } catch {
        if ($f -like "wintun/*") {
            Write-Warn "  跳过 $f（未在发布包中或下载失败）；WireGuard 模式需 wintun.dll，请按 wintun/README.md 运行 fetch-wintun.sh 后重新构建"
        } else {
            Write-Err "下载 $f 失败: $_"
            exit 1
        }
    }
}

Write-Info "所有文件下载完成"

# 若客户端正在运行，先退出以便覆盖更新
$exePath = Join-Path $InstallDir "one_client.exe"
if (Test-Path $exePath) {
    $proc = Get-Process -Name "one_client" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Info "正在停止运行中的 OneVPN 客户端..."
        Stop-Process -Name "one_client" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Info "已停止客户端，继续执行更新"
    }
}

# 第二阶段：复制驱动文件到安装目录（tap + wintun）
Write-Host ""
Write-Info "正在复制驱动文件..."
foreach ($f in $DriverFiles) {
    $srcFile = Join-Path $tempDir $f
    if (Test-Path $srcFile) {
        $destFile = Join-Path $InstallDir $f
        $destDir = Split-Path $destFile -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $srcFile -Destination $destFile -Force
        Write-Info "  已复制: $f"
    }
}
foreach ($f in $WintunFiles) {
    $srcFile = Join-Path $tempDir $f
    if (Test-Path $srcFile) {
        $destFile = Join-Path $InstallDir $f
        $destDir = Split-Path $destFile -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $srcFile -Destination $destFile -Force
        Write-Info "  已复制: $f"
    }
}
Write-Info "驱动文件已准备完成，客户端启动时会自动检测并安装 TAP 驱动，并放置 wintun.dll 供 WireGuard 模式使用"

# 第三阶段：复制客户端文件到安装目录
Write-Host ""
Write-Info "正在复制文件到安装目录..."

foreach ($f in $Files) {
    $outputFile = $f
    if ($f -match "one_client-(amd64|x86)\.exe") {
        $outputFile = "one_client.exe"
    }

    $srcFile = Join-Path $tempDir $f
    $destFile = Join-Path $InstallDir $outputFile

    Copy-Item -Path $srcFile -Destination $destFile -Force
    Write-Info "  已安装: $outputFile"
}

# 清理临时目录
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Info "客户端文件已安装到: $InstallDir"

$ExePath = Join-Path $InstallDir "one_client.exe"

# 创建桌面快捷方式，便于退出后再次启动
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "OneVPN 客户端.lnk"
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Description = "OneVPN 客户端 - 双击启动，右键托盘图标可显示 Web 界面或退出"
    $Shortcut.Save()
    # 设置为“以管理员身份运行”（通过修改快捷方式参数）
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20  # Set byte 21 (0x15) bit 6 (0x20) to enable RunAsAdmin
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
    Write-Info "已创建桌面快捷方式: OneVPN 客户端"
} catch {
    Write-Host "未创建桌面快捷方式（可手动到安装目录运行 one_client.exe）" -ForegroundColor Yellow
}
Write-Host ""

Write-Host ""
Write-Info "正在启动客户端（程序启动后会自动打开 Web 管理界面）..."
try {
    # 以管理员身份启动（若当前非管理员，UAC 会提示）
    Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir -Verb RunAs -WindowStyle Hidden
    Write-Host ""
    Write-Host "已启动 OneVPN 客户端，浏览器将自动打开 Web 管理界面。" -ForegroundColor Green
    Write-Host "首次运行会在安装目录下自动生成 client.yaml，无需下载配置。" -ForegroundColor Cyan
    Write-Host "客户端会在启动时自动检测并安装 TAP/Wintun 驱动（若未安装）。" -ForegroundColor Cyan
    Write-Host "请在页面中完成配置并保存，然后点击「启动服务」。" -ForegroundColor Cyan
    Write-Host "支持 mode: legacy（填写 server、password）或 mode: wireguard（填写 wg_private_key、wg_server_public_key、server）。" -ForegroundColor Gray
} catch {
    Write-Host "自动启动失败，请手动以管理员身份运行: $ExePath" -ForegroundColor Yellow
    Write-Host "运行后程序会自动打开 http://127.0.0.1:8081 进行配置。" -ForegroundColor Cyan
}
Write-Host ""
