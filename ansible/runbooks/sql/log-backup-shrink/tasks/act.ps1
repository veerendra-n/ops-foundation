# Changes state. Only called after the decision step and the approval check.
param(
    [string]$Instance = '.',
    [Parameter(Mandatory)][string]$Database,
    [bool]$Backup = $true,
    [bool]$Shrink = $true,
    [ValidateSet('agent_job', 'native')][string]$Mode = 'agent_job',
    [string]$AgentJob = '',
    [string]$BackupPath = '',
    [string]$RunId = 'manual',
    [int]$ShrinkTargetMb = 4096,
    [int]$JobTimeoutSeconds = 1800
)
$ErrorActionPreference = 'Stop'
$RunId = $RunId -replace '[^A-Za-z0-9_.-]', ''

function Invoke-Sql([System.Data.SqlClient.SqlConnection]$Conn, [string]$Sql, [hashtable]$Params = @{}, [int]$Timeout = 0) {
    $cmd = $Conn.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = $Timeout
    foreach ($k in $Params.Keys) { [void]$cmd.Parameters.AddWithValue($k, $Params[$k]) }
    $cmd.ExecuteScalar()
}

$conn = New-Object System.Data.SqlClient.SqlConnection "Server=$Instance;Database=master;Integrated Security=True;Application Name=ops-foundation"
$conn.Open()
try {
    if ($Backup -and $Mode -eq 'agent_job') {
        if (-not $AgentJob) { throw 'agent_job mode needs rb_agent_job' }
        $before = Invoke-Sql $conn "SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE database_name = @db AND type = 'L'" @{ '@db' = $Database }
        Invoke-Sql $conn 'EXEC msdb.dbo.sp_start_job @job_name = @job' @{ '@job' = $AgentJob } | Out-Null
        $deadline = (Get-Date).AddSeconds($JobTimeoutSeconds)
        do {
            Start-Sleep -Seconds 10
            $latest = Invoke-Sql $conn "SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE database_name = @db AND type = 'L'" @{ '@db' = $Database }
        } while (($latest -is [DBNull] -or ($before -isnot [DBNull] -and $latest -le $before)) -and (Get-Date) -lt $deadline)
        if ($latest -is [DBNull] -or ($before -isnot [DBNull] -and $latest -le $before)) {
            throw "Job '$AgentJob' did not produce a new log backup within $JobTimeoutSeconds seconds"
        }
        [pscustomobject]@{ action = 'log_backup'; mode = 'agent_job'; job = $AgentJob; finished_at = ([datetime]$latest).ToUniversalTime().ToString('o') }
    }
    elseif ($Backup) {
        if (-not $BackupPath) { throw 'native mode needs rb_backup_path' }
        $file = Join-Path $BackupPath ("{0}_{1}_{2}.trn" -f $env:COMPUTERNAME, $Database, $RunId)
        $sql = "DECLARE @s nvarchar(max) = N'BACKUP LOG ' + QUOTENAME(@db) + N' TO DISK = @f WITH CHECKSUM, NAME = N''ops-foundation ' + @run + N''''; EXEC sp_executesql @s, N'@f nvarchar(4000)', @f = @file;"
        Invoke-Sql $conn $sql @{ '@db' = $Database; '@file' = $file; '@run' = $RunId } | Out-Null
        [pscustomobject]@{ action = 'log_backup'; mode = 'native'; file = $file }
    }

    if ($Shrink) {
        $sql = @'
DECLARE @file sysname = (SELECT TOP 1 name FROM sys.master_files WHERE database_id = DB_ID(@db) AND type_desc = 'LOG');
DECLARE @s nvarchar(max) = N'USE ' + QUOTENAME(@db) + N'; DBCC SHRINKFILE (' + QUOTENAME(@file, '''') + N', ' + CAST(@target AS nvarchar(20)) + N') WITH NO_INFOMSGS;';
EXEC sp_executesql @s;
'@
        Invoke-Sql $conn $sql @{ '@db' = $Database; '@target' = $ShrinkTargetMb } | Out-Null
        [pscustomobject]@{ action = 'shrink_log'; target_mb = $ShrinkTargetMb }
    }
} finally {
    $conn.Close()
}
$Ansible.Changed = $true
