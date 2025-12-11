<#
.SYNOPSIS
    Usage examples for SQL Server Upgrade Script
    
.DESCRIPTION
    This file contains practical usage examples for the SQL Server upgrade script
#>

# Example 1: WhatIf mode to preview changes - See what would be migrated without making changes
Write-Host "Example 1: Preview upgrade with WhatIf" -ForegroundColor Green
Write-Host "# This shows exactly what databases and server objects would be migrated"
Write-Host "# By default: migrates ALL user databases + ALL server objects (logins, jobs, etc.)"
Write-Host "# Excludes: system databases (master, model, msdb, tempdb) and utility databases (ReportServer, SSISDB, distribution, etc.)"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases @("CustomerDB", "OrdersDB", "InventoryDB") `
    -WhatIf
"@

Write-Host "`nExample 2: Full upgrade with all user databases - Complete instance migration" -ForegroundColor Green
Write-Host "# This is the most common scenario for complete SQL Server instance upgrades"
Write-Host "# Migrates ALL user databases and ALL server objects by default"
Write-Host "# Includes encryption support for databases with TDE or other encryption features"
Write-Host "# Safe: automatically excludes system and utility databases to prevent conflicts"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases "All" `
    -IncludeEncryption `
    -LogPath "D:\Logs\SQLUpgrade"
"@

Write-Host "`nExample 3: Selective database upgrade - Migrate specific databases only" -ForegroundColor Green
Write-Host "# Use this when you only want to migrate specific databases instead of all user databases"
Write-Host "# Still migrates ALL server objects by default (logins, jobs, linked servers, etc.)"
Write-Host "# Useful for testing or when migrating databases in phases"
Write-Host "# WhatIf mode shows what would be done without making actual changes"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\DEV" `
    -TargetInstance "SQLSERVER2022\DEV" `
    -Databases @("TestDB") `
    -WhatIf
"@

Write-Host "`nExample 4: Upgrade with encryption support - Handle TDE and encrypted databases" -ForegroundColor Green
Write-Host "# Essential when migrating databases with Transparent Data Encryption (TDE) or other encryption"
Write-Host "# Automatically handles encryption keys, certificates, and encrypted database migration"
Write-Host "# Includes comprehensive logging for security audit requirements"
Write-Host "# Migrates all server objects including security-related objects (logins, credentials, etc.)"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\SECURE" `
    -TargetInstance "SQLSERVER2022\SECURE" `
    -Databases @("EncryptedDB", "TDEDatabase") `
    -IncludeEncryption `
    -LogPath "C:\SecureLogs\SQLUpgrade"
"@

Write-Host "`nExample 6: Minimal upgrade (single database) - Simple database migration with full server objects" -ForegroundColor Green
Write-Host "# Migrates a single database but still includes ALL server objects by default"
Write-Host "# Server objects (logins, jobs, etc.) are migrated to ensure database functionality"
Write-Host "# Use this for simple scenarios or when testing the migration process"
Write-Host "# Even minimal upgrades benefit from complete server object migration for consistency"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\TEST" `
    -TargetInstance "SQLSERVER2022\TEST" `
    -Databases @("SimpleDB")
"@

Write-Host "`nExample 7: Complete enterprise upgrade with all features - Full production migration" -ForegroundColor Green
Write-Host "# Enterprise-grade migration with comprehensive logging and encryption support"
Write-Host "# Migrates ALL user databases and ALL server objects (the complete instance)"
Write-Host "# Uses shared storage for logs accessible by multiple administrators"
Write-Host "# Verbose output provides detailed progress information for large migrations"
Write-Host "# Recommended approach for production SQL Server cluster upgrades"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLCLUSTER2019\ENTERPRISE" `
    -TargetInstance "SQLCLUSTER2022\ENTERPRISE" `
    -Databases "All" `
    -IncludeEncryption `
    -LogPath "\\SharedStorage\Logs\SQLUpgrade" `
    -Verbose
"@

Write-Host "`nExample 8: Using individual modules for custom workflows - Advanced customization" -ForegroundColor Green
Write-Host "# For advanced users who need custom migration workflows beyond the main script"
Write-Host "# Import only the modules you need for specific tasks"
Write-Host "# Useful for building custom automation or integrating with existing processes"
Write-Host "# Each module can be used independently for maximum flexibility"
Write-Host @"
# Import specific modules for custom workflow
Import-Module .\Modules\SQLUpgrade.Logging.psm1
Import-Module .\Modules\SQLUpgrade.Connection.psm1
Import-Module .\Modules\SQLUpgrade.Database.psm1

