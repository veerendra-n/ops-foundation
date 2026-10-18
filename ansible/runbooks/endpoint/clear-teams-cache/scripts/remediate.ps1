# Intune remediation (or Level script). Runs as the logged-on user.
# Closes Teams, clears new and classic Teams caches, starts new Teams again.
$ErrorActionPreference = 'Continue'
$cleared = @()

Get-Process -Name 'ms-teams', 'Teams' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# New Teams (MSTeams package): Microsoft's documented cache location.
$newCache = Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams'
if (Test-Path $newCache) {
    Get-ChildItem -Path $newCache -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $cleared += 'new-teams'
}

# Classic Teams: cache folders only, keep settings.
$classic = Join-Path $env:APPDATA 'Microsoft\Teams'
foreach ($sub in 'Application Cache', 'blob_storage', 'Cache', 'Code Cache', 'databases', 'GPUCache', 'IndexedDB', 'Local Storage', 'tmp') {
    $p = Join-Path $classic $sub
    if (Test-Path $p) {
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        $cleared += "classic:$sub"
    }
}

if (Get-AppxPackage -Name 'MSTeams' -ErrorAction SilentlyContinue) {
    Start-Process 'explorer.exe' 'shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams'
}

Write-Output ("Cleared: {0}" -f ($cleared -join ', '))
exit 0
