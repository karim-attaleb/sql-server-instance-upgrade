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
    Array of database names to upgrade. Use 'All' for all user databases
    
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

.PARAMETER IncludeLogins
    Migrate SQL Server logins (excluding system logins)

.PARAMETER IncludeJobs
    Migrate SQL Server Agent jobs

.PARAMETER IncludeLinkedServers
    Migrate linked servers

.PARAMETER IncludeTriggers
    Migrate server-level triggers

.PARAMETER IncludeServerRoles
    Migrate custom server roles

.PARAMETER IncludeCredentials
    Migrate credentials

.PARAMETER IncludeProxyAccounts
    Migrate SQL Server Agent proxy accounts

.PARAMETER IncludeAlerts
    Migrate SQL Server Agent alerts

.PARAMETER IncludeOperators
    Migrate SQL Server Agent operators

.PARAMETER IncludeBackupDevices
    Migrate backup devices

.PARAMETER IncludeServerConfiguration
    Migrate server configuration settings

.PARAMETER IncludeAllServerObjects
    Migrate all server-level objects (equivalent to enabling all individual switches)

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
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2") -WhatIf
    
.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeEncryption

.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeAllServerObjects

.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeLogins -IncludeJobs -IncludeLinkedServers

.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -MigrationMethod BackupRestore -BackupPath "C:\Backups"

.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("MyDB") -MigrationMethod BackupRestore -UseExistingBackups -FullBackupPath "C:\Backups\MyDB_Full.bak" -DifferentialBackupPath "C:\Backups\MyDB_Diff.bak" -LogBackupPaths @("C:\Backups\MyDB_Log1.trn", "C:\Backups\MyDB_Log2.trn")

.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeSupportDbs -Exclude 'Logins','AgentServer'
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceInstance,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetInstance,
    
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if ($_ -eq "All" -or ($_ -is [array] -and $_.Count -gt 0) -or ($_ -is [string] -and $_ -ne "")) {
            $true
        } else {
            throw "Databases must be 'All' or an array of database names"
        }
    })]
    $Databases,
    
    [switch]$IncludeEncryption,
    [string]$LogPath = "/tmp/SQLUpgrade",
    
    # Migration Method Options
    [ValidateSet('Direct', 'BackupRestore', 'DetachAttach')]
    [string]$MigrationMethod = 'Direct',
    
    [string]$BackupPath,
    [switch]$UseExistingBackups,
    [string]$FullBackupPath,
    [string]$DifferentialBackupPath,
    [string[]]$LogBackupPaths,
    
    # Server Object Migration Switches (enabled by default for complete instance migration)
    [switch]$IncludeLogins = $true,
    [switch]$IncludeJobs = $true,
    [switch]$IncludeLinkedServers = $true,
    [switch]$IncludeTriggers = $true,
    [switch]$IncludeServerRoles = $true,
    [switch]$IncludeCredentials = $true,
    [switch]$IncludeProxyAccounts = $true,
    [switch]$IncludeAlerts = $true,
    [switch]$IncludeOperators = $true,
    [switch]$IncludeBackupDevices = $true,
    [switch]$IncludeServerConfiguration = $true,
    [switch]$IncludeAllServerObjects,
    
    # Comprehensive exclusion parameter (alternative to individual switches)
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

# Execute upgrade process using module functions only
try {
    $logInfo = Initialize-UpgradeLogging -LogPath $LogPath
    
    # Establish connections to source and target instances
    $sourceConnection = Test-InstanceConnectivity -Instance $SourceInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    $targetConnection = Test-InstanceConnectivity -Instance $TargetInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    Test-CollationCompatibility -SourceConnection $sourceConnection -TargetConnection $targetConnection -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    # Get databases to process
    $databasesToProcess = Get-UserDatabases -Connection $sourceConnection -DatabaseFilter $Databases -IncludeSupportDbs:$IncludeSupportDbs -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    # Migrate server objects first (if requested and not excluded)
    $shouldMigrateServerObjects = ($IncludeAllServerObjects -or $IncludeLogins -or $IncludeJobs -or $IncludeLinkedServers -or $IncludeTriggers -or $IncludeServerRoles -or $IncludeCredentials -or $IncludeProxyAccounts -or $IncludeAlerts -or $IncludeOperators -or $IncludeBackupDevices -or $IncludeServerConfiguration) -and ($Exclude -notcontains 'Logins' -and $Exclude -notcontains 'AgentServer' -and $Exclude -notcontains 'LinkedServers' -and $Exclude -notcontains 'Credentials')
    
    if ($shouldMigrateServerObjects) {
        $serverObjectOptions = @{
            IncludeLogins = ($IncludeLogins -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'Logins')
            IncludeJobs = ($IncludeJobs -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'AgentServer')
            IncludeLinkedServers = ($IncludeLinkedServers -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'LinkedServers')
            IncludeTriggers = ($IncludeTriggers -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'SystemTriggers')
            IncludeServerRoles = ($IncludeServerRoles -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'Logins')
            IncludeCredentials = ($IncludeCredentials -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'Credentials')
            IncludeProxyAccounts = ($IncludeProxyAccounts -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'AgentServer')
            IncludeAlerts = ($IncludeAlerts -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'AgentServer')
            IncludeOperators = ($IncludeOperators -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'AgentServer')
            IncludeBackupDevices = ($IncludeBackupDevices -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'BackupDevices')
            IncludeServerConfiguration = ($IncludeServerConfiguration -or $IncludeAllServerObjects) -and ($Exclude -notcontains 'SpConfigure')
        }
        
        Write-UpgradeLog -Message "Server object migration options: $(($serverObjectOptions.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) -join ', ')" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        Copy-ServerObjects -SourceConnection $sourceConnection -TargetConnection $targetConnection -ServerObjectOptions $serverObjectOptions -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    } else {
        Write-UpgradeLog -Message "Server object migration skipped (excluded or not requested)" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Migrate databases (if not excluded)
    $processedDatabases = @()
    if ($Exclude -notcontains 'Databases') {
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