# Initialize logging for custom workflow
`$logInfo = Initialize-UpgradeLogging -LogPath "C:\Logs\CustomUpgrade"

# Test connectivity to both instances
`$sourceConn = Test-InstanceConnectivity -Instance "SQL2019\PROD" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile
`$targetConn = Test-InstanceConnectivity -Instance "SQL2022\PROD" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile

# Get user databases (excludes system and utility databases automatically)
`$databases = Get-UserDatabases -Connection `$sourceConn -DatabaseFilter "All" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile

Write-Host "Found `$(`$databases.Count) databases to process"
"@

Write-Host "`nExample 9: Testing individual module functions - Development and troubleshooting" -ForegroundColor Green
Write-Host "# Use this approach when developing custom solutions or troubleshooting issues"
Write-Host "# Test individual module functions to verify they work correctly in your environment"
Write-Host "# Helpful for understanding the modular architecture and building custom workflows"
Write-Host "# Each module can be tested independently before using the full migration script"
Write-Host @"
# Import and test logging module functionality
Import-Module .\Modules\SQLUpgrade.Logging.psm1 -Force

# Test logging functionality with custom path
`$logInfo = Initialize-UpgradeLogging -LogPath "C:\Temp\TestLogs"
Write-UpgradeLog -Message "Test message" -Level "Information" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile -WriteToEventLog

# Verify all exported functions are available
Get-Command -Module SQLUpgrade.Logging
"@

Write-Host "`nExample 10: Complete instance migration (default behavior - dbatools-style)" -ForegroundColor Green
Write-Host "# By default, migrates EVERYTHING for a complete instance upgrade:"
Write-Host "# - All user databases (excludes system: master, model, msdb, tempdb)"
Write-Host "# - All server objects: logins, jobs, linked servers, credentials, alerts, operators, etc."
Write-Host "# - Excludes utility databases (ReportServer, SSISDB, distribution) for safety"
Write-Host "# No -Databases parameter needed - defaults to 'All' (dbatools-style)"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQL2019\PROD" `
    -TargetInstance "SQL2022\PROD"
"@

Write-Host "`nExample 11: Server objects only - No database migration" -ForegroundColor Green
Write-Host "# Migrate only server objects (logins, jobs, linked servers, etc.) without touching databases"
Write-Host "# Use -Exclude 'Databases' to skip database migration entirely"
Write-Host "# Useful when you only need to sync server-level configuration"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQL2019\PROD" `
    -TargetInstance "SQL2022\PROD" `
    -Exclude 'Databases'
"@

Write-Host "`nExample 12: Exclude specific components for granular control" -ForegroundColor Green
Write-Host "# Exclude specific components when you need granular control:"
Write-Host "# - Exclude 'Logins' when you want to review/manage security separately"
Write-Host "# - Exclude 'AgentServer' when you want to prevent jobs from running immediately"
Write-Host "# - Exclude 'LinkedServers' when connection strings need updating for new environment"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQL2019\PROD" `
    -TargetInstance "SQL2022\PROD" `
    -Exclude 'Logins','AgentServer','LinkedServers'
"@

Write-Host "`nExample 13: Include utility databases for servers with SSRS/SSIS/Replication" -ForegroundColor Green
Write-Host "# Include ReportServer, SSISDB, distribution databases when migrating servers with:"
Write-Host "# - SQL Server Reporting Services (SSRS) - includes ReportServer databases"
Write-Host "# - SQL Server Integration Services (SSIS) - includes SSISDB database"
Write-Host "# - SQL Server Replication - includes distribution database"
Write-Host "# - Data Quality Services (DQS) - includes DQS databases"
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQL2019\PROD" `
    -TargetInstance "SQL2022\PROD" `
    -IncludeSupportDbs
"@

Write-Host "`n=== Prerequisites Check Script ===" -ForegroundColor Yellow
Write-Host "# Run this before executing the upgrade script to ensure your environment is ready"
Write-Host "# Verifies dbatools installation, connectivity, disk space, and SQL Server versions"
Write-Host @"
# Install dbatools module if not already available
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "Installing dbatools module..." -ForegroundColor Yellow
    Install-Module dbatools -Force -Scope CurrentUser
}

# Test connectivity to both source and target instances
Test-DbaConnection -SqlInstance "SQLSERVER2019\PROD"
Test-DbaConnection -SqlInstance "SQLSERVER2022\PROD"

# Check available disk space on target server
Get-DbaDbSpace -SqlInstance "SQLSERVER2022\PROD"

# Verify SQL Server versions to confirm upgrade path
Get-DbaInstanceProperty -SqlInstance "SQLSERVER2019\PROD" -InstanceProperty VersionString
Get-DbaInstanceProperty -SqlInstance "SQLSERVER2022\PROD" -InstanceProperty VersionString
"@
