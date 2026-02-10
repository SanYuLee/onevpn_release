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

# 检测管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Err "此脚本需要管理员权限才能运行"
    Write-Host ""
    Write-Host "请以管理员身份重新运行此脚本：" -ForegroundColor Yellow
    Write-Host "  1. 右键点击 PowerShell → 以管理员身份运行" -ForegroundColor Cyan
    Write-Host "  2. 或在 PowerShell 中运行: Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath'" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Green }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

# 使用 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 检测 TAP 驱动是否已安装
function Test-TAPDriver {
    $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*TAP*" -or $_.InterfaceDescription -like "*TAP*" }
    return ($null -ne $adapter)
}

# 获取系统架构（32位或64位）
function Get-SystemArchitecture {
    if ([Environment]::Is64BitOperatingSystem) {
        return "x64"
    } else {
        return "x86"
    }
}

# 获取 Windows 版本信息
function Get-WindowsVersion {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $version = [version]$os.Version
    return $version
}

# 检测是否需要安装 TAP 驱动
$needTapDriver = -not (Test-TAPDriver)
if ($needTapDriver) {
    Write-Host ""
    Write-Warn "未检测到 TAP-Windows 驱动"

    # 检查是否为自动安装模式（通过环境变量）
    $autoInstall = $false
    if ($env:AutoInstallTap -eq "1") {
        $autoInstall = $true
    } elseif ([Environment]::UserInteractive) {
        # 交互模式下询问用户
        $response = Read-Host "是否自动下载并安装 TAP 驱动？(Y/n)"
        if ($response -eq "" -or $response -match '^[yY]') {
            $autoInstall = $true
        }
    }

    if (-not $autoInstall) {
        Write-Warn "跳过驱动安装，VPN 可能无法正常运行"
        $needTapDriver = $false
    }
} else {
    Write-Host ""
    Write-Info "检测到 TAP 驱动已安装"
}
Write-Host ""

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
$winVersion = Get-WindowsVersion

if ($arch -eq "x64") {
    $clientExe = "one_client-amd64.exe"
    Write-Info "检测到 64位系统，将下载 64位客户端"
} else {
    $clientExe = "one_client-x86.exe"
    Write-Info "检测到 32位系统，将下载 32位客户端"
}

# 基础下载文件列表
$Files = @($clientExe, "client.yaml", "VERSION", "README.md")

# 如果需要安装驱动，添加驱动文件到下载列表
$tapFiles = @()
if ($needTapDriver) {
    # 根据 Windows 版本和架构选择驱动文件
    if ($winVersion.Major -ge 10) {
        $tapDir = "win10"
        Write-Info "将下载 Windows 10+ 驱动"
    } else {
        $tapDir = "win7"
        Write-Info "将下载 Windows 7/8 驱动"
    }

    if ($arch -eq "x64") {
        $tapArchDir = "amd64"
    } else {
        $tapArchDir = "i386"
    }

    # 添加驱动文件到下载列表（从固定的 tap 目录下载）
    $tapBase = "$RepoRaw/tap/$tapDir/$tapArchDir"
    $tapFiles = @(
        "OemVista.inf",
        "tap0901.cat",
        "tap0901.sys"
    )

    # 记录驱动下载路径
    $tapRemoteBase = $tapBase
}

# 合并所有下载文件
$allFiles = $Files + $tapFiles

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

Write-Info "正在下载 OneVPN 客户端 $Version 到 $InstallDir ..."
$tempDir = Join-Path $env:TEMP "onevpn-install"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 第一阶段：下载所有文件
$downloadFiles = $Files
if ($needTapDriver) {
    $downloadFiles = $allFiles
}

foreach ($f in $downloadFiles) {
    if ($f -eq "client.yaml" -and $SkipClientYaml) {
        Write-Info "  跳过 client.yaml（保留现有配置）"
        continue
    }

    # 对于客户端 exe，下载后重命名为 one_client.exe
    $outputFile = $f
    if ($f -match "one_client-(amd64|x86)\.exe") {
        $outputFile = "one_client.exe"
    }

    # 判断文件来源（客户端文件 vs 驱动文件）
    if ($tapFiles -contains $f) {
        $fileUrl = "$tapRemoteBase/$f"
        $destPath = Join-Path $tempDir $f
    } else {
        $fileUrl = "$Base/$f"
        $destPath = Join-Path $tempDir $f
    }

    Write-Info "  下载 $f"
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile $destPath -UseBasicParsing
    } catch {
        Write-Err "下载 $f 失败: $_"
        exit 1
    }
}

Write-Info "所有文件下载完成"

# 第二阶段：复制驱动文件到安装目录（如果需要）
if ($needTapDriver) {
    Write-Host ""
    Write-Info "正在复制驱动文件..."

    $tapDestDir = Join-Path $InstallDir "tap"
    if (-not (Test-Path $tapDestDir)) {
        New-Item -ItemType Directory -Path $tapDestDir -Force | Out-Null
    }

    foreach ($f in $tapFiles) {
        $srcFile = Join-Path $tempDir $f
        $destFile = Join-Path $tapDestDir $f
        Copy-Item -Path $srcFile -Destination $destFile -Force
        Write-Info "  已安装驱动文件: $f"
    }
}

