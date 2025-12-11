#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Instance Upgrade to SQL Server 2022 using Side-by-Side Installation
    
.DESCRIPTION
    This script orchestrates a comprehensive SQL Server upgrade using dbatools with modular design.
    The main script only imports modules and calls their functions - no function definitions are included.
    
.PARAMETER SourceInstance
    Source SQL Server instance name
    
.PARAMETER TargetInstance
    Target SQL Server 2022 instance name
    
.PARAMETER Databases
    Array of database names to upgrade. Use 'All' for all user databases.
    If omitted and 'Databases' is not in -Exclude, defaults to 'All' (migrate all user databases).
    If omitted and 'Databases' is in -Exclude, no databases are migrated (server objects only).
    
.PARAMETER IncludeEncryption
    Include encrypted objects and TDE databases
    
.PARAMETER WhatIf
    Show what would be done without making changes
    
.PARAMETER LogPath
    Path for detailed log files (default: C:\Logs\SQLUpgrade)

.PARAMETER MigrationMethod
    Migration method: 'Direct' (default), 'BackupRestore', or 'DetachAttach'

.PARAMETER BackupPath
    Path for backup files (required for BackupRestore method when creating new backups)

.PARAMETER UseExistingBackups
    Use existing backup files instead of creating new ones

.PARAMETER FullBackupPath
    Path to existing full backup file

.PARAMETER DifferentialBackupPath
    Path to existing differential backup file

.PARAMETER LogBackupPaths
    Array of paths to existing log backup files

.PARAMETER Exclude
    Server objects to exclude from migration. Valid values:
    'Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 
    'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 
    'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 
    'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'DataCollector', 'StartupProcedures'

.PARAMETER IncludeSupportDbs
    Include utility databases (ReportServer, SSISDB, distribution, etc.)
    By default, these databases are excluded to prevent conflicts with existing services.
    Use this when migrating servers with SQL Server Reporting Services, Integration Services, or replication configured.
    
.EXAMPLE
    # Full migration (all databases and all server objects - default behavior)
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1"
    
.EXAMPLE
    # Server objects only (no database migration)
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Exclude 'Databases'

.EXAMPLE
    # Specific databases only
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2")

.EXAMPLE
    # Full migration with encryption support
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -IncludeEncryption

.EXAMPLE
    # Full migration excluding logins and Agent jobs
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Exclude 'Logins','AgentServer'

.EXAMPLE
    # Backup/Restore migration method
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -MigrationMethod BackupRestore -BackupPath "C:\Backups"

.EXAMPLE
    # Restore from existing backups
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("MyDB") -MigrationMethod BackupRestore -UseExistingBackups -FullBackupPath "C:\Backups\MyDB_Full.bak"

