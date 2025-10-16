#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Upgrade Database Module
    
.DESCRIPTION
    Provides database enumeration and filtering functionality for SQL Server upgrade operations.
#>

function Get-UserDatabases {
    <#
    .SYNOPSIS
        Retrieves user databases from a SQL Server instance
    
    .PARAMETER Connection
        SQL Server connection object
    
    .PARAMETER DatabaseFilter
        Database filter - "All" for all user databases or array of specific database names
    
    .PARAMETER IncludeSupportDbs
        Include utility databases (ReportServer, SSISDB, distribution, etc.)
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    
    .OUTPUTS
        Array of database objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        
        [Parameter(Mandatory = $true)]
        $DatabaseFilter,
        
        [switch]$IncludeSupportDbs,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    try {
        # Always exclude system databases
        $systemDatabases = @('master', 'model', 'msdb', 'tempdb')
        $excludedDatabases = $systemDatabases
        
        # Conditionally exclude utility databases unless IncludeSupportDbs is specified
        if (-not $IncludeSupportDbs) {
            $utilityDatabases = @('ReportServer', 'ReportServerTempDB', 'SSISDB', 'distribution', 'DQS_MAIN', 'DQS_PROJECTS', 'DQS_STAGING_DATA')
            $excludedDatabases += $utilityDatabases
            Write-UpgradeLog -Message "Excluding utility databases: $($utilityDatabases -join ', ')" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        } else {
            Write-UpgradeLog -Message "Including utility databases (IncludeSupportDbs specified)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        $allDatabases = Get-DbaDatabase -SqlInstance $Connection | Where-Object { $_.Name -notin $excludedDatabases }
        
        Write-UpgradeLog -Message "Found $($allDatabases.Count) user databases after filtering" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        if ($DatabaseFilter -eq "All") {
            return $allDatabases
        } else {
            $filteredDatabases = $allDatabases | Where-Object { $_.Name -in $DatabaseFilter }
            Write-UpgradeLog -Message "Filtered to $($filteredDatabases.Count) databases based on DatabaseFilter" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            return $filteredDatabases
        }
    } catch {
        Write-UpgradeLog -Message "Error retrieving databases: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

Export-ModuleMember -Function Get-UserDatabases
