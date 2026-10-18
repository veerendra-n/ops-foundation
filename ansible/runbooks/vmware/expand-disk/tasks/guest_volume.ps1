# Read-only. Size, use and backing disk serial of a Windows drive.
param([Parameter(Mandatory)][string]$Drive)
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false
$letter = $Drive.TrimEnd(':', '\')
Update-HostStorageCache
$part = Get-Partition -DriveLetter $letter
$disk = $part | Get-Disk
$vol = $part | Get-Volume
$later = @(Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Offset -gt $part.Offset })
[pscustomobject]@{
    serial          = ("$($disk.SerialNumber)" -replace '[^0-9A-Fa-f]', '').ToLower()
    size_gb         = [math]::Round($vol.Size / 1GB, 1)
    used_pct        = [math]::Round(100 * (1 - $vol.SizeRemaining / $vol.Size), 1)
    blocked         = $later.Count -gt 0
    blocked_by      = @($later | ForEach-Object { "$($_.Type)" })
}
