# SQL Server 2022 Upgrade Script

This PowerShell script provides a comprehensive solution for upgrading SQL Server instances to SQL Server 2022 using a side-by-side installation approach with dbatools.

## Features

✅ **All Requirements Met:**

1. **dbatools Integration**: Uses dbatools for all SQL database operations (no T-SQL)
2. **Selective Object Transfer**: Choose specific object types to transfer
3. **Collation Checking**: Automatically verifies collation compatibility
4. **Encryption & TDE Support**: Handles encrypted objects and TDE databases
5. **Flexible Execution**: Direct application or output file generation
6. **WhatIf Support**: Preview changes without execution
7. **Safe Operations**: Never drops anything, only adds objects
8. **Database Selection**: Choose specific databases or all user databases
9. **Idempotent**: Safe to run multiple times

## Additional Features

- **Comprehensive Logging**: File-based and Windows Event Log integration
- **Post-Upgrade Tasks**: Integrity checks, compatibility level updates, statistics, index rebuilds
- **Error Handling**: Robust error handling with detailed logging
- **Connectivity Testing**: Validates connections before processing

## Prerequisites

- PowerShell 5.1 or later
- dbatools module installed (`Install-Module dbatools`)
- Appropriate SQL Server permissions on both source and target instances
- Administrative privileges for Windows Event Log writing

## Usage Examples

### Basic Usage with WhatIf
```powershell
.\SQL-Server-Upgrade-Script.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("Database1", "Database2") -WhatIf
```

### Complete Upgrade with All Databases
```powershell
.\SQL-Server-Upgrade-Script.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -IncludeEncryption
```

### Generate Script File for Later Execution
```powershell
.\SQL-Server-Upgrade-Script.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases "All" -OutputFile "C:\Scripts\UpgradeScript.sql"
```

### Selective Object Types
```powershell
.\SQL-Server-Upgrade-Script.ps1 -SourceInstance "SQL2019\INSTANCE1" -TargetInstance "SQL2022\INSTANCE1" -Databases @("MyDB") -ObjectTypes @("Tables", "Views", "StoredProcedures")
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SourceInstance` | String | Yes | Source SQL Server instance name |
| `TargetInstance` | String | Yes | Target SQL Server 2022 instance name |
| `Databases` | String/Array | Yes | Database names to upgrade or "All" for all user databases |
| `ObjectTypes` | String Array | No | Object types to transfer (default: all supported types) |
| `IncludeEncryption` | Switch | No | Include encrypted objects and TDE databases |
| `OutputFile` | String | No | Path to output file for later execution |
| `WhatIf` | Switch | No | Show what would be done without making changes |
| `LogPath` | String | No | Path for log files (default: C:\Logs\SQLUpgrade) |

## Supported Object Types

- Tables
- Views
- StoredProcedures
- Functions
- Triggers
- UserDefinedDataTypes
- UserDefinedTableTypes
- Schemas
- Users
- Roles
- Permissions

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
- **System Database Protection**: Excludes system databases from operations
- **Connectivity Validation**: Tests connections before processing
- **Collation Verification**: Warns about collation mismatches

## Error Handling

- Comprehensive try-catch blocks
- Detailed error logging
- Graceful failure handling
- Stack trace logging for debugging

## Installation

1. Install dbatools module:
   ```powershell
   Install-Module dbatools -Force
   ```

2. Download the script to your desired location

3. Run with appropriate parameters

## Support

For issues or questions:
- Check the log files in the specified log directory
- Review Windows Event Log entries
- Ensure all prerequisites are met
- Verify SQL Server permissions

## License

This script is provided as-is for educational and operational purposes.
