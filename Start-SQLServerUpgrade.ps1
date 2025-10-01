#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Instance Upgrade to SQL Server 2022 using Side-by-Side Installation
    
.DESCRIPTION
    This script performs a comprehensive SQL Server upgrade using dbatools with modular design:
    - Side-by-side installation support
    - Complete database migration
    - Collation checking
    - Encryption and TDE support
    - WhatIf functionality
    - Comprehensive logging including Windows Event Log
    - Idempotent operations
    - Post-upgrade tasks (integrity checks, compatibility level updates, statistics, indexes)
    
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
    
.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2") -WhatIf
    
.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeEncryption -OutputFile "C:\Scripts\UpgradeScript.sql"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceInstance,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetInstance,
    
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if ($_ -eq "All" -or ($_ -is [array] -and $_.Count -gt 0)) {
            $true
        } else {
            throw "Databases must be 'All' or an array of database names"
        }
    })]
    $Databases,
    
    [switch]$IncludeEncryption,
    
    [string]$OutputFile,
    
    [string]$LogPath = "C:\Logs\SQLUpgrade",
    
    [switch]$WhatIf
)

# Initialize error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Import required modules
$ModulePath = Join-Path $PSScriptRoot "Modules"

Import-Module (Join-Path $ModulePath "SQLUpgrade.Logging.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Connection.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Database.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Encryption.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.Migration.psm1") -Force
Import-Module (Join-Path $ModulePath "SQLUpgrade.PostUpgrade.psm1") -Force

# Main execution
try {
    # Initialize logging
    $logInfo = Initialize-UpgradeLogging -LogPath $LogPath
    $LogFile = $logInfo.LogFile
    $ErrorLogFile = $logInfo.ErrorLogFile
    
    Write-UpgradeLog -Message "=== SQL Server Upgrade Script Started ===" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    Write-UpgradeLog -Message "Source Instance: $SourceInstance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    Write-UpgradeLog -Message "Target Instance: $TargetInstance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    Write-UpgradeLog -Message "WhatIf Mode: $WhatIf" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    Write-UpgradeLog -Message "Include Encryption: $IncludeEncryption" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    # Establish robust connections to both instances
    Write-UpgradeLog -Message "Establishing connections to instances" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    $sourceConnection = Test-InstanceConnectivity -Instance $SourceInstance -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    if (-not $sourceConnection) {
        throw "Cannot connect to source instance: $SourceInstance"
    }
    
    $targetConnection = Test-InstanceConnectivity -Instance $TargetInstance -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    if (-not $targetConnection) {
        throw "Cannot connect to target instance: $TargetInstance"
    }
    
    Write-UpgradeLog -Message "Successfully established connections to both instances" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    # Check collation compatibility
    Test-CollationCompatibility -SourceConnection $sourceConnection -TargetConnection $targetConnection -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    # Get databases to process
    $databasesToProcess = Get-UserDatabases -Connection $sourceConnection -DatabaseFilter $Databases -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    Write-UpgradeLog -Message "Found $($databasesToProcess.Count) databases to process" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    foreach ($db in $databasesToProcess) {
        Write-UpgradeLog -Message "Processing database: $($db.Name)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    }
    
    # Process each database
    $processedDatabases = @()
    foreach ($database in $databasesToProcess) {
        try {
            Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption $IncludeEncryption -OutputFile $OutputFile -WhatIfMode $WhatIf -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            $processedDatabases += $database.Name
        } catch {
            Write-UpgradeLog -Message "Failed to process database $($database.Name): $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        }
    }
    
    # Run post-upgrade tasks
    if ($processedDatabases.Count -gt 0 -and -not $WhatIf) {
        Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -WhatIfMode $WhatIf -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    }
    
    Write-UpgradeLog -Message "=== SQL Server Upgrade Script Completed Successfully ===" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    Write-UpgradeLog -Message "Processed databases: $($processedDatabases -join ', ')" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    Write-UpgradeLog -Message "Log files location: $LogPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
} catch {
    Write-UpgradeLog -Message "Critical error in upgrade script: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    Write-UpgradeLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    throw
} finally {
    Write-UpgradeLog -Message "Script execution completed at $(Get-Date)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
}
