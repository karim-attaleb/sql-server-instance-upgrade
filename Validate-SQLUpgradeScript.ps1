#Requires -Version 5.1

<#
.SYNOPSIS
    Validation script for SQL Server Upgrade Script
    
.DESCRIPTION
    This script validates the SQL Server upgrade script to ensure it meets all requirements
#>

param(
    [string]$ScriptPath = "SQL-Server-Upgrade-Script.ps1"
)

Write-Host "=== SQL Server Upgrade Script Validation ===" -ForegroundColor Green

# Check if script file exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script file not found: $ScriptPath"
    exit 1
}

Write-Host "✓ Script file exists" -ForegroundColor Green

# Parse the script to check syntax
try {
    $scriptContent = Get-Content $ScriptPath -Raw
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        Write-Host "✓ PowerShell syntax is valid" -ForegroundColor Green
    } else {
        Write-Host "✗ PowerShell syntax errors found:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  - $($_.Message)" -ForegroundColor Red }
    }
} catch {
    Write-Host "✗ Error parsing PowerShell script: $($_.Exception.Message)" -ForegroundColor Red
}

# Check for required parameters
$requiredParams = @('SourceInstance', 'TargetInstance', 'Databases')
$optionalParams = @('ObjectTypes', 'IncludeEncryption', 'OutputFile', 'WhatIf', 'LogPath')

Write-Host "`n=== Parameter Validation ===" -ForegroundColor Yellow

foreach ($param in $requiredParams) {
    if ($scriptContent -match "\[Parameter\(Mandatory\s*=\s*\`$true\)\][\s\S]*?\`$$param") {
        Write-Host "✓ Required parameter '$param' found" -ForegroundColor Green
    } else {
        Write-Host "✗ Required parameter '$param' missing or not mandatory" -ForegroundColor Red
    }
}

foreach ($param in $optionalParams) {
    if ($scriptContent -match "\`$$param") {
        Write-Host "✓ Optional parameter '$param' found" -ForegroundColor Green
    } else {
        Write-Host "✗ Optional parameter '$param' missing" -ForegroundColor Red
    }
}

# Check for WhatIf support
if ($scriptContent -match "\[CmdletBinding\(SupportsShouldProcess\)\]") {
    Write-Host "✓ SupportsShouldProcess enabled for WhatIf functionality" -ForegroundColor Green
} else {
    Write-Host "✗ SupportsShouldProcess not found" -ForegroundColor Red
}

# Check for dbatools usage (no T-SQL)
Write-Host "`n=== dbatools Usage Validation ===" -ForegroundColor Yellow

$dbatoolsCmdlets = @(
    'Connect-DbaInstance',
    'Get-DbaDatabase', 
    'Copy-DbaDatabase',
    'Copy-DbaDbTable',
    'Copy-DbaDbView',
    'Copy-DbaDbStoredProcedure',
    'Copy-DbaDbFunction',
    'Copy-DbaDbUser',
    'Copy-DbaDbRole',
    'Get-DbaTdeEncryption',
    'Get-DbaModule',
    'Invoke-DbaDbccCheckDb',
    'Set-DbaDbCompatibility',
    'Update-DbaStatistics'
)

foreach ($cmdlet in $dbatoolsCmdlets) {
    if ($scriptContent -match $cmdlet) {
        Write-Host "✓ dbatools cmdlet '$cmdlet' found" -ForegroundColor Green
    } else {
        Write-Host "! dbatools cmdlet '$cmdlet' not found (may be optional)" -ForegroundColor Yellow
    }
}

# Check for T-SQL usage (should not be present)
$tsqlPatterns = @('Invoke-Sqlcmd', 'sqlcmd', 'EXEC ', 'SELECT ', 'INSERT ', 'UPDATE ', 'DELETE ')
$tsqlFound = $false

foreach ($pattern in $tsqlPatterns) {
    if ($scriptContent -match $pattern) {
        Write-Host "✗ T-SQL usage detected: '$pattern'" -ForegroundColor Red
        $tsqlFound = $true
    }
}

if (-not $tsqlFound) {
    Write-Host "✓ No T-SQL usage detected (dbatools only)" -ForegroundColor Green
}

# Check for required functions
Write-Host "`n=== Function Validation ===" -ForegroundColor Yellow

$requiredFunctions = @(
    'Write-UpgradeLog',
    'Test-InstanceConnectivity', 
    'Test-CollationCompatibility',
    'Get-UserDatabases',
    'Test-EncryptionSupport',
    'Copy-DatabaseObjects',
    'Invoke-PostUpgradeTasks'
)

foreach ($func in $requiredFunctions) {
    if ($scriptContent -match "function $func") {
        Write-Host "✓ Function '$func' found" -ForegroundColor Green
    } else {
        Write-Host "✗ Function '$func' missing" -ForegroundColor Red
    }
}

# Check for logging features
Write-Host "`n=== Logging Validation ===" -ForegroundColor Yellow

$loggingFeatures = @(
    'Write-EventLog',
    'New-EventLog',
    'Add-Content.*LogFile',
    'Windows Event Log'
)

foreach ($feature in $loggingFeatures) {
    if ($scriptContent -match $feature) {
        Write-Host "✓ Logging feature '$feature' found" -ForegroundColor Green
    } else {
        Write-Host "! Logging feature '$feature' not found" -ForegroundColor Yellow
    }
}

# Check for post-upgrade tasks
Write-Host "`n=== Post-Upgrade Tasks Validation ===" -ForegroundColor Yellow

$postUpgradeTasks = @(
    'Invoke-DbaDbccCheckDb',
    'Set-DbaDbCompatibility', 
    'Update-DbaStatistics',
    'CompatibilityLevel.*160'
)

foreach ($task in $postUpgradeTasks) {
    if ($scriptContent -match $task) {
        Write-Host "✓ Post-upgrade task '$task' found" -ForegroundColor Green
    } else {
        Write-Host "✗ Post-upgrade task '$task' missing" -ForegroundColor Red
    }
}

# Check for safety features
Write-Host "`n=== Safety Features Validation ===" -ForegroundColor Yellow

$safetyFeatures = @(
    'system databases.*NOT.*COPIED' = 'System database exclusion',
    'idempotent' = 'Idempotent operation mention',
    'never.*drop' = 'No drop operations policy',
    'ErrorAction.*SilentlyContinue' = 'Safe error handling'
)

foreach ($pattern in $safetyFeatures.Keys) {
    if ($scriptContent -match $pattern) {
        Write-Host "✓ Safety feature '$($safetyFeatures[$pattern])' found" -ForegroundColor Green
    } else {
        Write-Host "! Safety feature '$($safetyFeatures[$pattern])' not explicitly mentioned" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Validation Complete ===" -ForegroundColor Green
Write-Host "Review the results above to ensure all requirements are met." -ForegroundColor Cyan
