<##
.SYNOPSIS
    Generic logging module for myTech.Today PowerShell scripts.

.DESCRIPTION
    Provides centralized logging functionality for all myTech.Today scripts.
    Features:
    - Centralized logging to %USERPROFILE%\myTech.Today\
    - Monthly log rotation (one file per month)
    - Cyclical logging with 10MB size limit
    - Markdown table format for structured logging
    - ASCII-only indicators (no emoji)
    - Console output with color coding
    - Can be imported from GitHub URL

.NOTES
    Name:           logging.ps1
    Author:         myTech.Today
    Version:        1.0.0
    DateCreated:    2025-11-09
    LastModified:   2025-11-09
    Requires:       PowerShell 5.1 or later

    Usage from GitHub:
    $loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/logging.ps1'
    Invoke-Expression (Invoke-WebRequest -Uri $loggingUrl -UseBasicParsing).Content

    Usage from local path:
    . "$PSScriptRoot\..\scripts\logging.ps1"

.EXAMPLE
    # Initialize logging
    Initialize-Log -ScriptName "MyScript" -ScriptVersion "1.0.0"

    # Write log entries
    Write-Log "Script started" -Level INFO
    Write-Log "Operation completed successfully" -Level SUCCESS
    Write-Log "Warning: Configuration file not found" -Level WARNING
    Write-Log "Error: Failed to connect to server" -Level ERROR

    # Get current log path
    $logPath = Get-LogPath
    Write-Host "Logging to: $logPath"

.LINK
    https://github.com/mytech-today-now/PowerShellScripts
#>

#Requires -Version 5.1

# Script-scoped variables
$script:LogPath = $null
$script:CentralLogPath = "$env:USERPROFILE\myTech.Today\"
$script:MaxLogSizeMB = 10
$script:ScriptName = $null
$script:ScriptVersion = $null

function Initialize-Log {
    <#
    .SYNOPSIS
        Initializes logging for a script.

    .DESCRIPTION
        Creates the log directory if needed, sets up monthly log rotation,
        and creates a log file with markdown header.

    .PARAMETER ScriptName
        Name of the script (used in log file name).

    .PARAMETER ScriptVersion
        Version of the script (included in log header).

    .PARAMETER LogPath
        Optional custom log path. If not specified, uses %USERPROFILE%\myTech.Today\

    .PARAMETER MaxLogSizeMB
        Maximum log file size in MB before rotation. Default is 10MB.

    .OUTPUTS
        System.String
        Returns the path to the log file.

    .EXAMPLE
        Initialize-Log -ScriptName "MyScript" -ScriptVersion "1.0.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [string]$ScriptVersion = "1.0.0",

        [Parameter(Mandatory = $false)]
        [string]$LogPath = $null,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxLogSizeMB = 10
    )

    try {
        # Set script-scoped variables
        $script:ScriptName = $ScriptName
        $script:ScriptVersion = $ScriptVersion
        $script:MaxLogSizeMB = $MaxLogSizeMB

        # Determine log directory
        if ($LogPath) {
            $script:CentralLogPath = Split-Path $LogPath -Parent
        }

        # Create log directory if it doesn't exist
        if (-not (Test-Path $script:CentralLogPath)) {
            New-Item -ItemType Directory -Path $script:CentralLogPath -Force | Out-Null
        }

        # Calculate log file name (monthly format: ScriptName-yyyy-MM.md)
        $monthStamp = Get-Date -Format 'yyyy-MM'
        $logFileName = "$ScriptName-$monthStamp.md"
        $script:LogPath = Join-Path $script:CentralLogPath $logFileName

        # Check if log file exists and needs rotation
        if (Test-Path $script:LogPath) {
            $logFile = Get-Item $script:LogPath
            $sizeMB = $logFile.Length / 1MB

            if ($sizeMB -gt $script:MaxLogSizeMB) {
                # Archive the log
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $archiveName = "$ScriptName-$monthStamp`_archived_$timestamp.md"
                $archivePath = Join-Path $script:CentralLogPath $archiveName

                Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue

                Write-Host "[INFO] Log file archived: $archivePath" -ForegroundColor Cyan
            }
        }

        # Create log file with markdown header if it doesn't exist
        if (-not (Test-Path $script:LogPath)) {
            $logHeader = @"
# $ScriptName Log

**Script Version:** $ScriptVersion
**Log Started:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Computer:** $env:COMPUTERNAME
**User:** $env:USERNAME

---

## Activity Log

| Timestamp | Level | Message |
|-----------|-------|---------|
"@
            Set-Content -Path $script:LogPath -Value $logHeader -Force -ErrorAction Stop
        }

        Write-Host "[INFO] Logging initialized: $script:LogPath" -ForegroundColor Cyan
        return $script:LogPath
    }
    catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
        return $null
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry to console and file.

    .DESCRIPTION
        Writes formatted log messages to console with color coding and to file
        in markdown table format. Uses ASCII indicators only (no emoji).

    .PARAMETER Message
        The message to log.

    .PARAMETER Level
        The log level: INFO, SUCCESS, WARNING, or ERROR. Default is INFO.

    .EXAMPLE
        Write-Log "Script started" -Level INFO
        Write-Log "Operation completed" -Level SUCCESS
        Write-Log "Warning message" -Level WARNING
        Write-Log "Error occurred" -Level ERROR
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    # Check if Initialize-Log was called
    if (-not $script:LogPath) {
        Write-Warning "Logging not initialized. Call Initialize-Log first."
        return
    }

    # Check log rotation before writing
    Test-LogRotation

    # Format timestamp
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Map level to ASCII indicator and color
    $levelConfig = @{
        'INFO'    = @{ Indicator = '[INFO]';  Color = 'Cyan' }
        'SUCCESS' = @{ Indicator = '[OK]';    Color = 'Green' }
        'WARNING' = @{ Indicator = '[WARN]';  Color = 'Yellow' }
        'ERROR'   = @{ Indicator = '[ERROR]'; Color = 'Red' }
    }

    $config = $levelConfig[$Level]

    # Write to console with color
    Write-Host "[$timestamp] $($config.Indicator) $Message" -ForegroundColor $config.Color

    # Write to file in markdown table format
    try {
        $logEntry = "| $timestamp | $($config.Indicator) | $Message |"
        Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently continue if file logging fails
    }
}

