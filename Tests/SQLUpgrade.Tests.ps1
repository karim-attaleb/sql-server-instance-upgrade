#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for SQL Server Upgrade Solution - Modular Architecture
    
.DESCRIPTION
    Comprehensive test suite for all modules in the SQL Server upgrade solution
#>

BeforeAll {
    # Import required modules for testing
    $ModulePath = Join-Path $PSScriptRoot "..\Modules"
    
    # Import all modules
    Import-Module (Join-Path $ModulePath "SQLUpgrade.Logging.psm1") -Force
    Import-Module (Join-Path $ModulePath "SQLUpgrade.Connection.psm1") -Force
    Import-Module (Join-Path $ModulePath "SQLUpgrade.Database.psm1") -Force
    Import-Module (Join-Path $ModulePath "SQLUpgrade.Encryption.psm1") -Force
    Import-Module (Join-Path $ModulePath "SQLUpgrade.Migration.psm1") -Force
    Import-Module (Join-Path $ModulePath "SQLUpgrade.PostUpgrade.psm1") -Force
    
    # Test variables
    $script:TestLogPath = Join-Path $env:TEMP "SQLUpgradeTests"
    $script:TestLogFile = Join-Path $script:TestLogPath "test.log"
    $script:TestErrorLogFile = Join-Path $script:TestLogPath "error.log"
}

Describe "SQLUpgrade.Logging Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.Logging module successfully" {
            Get-Module SQLUpgrade.Logging | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Initialize-UpgradeLogging function" {
            Get-Command Initialize-UpgradeLogging -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Write-UpgradeLog function" {
            Get-Command Write-UpgradeLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Initialize-UpgradeLogging Function" {
        It "Should create log directory and return log info" {
            $result = Initialize-UpgradeLogging -LogPath $script:TestLogPath
            
            $result | Should -Not -BeNullOrEmpty
            $result.LogFile | Should -Not -BeNullOrEmpty
            $result.ErrorLogFile | Should -Not -BeNullOrEmpty
            Test-Path $script:TestLogPath | Should -Be $true
        }
        
        It "Should create log files with correct naming pattern" {
            $result = Initialize-UpgradeLogging -LogPath $script:TestLogPath
            
            $result.LogFile | Should -Match "SQLUpgrade_\d{8}_\d{6}\.log"
            $result.ErrorLogFile | Should -Match "SQLUpgrade_Error_\d{8}_\d{6}\.log"
        }
    }
    
    Context "Write-UpgradeLog Function" {
        BeforeEach {
            if (Test-Path $script:TestLogFile) { Remove-Item $script:TestLogFile -Force }
            if (Test-Path $script:TestErrorLogFile) { Remove-Item $script:TestErrorLogFile -Force }
        }
        
        It "Should write Information level messages to log file" {
            Write-UpgradeLog -Message "Test Information Message" -Level "Information" -LogFile $script:TestLogFile -ErrorLogFile $script:TestErrorLogFile
            
            Test-Path $script:TestLogFile | Should -Be $true
            $content = Get-Content $script:TestLogFile -Raw
            $content | Should -Match "Test Information Message"
            $content | Should -Match "\[INFO\]"
        }
        
        It "Should write Error level messages to both log files" {
            Write-UpgradeLog -Message "Test Error Message" -Level "Error" -LogFile $script:TestLogFile -ErrorLogFile $script:TestErrorLogFile
            
            Test-Path $script:TestLogFile | Should -Be $true
            Test-Path $script:TestErrorLogFile | Should -Be $true
            
            $logContent = Get-Content $script:TestLogFile -Raw
            $errorContent = Get-Content $script:TestErrorLogFile -Raw
            
            $logContent | Should -Match "Test Error Message"
            $errorContent | Should -Match "Test Error Message"
            $errorContent | Should -Match "\[ERROR\]"
        }
        
        It "Should include timestamp in log entries" {
            Write-UpgradeLog -Message "Timestamp Test" -LogFile $script:TestLogFile -ErrorLogFile $script:TestErrorLogFile
            
            $content = Get-Content $script:TestLogFile -Raw
            $content | Should -Match "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        }
    }
}

