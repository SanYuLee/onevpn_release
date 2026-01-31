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

Write-Info "正在安装 OneVPN 客户端 $Version 到 $InstallDir ..."
foreach ($f in $Files) {
    Write-Info "  下载 $f"
    try {
        Invoke-WebRequest -Uri "$Base/$f" -OutFile $f -UseBasicParsing
    } catch {
        Write-Err "下载 $f 失败: $_"
        exit 1
    }
}

Write-Info "客户端文件已安装到: $InstallDir"
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
