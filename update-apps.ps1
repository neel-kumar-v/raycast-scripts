#!/usr/bin/env pwsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Update All Apps
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon ⬆️
# @raycast.packageName Developer Tools

# Documentation:
# @raycast.description Updates every winget-tracked app, then Waku (via GitHub releases) and Delta (launches it so its built-in updater applies pending updates).
# @raycast.author green

$LogPath = Join-Path $env:LOCALAPPDATA 'update-apps.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $line
    try { Add-Content -LiteralPath $LogPath -Value $line -ErrorAction Stop } catch {}
}

function Compare-VersionNewer {
    param([string]$Candidate, [string]$Current)
    try {
        $a = [version](($Candidate -replace '^v', '') -split '-' | Select-Object -First 1)
        $b = [version](($Current -replace '^v', '') -split '-' | Select-Object -First 1)
        return $a -gt $b
    } catch {
        return ($Candidate -ne $Current)
    }
}

function Invoke-WingetUpdate {
    Write-Log 'Running winget upgrade --all'
    $common = @(
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity',
        '--silent',
        '--include-unknown'
    )
    & winget upgrade --all @common 2>&1 | Out-Host
    Write-Log "winget --all exit code: $LASTEXITCODE"
}

function Get-WakuInstalledVersion {
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $app = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq 'Waku' } |
        Select-Object -First 1
    return $app.DisplayVersion
}

function Update-Waku {
    $rel = $null
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/egoist/waku/releases/latest' `
            -Headers @{ 'User-Agent' = 'update-apps' } -ErrorAction Stop
    } catch {
        Write-Log "Waku: failed to reach GitHub API: $_" 'WARN'
        return
    }

    $latest = $rel.tag_name -replace '^v', ''
    $installed = Get-WakuInstalledVersion

    if (-not $installed) {
        Write-Log 'Waku: not detected in registry' 'WARN'
        return
    }

    Write-Log "Waku: installed=$installed latest=$latest"
    if (-not (Compare-VersionNewer -Candidate $latest -Current $installed)) {
        Write-Log 'Waku: already up to date'
        return
    }

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
    $asset = $rel.assets |
        Where-Object { $_.name -match "Waku-.*$([regex]::Escape($arch))-Setup\.exe$" } |
        Select-Object -First 1

    if (-not $asset) {
        Write-Log "Waku: no $arch Setup.exe asset found in release" 'WARN'
        return
    }

    $tmp = Join-Path $env:TEMP "Waku-$latest-Setup.exe"
    Write-Log "Waku: downloading $($asset.browser_download_url)"

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -ErrorAction Stop
    } catch {
        Write-Log "Waku: download failed: $_" 'WARN'
        return
    }

    Write-Log 'Waku: running installer (silent)'
    $p = Start-Process -FilePath $tmp -ArgumentList `
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS', '/SP-' -Wait -PassThru
    Write-Log "Waku: installer exit code: $($p.ExitCode)"
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

function Ensure-DeltaUpdated {
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Delta\delta.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Log "Delta: not found at $exe" 'WARN'
        return
    }

    if (Get-Process -Name delta -ErrorAction SilentlyContinue) {
        Write-Log 'Delta: already running (its built-in updater is active)'
        return
    }

    Write-Log 'Delta: launching so its built-in updater applies pending updates'
    Start-Process -FilePath $exe
}

Write-Log '=== Update run started ==='
Invoke-WingetUpdate
Update-Waku
Ensure-DeltaUpdated
Write-Log '=== Update run finished ==='