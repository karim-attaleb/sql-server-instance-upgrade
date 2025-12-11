# SQL Server 2022 Upgrade Solution - Modular Architecture

A comprehensive PowerShell solution for upgrading SQL Server instances to SQL Server 2022 using a side-by-side installation approach with dbatools. Built with a modular architecture similar to dbatools for maximum maintainability and reusability.

## Features

✅ **All Requirements Met:**

1. **dbatools Integration**: Uses dbatools for all SQL database operations (no T-SQL)
2. **Modular Design**: Organized into separate functional modules like dbatools
3. **Robust Connection Management**: Uses Connect-DbaInstance for persistent, reliable connections
4. **Complete Database Migration**: Migrates entire databases as complete units
5. **Collation Checking**: Automatically verifies collation compatibility
6. **Encryption & TDE Support**: Handles encrypted objects and TDE databases
7. **Direct Execution**: Immediate application of changes
8. **WhatIf Support**: Preview changes without execution
9. **Safe Operations**: Never drops anything, only adds objects
10. **Enhanced Database Filtering**: Excludes system and utility databases by default with optional inclusion
11. **Flexible Server Object Exclusion**: Comprehensive Exclude parameter for fine-grained control
12. **Database Selection**: Choose specific databases or all user databases
13. **Idempotent**: Safe to run multiple times

## Modular Architecture

The solution is organized into the following modules:

- **SQLUpgrade.Logging.psm1**: Centralized logging functionality with file and Windows Event Log support
- **SQLUpgrade.Connection.psm1**: Connection management and collation compatibility testing
- **SQLUpgrade.Database.psm1**: Database enumeration and filtering
- **SQLUpgrade.Encryption.psm1**: Encryption and TDE detection and handling
- **SQLUpgrade.Migration.psm1**: Complete database migration logic
- **SQLUpgrade.PostUpgrade.psm1**: Post-upgrade maintenance tasks

## Additional Features

- **Modular Design**: Each functional area is separated into its own module for better maintainability
- **Robust Connection Objects**: Establishes persistent connections using Connect-DbaInstance for better reliability
- **Comprehensive Logging**: File-based and Windows Event Log integration
- **Post-Upgrade Tasks**: Integrity checks, compatibility level updates, statistics, index rebuilds
- **Error Handling**: Robust error handling with detailed logging
- **Connectivity Testing**: Validates connections before processing and maintains them throughout execution

## Prerequisites

- PowerShell 5.1 or later
- dbatools module installed (`Install-Module dbatools`)
- Appropriate SQL Server permissions on both source and target instances
- Administrative privileges for Windows Event Log writing

## Usage Examples

### Complete Instance Migration (Default Behavior)

**Full Migration - All databases and all server objects (dbatools-style):**
```powershell
# By default, migrates EVERYTHING for a complete instance upgrade:
# - All user databases (excludes system: master, model, msdb, tempdb)
# - All server objects: logins, jobs, linked servers, credentials, alerts, operators, etc.
# - Excludes utility databases (ReportServer, SSISDB, distribution) for safety
# No -Databases parameter needed - defaults to 'All'
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\PROD" -TargetInstance "SQL2022\PROD" -WhatIf
```

**Server Objects Only - No database migration:**
```powershell
# Migrate only server objects (logins, jobs, linked servers, etc.) without touching databases
# Use -Exclude 'Databases' to skip database migration entirely
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\PROD" -TargetInstance "SQL2022\PROD" -Exclude 'Databases'
```

**Specific Databases Only:**
```powershell
# Migrate specific databases plus all server objects
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\PROD" -TargetInstance "SQL2022\PROD" -Databases @("Database1", "Database2")
```

**Include Utility Databases - For servers with SSRS/SSIS/Replication:**
```powershell
# Include ReportServer, SSISDB, distribution databases when migrating servers with:
# - SQL Server Reporting Services (SSRS) - includes ReportServer databases
# - SQL Server Integration Services (SSIS) - includes SSISDB database  
# - SQL Server Replication - includes distribution database
# - Data Quality Services (DQS) - includes DQS databases
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\PROD" -TargetInstance "SQL2022\PROD" -IncludeSupportDbs
```

**Exclude Specific Components - Fine-grained control:**
```powershell
# Exclude specific components when you need granular control:
# - Exclude 'Logins' when you want to review/manage security separately
# - Exclude 'AgentServer' when you want to prevent jobs from running immediately
# - Exclude 'LinkedServers' when connection strings need updating for new environment
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\PROD" -TargetInstance "SQL2022\PROD" -Exclude 'Logins','AgentServer','LinkedServers'
```

