<##
.SYNOPSIS
    Generic logging module for myTech.Today PowerShell scripts.

.DESCRIPTION
    Provides centralized logging functionality for all myTech.Today scripts.
    Features:
    - Centralized logging to %USERPROFILE%\myTech.Today\logs\
    - Monthly log archiving (current: scriptname.md, archived: scriptname.YYYY-MM.md)
    - Cyclical logging with 10MB size limit
    - Markdown table format for structured logging
    - ASCII-only indicators (no emoji)
    - Console output with color coding
    - Windows Event Log integration under 'myTech.Today' root folder
    - Can be imported from GitHub URL

.NOTES
    Name:           logging.ps1
    Author:         myTech.Today
    Version:        2.0.0
    DateCreated:    2025-11-09
    LastModified:   2025-11-20
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
$script:LogPath          = $null
$script:CentralLogPath   = "$env:USERPROFILE\myTech.Today\logs\"
$script:MaxLogSizeMB     = 10
$script:ScriptName       = $null
$script:ScriptVersion    = $null

# Windows Event Log integration (best-effort; failures do not block file logging)
$script:EnableEventLog   = $true
$script:EventLogName     = 'myTech.Today'  # Root log in Applications and Services Logs
$script:EventSource      = $null           # Will be set to script name (source within the log)

