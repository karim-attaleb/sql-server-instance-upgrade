# SQL Server Upgrade Solution - Module Documentation

This document provides detailed information about each module in the SQL Server upgrade solution.

## Module Overview

The solution is organized into 6 functional modules, each handling a specific aspect of the upgrade process:

### 1. SQLUpgrade.Logging.psm1
**Purpose**: Centralized logging functionality

**Functions**:
- `Initialize-UpgradeLogging`: Sets up log files and Windows Event Log
- `Write-UpgradeLog`: Writes messages to console, files, and Event Log

**Features**:
- Multiple log levels (Information, Warning, Error)
- File-based logging with timestamps
- Windows Event Log integration
- Error log separation

### 2. SQLUpgrade.Connection.psm1
**Purpose**: Connection management and testing

**Functions**:
- `Test-InstanceConnectivity`: Tests and establishes SQL Server connections
- `Test-CollationCompatibility`: Verifies collation compatibility between instances

**Features**:
- Robust connection objects using Connect-DbaInstance
- Connection timeout handling
- Collation mismatch detection and warnings

### 3. SQLUpgrade.Database.psm1
**Purpose**: Database enumeration and filtering

**Functions**:
- `Get-UserDatabases`: Retrieves user databases based on filter criteria

**Features**:
- Excludes system databases (master, model, msdb, tempdb)
- Supports "All" filter for all user databases
- Supports specific database name arrays

### 4. SQLUpgrade.Encryption.psm1
**Purpose**: Encryption and TDE support

**Functions**:
- `Test-EncryptionSupport`: Detects TDE and encrypted objects in databases

**Features**:
- TDE encryption state detection
- Encrypted object counting
- Comprehensive encryption information reporting

### 5. SQLUpgrade.Migration.psm1
**Purpose**: Complete database migration

**Functions**:
- `Copy-CompleteDatabase`: Migrates entire databases as complete units

**Features**:
- Complete database copy using Copy-DbaDatabase
- Backup/restore method for data integrity
- Encryption handling during migration
- Idempotent operations (checks for existing databases)
- WhatIf mode support

### 6. SQLUpgrade.PostUpgrade.psm1
**Purpose**: Post-upgrade maintenance tasks

**Functions**:
- `Invoke-PostUpgradeTasks`: Executes maintenance tasks after migration

**Features**:
- Database integrity checks (DBCC CHECKDB)
- Compatibility level updates to SQL Server 2022
- Statistics updates
- Index rebuilds

## Module Dependencies

All modules require:
- PowerShell 5.1 or later
- dbatools module

Module dependency chain:
1. **SQLUpgrade.Logging** - No dependencies (base module)
2. **SQLUpgrade.Connection** - Depends on Logging
3. **SQLUpgrade.Database** - Depends on Logging
4. **SQLUpgrade.Encryption** - Depends on Logging
5. **SQLUpgrade.Migration** - Depends on Logging and Encryption
6. **SQLUpgrade.PostUpgrade** - Depends on Logging

## Usage Pattern

The main script `Start-SQLServerUpgrade.ps1` follows this pattern:

1. Import all required modules
2. Initialize logging (SQLUpgrade.Logging)
3. Test connectivity (SQLUpgrade.Connection)
4. Check collation compatibility (SQLUpgrade.Connection)
5. Get databases to process (SQLUpgrade.Database)
6. For each database:
   - Test encryption if needed (SQLUpgrade.Encryption)
   - Migrate complete database (SQLUpgrade.Migration)
7. Execute post-upgrade tasks (SQLUpgrade.PostUpgrade)

## Error Handling

Each module implements consistent error handling:
- Try-catch blocks around all operations
- Detailed error logging with stack traces
- Graceful degradation for non-critical errors
- Windows Event Log integration for critical errors

## Extensibility

The modular design allows for easy extension:
- Add new modules for additional functionality
- Extend existing modules with new functions
- Modify individual modules without affecting others
- Follow the same patterns for consistency

## Testing

Each module can be tested independently:
- Import individual modules for unit testing
- Mock dependencies for isolated testing
- Use WhatIf mode for safe testing
- Validate function exports and parameters

## Example: Using Individual Modules

```powershell
# Import specific modules
Import-Module .\Modules\SQLUpgrade.Logging.psm1
Import-Module .\Modules\SQLUpgrade.Connection.psm1

# Initialize logging
$logInfo = Initialize-UpgradeLogging -LogPath "C:\Logs\CustomUpgrade"

# Test connectivity
$sourceConn = Test-InstanceConnectivity -Instance "SQL2019\PROD" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
$targetConn = Test-InstanceConnectivity -Instance "SQL2022\PROD" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile

# Check collation compatibility
$collationOK = Test-CollationCompatibility -SourceConnection $sourceConn -TargetConnection $targetConn -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile

Write-Host "Collation compatible: $collationOK"
```

## Module Function Reference

### SQLUpgrade.Logging Functions

#### Initialize-UpgradeLogging
```powershell
Initialize-UpgradeLogging -LogPath "C:\Logs\SQLUpgrade"
```
Returns hashtable with LogFile and ErrorLogFile paths.

#### Write-UpgradeLog
```powershell
Write-UpgradeLog -Message "Operation completed" -Level "Information" -LogFile $LogFile -ErrorLogFile $ErrorLogFile -WriteToEventLog
```

### SQLUpgrade.Connection Functions

#### Test-InstanceConnectivity
```powershell
$connection = Test-InstanceConnectivity -Instance "SQL2019\PROD" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```
Returns connection object or $null if failed.

#### Test-CollationCompatibility
```powershell
$isCompatible = Test-CollationCompatibility -SourceConnection $sourceConn -TargetConnection $targetConn -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```
Returns boolean indicating compatibility.

### SQLUpgrade.Database Functions

#### Get-UserDatabases
```powershell
$databases = Get-UserDatabases -Connection $sourceConn -DatabaseFilter "All" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
$databases = Get-UserDatabases -Connection $sourceConn -DatabaseFilter @("DB1", "DB2") -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```
Returns array of database objects.

### SQLUpgrade.Encryption Functions

#### Test-EncryptionSupport
```powershell
$encInfo = Test-EncryptionSupport -Connection $sourceConn -DatabaseName "MyDB" -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```
Returns hashtable with HasTDE, EncryptedObjectCount, and TDEStatus.

### SQLUpgrade.Migration Functions

#### Copy-CompleteDatabase
```powershell
Copy-CompleteDatabase -SourceConnection $sourceConn -TargetConnection $targetConn -DatabaseName "MyDB" -IncludeEncryption $true -WhatIfMode $false -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```

### SQLUpgrade.PostUpgrade Functions

#### Invoke-PostUpgradeTasks
```powershell
Invoke-PostUpgradeTasks -TargetConnection $targetConn -DatabaseNames @("DB1", "DB2") -WhatIfMode $false -LogFile $LogFile -ErrorLogFile $ErrorLogFile
```
