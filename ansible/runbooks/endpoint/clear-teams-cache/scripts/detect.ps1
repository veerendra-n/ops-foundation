# Intune remediation detection. Runs as the logged-on user.
# On-demand runs should always remediate when a Teams cache exists, so exit 1 if one does.
$paths = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams'),
    (Join-Path $env:APPDATA 'Microsoft\Teams')
)
if ($paths | Where-Object { Test-Path $_ }) {
    Write-Output 'Teams cache present'
    exit 1
}
Write-Output 'No Teams cache found'
exit 0