function Initialize-MyTechTodayEventLog {
    <#
    .SYNOPSIS
        Initializes Windows Event Log integration for the current script.

    .DESCRIPTION
        Creates (if necessary) the 'myTech.Today' Event Log in Applications and Services Logs
        and registers the script as an event source within that log.

        Event Viewer Structure:
        Applications and Services Logs
          └─ myTech.Today (event log)
              ├─ Bookmarks-Manager (event source)
              ├─ AppInstaller (event source)
              └─ ... (other scripts as sources)

        If creation fails (for example, due to insufficient privileges), file
        logging continues to work and event logging is silently disabled.

    .PARAMETER ScriptName
        The logical name of the script (used as the event source name).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName
    )

    try {
        # Set the event source to the script name
        $script:EventSource = $ScriptName

        # Check if the source already exists
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
            # Create the event source under the 'myTech.Today' log
            # This will automatically create the log if it doesn't exist
            New-EventLog -LogName $script:EventLogName -Source $script:EventSource -ErrorAction Stop

            # Ensure the log has a File path configured in the registry
            # This is required for events to be written to the log
            $logRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$($script:EventLogName)"
            $fileProperty = Get-ItemProperty -Path $logRegPath -Name "File" -ErrorAction SilentlyContinue
            if (-not $fileProperty -or [string]::IsNullOrWhiteSpace($fileProperty.File)) {
                # Set the file path for the log
                $logFileName = $script:EventLogName -replace '\.', ''  # Remove dots for filename
                Set-ItemProperty -Path $logRegPath -Name "File" -Value "%SystemRoot%\System32\Winevt\Logs\$logFileName.evtx" -ErrorAction Stop
                # Restart the Event Log service to apply the changes
                Restart-Service -Name EventLog -Force -ErrorAction Stop
            }

            # Configure the event source to use PowerShell's message file
            # This prevents "The description for Event ID cannot be found" warnings in Event Viewer
            $sourceRegPath = "$logRegPath\$script:EventSource"
            $messageFile = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
            Set-ItemProperty -Path $sourceRegPath -Name "EventMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $sourceRegPath -Name "CategoryMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $sourceRegPath -Name "ParameterMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
        }
        else {
            # Verify the source is registered to the correct log
            $existingLog = [System.Diagnostics.EventLog]::LogNameFromSourceName($script:EventSource, '.')
            if ($existingLog -ne $script:EventLogName) {
                # Source exists but is registered to a different log - disable event logging
                Write-Warning "Event source '$script:EventSource' is already registered to log '$existingLog'. Event logging disabled."
                $script:EnableEventLog = $false
            }
            else {
                # Source exists and is registered to the correct log
                # Update the message files to prevent "description cannot be found" warnings
                $sourceRegPath = "$logRegPath\$script:EventSource"
                $messageFile = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
                Set-ItemProperty -Path $sourceRegPath -Name "EventMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sourceRegPath -Name "CategoryMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sourceRegPath -Name "ParameterMessageFile" -Value $messageFile -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        # If event log registration fails (e.g. non-admin), disable event logging
        $script:EnableEventLog = $false
    }
}

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
        Optional custom log path. If not specified, uses %USERPROFILE%\myTech.Today\logs\

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
        $script:ScriptName    = $ScriptName
        $script:ScriptVersion = $ScriptVersion
        $script:MaxLogSizeMB  = $MaxLogSizeMB

        # Initialize Windows Event Log integration (best-effort)
        Initialize-MyTechTodayEventLog -ScriptName $ScriptName

        # Determine log directory
        if ($LogPath) {
            $script:CentralLogPath = Split-Path $LogPath -Parent
        }

        # Create log directory if it doesn't exist
        if (-not (Test-Path $script:CentralLogPath)) {
            New-Item -ItemType Directory -Path $script:CentralLogPath -Force | Out-Null
        }

        # Calculate log file name (format: scriptname.md, lowercase)
        $logFileName = "$($ScriptName.ToLower()).md"
        $script:LogPath = Join-Path $script:CentralLogPath $logFileName

        # Check if log file exists and needs monthly archiving
        if (Test-Path $script:LogPath) {
            $logFile = Get-Item $script:LogPath
            $logLastWriteMonth = $logFile.LastWriteTime.ToString('yyyy-MM')
            $currentMonth = Get-Date -Format 'yyyy-MM'

            # If the log file is from a previous month, archive it
            if ($logLastWriteMonth -ne $currentMonth) {
                $archiveName = "$($ScriptName.ToLower()).$logLastWriteMonth.md"
                $archivePath = Join-Path $script:CentralLogPath $archiveName

                # Only archive if the archive doesn't already exist
                if (-not (Test-Path $archivePath)) {
                    Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue
                    Write-Host "[INFO] Previous month's log archived: $archivePath" -ForegroundColor Cyan
                }
                else {
                    # Archive already exists, just delete the old log
                    Remove-Item -Path $script:LogPath -Force -ErrorAction SilentlyContinue
                }
            }
            else {
                # Same month - check if log file needs size-based rotation
                $sizeMB = $logFile.Length / 1MB

                if ($sizeMB -gt $script:MaxLogSizeMB) {
                    # Archive the log with timestamp
                    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                    $archiveName = "$($ScriptName.ToLower())_archived_$timestamp.md"
                    $archivePath = Join-Path $script:CentralLogPath $archiveName

                    Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue

                    Write-Host "[INFO] Log file size limit exceeded. Archived to: $archivePath" -ForegroundColor Cyan
                }
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

    # Also write to Windows Event Log (best-effort)
    if ($script:EnableEventLog -and $script:EventLogName -and $script:EventSource) {
        try {
            $entryType = switch ($Level) {
                'SUCCESS' { [System.Diagnostics.EventLogEntryType]::Information }
                'INFO'    { [System.Diagnostics.EventLogEntryType]::Information }
                'WARNING' { [System.Diagnostics.EventLogEntryType]::Warning }
                'ERROR'   { [System.Diagnostics.EventLogEntryType]::Error }
                default   { [System.Diagnostics.EventLogEntryType]::Information }
            }

            $eventId = switch ($Level) {
                'SUCCESS' { 1001 }
                'INFO'    { 1000 }
                'WARNING' { 2000 }
                'ERROR'   { 3000 }
                default   { 1000 }
            }

            # Create detailed event message with full context
            $eventMessage = @"
Script: $($script:ScriptName)
Version: $($script:ScriptVersion)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Timestamp: $timestamp
Level: $($config.Indicator)

Message:
$Message

Log File: $($script:LogPath)
"@

            # Write event to the myTech.Today log
            Write-EventLog -LogName $script:EventLogName -Source $script:EventSource -EntryType $entryType -EventId $eventId -Message $eventMessage -ErrorAction SilentlyContinue
        }
        catch {
            # If event log write fails, disable further event logging to avoid repeated errors
            $script:EnableEventLog = $false
        }
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
        Internal function that checks the current log file size and month,
        archiving it if it exceeds the maximum size limit or if the month has changed.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:LogPath -or -not (Test-Path $script:LogPath)) {
        return
    }

    try {
        $logFile = Get-Item $script:LogPath
        $logLastWriteMonth = $logFile.LastWriteTime.ToString('yyyy-MM')
        $currentMonth = Get-Date -Format 'yyyy-MM'

        # Check if month has changed - archive to previous month's file
        if ($logLastWriteMonth -ne $currentMonth) {
            $archiveName = "$($script:ScriptName.ToLower()).$logLastWriteMonth.md"
            $archivePath = Join-Path $script:CentralLogPath $archiveName

            # Only archive if the archive doesn't already exist
            if (-not (Test-Path $archivePath)) {
                Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue
                Write-Host "[INFO] Month changed. Previous month's log archived: $archivePath" -ForegroundColor Cyan
            }
            else {
                # Archive already exists, just delete the old log
                Remove-Item -Path $script:LogPath -Force -ErrorAction SilentlyContinue
            }

            # Create new log file with header
            $logHeader = @"
# $($script:ScriptName) Log

**Script Version:** $($script:ScriptVersion)
**Log Started:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Computer:** $env:COMPUTERNAME
**User:** $env:USERNAME
**Note:** Previous month's log archived to $archiveName

---

## Activity Log

| Timestamp | Level | Message |
|-----------|-------|---------|
"@
            Set-Content -Path $script:LogPath -Value $logHeader -Force -ErrorAction SilentlyContinue
        }
        else {
            # Same month - check size-based rotation
            $sizeMB = $logFile.Length / 1MB

            if ($sizeMB -gt $script:MaxLogSizeMB) {
                # Archive the log with timestamp
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $archiveName = "$($script:ScriptName.ToLower())_archived_$timestamp.md"
                $archivePath = Join-Path $script:CentralLogPath $archiveName

                Move-Item -Path $script:LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue

                # Create new log file with header
                $logHeader = @"
# $($script:ScriptName) Log

**Script Version:** $($script:ScriptVersion)
**Log Started:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Computer:** $env:COMPUTERNAME
**User:** $env:USERNAME
**Note:** Previous log archived to $archiveName (size limit exceeded)

---

## Activity Log

| Timestamp | Level | Message |
|-----------|-------|---------|
"@
                Set-Content -Path $script:LogPath -Value $logHeader -Force -ErrorAction SilentlyContinue

                Write-Host "[INFO] Log file size limit exceeded. Archived to: $archivePath" -ForegroundColor Cyan
            }
        }
    }
    catch {
        # Silently continue if rotation fails
    }
}

# Note: When dot-sourcing this script, all functions are automatically available.
# Export-ModuleMember is not needed for .ps1 scripts (only for .psm1 modules).