# 第三阶段：安装驱动（如果需要）
$driverInstalled = $false
if ($needTapDriver) {
    Write-Host ""
    Write-Info "正在安装 TAP 驱动..."

    $infFile = Join-Path $InstallDir "tap\OemVista.inf"
    if (-not (Test-Path $infFile)) {
        Write-Warn "驱动文件未找到，跳过安装"
    } else {
        try {
            Write-Warn "此过程可能需要 10-30 秒，请稍候..."

            # 尝试安装驱动（先尝试正常安装，失败则尝试强制安装）
            $exitCode = 0
            try {
                $process = Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver", "`"$infFile`"", "/install", "/noreboot" -Wait -PassThru -WindowStyle Hidden
                $exitCode = $process.ExitCode
            } catch {
                $exitCode = -1
            }

            # 如果安装失败，尝试强制安装
            if ($exitCode -ne 0 -and $exitCode -ne 3010) {
                Write-Info "尝试强制安装驱动..."
                try {
                    $process = Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver", "`"$infFile`"", "/install", "/noreboot", "/force" -Wait -PassThru -WindowStyle Hidden
                    $exitCode = $process.ExitCode
                } catch {
                    $exitCode = -1
                }
            }

            # 检查安装结果
            if ($exitCode -eq 0) {
                Write-Info "TAP 驱动安装成功！"
                $driverInstalled = $true
            } elseif ($exitCode -eq 3010) {
                Write-Info "TAP 驱动安装成功，但需要重启计算机才能生效"
                Write-Warn "请重启计算机后再次运行 OneVPN 客户端"
                $driverInstalled = $true
            } elseif ($exitCode -eq -1797) {
                # 错误码 -1797 (0xFFFFF909) 表示驱动未签名
                Write-Warn "驱动未签名或系统禁止安装未签名驱动"
                Write-Host "已下载客户端和驱动文件，但驱动安装失败，请手动安装" -ForegroundColor Yellow
                Write-Host "驱动文件位置: $infFile" -ForegroundColor Cyan
                Write-Host "提示：可以尝试以下方法安装：" -ForegroundColor Cyan
                Write-Host "  1. 临时禁用驱动签名强制：bcdedit /set testsigning on（需要重启）" -ForegroundColor Cyan
                Write-Host "  2. 右键 OemVista.inf → 安装" -ForegroundColor Cyan
            } elseif ($exitCode -eq -1073700886) {
                # 错误码 -1073700886 (0xC000007A) 表示系统资源不足
                Write-Warn "系统资源不足，无法安装驱动"
                Write-Host "已下载客户端和驱动文件，但驱动安装失败，请手动安装" -ForegroundColor Yellow
                Write-Host "驱动文件位置: $infFile" -ForegroundColor Cyan
            } else {
                # 其他错误，可能是驱动已安装
                $checkExisting = & pnputil /enum-drivers | Select-String -Pattern "tap0901" -Quiet
                if ($checkExisting) {
                    Write-Info "TAP 驱动已存在于系统中"
                    $driverInstalled = $true
                } else {
                    Write-Warn "TAP 驱动安装失败，退出码: $exitCode"
                    Write-Host "已下载客户端和驱动文件，但驱动安装失败，请手动安装" -ForegroundColor Yellow
                    Write-Host "驱动文件位置: $infFile" -ForegroundColor Cyan
                    Write-Host "尝试手动安装命令：" -ForegroundColor Cyan
                    Write-Host "  pnputil /add-driver `"$infFile`" /install" -ForegroundColor White
                }
            }

            # 等待驱动加载
            Start-Sleep -Seconds 3

            if ($driverInstalled) {
                if (Test-TAPDriver) {
                    Write-Info "TAP 驱动检测成功！"
                } else {
                    Write-Warn "TAP 驱动可能未正确安装，建议重启计算机"
                }
            }
        } catch {
            Write-Warn "TAP 驱动安装失败: $_"
            Write-Host "已下载客户端和驱动文件，但驱动安装失败，请手动安装" -ForegroundColor Yellow
            Write-Host "驱动文件位置: $infFile" -ForegroundColor Cyan
        }
    }
}

# 第四阶段：复制客户端文件到安装目录
Write-Host ""
Write-Info "正在复制文件到安装目录..."

foreach ($f in $Files) {
    if ($f -eq "client.yaml" -and $SkipClientYaml) {
        continue
    }

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

# 只有在驱动已安装成功或不需要安装驱动时才启动客户端
if (-not $needTapDriver -or $driverInstalled) {
    Write-Host ""
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
} else {
    Write-Host ""
    Write-Warn "驱动安装失败，未启动客户端"
    Write-Host "请手动安装驱动或重启计算机后，运行: $ExePath" -ForegroundColor Yellow
}
Write-Host ""
