# Changes state. Restarts the spooler and, when asked, removes only the stuck jobs' spool files.
param([bool]$Clear = $false, [int[]]$JobIds = @())
$ErrorActionPreference = 'Stop'

Stop-Service -Name Spooler -Force
(Get-Service Spooler).WaitForStatus('Stopped', [timespan]::FromSeconds(60))
[pscustomobject]@{ action = 'stop_spooler' }

if ($Clear -and $JobIds.Count -gt 0) {
    $dir = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
    $removed = @()
    foreach ($id in $JobIds) {
        Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -match ('{0:D5}$' -f $id) -and $_.Extension -in '.SPL', '.SHD' } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; $removed += $_.Name }
    }
    [pscustomobject]@{ action = 'remove_spool_files'; files = $removed }
}

Start-Service -Name Spooler
(Get-Service Spooler).WaitForStatus('Running', [timespan]::FromSeconds(60))
[pscustomobject]@{ action = 'start_spooler' }
$Ansible.Changed = $true
