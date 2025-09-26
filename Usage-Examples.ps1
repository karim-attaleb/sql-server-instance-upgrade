<#
.SYNOPSIS
    Usage examples for SQL Server Upgrade Script
    
.DESCRIPTION
    This file contains practical usage examples for the SQL Server upgrade script
#>

# Example 1: WhatIf mode to preview changes
Write-Host "Example 1: Preview upgrade with WhatIf" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases @("CustomerDB", "OrdersDB", "InventoryDB") `
    -WhatIf
"@

Write-Host "`nExample 2: Full upgrade with all user databases" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases "All" `
    -IncludeEncryption `
    -LogPath "D:\Logs\SQLUpgrade"
"@

Write-Host "`nExample 3: Selective object types upgrade" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\DEV" `
    -TargetInstance "SQLSERVER2022\DEV" `
    -Databases @("TestDB") `
    -ObjectTypes @("Tables", "Views", "StoredProcedures") `
    -WhatIf
"@

Write-Host "`nExample 4: Generate script file for later execution" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\PROD" `
    -TargetInstance "SQLSERVER2022\PROD" `
    -Databases "All" `
    -OutputFile "C:\Scripts\ProductionUpgrade.sql" `
    -IncludeEncryption
"@

Write-Host "`nExample 5: Upgrade with encryption support" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\SECURE" `
    -TargetInstance "SQLSERVER2022\SECURE" `
    -Databases @("EncryptedDB", "TDEDatabase") `
    -IncludeEncryption `
    -LogPath "C:\SecureLogs\SQLUpgrade"
"@

Write-Host "`nExample 6: Minimal upgrade (single database, basic objects)" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLSERVER2019\TEST" `
    -TargetInstance "SQLSERVER2022\TEST" `
    -Databases @("SimpleDB") `
    -ObjectTypes @("Tables", "Views")
"@

Write-Host "`nExample 7: Complete enterprise upgrade with all features" -ForegroundColor Green
Write-Host @"
.\SQL-Server-Upgrade-Script.ps1 `
    -SourceInstance "SQLCLUSTER2019\ENTERPRISE" `
    -TargetInstance "SQLCLUSTER2022\ENTERPRISE" `
    -Databases "All" `
    -ObjectTypes @("Tables", "Views", "StoredProcedures", "Functions", "Triggers", "Users", "Roles", "Permissions") `
    -IncludeEncryption `
    -LogPath "\\SharedStorage\Logs\SQLUpgrade" `
    -Verbose
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
