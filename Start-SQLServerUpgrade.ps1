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
    
.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2") -WhatIf
    
.EXAMPLE
    .\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeEncryption
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
    
    $processedDatabases = @()
    foreach ($database in $databasesToProcess) {
        try {
            Copy-CompleteDatabase -SourceConnection $sourceConnection -TargetConnection $targetConnection -DatabaseName $database.Name -IncludeEncryption $IncludeEncryption -OutputFile $OutputFile -WhatIfMode $WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            $processedDatabases += $database.Name
        } catch {
            Write-UpgradeLog -Message "Failed to process database $($database.Name): $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
        }
    }
    
    if ($processedDatabases.Count -gt 0 -and -not $WhatIf) {
        Invoke-PostUpgradeTasks -TargetConnection $targetConnection -DatabaseNames $processedDatabases -WhatIfMode $WhatIf -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
    }
    
} catch {
    Write-UpgradeLog -Message "Critical error: $($_.Exception.Message)" -Level "Error" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile -WriteToEventLog
    throw
}
