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
        
        [ValidateSet('Direct', 'BackupRestore', 'DetachAttach')]
        [string]$MigrationMethod = 'Direct',
        
        [string]$BackupPath,
        [switch]$UseExistingBackups,
        [string]$FullBackupPath,
        [string]$DifferentialBackupPath,
        [string[]]$LogBackupPaths,
        
        [string]$OutputFile,
        
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
        # Skip database existence check and encryption handling for OutputFile mode
        if (-not $OutputFile) {
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
        }
        
        # Generate SQL script if OutputFile is specified
        if ($OutputFile) {
            Write-UpgradeLog -Message "Generating SQL script for database $DatabaseName migration to: $OutputFile" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            
            $sourceInstanceName = if ($SourceConnection.InstanceName) { $SourceConnection.InstanceName } else { $SourceConnection.ComputerName }
            $targetInstanceName = if ($TargetConnection.InstanceName) { $TargetConnection.InstanceName } else { $TargetConnection.ComputerName }
            
            $psScript = @"
# PowerShell Database Migration Script for: $DatabaseName
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Source Instance: $sourceInstanceName
# Target Instance: $targetInstanceName
# Migration Method: $MigrationMethod
# Uses dbatools for all SQL Server operations

# Import required module
Import-Module dbatools -Force

# Establish connections
`$sourceConn = Connect-DbaInstance -SqlInstance '$sourceInstanceName'
`$targetConn = Connect-DbaInstance -SqlInstance '$targetInstanceName'

Write-Host "Starting migration of database: $DatabaseName" -ForegroundColor Green

"@
            
            switch ($MigrationMethod) {
                'BackupRestore' {
                    if ($UseExistingBackups) {
                        $psScript += @"
# Restore from existing backup files using dbatools
try {
    Write-Host "Restoring from existing backup chain" -ForegroundColor Yellow
    
"@
                        if ($FullBackupPath) {
                            $psScript += @"
    # Restore full backup
    Restore-DbaDatabase -SqlInstance `$targetConn -Path '$FullBackupPath' -DatabaseName '$DatabaseName' -ReplaceDbNameInFile -WithReplace -NoRecovery
"@
                        }
                        if ($DifferentialBackupPath) {
                            $psScript += @"
    
    # Restore differential backup
    Restore-DbaDatabase -SqlInstance `$targetConn -Path '$DifferentialBackupPath' -DatabaseName '$DatabaseName' -Continue -NoRecovery
"@
                        }
                        if ($LogBackupPaths) {
                            foreach ($logPath in $LogBackupPaths) {
                                $psScript += @"
    
    # Restore log backup: $logPath
    Restore-DbaDatabase -SqlInstance `$targetConn -Path '$logPath' -DatabaseName '$DatabaseName' -Continue -NoRecovery
"@
                            }
                            $psScript += @"
    
    # Final recovery
    Restore-DbaDatabase -SqlInstance `$targetConn -DatabaseName '$DatabaseName' -Continue
"@
                        }
                        $psScript += @"
    
    Write-Host "Database $DatabaseName restored successfully from existing backups" -ForegroundColor Green
} catch {
    Write-Error "Failed to restore database $DatabaseName : `$(`$_.Exception.Message)"
    throw
}

"@
                    } else {
                        $backupFile = Join-Path $BackupPath "$DatabaseName`_Full_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
                        $psScript += @"
# Create new backup and restore using dbatools
try {
    Write-Host "Creating backup for database: $DatabaseName" -ForegroundColor Yellow
    
    # Create full backup
    `$backupFile = "$backupFile"
    Backup-DbaDatabase -SqlInstance `$sourceConn -Database '$DatabaseName' -Path `$backupFile -CompressBackup
    
    Write-Host "Restoring database from backup: `$backupFile" -ForegroundColor Yellow
    
    # Restore database
    Restore-DbaDatabase -SqlInstance `$targetConn -Path `$backupFile -DatabaseName '$DatabaseName' -ReplaceDbNameInFile -WithReplace
    
    Write-Host "Database $DatabaseName migrated successfully via backup/restore" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate database $DatabaseName via backup/restore: `$(`$_.Exception.Message)"
    throw
}

"@
                    }
                }
                'DetachAttach' {
                    $psScript += @"
# Detach/Attach migration using dbatools
try {
    Write-Host "Starting detach/attach migration for database: $DatabaseName" -ForegroundColor Yellow
    
    # Get database file paths
    `$dbFiles = Get-DbaDbFile -SqlInstance `$sourceConn -Database '$DatabaseName'
    
    # Detach database from source
    Dismount-DbaDatabase -SqlInstance `$sourceConn -Database '$DatabaseName' -Force
    
    # Note: Files must be copied to target server location manually
    Write-Host "Manual step required: Copy database files to target server" -ForegroundColor Yellow
    Write-Host "Files to copy:" -ForegroundColor Yellow
    `$dbFiles | ForEach-Object { Write-Host "  `$(`$_.PhysicalName)" -ForegroundColor Cyan }
    
    # Attach database to target (uncomment after files are copied)
    # Mount-DbaDatabase -SqlInstance `$targetConn -Database '$DatabaseName' -FileStructure `$dbFiles
    
    Write-Host "Database $DatabaseName detached from source. Complete file copy and uncomment attach command." -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate database $DatabaseName via detach/attach: `$(`$_.Exception.Message)"
    throw
}

"@
                }
                'Direct' {
                    $psScript += @"
# Direct migration using Copy-DbaDatabase
try {
    Write-Host "Attempting direct migration using Copy-DbaDatabase" -ForegroundColor Yellow
    
    Copy-DbaDatabase -Source `$sourceConn -Destination `$targetConn -Database '$DatabaseName' -BackupRestore -SharedPath '/tmp/SQLUpgrade' -Force
    
    Write-Host "Database $DatabaseName migrated successfully using Copy-DbaDatabase" -ForegroundColor Green
} catch {
    Write-Warning "Copy-DbaDatabase failed: `$(`$_.Exception.Message). Attempting table-by-table migration."
    
    # Fallback: Create empty database and copy data
    New-DbaDatabase -SqlInstance `$targetConn -Name '$DatabaseName'
    
    # Copy tables and data
    `$tables = Get-DbaDbTable -SqlInstance `$sourceConn -Database '$DatabaseName'
    foreach (`$table in `$tables) {
        Write-Host "Copying table: `$(`$table.Schema).`$(`$table.Name)" -ForegroundColor Cyan
        Copy-DbaDbTableData -SqlInstance `$sourceConn -Database '$DatabaseName' -Table "`$(`$table.Schema).`$(`$table.Name)" -DestinationSqlInstance `$targetConn -DestinationDatabase '$DatabaseName'
    }
    
    Write-Host "Database $DatabaseName migrated successfully using table-by-table method" -ForegroundColor Green
}

"@
                }
            }
            
            $psScript += @"
# Post-migration tasks using dbatools
try {
    Write-Host "Running post-migration tasks for database: $DatabaseName" -ForegroundColor Yellow
    
    # Update database compatibility level to SQL Server 2022
    Set-DbaDbCompatibility -SqlInstance `$targetConn -Database '$DatabaseName' -CompatibilityLevel 160
    Write-Host "Updated compatibility level to SQL Server 2022 (160)" -ForegroundColor Cyan
    
    # Update statistics
    Update-DbaStatistics -SqlInstance `$targetConn -Database '$DatabaseName'
    Write-Host "Updated statistics for database: $DatabaseName" -ForegroundColor Cyan
    
    # Run DBCC CHECKDB
    `$checkResult = Invoke-DbaDbccCheckdb -SqlInstance `$targetConn -Database '$DatabaseName'
    if (`$checkResult.Status -eq "Success") {
        Write-Host "DBCC CHECKDB completed successfully for database: $DatabaseName" -ForegroundColor Green
    } else {
        Write-Warning "DBCC CHECKDB found issues in database: $DatabaseName"
    }
    
    Write-Host "Post-migration tasks completed for database: $DatabaseName" -ForegroundColor Green
    
} catch {
    Write-Error "Error in post-migration tasks for database $DatabaseName : `$(`$_.Exception.Message)"
}

Write-Host "Migration script completed for database: $DatabaseName" -ForegroundColor Green

"@
            
            # Append to output file
            Add-Content -Path $OutputFile -Value $psScript -Encoding UTF8
            Write-UpgradeLog -Message "PowerShell script generated and appended to: $OutputFile" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
            return
        }
        
        # Execute migration based on selected method (skip for OutputFile mode)
        if (-not $OutputFile) {
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
        [hashtable]$ServerObjectOptions,
        
        [string]$OutputFile,
        
        [switch]$WhatIfMode,
        
        [string]$LogFile,
        
        [string]$ErrorLogFile
    )
    
    Write-UpgradeLog -Message "Starting server object migration" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
    
    # Generate SQL script if OutputFile is specified
    if ($OutputFile) {
        Write-UpgradeLog -Message "Generating PowerShell script for server object migration to: $OutputFile" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        $psScript = @"
# PowerShell Server Objects Migration Script
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Source Instance: $($SourceConnection.Name)
# Target Instance: $($TargetConnection.Name)

# Import required module
Import-Module dbatools -Force

# Establish connections
`$sourceConn = Connect-DbaInstance -SqlInstance '$($SourceConnection.Name)'
`$targetConn = Connect-DbaInstance -SqlInstance '$($TargetConnection.Name)'

Write-Host "Starting server objects migration" -ForegroundColor Green

"@
        
        if ($ServerObjectOptions.IncludeLogins) {
            $psScript += @"
# Migrate SQL Server Logins using dbatools
try {
    Write-Host "Migrating SQL Server Logins..." -ForegroundColor Yellow
    Copy-DbaLogin -Source `$sourceConn -Destination `$targetConn -ExcludeSystemLogins
    Write-Host "SQL Server Logins migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate logins: `$(`$_.Exception.Message)"
}

"@
        }
        
        if ($ServerObjectOptions.IncludeJobs) {
            $psScript += @"
# Migrate SQL Server Agent Jobs using dbatools
try {
    Write-Host "Migrating SQL Server Agent Jobs..." -ForegroundColor Yellow
    Copy-DbaAgentJob -Source `$sourceConn -Destination `$targetConn
    Write-Host "SQL Server Agent Jobs migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate jobs: `$(`$_.Exception.Message)"
}

"@
        }
        
        if ($ServerObjectOptions.IncludeLinkedServers) {
            $psScript += @"
# Migrate Linked Servers using dbatools
try {
    Write-Host "Migrating Linked Servers..." -ForegroundColor Yellow
    Copy-DbaLinkedServer -Source `$sourceConn -Destination `$targetConn
    Write-Host "Linked Servers migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate linked servers: `$(`$_.Exception.Message)"
}

"@
        }
        
        if ($ServerObjectOptions.IncludeServerRoles) {
            $psScript += @"
# Migrate Custom Server Roles using dbatools
try {
    Write-Host "Migrating Custom Server Roles..." -ForegroundColor Yellow
    Copy-DbaServerRole -Source `$sourceConn -Destination `$targetConn
    Write-Host "Custom Server Roles migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate server roles: `$(`$_.Exception.Message)"
}

"@
        }
        
        if ($ServerObjectOptions.IncludeCredentials) {
            $psScript += @"
# Migrate Credentials using dbatools
try {
    Write-Host "Migrating Credentials..." -ForegroundColor Yellow
    Copy-DbaCredential -Source `$sourceConn -Destination `$targetConn
    Write-Host "Credentials migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate credentials: `$(`$_.Exception.Message)"
}

"@
        }
        
        if ($ServerObjectOptions.IncludeServerConfiguration) {
            $psScript += @"
# Migrate Server Configuration Settings using dbatools
try {
    Write-Host "Migrating Server Configuration Settings..." -ForegroundColor Yellow
    Copy-DbaSpConfigure -Source `$sourceConn -Destination `$targetConn
    Write-Host "Server Configuration Settings migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate server configuration settings: `$(`$_.Exception.Message)"
}

"@
        }
        
        $psScript += @"
Write-Host "Server objects migration script completed" -ForegroundColor Green

"@
        
        # Append to output file
        Add-Content -Path $OutputFile -Value $psScript -Encoding UTF8
        Write-UpgradeLog -Message "PowerShell server objects script generated and appended to: $OutputFile" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        return
    }
    
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
                    Copy-DbaServerTrigger -Source $SourceConnection -Destination $TargetConnection
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
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fullBackupFile = Join-Path $BackupPath "$DatabaseName`_Full_$timestamp.bak"
        
        # Create full backup
        Write-UpgradeLog -Message "Creating full backup: $fullBackupFile" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Backup-DbaDatabase -SqlInstance $SourceConnection -Database $DatabaseName -Path $fullBackupFile -Type Full
        Write-UpgradeLog -Message "Successfully created full backup" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        
        # Restore database
        Write-UpgradeLog -Message "Restoring database from backup" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
        Restore-DbaDatabase -SqlInstance $TargetConnection -Path $fullBackupFile -DatabaseName $DatabaseName
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
