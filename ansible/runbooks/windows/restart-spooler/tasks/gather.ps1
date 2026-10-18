# Read-only. Spooler state, stuck jobs and recent crashes.
param([int]$StuckMinutes = 15)
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$svc = Get-CimInstance Win32_Service -Filter "Name='Spooler'"
$role = (Get-CimInstance Win32_ComputerSystem).DomainRole   # 4 or 5 = domain controller
$since = (Get-Date).AddHours(-1)
$crashes = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Service Control Manager'; Id = 7031, 7034; StartTime = $since } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'Print Spooler' }).Count

$stuck = @()
$total = 0
if ($svc.State -eq 'Running') {
    $cutoff = (Get-Date).AddMinutes(-$StuckMinutes)
    foreach ($p in Get-Printer -ErrorAction SilentlyContinue) {
        foreach ($j in Get-PrintJob -PrinterObject $p -ErrorAction SilentlyContinue) {
            $total++
            if ($j.JobStatus -match 'Error|Deleting|Blocked' -or $j.SubmittedTime -lt $cutoff) {
                $stuck += [pscustomobject]@{ printer = $p.Name; id = $j.Id; status = "$($j.JobStatus)"; submitted = $j.SubmittedTime.ToUniversalTime().ToString('o') }
            }
        }
    }
}

[pscustomobject]@{
    service_state      = "$($svc.State)"
    start_mode         = "$($svc.StartMode)"
    is_domain_controller = ($role -ge 4)
    crashes_last_hour  = $crashes
    jobs_total         = $total
    jobs_stuck         = $stuck.Count
    stuck_jobs         = $stuck
}