### Basic Usage with WhatIf
```powershell
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2") -WhatIf
```

### Complete Upgrade with Encryption Support
```powershell
.\Start-SQLServerUpgrade.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -IncludeEncryption
```

### Using Individual Modules
```powershell
# Import specific modules for custom workflows
Import-Module .\Modules\SQLUpgrade.Logging.psm1
Import-Module .\Modules\SQLUpgrade.Connection.psm1

# Initialize logging
$logInfo = Initialize-UpgradeLogging -LogPath "C:\Logs\CustomUpgrade"

# Test connectivity
$connection = Test-InstanceConnectivity -Instance "SQL2019\INSTANCE1" -LogFile $logInfo.LogFile -ErrorLogFile $logInfo.ErrorLogFile
```


## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SourceInstance` | String | Yes | Source SQL Server instance name |
| `TargetInstance` | String | Yes | Target SQL Server 2022 instance name |
| `Databases` | String/Array | No | Database names to upgrade or "All". Defaults to "All" if not specified. Use `-Exclude 'Databases'` to skip database migration entirely. |
| `IncludeEncryption` | Switch | No | Include encrypted objects and TDE databases |
| `WhatIf` | Switch | No | Show what would be done without making changes |
| `LogPath` | String | No | Path for log files (default: C:\Logs\SQLUpgrade) |
| `IncludeSupportDbs` | Switch | No | Include utility databases (ReportServer, SSISDB, distribution, etc.) |
| `Exclude` | String[] | No | Components to exclude from migration. By default, ALL components are migrated. Valid values: 'Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'SystemTriggers', 'BackupDevices', etc. |

## Database Migration Approach

The script performs complete database migration using:

- **Full Database Copy**: Uses Copy-DbaDatabase with backup/restore method
- **Complete Structure**: All database objects migrated together as a unit
- **Data Integrity**: Maintains referential integrity and dependencies
- **Encryption Support**: Handles TDE and encrypted objects during migration
- **Idempotent Operations**: Safe to run multiple times without duplication

## Logging

The script provides comprehensive logging:

- **File Logs**: Detailed logs in the specified log directory
- **Windows Event Log**: Important events logged to Application log
- **Console Output**: Real-time progress information
- **Error Logs**: Separate error log file for troubleshooting

## Post-Upgrade Tasks

Automatically performs:

1. **Database Integrity Check**: Runs DBCC CHECKDB
2. **Compatibility Level Update**: Updates to SQL Server 2022 level (160)
3. **Statistics Update**: Refreshes all database statistics
4. **Index Rebuild**: Rebuilds fragmented indexes

## Safety Features

- **No Destructive Operations**: Never drops or deletes existing objects
- **Idempotent Design**: Safe to run multiple times
- **Enhanced Database Protection**: Excludes system and utility databases from operations by default
- **Connectivity Validation**: Tests connections before processing
- **Collation Verification**: Warns about collation mismatches

## Error Handling

- Comprehensive try-catch blocks
- Detailed error logging
- Graceful failure handling
- Stack trace logging for debugging

## Installation

1. **Install dbatools module**:
   ```powershell
   Install-Module dbatools -Force
   ```

2. **Download the solution** to your preferred location, ensuring the Modules folder structure is preserved

3. **Ensure you have appropriate permissions**:
   - SQL Server sysadmin rights on both source and target instances
   - Windows administrative privileges for Event Log access
   - Network connectivity between instances

## File Structure

```
SQL-Server-Upgrade-Solution/
├── Start-SQLServerUpgrade.ps1          # Main orchestrator script
├── Modules/                             # PowerShell modules
│   ├── SQLUpgrade.Logging.psm1         # Logging functionality
│   ├── SQLUpgrade.Connection.psm1      # Connection management
│   ├── SQLUpgrade.Database.psm1        # Database operations
│   ├── SQLUpgrade.Encryption.psm1      # Encryption handling
│   ├── SQLUpgrade.Migration.psm1       # Database migration
│   └── SQLUpgrade.PostUpgrade.psm1     # Post-upgrade tasks
├── Tests/                               # Pester test suite
│   └── SQLUpgrade.Tests.ps1            # Comprehensive tests
├── README.md                            # This documentation
├── README-Modules.md                    # Detailed module documentation
└── Usage-Examples.ps1                   # Usage examples
```

4. **Run with appropriate parameters**

## Support

For issues or questions:
- Check the log files in the specified log directory
- Review Windows Event Log entries
- Ensure all prerequisites are met
- Verify SQL Server permissions

## License

This script is provided as-is for educational and operational purposes.