.EXAMPLE
    # Include utility databases (SSRS, SSIS, replication)
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -IncludeSupportDbs
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceInstance,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetInstance,
    
    # Optional: Filter which databases to migrate. Defaults to 'All' if not specified.
    # Use -Exclude 'Databases' to skip database migration entirely.
    [ValidateScript({
        if ($null -eq $_ -or $_ -eq "All" -or ($_ -is [array] -and $_.Count -gt 0) -or ($_ -is [string] -and $_ -ne "")) {
            $true
        } else {
            throw "Databases must be 'All' or an array of database names"
        }
    })]
    $Databases,
    
    [switch]$IncludeEncryption,
    [string]$LogPath = "c:\temp\SQLUpgrade",
    
    # Migration Method Options
    [ValidateSet('Direct', 'BackupRestore', 'DetachAttach')]
    [string]$MigrationMethod = 'Direct',
    
    [string]$BackupPath,
    [switch]$UseExistingBackups,
    [string]$FullBackupPath,
    [string]$DifferentialBackupPath,
    [string[]]$LogBackupPaths,
    
    # Exclusion parameter - use to skip specific components (dbatools-style)
    # By default, ALL components are migrated. Use -Exclude to skip specific ones.
    [ValidateSet('Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'DataCollector', 'StartupProcedures')]
    [string[]]$Exclude = @(),
    
    # Support database inclusion parameter
    [switch]$IncludeSupportDbs
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Import all required modules
$ModulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $ModulePath "SQLUpgrade.Logging.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Connection.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Database.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Encryption.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Migration.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.PostUpgrade.psm1") -Force

# Validate conflicting parameters
if ($PSBoundParameters.ContainsKey('Databases') -and $Exclude -contains 'Databases') {
    throw "You cannot specify -Databases and also exclude 'Databases' via -Exclude. Remove one of these parameters."
}

# Execute upgrade process using module functions only
try {
    $logInfo = Initialize-UpgradeLogging -LogPath $LogPath
    
    # Establish connections to source and target instances
    $sourceConnection = Test-InstanceConnectivity -Instance $SourceInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    $targetConnection = Test-InstanceConnectivity -Instance $TargetInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    Test-CollationCompatibility -SourceConnection $sourceConnection -TargetConnection $targetConnection -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    # Build server object options based purely on -Exclude parameter (dbatools-style)
    # By default, ALL server objects are migrated. Use -Exclude to skip specific ones.
    $serverObjectOptions = @{
        IncludeLogins             = ($Exclude -notcontains 'Logins')
        IncludeJobs               = ($Exclude -notcontains 'AgentServer')
        IncludeLinkedServers      = ($Exclude -notcontains 'LinkedServers')
        IncludeTriggers           = ($Exclude -notcontains 'SystemTriggers')
        IncludeServerRoles        = ($Exclude -notcontains 'Logins')
        IncludeCredentials        = ($Exclude -notcontains 'Credentials')
        IncludeProxyAccounts      = ($Exclude -notcontains 'AgentServer')
        IncludeAlerts             = ($Exclude -notcontains 'AgentServer')
        IncludeOperators          = ($Exclude -notcontains 'AgentServer')
        IncludeBackupDevices      = ($Exclude -notcontains 'BackupDevices')
        IncludeServerConfiguration = ($Exclude -notcontains 'SpConfigure')
    }
    
    # Migrate server objects if any are enabled
    $shouldMigrateServerObjects = $serverObjectOptions.Values -contains $true
    
    if ($shouldMigrateServerObjects) {
        Write-UpgradeLog -Message "Server object migration options: $(($serverObjectOptions.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) -join ', ')" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        Copy-ServerObjects -SourceConnection $sourceConnection -TargetConnection $targetConnection -ServerObjectOptions $serverObjectOptions -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    } else {
        Write-UpgradeLog -Message "Server object migration skipped (all server objects excluded)" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Migrate databases (if not excluded)
    $processedDatabases = @()
    if ($Exclude -notcontains 'Databases') {
        # Determine effective database filter: use provided value or default to 'All'
        $effectiveDatabaseFilter = if ($PSBoundParameters.ContainsKey('Databases')) {
            $Databases
        } else {
            'All'
        }
        
        # Get databases to process (only when databases are NOT excluded)
        $databasesToProcess = Get-UserDatabases -Connection $sourceConnection -DatabaseFilter $effectiveDatabaseFilter -IncludeSupportDbs:$IncludeSupportDbs -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        Write-UpgradeLog -Message "Starting database migration for $($databasesToProcess.Count) databases" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        foreach ($database in $databasesToProcess) {
            try {
                Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption:$IncludeEncryption -MigrationMethod $MigrationMethod -BackupPath $BackupPath -UseExistingBackups:$UseExistingBackups -FullBackupPath $FullBackupPath -DifferentialBackupPath $DifferentialBackupPath -LogBackupPaths $LogBackupPaths -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
                $processedDatabases += $database.Name
            } catch {
                Write-UpgradeLog -Message "Failed to process database $($database.Name): $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
            }
        }
    } else {
        Write-UpgradeLog -Message "Database migration excluded via -Exclude parameter" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Run post-upgrade tasks
    if ($processedDatabases.Count -gt 0 -and -not $WhatIf) {
        Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
} catch {
    Write-UpgradeLog -Message "Critical error: $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
    throw
}
