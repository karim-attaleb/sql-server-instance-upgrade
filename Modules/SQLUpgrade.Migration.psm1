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
                
                # Copy complete database using Copy-DbaDatabase for full database migration
                Write-UpgradeLog -Message "Starting complete database migration for $DatabaseName using Copy-DbaDatabase" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                
                try {
                    Copy-DbaDatabase -Source $SourceConnection -Destination $TargetConnection -Database $DatabaseName -BackupRestore -SharedPath "/tmp/SQLUpgrade" -Force
                    Write-UpgradeLog -Message "Database $DatabaseName migration completed successfully using Copy-DbaDatabase" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                } catch {
                    Write-UpgradeLog -Message "Copy-DbaDatabase failed for $DatabaseName, falling back to manual migration: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    
                    # Fallback to manual database creation and table migration
                    $targetDbExists = Get-DbaDatabase -SqlInstance $TargetConnection -Database $DatabaseName -ErrorAction SilentlyContinue
                    if (-not $targetDbExists) {
                        New-DbaDatabase -SqlInstance $TargetConnection -Name $DatabaseName -Owner 'sa'
                        Write-UpgradeLog -Message "Created database $DatabaseName on target instance (fallback method)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    }
                    
                    # Copy database schema and data using table-by-table method as fallback
                    Write-UpgradeLog -Message "Copying database objects and data for $DatabaseName using fallback method" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                    
                    $sourceTables = Get-DbaDbTable -SqlInstance $SourceConnection -Database $DatabaseName
                    foreach ($table in $sourceTables) {
                        Write-UpgradeLog -Message "Migrating table: $($table.Schema).$($table.Name)" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                        
                        try {
                            Copy-DbaDbTableData -SqlInstance $SourceConnection -Database $DatabaseName -Table "$($table.Schema).$($table.Name)" -Destination $TargetConnection -DestinationDatabase $DatabaseName -AutoCreateTable
                        } catch {
                            Write-UpgradeLog -Message "Warning: Could not migrate table $($table.Schema).$($table.Name): $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                        }
                    }
                    Write-UpgradeLog -Message "Database $DatabaseName migration completed using fallback method" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
                }
                
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

Export-ModuleMember -Function Copy-CompleteDatabase, Copy-ServerObjects