function Get-LogPath {
    <#
    .SYNOPSIS
        Returns the current log file path.

    .DESCRIPTION
        Returns the path to the current log file, or $null if logging is not initialized.

    .OUTPUTS
        System.String
        The path to the current log file.

    .EXAMPLE
        $logPath = Get-LogPath
        Write-Host "Logging to: $logPath"
    #>
    [CmdletBinding()]
    param()

    return $script:LogPath
}

function Test-LogRotation {
    <#
    .SYNOPSIS
        Checks if log rotation is needed and performs it if necessary.

    .DESCRIPTION
        Internal function that checks the current log file size and archives it
        if it exceeds the maximum size limit.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:LogPath -or -not (Test-Path $script:LogPath)) {
        return
    }

    try {
        $logFile = Get-Item $script:LogPath
        $sizeMB = $logFile.Length / 1MB

        if ($sizeMB -gt $script:MaxLogSizeMB) {
            # Archive the log
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $monthStamp = Get-Date -Format 'yyyy-MM'
            $archiveName = "$($script:ScriptName)-$monthStamp`_archived_$timestamp.md"
            $archivePath = Join-Path $script:CentralLogPath $archiveName

            Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue

            # Create new log file with header
            $logHeader = @"
# $($script:ScriptName) Log

**Script Version:** $($script:ScriptVersion)
**Log Started:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Computer:** $env:COMPUTERNAME
**User:** $env:USERNAME
**Note:** Previous log archived to $archiveName

---

## Activity Log

| Timestamp | Level | Message |
|-----------|-------|---------|
"@
            Set-Content -Path $script:LogPath -Value $logHeader -Force -ErrorAction SilentlyContinue

            Write-Host "[INFO] Log file rotated. Archived to: $archivePath" -ForegroundColor Cyan
        }
    }
    catch {
        # Silently continue if rotation fails
    }
}

# Note: When dot-sourcing this script, all functions are automatically available.
# Export-ModuleMember is not needed for .ps1 scripts (only for .psm1 modules).
