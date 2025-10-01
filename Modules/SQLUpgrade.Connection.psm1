#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Upgrade Connection Module
    
.DESCRIPTION
    Provides connection management and testing functionality for SQL Server upgrade operations.
#>

function Test-InstanceConnectivity {
    <#
    .SYNOPSIS
        Tests connectivity to a SQL Server instance and returns connection object
    
    .PARAMETER Instance
        SQL Server instance name
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    
    .OUTPUTS
        Connection object if successful, null if failed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    try {
        $connection = Connect-DbaInstance -SqlInstance $Instance -ConnectTimeout 10
        if ($connection) {
            Write-UpgradeLog -Message "Successfully connected to $Instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
            return $connection
        }
    } catch {
        Write-UpgradeLog -Message "Failed to connect to $Instance : $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        return $null
    }
}

function Test-CollationCompatibility {
    <#
    .SYNOPSIS
        Tests collation compatibility between source and target instances
    
    .PARAMETER SourceConnection
        Source SQL Server connection object
    
    .PARAMETER TargetConnection
        Target SQL Server connection object
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    
    .OUTPUTS
        Boolean indicating collation compatibility
    #>
    param(
        [Parameter(Mandatory = $true)]
        $SourceConnection,
        
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Checking collation compatibility between instances" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    try {
        $sourceCollation = (Get-DbaDatabase -SqlInstance $SourceConnection -Database master).Collation
        $targetCollation = (Get-DbaDatabase -SqlInstance $TargetConnection -Database master).Collation
        
        Write-UpgradeLog -Message "Source instance collation: $sourceCollation" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Write-UpgradeLog -Message "Target instance collation: $targetCollation" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        if ($sourceCollation -ne $targetCollation) {
            Write-UpgradeLog -Message "WARNING: Collation mismatch detected. This may cause issues with data transfer." -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
            return $false
        } else {
            Write-UpgradeLog -Message "Collation compatibility verified" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
            return $true
        }
    } catch {
        Write-UpgradeLog -Message "Error checking collation: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

Export-ModuleMember -Function Test-InstanceConnectivity, Test-CollationCompatibility
