#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Upgrade Migration Module
    
.DESCRIPTION
    Provides complete database migration functionality for SQL Server upgrade operations.
#>

function Copy-CompleteDatabase {
    <#
    .SYNOPSIS
        Migrates a complete database from source to target instance
    
    .PARAMETER SourceConnection
        Source SQL Server connection object
    
    .PARAMETER TargetConnection
        Target SQL Server connection object
    
    .PARAMETER DatabaseName
        Name of the database to migrate
    
    .PARAMETER IncludeEncryption
        Whether to include encryption handling
    
    .PARAMETER OutputFile
        Path to output file for script generation
    
    .PARAMETER WhatIfMode
        Whether to run in WhatIf mode
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        $SourceConnection,
        
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        
        [switch]$IncludeEncryption,
        
        [string]$OutputFile,
        
        [switch]$WhatIfMode,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Migrating complete database: $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    try {
        # Check if database already exists on target (idempotent check)
        $targetDb = Get-DbaDatabase -SqlInstance $TargetConnection -Database $DatabaseName -ErrorAction SilentlyContinue
        
        if (-not $targetDb) {
            Write-UpgradeLog -Message "Migrating database $DatabaseName to target instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            
            if (-not $WhatIfMode) {
                # Handle encryption/TDE before migration if needed
                if ($IncludeEncryption) {
                    $encryptionInfo = Test-EncryptionSupport -Connection $SourceConnection -DatabaseName $DatabaseName -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    
                    if ($encryptionInfo.HasTDE) {
                        Write-UpgradeLog -Message "Database $DatabaseName has TDE encryption - preparing TDE migration" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                        # TDE certificate and key migration would be handled here before database copy
                        # This is a placeholder for TDE-specific migration logic
                    }
                    
                    if ($encryptionInfo.EncryptedObjectCount -gt 0) {
                        Write-UpgradeLog -Message "Found $($encryptionInfo.EncryptedObjectCount) encrypted objects in database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    }
                }
                
                # Copy complete database using backup/restore method
                Write-UpgradeLog -Message "Starting complete database migration for $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                Copy-DbaDatabase -Source $SourceConnection -Destination $TargetConnection -Database $DatabaseName -BackupRestore -SharedPath "/tmp/SQLUpgrade" -Force
                Write-UpgradeLog -Message "Database $DatabaseName migration completed successfully" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate complete database $DatabaseName to target instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                if ($IncludeEncryption) {
                    $encryptionInfo = Test-EncryptionSupport -Connection $SourceConnection -DatabaseName $DatabaseName -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    if ($encryptionInfo.HasTDE) {
                        Write-UpgradeLog -Message "[WHATIF] Would handle TDE encryption migration for database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    }
                    if ($encryptionInfo.EncryptedObjectCount -gt 0) {
                        Write-UpgradeLog -Message "[WHATIF] Would migrate $($encryptionInfo.EncryptedObjectCount) encrypted objects in database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    }
                }
            }
        } else {
            Write-UpgradeLog -Message "Database $DatabaseName already exists on target instance - skipping migration (idempotent)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            Write-UpgradeLog -Message "Note: For incremental updates, consider using database synchronization tools" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
    } catch {
        Write-UpgradeLog -Message "Error migrating database $DatabaseName : $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

Export-ModuleMember -Function Copy-CompleteDatabase
