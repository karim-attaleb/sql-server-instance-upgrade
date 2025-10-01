#Requires -Version 5.1

<#
.SYNOPSIS
    SQL Server Upgrade Logging Module
    
.DESCRIPTION
    Provides centralized logging functionality for SQL Server upgrade operations
    including file logging, console output, and Windows Event Log integration.
#>

# Event Log setup
$script:EventLogSource = "SQL Server Upgrade Script"
$script:EventLogName = "Application"

function Initialize-UpgradeLogging {
    <#
    .SYNOPSIS
        Initializes logging infrastructure for SQL Server upgrade operations
    
    .PARAMETER LogPath
        Path for log files
    
    .OUTPUTS
        Hashtable containing log file paths
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )
    
    # Create log directory
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    $LogFile = Join-Path $LogPath "SQLUpgrade_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $ErrorLogFile = Join-Path $LogPath "SQLUpgrade_Errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    # Event Log setup
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventLogSource)) {
            New-EventLog -LogName $script:EventLogName -Source $script:EventLogSource
        }
    } catch {
        Write-Warning "Could not create Event Log source. Running with limited logging."
    }
    
    return @{
        LogFile = $LogFile
        ErrorLogFile = $ErrorLogFile
    }
}

function Write-UpgradeLog {
    <#
    .SYNOPSIS
        Writes log messages to multiple outputs
    
    .PARAMETER Message
        Log message content
    
    .PARAMETER Level
        Log level (Information, Warning, Error)
    
    .PARAMETER LogFile
        Path to main log file
    
    .PARAMETER ErrorLogFile
        Path to error log file
    
    .PARAMETER WriteToEventLog
        Whether to write to Windows Event Log
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet("Information", "Warning", "Error")]
        [string]$Level = "Information",
        
        [string]$LogFile,
        
        [string]$ErrorLogFile,
        
        [switch]$WriteToEventLog
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "Information" { Write-Host $LogMessage -ForegroundColor Green }
        "Warning" { Write-Warning $LogMessage }
        "Error" { Write-Error $LogMessage }
    }
    
    # Write to file
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $LogMessage
    }
    
    if ($Level -eq "Error" -and $ErrorLogFile) {
        Add-Content -Path $ErrorLogFile -Value $LogMessage
    }
    
    # Write to Event Log
    if ($WriteToEventLog -and [System.Diagnostics.EventLog]::SourceExists($script:EventLogSource)) {
        $EventType = switch ($Level) {
            "Information" { "Information" }
            "Warning" { "Warning" }
            "Error" { "Error" }
        }
        Write-EventLog -LogName $script:EventLogName -Source $script:EventLogSource -EntryType $EventType -EventId 1001 -Message $Message
    }
}

Export-ModuleMember -Function Initialize-UpgradeLogging, Write-UpgradeLog
