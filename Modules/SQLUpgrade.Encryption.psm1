#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Upgrade Encryption Module
    
.DESCRIPTION
    Provides encryption and TDE support functionality for SQL Server upgrade operations.
#>

function Test-EncryptionSupport {
    <#
    .SYNOPSIS
        Tests encryption support for a specific database
    
    .PARAMETER Connection
        SQL Server connection object
    
    .PARAMETER DatabaseName
        Name of the database to check
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    
    .OUTPUTS
        Hashtable with encryption information
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    try {
        $database = Get-DbaDatabase -SqlInstance $Connection -Database $DatabaseName
        
        # Check for TDE
        $tdeStatus = Get-DbaTdeEncryption -SqlInstance $Connection -Database $DatabaseName
        
        # Check for encrypted objects
        $encryptedObjects = Get-DbaModule -SqlInstance $Connection -Database $DatabaseName | Where-Object { $_.IsEncrypted -eq $true }
        
        return @{
            HasTDE = ($tdeStatus.EncryptionState -eq "Encrypted")
            EncryptedObjectCount = $encryptedObjects.Count
            TDEStatus = $tdeStatus
        }
    } catch {
        Write-UpgradeLog -Message "Error checking encryption for database $DatabaseName : $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        return @{
            HasTDE = $false
            EncryptedObjectCount = 0
            TDEStatus = $null
        }
    }
}

Export-ModuleMember -Function Test-EncryptionSupport
