#!/usr/bin/env pwsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Register "Update All Apps" Daily Task
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🗓️
# @raycast.packageName Developer Tools

# Documentation:
# @raycast.description Creates a Windows scheduled task that runs update-apps.ps1 every day at 08:00.
# @raycast.author green

$taskName = 'Update All Apps'
$scriptPath = Join-Path $PSScriptRoot 'update-apps.ps1'

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Host "Scheduled task '$taskName' already exists."
    exit 0
}

if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Host "Could not find update-apps.ps1 next to this script." -ForegroundColor Red
    exit 1
}

$pwsh = (Get-Command pwsh).Source
if (-not $pwsh) {
    Write-Host "PowerShell 7 (pwsh) not found." -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At '08:00'
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Scheduled task '$taskName' registered (daily 08:00)."
Write-Host "Run it any time: schtasks /Run /TN '$taskName'"