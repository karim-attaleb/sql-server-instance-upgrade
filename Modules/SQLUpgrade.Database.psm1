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
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    try {
        $allDatabases = Get-DbaDatabase -SqlInstance $Connection | Where-Object { $_.Name -notin @('master', 'model', 'msdb', 'tempdb') }
        
        if ($DatabaseFilter -eq "All") {
            return $allDatabases
        } else {
            return $allDatabases | Where-Object { $_.Name -in $DatabaseFilter }
        }
    } catch {
        Write-UpgradeLog -Message "Error retrieving databases: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

Export-ModuleMember -Function Get-UserDatabases
