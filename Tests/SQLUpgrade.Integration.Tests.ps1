#Requires -Modules Pester

<#
.SYNOPSIS
    Integration tests for SQL Server Upgrade Solution
    
.DESCRIPTION
    Integration tests that verify the complete workflow and module interactions
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
    $script:TestLogPath = Join-Path $env:TEMP "SQLUpgradeIntegrationTests"
    $script:MainScriptPath = Join-Path $PSScriptRoot "..\Start-SQLServerUpgrade.ps1"
}

Describe "End-to-End Workflow Integration Tests" {
    Context "Logging Workflow" {
        It "Should initialize logging and write messages successfully" {
            $logInfo = Initialize-UpgradeLogging -LogPath $script:TestLogPath
            
            $logInfo | Should -Not -BeNullOrEmpty
            $logInfo.LogFile | Should -Not -BeNullOrEmpty
            $logInfo.ErrorLogFile | Should -Not -BeNullOrEmpty
            
            Write-UpgradeLog -Message "Integration test message" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            
            Test-Path $logInfo.LogFile | Should -Be $true
            $content = Get-Content $logInfo.LogFile -Raw
            $content | Should -Match "Integration test message"
        }
    }
    
    Context "Module Interaction" {
        It "Should be able to chain module function calls" {
            $logInfo = Initialize-UpgradeLogging -LogPath $script:TestLogPath
            
            # This simulates the workflow in the main script
            Write-UpgradeLog -Message "Starting integration test workflow" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            Write-UpgradeLog -Message "Testing module interactions" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            Write-UpgradeLog -Message "Integration test completed" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
            
            $content = Get-Content $logInfo.LogFile -Raw
            $content | Should -Match "Starting integration test workflow"
            $content | Should -Match "Testing module interactions"
            $content | Should -Match "Integration test completed"
        }
    }
}

Describe "Main Script Syntax and Structure Validation" {
    Context "PowerShell Syntax Validation" {
        It "Should have valid PowerShell syntax" {
            $scriptContent = Get-Content $script:MainScriptPath -Raw
            $tokens = $null
            $errors = $null
            
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$errors)
            
            $errors.Count | Should -Be 0
            $ast | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper parameter definitions" {
            $scriptContent = Get-Content $script:MainScriptPath -Raw
            
            # Check for mandatory parameters
            $scriptContent | Should -Match "\[Parameter\(Mandatory\s*=\s*\`$true\)\][\s\S]*?\`$SourceInstance"
            $scriptContent | Should -Match "\[Parameter\(Mandatory\s*=\s*\`$true\)\][\s\S]*?\`$TargetInstance"
            $scriptContent | Should -Match "\[Parameter\(Mandatory\s*=\s*\`$true\)\][\s\S]*?\`$Databases"
        }
        
        It "Should have proper error handling structure" {
            $scriptContent = Get-Content $script:MainScriptPath -Raw
            
            $scriptContent | Should -Match "try"
            $scriptContent | Should -Match "catch"
            $scriptContent | Should -Match "ErrorActionPreference"
        }
    }
    
    Context "Module Import Validation" {
        It "Should import all modules with proper paths" {
            $scriptContent = Get-Content $script:MainScriptPath -Raw
            
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.Logging\.psm1.*-Force"
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.Connection\.psm1.*-Force"
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.Database\.psm1.*-Force"
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.Encryption\.psm1.*-Force"
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.Migration\.psm1.*-Force"
            $scriptContent | Should -Match "Import-Module.*SQLUpgrade\.PostUpgrade\.psm1.*-Force"
        }
        
        It "Should use relative module paths correctly" {
            $scriptContent = Get-Content $script:MainScriptPath -Raw
            
            $scriptContent | Should -Match "ModulePath.*Join-Path.*PSScriptRoot.*Modules"
            $scriptContent | Should -Match "Join-Path.*ModulePath"
        }
    }
}

Describe "Documentation and Examples Validation" {
    Context "Usage Examples Validation" {
        BeforeAll {
            $script:UsageExamplesPath = Join-Path $PSScriptRoot "..\Usage-Examples.ps1"
            $script:UsageExamplesContent = Get-Content $script:UsageExamplesPath -Raw
        }
        
        It "Should reference the correct main script name" {
            $script:UsageExamplesContent | Should -Match "Start-SQLServerUpgrade\.ps1"
            $script:UsageExamplesContent | Should -Not -Match "SQL-Server-Upgrade-Script\.ps1"
        }
        
        It "Should include modular usage examples" {
            $script:UsageExamplesContent | Should -Match "Import-Module.*Modules"
            $script:UsageExamplesContent | Should -Match "Initialize-UpgradeLogging"
            $script:UsageExamplesContent | Should -Match "Test-InstanceConnectivity"
        }
    }
    
    Context "README Documentation" {
        BeforeAll {
            $script:ReadmePath = Join-Path $PSScriptRoot "..\README.md"
            $script:ReadmeContent = Get-Content $script:ReadmePath -Raw
        }
        
        It "Should document the modular architecture" {
            $script:ReadmeContent | Should -Match "Modular Architecture"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.Logging\.psm1"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.Connection\.psm1"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.Database\.psm1"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.Encryption\.psm1"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.Migration\.psm1"
            $script:ReadmeContent | Should -Match "SQLUpgrade\.PostUpgrade\.psm1"
        }
        
        It "Should reference the correct main script" {
            $script:ReadmeContent | Should -Match "Start-SQLServerUpgrade\.ps1"
        }
    }
}

Describe "Security and Best Practices Validation" {
    Context "Security Best Practices" {
        It "Should not contain hardcoded credentials" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
            $mainScript = Get-Content $script:MainScriptPath -Raw
            
            # Check main script for hardcoded passwords
            $mainScript | Should -Not -Match "password\s*="
            $mainScript | Should -Not -Match "pwd\s*="
            
            # Check all modules for hardcoded passwords
            foreach ($moduleFile in $moduleFiles) {
                $content = Get-Content $moduleFile.FullName -Raw
                $content | Should -Not -Match "password\s*="
                $content | Should -Not -Match "pwd\s*="
            }
        }
        
        It "Should use proper error handling in all modules" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
            
            foreach ($moduleFile in $moduleFiles) {
                $content = Get-Content $moduleFile.FullName -Raw
                $hasErrorHandling = ($content -match "try") -or ($content -match "catch") -or ($content -match "ErrorActionPreference")
                $hasErrorHandling | Should -Be $true
            }
        }
    }
    
    Context "PowerShell Best Practices" {
        It "Should use approved verbs in function names" {
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
            
            foreach ($moduleFile in $moduleFiles) {
                $content = Get-Content $moduleFile.FullName -Raw
                $functionMatches = [regex]::Matches($content, "function\s+(\w+)-")
                
                foreach ($match in $functionMatches) {
                    $verb = $match.Groups[1].Value
                    $approvedVerbs | Should -Contain $verb
                }
            }
        }
        
        It "Should have proper comment-based help in functions" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules"
            $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
            
            foreach ($moduleFile in $moduleFiles) {
                $content = Get-Content $moduleFile.FullName -Raw
                if ($content -match "function\s+") {
                    $content | Should -Match "\.SYNOPSIS"
                    $content | Should -Match "\.DESCRIPTION"
                }
            }
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
