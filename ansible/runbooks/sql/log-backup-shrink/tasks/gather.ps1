# Read-only. Returns one object describing why the log of $Database cannot be reused.
param(
    [string]$Instance = '.',
    [Parameter(Mandatory)][string]$Database,
    [string]$BackupPath = ''
)
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$conn = New-Object System.Data.SqlClient.SqlConnection "Server=$Instance;Database=master;Integrated Security=True;Application Name=ops-foundation"
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = @'
SELECT d.recovery_model_desc AS recovery_model,
       d.log_reuse_wait_desc AS log_reuse_wait,
       ISNULL(ars.role_desc, 'NONE') AS hadr_role,
       CAST(ls.total_log_size_mb AS decimal(18,1)) AS log_size_mb,
       CAST(ls.active_log_size_mb AS decimal(18,1)) AS active_log_mb,
       CAST(CASE WHEN ls.total_log_size_mb = 0 THEN 0
                 ELSE 100.0 * ls.active_log_size_mb / ls.total_log_size_mb END AS decimal(5,1)) AS log_used_pct,
       (SELECT TOP 1 name FROM sys.master_files WHERE database_id = d.database_id AND type_desc = 'LOG') AS log_file,
       lb.backup_finish_date AS last_log_backup_at,
       lb.user_name AS last_log_backup_by,
       lb.software_name AS last_log_backup_software
FROM sys.databases d
CROSS APPLY sys.dm_db_log_stats(d.database_id) ls
LEFT JOIN sys.dm_hadr_availability_replica_states ars ON ars.replica_id = d.replica_id AND ars.is_local = 1
OUTER APPLY (SELECT TOP 1 b.backup_finish_date, b.user_name, m.software_name
             FROM msdb.dbo.backupset b
             JOIN msdb.dbo.backupmediaset m ON m.media_set_id = b.media_set_id
             WHERE b.database_name = d.name AND b.type = 'L'
             ORDER BY b.backup_finish_date DESC) lb
WHERE d.name = @db;
'@
    [void]$cmd.Parameters.AddWithValue('@db', $Database)
    $r = $cmd.ExecuteReader()
    if (-not $r.Read()) { throw "Database '$Database' not found on $Instance" }
    $state = [ordered]@{}
    for ($i = 0; $i -lt $r.FieldCount; $i++) {
        $v = $r.GetValue($i)
        if ($v -is [DBNull]) { $v = $null }
        elseif ($v -is [datetime]) { $v = $v.ToUniversalTime().ToString('o') }
        elseif ($v -is [decimal]) { $v = [double]$v }
        $state[$r.GetName($i)] = $v
    }
    $r.Close()
} finally {
    $conn.Close()
}

# Free space where a native backup would land. Works for local folders and UNC shares.
$state['backup_target_free_mb'] = $null
if ($BackupPath) {
    Add-Type -Namespace OpsFoundation -Name Disk -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool GetDiskFreeSpaceEx(string dir, out ulong freeToCaller, out ulong total, out ulong totalFree);
'@
    $free = [uint64]0; $total = [uint64]0; $totalFree = [uint64]0
    if ([OpsFoundation.Disk]::GetDiskFreeSpaceEx($BackupPath, [ref]$free, [ref]$total, [ref]$totalFree)) {
        $state['backup_target_free_mb'] = [math]::Round($free / 1MB)
    }
}

[pscustomobject]$state
