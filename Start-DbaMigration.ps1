#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    Complete SQL Server Instance Migration using dbatools patterns
    
.DESCRIPTION
    This script provides comprehensive SQL Server instance migration capabilities based on dbatools Start-DbaMigration patterns.
    It migrates only user databases (excluding system and utility databases by default) with flexible server object exclusion options.
    
.PARAMETER Source
    Source SQL Server instance name
    
.PARAMETER Destination
    Destination SQL Server instance name
    
.PARAMETER BackupRestore
    Use backup/restore method for database migration
    
.PARAMETER DetachAttach
    Use detach/attach method for database migration
    
.PARAMETER SharedPath
    Network path for backup files (required for BackupRestore method)
    
.PARAMETER IncludeSupportDbs
    Include utility databases (ReportServer, SSISDB, distribution, etc.)
    By default, these databases are excluded to prevent conflicts with existing services.
    Use this when migrating servers with SQL Server Reporting Services, Integration Services, or replication configured.
    
.PARAMETER Exclude
    Server objects to exclude from migration. Valid values:
    'Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 
    'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 
    'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 
    'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'DataCollector', 'StartupProcedures'
    
.PARAMETER WhatIf
    Show what would be done without making changes
    
.PARAMETER SourceSqlCredential
    SQL Server credentials for source instance
    
.PARAMETER DestinationSqlCredential
    SQL Server credentials for destination instance
    
.EXAMPLE
    .\Start-DbaMigration.ps1 -Source "SQL2019\PROD" -Destination "SQL2022\PROD" -BackupRestore -SharedPath "\\server\backups" -WhatIf
    
.EXAMPLE
    .\Start-DbaMigration.ps1 -Source "SQL2019\PROD" -Destination "SQL2022\PROD" -IncludeSupportDbs -Exclude 'Logins','AgentServer'
    
.EXAMPLE
    .\Start-DbaMigration.ps1 -Source "SQL2019\PROD" -Destination "SQL2022\PROD" -DetachAttach -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    
    [Parameter(Mandatory = $true)]
    [string]$Destination,
    
    [switch]$BackupRestore,
    [switch]$DetachAttach,
    [string]$SharedPath,
    [switch]$IncludeSupportDbs,
    
    [ValidateSet('Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'DataCollector', 'StartupProcedures')]
    [string[]]$Exclude = @(),
    
    [PSCredential]$SourceSqlCredential,
    [PSCredential]$DestinationSqlCredential
)

Write-Host "Starting SQL Server instance migration using Start-DbaMigration patterns" -ForegroundColor Green
Write-Host "Source: $Source" -ForegroundColor Cyan
Write-Host "Destination: $Destination" -ForegroundColor Cyan

# Determine migration method
$migrationMethod = 'Direct'
if ($BackupRestore) { 
    $migrationMethod = 'BackupRestore' 
    Write-Host "Migration Method: Backup/Restore" -ForegroundColor Yellow
} elseif ($DetachAttach) { 
    $migrationMethod = 'DetachAttach' 
    Write-Host "Migration Method: Detach/Attach" -ForegroundColor Yellow
} else {
    Write-Host "Migration Method: Direct (Copy-DbaDatabase)" -ForegroundColor Yellow
}

# Display exclusion information
if ($Exclude.Count -gt 0) {
    Write-Host "Excluded Objects: $($Exclude -join ', ')" -ForegroundColor Red
}

if ($IncludeSupportDbs) {
    Write-Host "Including utility databases (ReportServer, SSISDB, distribution, etc.)" -ForegroundColor Yellow
} else {
    Write-Host "Excluding utility databases (use -IncludeSupportDbs to include)" -ForegroundColor Yellow
}

# Call the enhanced Start-SQLServerUpgrade.ps1 with appropriate parameters
$params = @{
    SourceInstance = $Source
    TargetInstance = $Destination
    Databases = 'All'
    MigrationMethod = $migrationMethod
    IncludeSupportDbs = $IncludeSupportDbs
    Exclude = $Exclude
    WhatIf = $WhatIf
    IncludeAllServerObjects = $true
}

if ($BackupRestore -and $SharedPath) {
    $params.BackupPath = $SharedPath
    Write-Host "Backup Path: $SharedPath" -ForegroundColor Cyan
}

# Execute the migration using the modular solution
# By default, this migrates everything except system and utility databases:
# - All user databases (excludes master, model, msdb, tempdb)
# - All server objects (logins, jobs, linked servers, credentials, etc.)
# - Excludes utility databases (ReportServer, SSISDB, distribution) unless -IncludeSupportDbs is specified
try {
    Write-Host "Starting comprehensive instance migration..." -ForegroundColor Yellow
    Write-Host "This will migrate all user databases and server objects by default" -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "Start-SQLServerUpgrade.ps1") @params
    Write-Host "SQL Server instance migration completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Migration failed: $($_.Exception.Message)"
    throw
}