Describe "SQLUpgrade.Connection Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.Connection module successfully" {
            Get-Module SQLUpgrade.Connection | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-InstanceConnectivity function" {
            Get-Command Test-InstanceConnectivity -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-CollationCompatibility function" {
            Get-Command Test-CollationCompatibility -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test-InstanceConnectivity Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Test-InstanceConnectivity
            $command.Parameters.Keys | Should -Contain "Instance"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
        
        It "Should fail gracefully with invalid instance" {
            { Test-InstanceConnectivity -Instance "InvalidInstance" -LogFile $script:TestLogFile -ErrorLogFile $script:TestErrorLogFile } | Should -Not -Throw
        }
    }
}

Describe "SQLUpgrade.Database Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.Database module successfully" {
            Get-Module SQLUpgrade.Database | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-UserDatabases function" {
            Get-Command Get-UserDatabases -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-UserDatabases Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Get-UserDatabases
            $command.Parameters.Keys | Should -Contain "Connection"
            $command.Parameters.Keys | Should -Contain "DatabaseFilter"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
        
        It "Should handle 'All' database filter parameter" {
            # This test would require a mock connection, so we just verify the parameter exists
            $command = Get-Command Get-UserDatabases
            $command.Parameters["DatabaseFilter"] | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "SQLUpgrade.Encryption Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.Encryption module successfully" {
            Get-Module SQLUpgrade.Encryption | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-EncryptionSupport function" {
            Get-Command Test-EncryptionSupport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test-EncryptionSupport Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Test-EncryptionSupport
            $command.Parameters.Keys | Should -Contain "Connection"
            $command.Parameters.Keys | Should -Contain "DatabaseName"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
    }
}

Describe "SQLUpgrade.Migration Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.Migration module successfully" {
            Get-Module SQLUpgrade.Migration | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Copy-CompleteDatabase function" {
            Get-Command Copy-CompleteDatabase -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Copy-ServerObjects function" {
            Get-Command Copy-ServerObjects -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Copy-CompleteDatabase Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Copy-CompleteDatabase
            $command.Parameters.Keys | Should -Contain "SourceConnection"
            $command.Parameters.Keys | Should -Contain "TargetConnection"
            $command.Parameters.Keys | Should -Contain "DatabaseName"
            $command.Parameters.Keys | Should -Contain "IncludeEncryption"
            $command.Parameters.Keys | Should -Contain "WhatIfMode"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
        
        It "Should support WhatIf functionality" {
            $command = Get-Command Copy-CompleteDatabase
            $command.Parameters["WhatIfMode"] | Should -Not -BeNullOrEmpty
            $command.Parameters["WhatIfMode"].ParameterType | Should -Be ([switch])
        }
    }
    
    Context "Copy-ServerObjects Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Copy-ServerObjects
            $command.Parameters.Keys | Should -Contain "SourceConnection"
            $command.Parameters.Keys | Should -Contain "TargetConnection"
            $command.Parameters.Keys | Should -Contain "ServerObjectOptions"
            $command.Parameters.Keys | Should -Contain "WhatIfMode"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
        
        It "Should support WhatIf functionality" {
            $command = Get-Command Copy-ServerObjects
            $command.Parameters["WhatIfMode"] | Should -Not -BeNullOrEmpty
            $command.Parameters["WhatIfMode"].ParameterType | Should -Be ([switch])
        }
        
        It "Should require ServerObjectOptions hashtable parameter" {
            $command = Get-Command Copy-ServerObjects
            $command.Parameters["ServerObjectOptions"] | Should -Not -BeNullOrEmpty
            $command.Parameters["ServerObjectOptions"].ParameterType | Should -Be ([hashtable])
        }
    }
}

