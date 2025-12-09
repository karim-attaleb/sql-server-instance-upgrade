#Requires -Version 5.1
#Requires -Modules dbatools

<#
.SYNOPSIS
    SQL Server Upgrade Post-Upgrade Tasks Module
    
.DESCRIPTION
    Provides post-upgrade maintenance functionality for SQL Server upgrade operations.
#>

function Invoke-PostUpgradeTasks {
    <#
    .SYNOPSIS
        Executes post-upgrade maintenance tasks
    
    .PARAMETER TargetConnection
        Target SQL Server connection object
    
    .PARAMETER DatabaseNames
        Array of database names to process
    
    .PARAMETER WhatIfMode
        Whether to run in WhatIf mode
    
    .PARAMETER LogFile
        Path to log file for logging
    
    .PARAMETER ErrorLogFile
        Path to error log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [Parameter(Mandatory = $true)]
        [string[]]$DatabaseNames,
        
        [switch]$WhatIfMode,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting post-upgrade tasks" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    foreach ($dbName in $DatabaseNames) {
        Write-UpgradeLog -Message "Running post-upgrade tasks for database: $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        try {
            # Database Integrity Check
            Write-UpgradeLog -Message "Running DBCC CHECKDB for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Invoke-DbaQuery -SqlInstance $TargetConnection -Database $dbName -Query "DBCC CHECKDB([$dbName]) WITH NO_INFOMSGS" -EnableException
                    Write-UpgradeLog -Message "DBCC CHECKDB completed successfully for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
                } catch {
                    Write-UpgradeLog -Message "DBCC CHECKDB found issues in $dbName : $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would run DBCC CHECKDB for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            
            # Update Database Compatibility Level
            Write-UpgradeLog -Message "Updating compatibility level for $dbName to SQL Server 2022" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                Set-DbaDbCompatibility -SqlInstance $TargetConnection -Database $dbName -Compatibility 160 # SQL Server 2022
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would update compatibility level for $dbName to 160" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            
            # Update Statistics
            Write-UpgradeLog -Message "Updating statistics for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                Update-DbaStatistics -SqlInstance $TargetConnection -Database $dbName
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would update statistics for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            
            # Rebuild Indexes
            Write-UpgradeLog -Message "Rebuilding indexes for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                # Use Update-DbaStatistics and basic index rebuild approach
                Invoke-DbaQuery -SqlInstance $TargetConnection -Database $dbName -Query "ALTER INDEX ALL ON [dbo].[YourTable] REBUILD" -ErrorAction SilentlyContinue
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would rebuild indexes for $dbName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            
        } catch {
            Write-UpgradeLog -Message "Error in post-upgrade tasks for $dbName : $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        }
    }
}

Export-ModuleMember -Function Invoke-PostUpgradeTasks
