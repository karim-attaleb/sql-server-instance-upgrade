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
    
.PARAMETER OutputFile
    Path to output file for later execution instead of direct application
    
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
    [string]$OutputFile,
    [string]$LogPath = "/tmp/SQLUpgrade",
    
    # Migration Method Options
    [ValidateSet('Direct', 'BackupRestore', 'DetachAttach')]
    [string]$MigrationMethod = 'Direct',
    
    [string]$BackupPath,
    [switch]$UseExistingBackups,
    [string]$FullBackupPath,
    [string]$DifferentialBackupPath,
    [string[]]$LogBackupPaths,
    
    # Server Object Migration Switches
    [switch]$IncludeLogins,
    [switch]$IncludeJobs,
    [switch]$IncludeLinkedServers,
    [switch]$IncludeTriggers,
    [switch]$IncludeServerRoles,
    [switch]$IncludeCredentials,
    [switch]$IncludeProxyAccounts,
    [switch]$IncludeAlerts,
    [switch]$IncludeOperators,
    [switch]$IncludeBackupDevices,
    [switch]$IncludeServerConfiguration,
    [switch]$IncludeAllServerObjects
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
    
    $sourceConnection = Test-InstanceConnectivity -Instance $SourceInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    $targetConnection = Test-InstanceConnectivity -Instance $TargetInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    Test-CollationCompatibility -SourceConnection $sourceConnection -TargetConnection $targetConnection -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    $databasesToProcess = Get-UserDatabases -Connection $sourceConnection -DatabaseFilter $Databases -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    
    # Migrate server objects first (if requested)
    if ($IncludeAllServerObjects -or $IncludeLogins -or $IncludeJobs -or $IncludeLinkedServers -or $IncludeTriggers -or $IncludeServerRoles -or $IncludeCredentials -or $IncludeProxyAccounts -or $IncludeAlerts -or $IncludeOperators -or $IncludeBackupDevices -or $IncludeServerConfiguration) {
        $serverObjectOptions = @{
            IncludeLogins = $IncludeLogins -or $IncludeAllServerObjects
            IncludeJobs = $IncludeJobs -or $IncludeAllServerObjects
            IncludeLinkedServers = $IncludeLinkedServers -or $IncludeAllServerObjects
            IncludeTriggers = $IncludeTriggers -or $IncludeAllServerObjects
            IncludeServerRoles = $IncludeServerRoles -or $IncludeAllServerObjects
            IncludeCredentials = $IncludeCredentials -or $IncludeAllServerObjects
            IncludeProxyAccounts = $IncludeProxyAccounts -or $IncludeAllServerObjects
            IncludeAlerts = $IncludeAlerts -or $IncludeAllServerObjects
            IncludeOperators = $IncludeOperators -or $IncludeAllServerObjects
            IncludeBackupDevices = $IncludeBackupDevices -or $IncludeAllServerObjects
            IncludeServerConfiguration = $IncludeServerConfiguration -or $IncludeAllServerObjects
        }
        
        Copy-ServerObjects -SourceConnection $sourceConnection -TargetConnection $targetConnection -ServerObjectOptions $serverObjectOptions -OutputFile $OutputFile -WhatIfMode $WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Migrate databases
    $processedDatabases = @()
    foreach ($database in $databasesToProcess) {
        try {
            Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption $IncludeEncryption -MigrationMethod $MigrationMethod -BackupPath $BackupPath -UseExistingBackups $UseExistingBackups -FullBackupPath $FullBackupPath -DifferentialBackupPath $DifferentialBackupPath -LogBackupPaths $LogBackupPaths -OutputFile $OutputFile -WhatIfMode $WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            $processedDatabases += $database.Name
        } catch {
            Write-UpgradeLog -Message "Failed to process database $($database.Name): $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
        }
    }
    
    # Run post-upgrade tasks
    if ($processedDatabases.Count -gt 0 -and -not $WhatIf) {
        Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -WhatIfMode $WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
} catch {
    Write-UpgradeLog -Message "Critical error: $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
    throw
}