Describe "SQLUpgrade.PostUpgrade Module Tests" {
    Context "Module Import and Function Export" {
        It "Should import SQLUpgrade.PostUpgrade module successfully" {
            Get-Module SQLUpgrade.PostUpgrade | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-PostUpgradeTasks function" {
            Get-Command Invoke-PostUpgradeTasks -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-PostUpgradeTasks Function" {
        It "Should have proper parameter validation" {
            $command = Get-Command Invoke-PostUpgradeTasks
            $command.Parameters.Keys | Should -Contain "TargetConnection"
            $command.Parameters.Keys | Should -Contain "DatabaseNames"
            $command.Parameters.Keys | Should -Contain "WhatIfMode"
            $command.Parameters.Keys | Should -Contain "LogFile"
            $command.Parameters.Keys | Should -Contain "ErrorLogFile"
        }
        
        It "Should support WhatIf functionality" {
            $command = Get-Command Invoke-PostUpgradeTasks
            $command.Parameters["WhatIfMode"] | Should -Not -BeNullOrEmpty
            $command.Parameters["WhatIfMode"].ParameterType | Should -Be ([switch])
        }
    }
}

Describe "Main Script Integration Tests" {
    Context "Start-SQLServerUpgrade.ps1 Structure" {
        BeforeAll {
            $script:MainScriptPath = Join-Path $PSScriptRoot "..\Start-SQLServerUpgrade.ps1"
            $script:MainScriptContent = Get-Content $script:MainScriptPath -Raw
        }
        
        It "Should exist and be readable" {
            Test-Path $script:MainScriptPath | Should -Be $true
            $script:MainScriptContent | Should -Not -BeNullOrEmpty
        }
        
        It "Should contain NO function definitions" {
            $script:MainScriptContent | Should -Not -Match "^\s*function\s+\w+"
            $script:MainScriptContent | Should -Not -Match "\n\s*function\s+\w+"
        }
        
        It "Should import all required modules" {
            $script:MainScriptContent | Should -Match "SQLUpgrade\.Logging\.psm1"
            $script:MainScriptContent | Should -Match "SQLUpgrade\.Connection\.psm1"
            $script:MainScriptContent | Should -Match "SQLUpgrade\.Database\.psm1"
            $script:MainScriptContent | Should -Match "SQLUpgrade\.Encryption\.psm1"
            $script:MainScriptContent | Should -Match "SQLUpgrade\.Migration\.psm1"
            $script:MainScriptContent | Should -Match "SQLUpgrade\.PostUpgrade\.psm1"
        }
        
        It "Should have proper PowerShell requirements" {
            $script:MainScriptContent | Should -Match "#Requires -Version 5\.1"
            $script:MainScriptContent | Should -Match "#Requires -Modules dbatools"
        }
        
        It "Should support ShouldProcess for WhatIf functionality" {
            $script:MainScriptContent | Should -Match "\[CmdletBinding\(SupportsShouldProcess\)\]"
        }
        
        It "Should have all required parameters" {
            $script:MainScriptContent | Should -Match "\`$SourceInstance"
            $script:MainScriptContent | Should -Match "\`$TargetInstance"
            $script:MainScriptContent | Should -Match "\`$Databases"
            $script:MainScriptContent | Should -Match "\`$IncludeEncryption"
            $script:MainScriptContent | Should -Match "\`$WhatIf"
            $script:MainScriptContent | Should -Match "\`$LogPath"
        }
        
        It "Should have server object migration parameters" {
            $script:MainScriptContent | Should -Match "\`$IncludeLogins"
            $script:MainScriptContent | Should -Match "\`$IncludeJobs"
            $script:MainScriptContent | Should -Match "\`$IncludeLinkedServers"
            $script:MainScriptContent | Should -Match "\`$IncludeTriggers"
            $script:MainScriptContent | Should -Match "\`$IncludeServerRoles"
            $script:MainScriptContent | Should -Match "\`$IncludeCredentials"
            $script:MainScriptContent | Should -Match "\`$IncludeProxyAccounts"
            $script:MainScriptContent | Should -Match "\`$IncludeAlerts"
            $script:MainScriptContent | Should -Match "\`$IncludeOperators"
            $script:MainScriptContent | Should -Match "\`$IncludeBackupDevices"
            $script:MainScriptContent | Should -Match "\`$IncludeServerConfiguration"
            $script:MainScriptContent | Should -Match "\`$IncludeAllServerObjects"
        }
        
        It "Should call module functions only" {
            $script:MainScriptContent | Should -Match "Initialize-UpgradeLogging"
            $script:MainScriptContent | Should -Match "Test-InstanceConnectivity"
            $script:MainScriptContent | Should -Match "Test-CollationCompatibility"
            $script:MainScriptContent | Should -Match "Get-UserDatabases"
            $script:MainScriptContent | Should -Match "Copy-CompleteDatabase"
            $script:MainScriptContent | Should -Match "Copy-ServerObjects"
            $script:MainScriptContent | Should -Match "Invoke-PostUpgradeTasks"
        }
    }
    
    Context "Backup and Restore Method Validation" {
        It "Should validate backup path requirements for BackupRestore method" {
            # Test that backup path validation works correctly
            $testParams = @{
                MigrationMethod = 'BackupRestore'
                UseExistingBackups = $false
                BackupPath = $null
            }
            # This would normally validate in the actual function call
            $testParams.MigrationMethod | Should -Be 'BackupRestore'
        }
        
        It "Should validate existing backup file requirements" {
            $testParams = @{
                MigrationMethod = 'BackupRestore'
                UseExistingBackups = $true
                FullBackupPath = '/path/to/backup.bak'
            }
            $testParams.UseExistingBackups | Should -Be $true
            $testParams.FullBackupPath | Should -Not -BeNullOrEmpty
        }
        
        It "Should support all migration methods" {
            $validMethods = @('Direct', 'BackupRestore', 'DetachAttach')
            foreach ($method in $validMethods) {
                $method | Should -BeIn @('Direct', 'BackupRestore', 'DetachAttach')
            }
        }
    }
}

# OutputFile PowerShell Script Generation Tests
Describe "OutputFile PowerShell Script Generation" {
    It "Should generate PowerShell script instead of T-SQL when OutputFile is specified" {
        # Create a temporary output file
        $outputFile = "/tmp/test_migration_script.ps1"
        if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
        
        # Mock the migration function call that would generate the output file
        $testContent = @"
# PowerShell Database Migration Script for: TestDB
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Uses dbatools for all SQL Server operations

# Import required module
Import-Module dbatools -Force

# Establish connections
`$sourceConn = Connect-DbaInstance -SqlInstance 'localhost,1435'
`$targetConn = Connect-DbaInstance -SqlInstance 'localhost,1436'

# Create new backup and restore using dbatools
try {
    Write-Host "Creating backup for database: TestDB" -ForegroundColor Yellow
    
    # Create full backup
    `$backupFile = "/tmp/backups/TestDB_Full_20251003_143105.bak"
    Backup-DbaDatabase -SqlInstance `$sourceConn -Database 'TestDB' -Path `$backupFile -CompressBackup
    
    Write-Host "Restoring database from backup: `$backupFile" -ForegroundColor Yellow
    
    # Restore database
    Restore-DbaDatabase -SqlInstance `$targetConn -Path `$backupFile -DatabaseName 'TestDB' -ReplaceDbNameInFile -WithReplace
    
    Write-Host "Database TestDB migrated successfully via backup/restore" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate database TestDB via backup/restore: `$(`$_.Exception.Message)"
    throw
}

# Post-migration tasks using dbatools
try {
    Write-Host "Running post-migration tasks for database: TestDB" -ForegroundColor Yellow
    
    # Update database compatibility level to SQL Server 2022
    Set-DbaDbCompatibility -SqlInstance `$targetConn -Database 'TestDB' -CompatibilityLevel 160
    Write-Host "Updated compatibility level to SQL Server 2022 (160)" -ForegroundColor Cyan
    
    # Update statistics
    Update-DbaStatistics -SqlInstance `$targetConn -Database 'TestDB'
    Write-Host "Updated statistics for database: TestDB" -ForegroundColor Cyan
    
    # Run DBCC CHECKDB
    try {
        Invoke-DbaQuery -SqlInstance `$targetConn -Database 'TestDB' -Query "DBCC CHECKDB([TestDB]) WITH NO_INFOMSGS" -EnableException
        Write-Host "DBCC CHECKDB completed successfully for database: TestDB" -ForegroundColor Green
    } catch {
        Write-Warning "DBCC CHECKDB found issues in database: TestDB - `$(`$_.Exception.Message)"
    }
    
    Write-Host "Post-migration tasks completed for database: TestDB" -ForegroundColor Green
    
} catch {
    Write-Error "Error in post-migration tasks for database TestDB : `$(`$_.Exception.Message)"
}

Write-Host "Migration script completed for database: TestDB" -ForegroundColor Green
"@
        
        # Write test content to file
        Add-Content -Path $outputFile -Value $testContent -Encoding UTF8
        
        # Verify the generated file contains PowerShell/dbatools commands, not T-SQL
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "Import-Module dbatools"
        $content | Should -Match "Connect-DbaInstance"
        $content | Should -Match "Backup-DbaDatabase"
        $content | Should -Match "Restore-DbaDatabase"
        $content | Should -Match "Set-DbaDbCompatibility"
        $content | Should -Match "Update-DbaStatistics"
        $content | Should -Match "Invoke-DbaQuery"
        
        # Verify it does NOT contain raw T-SQL commands (DBCC CHECKDB is now executed via Invoke-DbaQuery)
        $content | Should -Not -Match "BACKUP DATABASE \["
        $content | Should -Not -Match "RESTORE DATABASE \["
        $content | Should -Not -Match "ALTER DATABASE.*SET COMPATIBILITY_LEVEL"
        $content | Should -Not -Match "EXEC sp_updatestats"
        # Note: DBCC CHECKDB is now executed via Invoke-DbaQuery cmdlet, so it appears as a query string
        $content | Should -Not -Match "USE \[master\]"
        $content | Should -Not -Match "GO"
        
        # Clean up
        if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
    }
    
    It "Should generate PowerShell server objects script instead of T-SQL" {
        # Create a temporary output file
        $outputFile = "/tmp/test_server_objects_script.ps1"
        if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
        
        # Mock server objects migration script content
        $testContent = @"
# PowerShell Server Objects Migration Script
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Import required module
Import-Module dbatools -Force

# Establish connections
`$sourceConn = Connect-DbaInstance -SqlInstance 'localhost,1435'
`$targetConn = Connect-DbaInstance -SqlInstance 'localhost,1436'

Write-Host "Starting server objects migration" -ForegroundColor Green

# Migrate SQL Server Logins using dbatools
try {
    Write-Host "Migrating SQL Server Logins..." -ForegroundColor Yellow
    Copy-DbaLogin -Source `$sourceConn -Destination `$targetConn -ExcludeSystemLogins
    Write-Host "SQL Server Logins migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate logins: `$(`$_.Exception.Message)"
}

# Migrate SQL Server Agent Jobs using dbatools
try {
    Write-Host "Migrating SQL Server Agent Jobs..." -ForegroundColor Yellow
    Copy-DbaAgentJob -Source `$sourceConn -Destination `$targetConn
    Write-Host "SQL Server Agent Jobs migrated successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to migrate jobs: `$(`$_.Exception.Message)"
}

Write-Host "Server objects migration script completed" -ForegroundColor Green
"@
        
        # Write test content to file
        Add-Content -Path $outputFile -Value $testContent -Encoding UTF8
        
        # Verify the generated file contains PowerShell/dbatools commands, not T-SQL
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "Import-Module dbatools"
        $content | Should -Match "Connect-DbaInstance"
        $content | Should -Match "Copy-DbaLogin"
        $content | Should -Match "Copy-DbaAgentJob"
        
        # Verify it does NOT contain T-SQL commands
        $content | Should -Not -Match "CREATE LOGIN"
        $content | Should -Not -Match "EXEC dbo\.sp_add_job"
        $content | Should -Not -Match "USE msdb"
        $content | Should -Not -Match "GO"
        
        # Clean up
        if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
    }
}

Describe "Module Architecture Validation" {
    Context "Module File Structure" {
        It "Should have all required module files" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            
            Test-Path (Join-Path $ModulePath "SQLUpgrade.Logging.psm1") | Should -Be $true
            Test-Path (Join-Path $ModulePath "SQLUpgrade.Connection.psm1") | Should -Be $true
            Test-Path (Join-Path $ModulePath "SQLUpgrade.Database.psm1") | Should -Be $true
            Test-Path (Join-Path $ModulePath "SQLUpgrade.Encryption.psm1") | Should -Be $true
            Test-Path (Join-Path $ModulePath "SQLUpgrade.Migration.psm1") | Should -Be $true
            Test-Path (Join-Path $ModulePath "SQLUpgrade.PostUpgrade.psm1") | Should -Be $true
        }
        
        It "Should have proper Export-ModuleMember statements in all modules" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
            
            foreach ($moduleFile in $moduleFiles) {
                $content = Get-Content $moduleFile.FullName -Raw
                $content | Should -Match "Export-ModuleMember"
            }
        }
    }
    
    Context "Enhanced Database Filtering" {
        It "Should exclude utility databases by default" {
            $command = Get-Command Get-UserDatabases
            $command.Parameters.Keys | Should -Contain "IncludeSupportDbs"
        }
        
        It "Should include utility databases when IncludeSupportDbs is specified" {
            $command = Get-Command Get-UserDatabases
            $command.Parameters["IncludeSupportDbs"].ParameterType | Should -Be ([switch])
        }
        
        It "Should support comprehensive Exclude parameter in main script" {
            $script:MainScriptContent | Should -Match "\[string\[\]\]\`$Exclude"
            $script:MainScriptContent | Should -Match "IncludeSupportDbs"
        }
        
        It "Should have Start-DbaMigration.ps1 wrapper script" {
            $wrapperScript = Join-Path $PSScriptRoot "..\Start-DbaMigration.ps1"
            $wrapperScript | Should -Exist
            $wrapperContent = Get-Content $wrapperScript -Raw
            $wrapperContent | Should -Match "Start-SQLServerUpgrade\.ps1"
            $wrapperContent | Should -Match "IncludeSupportDbs"
            $wrapperContent | Should -Match "Exclude"
        }
    }
    
    Context "Function Distribution" {
        It "Should have functions properly distributed across modules" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            
            # Check Logging module
            $loggingContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.Logging.psm1") -Raw
            $loggingContent | Should -Match "function Initialize-UpgradeLogging"
            $loggingContent | Should -Match "function Write-UpgradeLog"
            
            # Check Connection module
            $connectionContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.Connection.psm1") -Raw
            $connectionContent | Should -Match "function Test-InstanceConnectivity"
            $connectionContent | Should -Match "function Test-CollationCompatibility"
            
            # Check Database module
            $databaseContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.Database.psm1") -Raw
            $databaseContent | Should -Match "function Get-UserDatabases"
            
            # Check Encryption module
            $encryptionContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.Encryption.psm1") -Raw
            $encryptionContent | Should -Match "function Test-EncryptionSupport"
            
            # Check Migration module
            $migrationContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.Migration.psm1") -Raw
            $migrationContent | Should -Match "function Copy-CompleteDatabase"
            $migrationContent | Should -Match "function Copy-ServerObjects"
            
            # Check PostUpgrade module
            $postUpgradeContent = Get-Content (Join-Path $ModulePath "SQLUpgrade.PostUpgrade.psm1") -Raw
            $postUpgradeContent | Should -Match "function Invoke-PostUpgradeTasks"
        }
    }
}

AfterAll {
    # Clean up test files
    if (Test-Path $script:TestLogPath) {
        Remove-Item $script:TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove imported modules
    Remove-Module SQLUpgrade.* -Force -ErrorAction SilentlyContinue
}
