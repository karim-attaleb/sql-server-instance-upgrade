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
    
    .PARAMETER MigrationMethod
        Migration method: 'Direct', 'BackupRestore', 'DetachAttach'
    
    .PARAMETER BackupPath
        Path for backup files (required for BackupRestore method)
    
    .PARAMETER UseExistingBackups
        Use existing backup files instead of creating new ones
    
    .PARAMETER FullBackupPath
        Path to existing full backup file
    
    .PARAMETER DifferentialBackupPath
        Path to existing differential backup file
    
    .PARAMETER LogBackupPaths
        Array of paths to existing log backup files
    
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
        
        [ValidateSet('Direct', 'BackupRestore', 'DetachAttach')]
        [string]$MigrationMethod = 'Direct',
        
        [string]$BackupPath,
        [switch]$UseExistingBackups,
        [string]$FullBackupPath,
        [string]$DifferentialBackupPath,
        [string[]]$LogBackupPaths,
        
        [switch]$WhatIfMode,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Migrating complete database: $DatabaseName using method: $MigrationMethod" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    if ($WhatIfMode) {
        Write-UpgradeLog -Message "[WHATIF] Would migrate database $DatabaseName from $($SourceConnection.Name) to $($TargetConnection.Name) using $MigrationMethod method" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        if ($MigrationMethod -eq 'BackupRestore') {
            if ($UseExistingBackups) {
                Write-UpgradeLog -Message "[WHATIF] Would restore from existing backups:" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                if ($FullBackupPath) { Write-UpgradeLog -Message "[WHATIF]   Full backup: $FullBackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile }
                if ($DifferentialBackupPath) { Write-UpgradeLog -Message "[WHATIF]   Differential backup: $DifferentialBackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile }
                if ($LogBackupPaths) { 
                    Write-UpgradeLog -Message "[WHATIF]   Log backups: $($LogBackupPaths -join ', ')" -LogFile $LogFile -ErrorLogFile $ErrorLogFile 
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would create new backups in: $BackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        if ($IncludeEncryption) {
            $encryptionInfo = Test-EncryptionSupport -Connection $SourceConnection -DatabaseName $DatabaseName -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if ($encryptionInfo.HasTDE) {
                Write-UpgradeLog -Message "[WHATIF] Would handle TDE encryption migration for database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            if ($encryptionInfo.EncryptedObjectCount -gt 0) {
                Write-UpgradeLog -Message "[WHATIF] Would migrate $($encryptionInfo.EncryptedObjectCount) encrypted objects in database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        return
    }
    
    try {
        # Check if database already exists on target (idempotent check)
        $targetDb = Get-DbaDatabase -SqlInstance $TargetConnection -Database $DatabaseName -ErrorAction SilentlyContinue
        if ($targetDb) {
            Write-UpgradeLog -Message "Database $DatabaseName already exists on target instance - skipping migration (idempotent)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            return
        }
        
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
        
        # Execute migration based on selected method
        switch ($MigrationMethod) {
            'BackupRestore' {
                if ($UseExistingBackups) {
                    Restore-DatabaseFromExistingBackups -SourceConnection $SourceConnection -TargetConnection $TargetConnection -DatabaseName $DatabaseName -FullBackupPath $FullBackupPath -DifferentialBackupPath $DifferentialBackupPath -LogBackupPaths $LogBackupPaths -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } else {
                    Restore-DatabaseFromNewBackups -SourceConnection $SourceConnection -TargetConnection $TargetConnection -DatabaseName $DatabaseName -BackupPath $BackupPath -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            }
            'DetachAttach' {
                Copy-DatabaseDetachAttach -SourceConnection $SourceConnection -TargetConnection $TargetConnection -DatabaseName $DatabaseName -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
            'Direct' {
                # Primary method: Use Copy-DbaDatabase for complete database migration
                try {
                    Write-UpgradeLog -Message "Attempting complete database migration using Copy-DbaDatabase" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    Copy-DbaDatabase -Source $SourceConnection -Destination $TargetConnection -Database $DatabaseName -BackupRestore -SharedPath "/tmp/SQLUpgrade" -Force
                    Write-UpgradeLog -Message "Successfully migrated database $DatabaseName using Copy-DbaDatabase" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
                    return
                } catch {
                    Write-UpgradeLog -Message "Copy-DbaDatabase failed: $($_.Exception.Message). Falling back to table-by-table migration." -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
                
                # Fallback method: Table-by-table migration
                Copy-DatabaseTableByTable -SourceConnection $SourceConnection -TargetConnection $TargetConnection -DatabaseName $DatabaseName -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
    } catch {
        Write-UpgradeLog -Message "Failed to migrate database $DatabaseName : $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

function Copy-ServerObjects {
    <#
    .SYNOPSIS
        Migrates server-level objects from source to target instance
    
    .PARAMETER SourceConnection
        Source SQL Server connection object
    
    .PARAMETER TargetConnection
        Target SQL Server connection object
    
    .PARAMETER ServerObjectOptions
        Hashtable containing switches for which server objects to migrate
    
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
        [hashtable]$ServerObjectOptions,
        
        [switch]$WhatIfMode,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting server object migration" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    try {
        # Migrate Logins
        if ($ServerObjectOptions.IncludeLogins) {
            Write-UpgradeLog -Message "Migrating SQL Server logins" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaLogin -Source $SourceConnection -Destination $TargetConnection -ExcludeSystemLogins
                    Write-UpgradeLog -Message "Successfully migrated logins" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating logins: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate SQL Server logins" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Jobs
        if ($ServerObjectOptions.IncludeJobs) {
            Write-UpgradeLog -Message "Migrating SQL Server Agent jobs" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaAgentJob -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated Agent jobs" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating Agent jobs: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate SQL Server Agent jobs" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Linked Servers
        if ($ServerObjectOptions.IncludeLinkedServers) {
            Write-UpgradeLog -Message "Migrating linked servers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaLinkedServer -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated linked servers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating linked servers: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate linked servers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Server Triggers
        if ($ServerObjectOptions.IncludeTriggers) {
            Write-UpgradeLog -Message "Migrating server triggers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaInstanceTrigger -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated server triggers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating server triggers: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate server triggers" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Server Roles
        if ($ServerObjectOptions.IncludeServerRoles) {
            Write-UpgradeLog -Message "Migrating server roles" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaServerRole -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated server roles" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating server roles: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate server roles" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Credentials
        if ($ServerObjectOptions.IncludeCredentials) {
            Write-UpgradeLog -Message "Migrating credentials" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaCredential -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated credentials" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating credentials: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate credentials" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Proxy Accounts
        if ($ServerObjectOptions.IncludeProxyAccounts) {
            Write-UpgradeLog -Message "Migrating proxy accounts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaAgentProxy -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated proxy accounts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating proxy accounts: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate proxy accounts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Alerts
        if ($ServerObjectOptions.IncludeAlerts) {
            Write-UpgradeLog -Message "Migrating alerts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaAgentAlert -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated alerts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating alerts: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate alerts" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Operators
        if ($ServerObjectOptions.IncludeOperators) {
            Write-UpgradeLog -Message "Migrating operators" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaAgentOperator -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated operators" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating operators: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate operators" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Backup Devices
        if ($ServerObjectOptions.IncludeBackupDevices) {
            Write-UpgradeLog -Message "Migrating backup devices" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaBackupDevice -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated backup devices" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating backup devices: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate backup devices" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        # Migrate Server Configuration
        if ($ServerObjectOptions.IncludeServerConfiguration) {
            Write-UpgradeLog -Message "Migrating server configuration settings" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            if (-not $WhatIfMode) {
                try {
                    Copy-DbaSpConfigure -Source $SourceConnection -Destination $TargetConnection
                    Write-UpgradeLog -Message "Successfully migrated server configuration" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Error migrating server configuration: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
            } else {
                Write-UpgradeLog -Message "[WHATIF] Would migrate server configuration settings" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        
        Write-UpgradeLog -Message "Server object migration completed" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        
    } catch {
        Write-UpgradeLog -Message "Error during server object migration: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

function Restore-DatabaseFromExistingBackups {
    <#
    .SYNOPSIS
        Restores a database from existing full, differential, and log backups
    #>
    param(
        [Parameter(Mandatory = $true)]
        $SourceConnection,
        
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        
        [string]$FullBackupPath,
        [string]$DifferentialBackupPath,
        [string[]]$LogBackupPaths,
        [string]$LogFile,
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting restore from existing backups for database: $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    try {
        # Validate backup files exist
        if ($FullBackupPath -and -not (Test-Path $FullBackupPath)) {
            throw "Full backup file not found: $FullBackupPath"
        }
        
        if ($DifferentialBackupPath -and -not (Test-Path $DifferentialBackupPath)) {
            throw "Differential backup file not found: $DifferentialBackupPath"
        }
        
        foreach ($logPath in $LogBackupPaths) {
            if (-not (Test-Path $logPath)) {
                throw "Log backup file not found: $logPath"
            }
        }
        
        # Restore full backup
        if ($FullBackupPath) {
            Write-UpgradeLog -Message "Restoring full backup: $FullBackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            Restore-DbaDatabase -SqlInstance $TargetConnection -Path $FullBackupPath -DatabaseName $DatabaseName -NoRecovery
            Write-UpgradeLog -Message "Successfully restored full backup" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        # Restore differential backup
        if ($DifferentialBackupPath) {
            Write-UpgradeLog -Message "Restoring differential backup: $DifferentialBackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            Restore-DbaDatabase -SqlInstance $TargetConnection -Path $DifferentialBackupPath -DatabaseName $DatabaseName -NoRecovery
            Write-UpgradeLog -Message "Successfully restored differential backup" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        # Restore log backups in sequence
        foreach ($logPath in $LogBackupPaths) {
            Write-UpgradeLog -Message "Restoring log backup: $logPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            Restore-DbaDatabase -SqlInstance $TargetConnection -Path $logPath -DatabaseName $DatabaseName -NoRecovery
            Write-UpgradeLog -Message "Successfully restored log backup: $logPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        # Final recovery
        Write-UpgradeLog -Message "Bringing database online with recovery" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Restore-DbaDatabase -SqlInstance $TargetConnection -DatabaseName $DatabaseName -Recover
        
        Write-UpgradeLog -Message "Successfully restored database $DatabaseName from existing backups" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        
    } catch {
        Write-UpgradeLog -Message "Failed to restore database from existing backups: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

function Restore-DatabaseFromNewBackups {
    <#
    .SYNOPSIS
        Creates new backups and restores database
    #>
    param(
        [Parameter(Mandatory = $true)]
        $SourceConnection,
        
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        
        [string]$LogFile,
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting backup and restore migration for database: $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    try {
        # Ensure backup directory exists
        if (-not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            Write-UpgradeLog -Message "Created backup directory: $BackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        # Create full backup - Pass directory path to Backup-DbaDatabase
        Write-UpgradeLog -Message "Creating full backup in directory: $BackupPath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        $backupResult = Backup-DbaDatabase -SqlInstance $SourceConnection -Database $DatabaseName -Path $BackupPath -Type Full
        
        # Get the actual backup file path from the backup result
        $backupFilePath = $backupResult.Path
        Write-UpgradeLog -Message "Successfully created full backup: $backupFilePath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        # Restore database using the actual backup file path
        Write-UpgradeLog -Message "Restoring database from backup: $backupFilePath" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Restore-DbaDatabase -SqlInstance $TargetConnection -Path $backupFilePath -DatabaseName $DatabaseName
        Write-UpgradeLog -Message "Successfully restored database $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        
    } catch {
        Write-UpgradeLog -Message "Failed to backup and restore database: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

function Copy-DatabaseTableByTable {
    <#
    .SYNOPSIS
        Migrates a database using table-by-table copy method
    
    .PARAMETER SourceConnection
        Source SQL Server connection object
    
    .PARAMETER TargetConnection
        Target SQL Server connection object
    
    .PARAMETER DatabaseName
        Name of the database to migrate
    
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
        
        [string]$LogFile,
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting table-by-table migration for database: $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    try {
        # Create database on target if it doesn't exist
        $targetDbExists = Get-DbaDatabase -SqlInstance $TargetConnection -Database $DatabaseName -ErrorAction SilentlyContinue
        if (-not $targetDbExists) {
            New-DbaDatabase -SqlInstance $TargetConnection -Name $DatabaseName -Owner 'sa'
            Write-UpgradeLog -Message "Created database $DatabaseName on target instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        }
        
        # Copy database schema and data using table-by-table method
        Write-UpgradeLog -Message "Copying database objects and data for $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        $sourceTables = Get-DbaDbTable -SqlInstance $SourceConnection -Database $DatabaseName
        foreach ($table in $sourceTables) {
            Write-UpgradeLog -Message "Migrating table: $($table.Schema).$($table.Name)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            
            try {
                Copy-DbaDbTableData -SqlInstance $SourceConnection -Database $DatabaseName -Table "$($table.Schema).$($table.Name)" -Destination $TargetConnection -DestinationDatabase $DatabaseName -AutoCreateTable
            } catch {
                Write-UpgradeLog -Message "Warning: Could not migrate table $($table.Schema).$($table.Name): $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            }
        }
        Write-UpgradeLog -Message "Database $DatabaseName migration completed using table-by-table method" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
    } catch {
        Write-UpgradeLog -Message "Failed to migrate database using table-by-table method: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}

function Copy-DatabaseDetachAttach {
    <#
    .SYNOPSIS
        Migrates database using detach/attach method
    #>
    param(
        [Parameter(Mandatory = $true)]
        $SourceConnection,
        
        [Parameter(Mandatory = $true)]
        $TargetConnection,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        
        [string]$LogFile,
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting detach/attach migration for database: $DatabaseName" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
    
    try {
        # Use dbatools detach/attach functionality
        Write-UpgradeLog -Message "Detaching database from source instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Detach-DbaDatabase -SqlInstance $SourceConnection -Database $DatabaseName
        
        Write-UpgradeLog -Message "Attaching database to target instance" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Mount-DbaDatabase -SqlInstance $TargetConnection -Database $DatabaseName
        
        Write-UpgradeLog -Message "Successfully migrated database $DatabaseName using detach/attach" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        
    } catch {
        Write-UpgradeLog -Message "Failed to migrate database using detach/attach: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
        throw
    }
}


Export-ModuleMember -Function Copy-CompleteDatabase, Copy-ServerObjects, Restore-DatabaseFromExistingBackups, Restore-DatabaseFromNewBackups, Copy-DatabaseTableByTable, Copy-DatabaseDetachAttach
