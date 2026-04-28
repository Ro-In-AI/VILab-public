param()

$ErrorActionPreference = "Stop"

function Get-EnvOrDefault {
    param(
        [string] $Name,
        [string] $Default
    )

    $Value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Default
    }
    return $Value
}

function Write-Step {
    param([string] $Message)
    Write-Host "→ " -NoNewline -ForegroundColor Cyan
    Write-Host $Message
}

function Write-Success {
    param([string] $Message)
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host $Message
}

function Write-Warn {
    param([string] $Message)
    Write-Host "Warning: " -NoNewline -ForegroundColor Yellow
    Write-Host $Message
}

function Write-Banner {
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "│                 VILab 快速安装                         │" -ForegroundColor Magenta
    Write-Host "├─────────────────────────────────────────────────────────┤" -ForegroundColor Magenta
    Write-Host "│  声音输入能力平台：桌面客户端 + 无头服务器              │" -ForegroundColor Magenta
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
    Write-Host ""
}

function Stop-Install {
    param([string] $Message)
    throw "vilab install: $Message"
}

function Get-LatestRelease {
    param([string] $Repo)

    $Uri = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        return Invoke-RestMethod -Uri $Uri -Headers @{ "User-Agent" = "vilab-installer" }
    } catch {
        Stop-Install "无法读取最新发布信息：$Uri"
    }
}

function Resolve-InstallerAsset {
    param($Release)

    $Assets = @($Release.assets)
    $Patterns = @(
        '(?i)(setup|installer).*\.exe$',
        '(?i)\.exe$',
        '(?i)\.msi$'
    )

    foreach ($Pattern in $Patterns) {
        $Match = $Assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
        if ($null -ne $Match) {
            return $Match
        }
    }

    Stop-Install "latest release 中没有找到 Windows 安装包（.exe 或 .msi）"
}

function Install-WindowsDesktop {
    $ReleaseRepo = Get-EnvOrDefault "VILAB_RELEASE_REPO" "Ro-In-AI/VILab-public"
    Write-Success "检测到平台：Windows"
    Write-Step "读取 $ReleaseRepo 的最新发布资源..."
    $Release = Get-LatestRelease $ReleaseRepo
    $Asset = Resolve-InstallerAsset $Release
    $TargetPath = Join-Path $env:TEMP $Asset.name

    Write-Step "下载：$($Asset.browser_download_url)"
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $TargetPath -Headers @{ "User-Agent" = "vilab-installer" }

    Write-Step "已下载 Windows 安装包：$TargetPath"
    if ($Asset.name -match '(?i)\.msi$') {
        Write-Step "正在启动 MSI 安装器。"
        Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", $TargetPath) -Wait
    } else {
        Write-Step "正在启动安装器。"
        Start-Process -FilePath $TargetPath -Wait
    }

    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "│                 桌面客户端安装完成                     │" -ForegroundColor Green
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "安装后配置：" -ForegroundColor Cyan
    Write-Host "  1. 打开 VILab 桌面客户端"
    Write-Host "  2. 在设置里选择远程 VILab Server"
    Write-Host "  3. 填入 Server URL 和 external API key"
}

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    Stop-Install "这个 PowerShell 脚本只用于原生 Windows。macOS/Linux/WSL2 请运行 install.sh。"
}

Write-Banner
Install-WindowsDesktop
