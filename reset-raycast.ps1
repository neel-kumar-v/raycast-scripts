#!/usr/bin/env pwsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Refresh Raycast Cache
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.packageName System

# Documentation:
# @raycast.description Clears Raycast cache and relaunches the app to fix lag on Windows.
# @raycast.author green

Write-Host "Clearing cache files..."
# 1. Clear Raycast local app data cache on Windows
$CachePath = "$env:LocalAppData\Raycast\Cache"
if (Test-Path $CachePath) {
    Remove-Item -Path "$CachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Relaunching Raycast clean..."
# 2. Detach a background job to kill and restart the process so it survives Raycast closing
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 1
    Stop-Process -Name "Raycast" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    # Relaunch the Raycast Windows client application
    $RaycastPath = "$env:LocalAppData\Programs\Raycast\Raycast.exe"
    if (Test-Path $RaycastPath) {
        Start-Process -FilePath $RaycastPath
    } else {
        # Fallback if installed via alternative Microsoft Store paths
        Start-Process -FilePath "raycast" -ErrorAction SilentlyContinue
    }
} | Out-Null

Write-Host "Done! Restarting..."
