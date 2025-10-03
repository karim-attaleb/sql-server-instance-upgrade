# SQL Server Upgrade Solution - Test Suite

This directory contains comprehensive Pester tests for the SQL Server upgrade solution with modular architecture.

## Test Files

### SQLUpgrade.Tests.ps1
**Unit Tests** - Tests individual modules and functions:
- Module import and function export validation
- Parameter validation for all functions
- Logging functionality tests
- Function structure and behavior tests
- Main script structure validation
- Module architecture validation

### SQLUpgrade.Integration.Tests.ps1
**Integration Tests** - Tests module interactions and workflows:
- End-to-end workflow validation
- Module interaction testing
- Main script syntax validation
- Documentation consistency checks
- Security and best practices validation

## Running the Tests

### Prerequisites
```powershell
# Install Pester if not already installed
Install-Module Pester -Force -SkipPublisherCheck

# Ensure you're in the repository root directory
Set-Location "path\to\sql-server-instance-upgrade"
```

### Run All Tests
```powershell
# Run all tests in the Tests directory
Invoke-Pester -Path ".\Tests\" -Output Detailed

# Run with code coverage
Invoke-Pester -Path ".\Tests\" -CodeCoverage ".\Modules\*.psm1" -Output Detailed
```

### Run Specific Test Files
```powershell
# Run only unit tests
Invoke-Pester -Path ".\Tests\SQLUpgrade.Tests.ps1" -Output Detailed

# Run only integration tests
Invoke-Pester -Path ".\Tests\SQLUpgrade.Integration.Tests.ps1" -Output Detailed
```

### Run Specific Test Categories
```powershell
# Run only module import tests
Invoke-Pester -Path ".\Tests\SQLUpgrade.Tests.ps1" -Tag "ModuleImport" -Output Detailed

# Run only security validation tests
Invoke-Pester -Path ".\Tests\SQLUpgrade.Integration.Tests.ps1" -Tag "Security" -Output Detailed
```

## Test Coverage

The test suite covers:

### ✅ Module Functionality
- All 6 PowerShell modules (Logging, Connection, Database, Encryption, Migration, PostUpgrade)
- Function parameter validation
- Export-ModuleMember statements
- Error handling and logging

### ✅ Main Script Validation
- Zero function definitions in main script
- Proper module imports
- Parameter validation
- PowerShell syntax validation
- SupportsShouldProcess implementation

### ✅ Architecture Validation
- Modular design compliance
- Function distribution across modules
- File structure validation
- Documentation consistency

### ✅ Security & Best Practices
- No hardcoded credentials
- Proper error handling
- Approved PowerShell verbs
- Comment-based help documentation

### ✅ Integration Testing
- Module interaction workflows
- End-to-end process validation
- Documentation accuracy
- Usage example validation

## Test Results Interpretation

### Passing Tests ✅
- All modules import successfully
- Functions are properly exported
- Main script contains no function definitions
- Architecture follows modular design principles

### Common Issues to Watch For ❌
- Missing Export-ModuleMember statements
- Function definitions in main script
- Incorrect module import paths
- Missing parameter validation
- Hardcoded credentials or connection strings

## Continuous Integration

These tests are designed to be run in CI/CD pipelines to ensure:
- Code quality and consistency
- Modular architecture compliance
- Security best practices
- Documentation accuracy

## Contributing

When adding new functionality:
1. Add corresponding unit tests to `SQLUpgrade.Tests.ps1`
2. Add integration tests to `SQLUpgrade.Integration.Tests.ps1`
3. Ensure all tests pass before committing
4. Update this README if new test categories are added

## Test Environment

Tests are designed to run without requiring actual SQL Server instances:
- Uses mock objects and parameter validation
- Tests file system operations in temp directories
- Validates syntax and structure without execution
- Focuses on architecture and design compliance
