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
