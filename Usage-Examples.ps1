<#
.SYNOPSIS
    Usage examples for SQL Server Upgrade Script
    
.DESCRIPTION
    This file contains practical usage examples for the SQL Server upgrade script
#>

# Example 1: WhatIf mode to preview changes
Write-Host "Example 1: Preview upgrade with WhatIf" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases @("CustomerDB", "OrdersDB", "InventoryDB") `
    -WhatIf
"@

Write-Host "`nExample 2: Full upgrade with all user databases" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases "All" `
    -IncludeEncryption `
    -LogPath "D:\Logs\SQLUpgrade"
"@

Write-Host "`nExample 3: Selective database upgrade" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\DEV" `
    -TargetInstance "SQLSERVER2022\DEV" `
    -Databases @("TestDB") `
    -WhatIf
"@

Write-Host "`nExample 4: Generate script file for later execution" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases "All" `
    -OutputFile "C:\Scripts\ProductionUpgrade.sql" `
    -IncludeEncryption
"@

Write-Host "`nExample 5: Upgrade with encryption support" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\SECURE" `
    -TargetInstance "SQLSERVER2022\SECURE" `
    -Databases @("EncryptedDB", "TDEDatabase") `
    -IncludeEncryption `
    -LogPath "C:\SecureLogs\SQLUpgrade"
"@

Write-Host "`nExample 6: Minimal upgrade (single database)" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLSERVER2019\TEST" `
    -TargetInstance "SQLSERVER2022\TEST" `
    -Databases @("SimpleDB")
"@

Write-Host "`nExample 7: Complete enterprise upgrade with all features" -ForegroundColor Green
Write-Host @"
.\Start-SQLServerUpgrade.ps1 `
    -SourceInstance "SQLCLUSTER2019\ENTERPRISE" `
    -TargetInstance "SQLCLUSTER2022\ENTERPRISE" `
    -Databases "All" `
    -IncludeEncryption `
    -LogPath "\\SharedStorage\Logs\SQLUpgrade" `
    -Verbose
"@

Write-Host "`nExample 8: Using individual modules for custom workflows" -ForegroundColor Green
Write-Host @"
# Import specific modules
Import-Module .\Modules\SQLUpgrade.Logging.psm1
Import-Module .\Modules\SQLUpgrade.Connection.psm1
Import-Module .\Modules\SQLUpgrade.Database.psm1

# Initialize logging
`$logInfo = Initialize-UpgradeLogging -LogPath "C:\Logs\CustomUpgrade"

# Test connectivity
`$sourceConn = Test-InstanceConnectivity -Instance "SQL2019\PROD" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile
`$targetConn = Test-InstanceConnectivity -Instance "SQL2022\PROD" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile

# Get user databases
`$databases = Get-UserDatabases -Connection `$sourceConn -DatabaseFilter "All" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile

Write-Host "Found `$(`$databases.Count) databases to process"
"@

Write-Host "`nExample 9: Testing individual module functions" -ForegroundColor Green
Write-Host @"
# Import and test logging module
Import-Module .\Modules\SQLUpgrade.Logging.psm1 -Force

# Test logging functionality
`$logInfo = Initialize-UpgradeLogging -LogPath "C:\Temp\TestLogs"
Write-UpgradeLog -Message "Test message" -Level "Information" -LogFile `$logInfo.LogFile -ErrorLogFile `$logInfo.ErrorLogFile -WriteToEventLog

# Verify exported functions
Get-Command -Module SQLUpgrade.Logging
"@

Write-Host "`n=== Prerequisites Check Script ===" -ForegroundColor Yellow
Write-Host @"
# Run this before executing the upgrade script
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "Installing dbatools module..." -ForegroundColor Yellow
    Install-Module dbatools -Force -Scope CurrentUser
}

# Test connectivity to both instances
Test-DbaConnection -SqlInstance "SQLSERVER2019\PROD"
Test-DbaConnection -SqlInstance "SQLSERVER2022\PROD"

# Check available disk space
Get-DbaDbSpace -SqlInstance "SQLSERVER2022\PROD"

# Verify SQL Server versions
Get-DbaInstanceProperty -SqlInstance "SQLSERVER2019\PROD" -InstanceProperty VersionString
Get-DbaInstanceProperty -SqlInstance "SQLSERVER2022\PROD" -InstanceProperty VersionString
"@
