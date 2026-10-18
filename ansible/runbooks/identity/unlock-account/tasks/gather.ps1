# Read-only. Account state plus lockout events (4740) on this PDC emulator for the last 24 hours.
param([Parameter(Mandatory)][string]$Username)
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false
Import-Module ActiveDirectory

$privileged = 'Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators', 'Account Operators', 'Backup Operators', 'Server Operators'
$u = Get-ADUser -Filter "sAMAccountName -eq '$($Username -replace "'", "''")'" -Properties LockedOut, Enabled, badPwdCount, LockoutTime, LastBadPasswordAttempt, AdminCount, MemberOf
if (-not $u) {
    return [pscustomobject]@{ found = $false; username = $Username }
}
$groups = @($u.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' })

$events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740; StartTime = (Get-Date).AddHours(-24) } -ErrorAction SilentlyContinue |
    Where-Object { $_.Properties[0].Value -eq $u.SamAccountName })
$sources = @($events | ForEach-Object { $_.Properties[1].Value } | Group-Object | Sort-Object Count -Descending |
    ForEach-Object { [pscustomobject]@{ computer = $_.Name; count = $_.Count } })

[pscustomobject]@{
    found              = $true
    username           = $u.SamAccountName
    enabled            = [bool]$u.Enabled
    locked             = [bool]$u.LockedOut
    privileged         = ([int]$u.AdminCount -eq 1) -or [bool]($groups | Where-Object { $_ -in $privileged })
    bad_password_count = [int]$u.badPwdCount
    last_bad_password  = if ($u.LastBadPasswordAttempt) { $u.LastBadPasswordAttempt.ToUniversalTime().ToString('o') } else { $null }
    lockouts_24h       = $events.Count
    lockout_sources    = $sources
}
