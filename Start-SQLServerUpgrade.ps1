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
    
    # For OutputFile generation, we can work with mock connections or skip connection validation
    if ($OutputFile) {
        Write-UpgradeLog -Message "OutputFile specified - generating SQL scripts for later execution" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        # Initialize output file with PowerShell header
        $scriptHeader = @"
# PowerShell SQL Server Instance Upgrade Script
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Source Instance: $SourceInstance
# Target Instance: $TargetInstance
# Migration Method: $MigrationMethod
# 
# This script contains PowerShell commands using dbatools to migrate databases and server objects
# Review and execute this script in PowerShell on a machine with access to both SQL Server instances
#

# Import required module
Import-Module dbatools -Force

# Establish connections
`$sourceConn = Connect-DbaInstance -SqlInstance '$SourceInstance'
`$targetConn = Connect-DbaInstance -SqlInstance '$TargetInstance'

Write-Host "Starting SQL Server instance upgrade migration" -ForegroundColor Green

"@
        Set-Content -Path $OutputFile -Value $scriptHeader -Encoding UTF8
        Write-UpgradeLog -Message "Initialized output file: $OutputFile" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        # Create mock connection objects for script generation
        $sourceConnection = @{ ComputerName = $SourceInstance; InstanceName = $SourceInstance }
        $targetConnection = @{ ComputerName = $TargetInstance; InstanceName = $TargetInstance }
        
        # Skip collation compatibility check for script generation
        Write-UpgradeLog -Message "[SCRIPT MODE] Skipping collation compatibility check - will be included in generated script" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    } else {
        # Normal execution mode - establish real connections
        $sourceConnection = Test-InstanceConnectivity -Instance $SourceInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        $targetConnection = Test-InstanceConnectivity -Instance $TargetInstance -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        Test-CollationCompatibility -SourceConnection $sourceConnection -TargetConnection $targetConnection -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Get databases to process
    if ($OutputFile) {
        # For script generation, create mock database objects
        if ($Databases -eq "All") {
            $databasesToProcess = @(
                @{ Name = "UserDatabase1" },
                @{ Name = "UserDatabase2" },
                @{ Name = "UserDatabase3" }
            )
            Write-UpgradeLog -Message "[SCRIPT MODE] Using sample database names - modify the generated script with your actual database names" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        } else {
            if ($Databases -is [string]) {
                $databasesToProcess = @(@{ Name = $Databases })
            } else {
                $databasesToProcess = $Databases | ForEach-Object { @{ Name = $_ } }
            }
        }
    } else {
        $databasesToProcess = Get-UserDatabases -Connection $sourceConnection -DatabaseFilter $Databases -IncludeSupportDbs:$IncludeSupportDbs -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
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
        
        if ($OutputFile) {
            Copy-ServerObjects -SourceConnection $sourceConnection -TargetConnection $targetConnection -ServerObjectOptions $serverObjectOptions -OutputFile $OutputFile -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        } else {
            Copy-ServerObjects -SourceConnection $sourceConnection -TargetConnection $targetConnection -ServerObjectOptions $serverObjectOptions -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        }
    } else {
        Write-UpgradeLog -Message "Server object migration skipped (excluded or not requested)" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
    # Migrate databases (if not excluded)
    $processedDatabases = @()
    if ($Exclude -notcontains 'Databases') {
        Write-UpgradeLog -Message "Starting database migration for $($databasesToProcess.Count) databases" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        
        foreach ($database in $databasesToProcess) {
            try {
                if ($OutputFile) {
                    Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption:$IncludeEncryption -MigrationMethod $MigrationMethod -BackupPath $BackupPath -UseExistingBackups:$UseExistingBackups -FullBackupPath $FullBackupPath -DifferentialBackupPath $DifferentialBackupPath -LogBackupPaths $LogBackupPaths -OutputFile $OutputFile -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
                } else {
                    Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption:$IncludeEncryption -MigrationMethod $MigrationMethod -BackupPath $BackupPath -UseExistingBackups:$UseExistingBackups -FullBackupPath $FullBackupPath -DifferentialBackupPath $DifferentialBackupPath -LogBackupPaths $LogBackupPaths -WhatIfMode:$WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
                }
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
        if ($OutputFile) {
            # Generate post-upgrade tasks PowerShell script
            $postUpgradeScript = @"

# Post-Upgrade Tasks using dbatools
# Run these PowerShell commands after the database migration is complete

"@
            foreach ($dbName in $processedDatabases) {
                $postUpgradeScript += @"
# Database: $dbName
Write-Host "Running post-upgrade tasks for database: $dbName" -ForegroundColor Yellow

# Check database integrity
`$checkResult = Invoke-DbaDbccCheckdb -SqlInstance `$targetConn -Database '$dbName'
if (`$checkResult.Status -eq "Success") {
    Write-Host "DBCC CHECKDB completed successfully for $dbName" -ForegroundColor Green
} else {
    Write-Warning "DBCC CHECKDB found issues in $dbName"
}

# Update compatibility level to SQL Server 2022 (160)
Set-DbaDbCompatibility -SqlInstance `$targetConn -Database '$dbName' -CompatibilityLevel 160
Write-Host "Updated compatibility level for $dbName to SQL Server 2022" -ForegroundColor Cyan

# Update statistics
Update-DbaStatistics -SqlInstance `$targetConn -Database '$dbName'
Write-Host "Updated statistics for $dbName" -ForegroundColor Cyan

# Note: Index rebuilding should be customized based on your specific tables and requirements
Write-Host "Post-upgrade tasks completed for $dbName" -ForegroundColor Green

"@
            }
            Add-Content -Path $OutputFile -Value $postUpgradeScript -Encoding UTF8
            Write-UpgradeLog -Message "Post-upgrade tasks added to output file: $OutputFile" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
        } else {
            if ($WhatIf) {
                Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -WhatIfMode -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            } else {
                Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            }
        }
    }
    
    # Final message for OutputFile mode
    if ($OutputFile) {
        Write-UpgradeLog -Message "SQL script generation completed successfully. Review and execute: $OutputFile" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
        Write-Host "SQL script generated successfully: $OutputFile" -ForegroundColor Green
        Write-Host "Review the generated script and execute it on your target SQL Server instance." -ForegroundColor Yellow
    }
    
} catch {
    Write-UpgradeLog -Message "Critical error: $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
    throw
}
