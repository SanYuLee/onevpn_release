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

function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Green }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# 使用 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
$Files = @("one_client.exe", "client.yaml", "VERSION", "README.md")

if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
Set-Location $InstallDir

# 配置文件：不存在则下载（首次安装）；已存在则可交互时询问、不可交互时默认不覆盖
$SkipClientYaml = $false
if (Test-Path "client.yaml") {
    if ($env:OVERWRITE_CONFIG -eq "1") {
        $SkipClientYaml = $false
    } elseif (-not [Environment]::UserInteractive) {
        Write-Info "已存在 client.yaml，跳过下载（保留现有配置）。若需覆盖可设置 OVERWRITE_CONFIG=1 后重试"
        $SkipClientYaml = $true
    } else {
        $r = Read-Host "目录下已存在 client.yaml，是否覆盖？(y/N)"
        if ($r -notmatch '^[yY]') { $SkipClientYaml = $true }
    }
} else {
    Write-Info "未检测到 client.yaml，将下载默认配置"
}

Write-Info "正在安装 OneVPN 客户端 $Version 到 $InstallDir ..."
foreach ($f in $Files) {
    if ($f -eq "client.yaml" -and $SkipClientYaml) {
        Write-Info "  跳过 client.yaml（保留现有配置）"
        continue
    }
    Write-Info "  下载 $f"
    try {
        Invoke-WebRequest -Uri "$Base/$f" -OutFile $f -UseBasicParsing
    } catch {
        Write-Err "下载 $f 失败: $_"
        exit 1
    }
}

Write-Info "客户端文件已安装到: $InstallDir"

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

$ExePath = Join-Path $InstallDir "one_client.exe"

Write-Info "正在启动客户端（程序启动后会自动打开 Web 管理界面）..."
try {
    # 以管理员身份启动（若当前非管理员，UAC 会提示）
    Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir -Verb RunAs -WindowStyle Hidden
    Write-Host ""
    Write-Host "已启动 OneVPN 客户端，浏览器将自动打开 Web 管理界面。" -ForegroundColor Green
    Write-Host "请在页面中完成 server、password 等配置并保存，然后点击「启动服务」。" -ForegroundColor Cyan
} catch {
    Write-Host "自动启动失败，请手动以管理员身份运行: $ExePath" -ForegroundColor Yellow
    Write-Host "运行后程序会自动打开 http://127.0.0.1:8081 进行配置。" -ForegroundColor Cyan
}
Write-Host ""
