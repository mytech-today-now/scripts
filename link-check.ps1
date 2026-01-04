<#
.SYNOPSIS
    Validate HTTP/HTTPS links in one or more input scripts.

.DESCRIPTION
    Scans each specified file for absolute HTTP/HTTPS URLs and issues a web
    request to verify the HTTP status code. Results are written to:

    - Central script log via the shared myTech.Today logging module.
    - URL-specific log at "%USERPROFILE%\myTech.Today\logs\link-check.md" with
      monthly archiving to "link-check.YYYY-MM.md" (for the month the log was written).

.PARAMETER Path
    One or more file paths or glob patterns for scripts to validate.

.PARAMETER TimeoutSeconds
    Per-request timeout in seconds. Default is 15.

.EXAMPLE
    # Validate all links in a single script
    .\scripts\link-check.ps1 -Path .\bookmarks\bookmarks.ps1

.EXAMPLE
    # Validate links in multiple scripts using wildcards
    .\scripts\link-check.ps1 -Path .\bookmarks\*.ps1
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true,
               Position = 0)]
    [Alias('FullName')]
    [string[]]$Path,

    [int]$TimeoutSeconds = 15
)

# PowerShell 7+ Version Check - myTech.Today standard
$script:PS7ContinueOnPS51 = $true  # Allow running on PS 5.1 with warning
$script:PS7Silent = $false
$script:_RepoRoot = $PSScriptRoot
while ($script:_RepoRoot -and -not (Test-Path (Join-Path $script:_RepoRoot 'scripts\Require-PowerShell7.ps1'))) {
    $script:_RepoRoot = Split-Path $script:_RepoRoot -Parent
}
if ($script:_RepoRoot -and (Test-Path (Join-Path $script:_RepoRoot 'scripts\Require-PowerShell7.ps1'))) {
    . (Join-Path $script:_RepoRoot 'scripts\Require-PowerShell7.ps1')
}

$ErrorActionPreference = 'Stop'

# Import generic logging module (GitHub first, local fallback)
$loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/logging.ps1'
$script:LoggingModuleLoaded = $false

try {
    Write-Host 'Loading generic logging module...' -ForegroundColor Cyan
    Invoke-Expression (Invoke-WebRequest -Uri $loggingUrl -UseBasicParsing).Content
    $script:LoggingModuleLoaded = $true
    Write-Host '[OK] Generic logging module loaded successfully' -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to load generic logging module: $_" -ForegroundColor Red
    Write-Host '[INFO] Falling back to local logging implementation' -ForegroundColor Yellow

    $localLoggingPath = Join-Path $PSScriptRoot 'logging.ps1'
    if (Test-Path $localLoggingPath) {
        try {
            . $localLoggingPath
            $script:LoggingModuleLoaded = $true
            Write-Host '[OK] Loaded logging module from local path' -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to load local logging module: $_" -ForegroundColor Red
        }
    }
}

if (-not $script:LoggingModuleLoaded) {
    Write-Warning 'Logging module not available. Continuing without centralized logging.'
}

if ($script:LoggingModuleLoaded) {
    $null = Initialize-Log -ScriptName 'Link-Check' -ScriptVersion '1.0.0'
    Write-Log '=== Link-Check started ===' -Level INFO
}

function Initialize-LinkCheckLog {
    [CmdletBinding()]
    param()

    $root = Join-Path $env:USERPROFILE 'myTech.Today'
    $logDir = Join-Path $root 'logs'

    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $currentLogPath = Join-Path $logDir 'link-check.md'
    $now = Get-Date
    $currentMonthStamp = $now.ToString('yyyy-MM')

    if (Test-Path $currentLogPath) {
        $fileInfo = Get-Item $currentLogPath
        $fileMonthStamp = $fileInfo.LastWriteTime.ToString('yyyy-MM')

        if ($fileMonthStamp -ne $currentMonthStamp) {
            $archiveName = "link-check.$fileMonthStamp.md"
            $archivePath = Join-Path $logDir $archiveName

            if (Test-Path $archivePath) {
                $timestamp = $fileInfo.LastWriteTime.ToString('yyyyMMdd_HHmmss')
                $archiveName = "link-check.$fileMonthStamp.$timestamp.md"
                $archivePath = Join-Path $logDir $archiveName
            }

            Move-Item -Path $currentLogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue

            if ($script:LoggingModuleLoaded) {
                Write-Log "Archived previous link-check log to '$archivePath'." -Level INFO
            }
        }
    }

    if (-not (Test-Path $currentLogPath)) {
        $header = @"
# link-check URL Validation Log

**Log Created:** $($now.ToString('yyyy-MM-dd HH:mm:ss'))
**Computer:** $env:COMPUTERNAME
**User:** $env:USERNAME

---

| Timestamp | File | Line | Status | URL |
|-----------|------|------|--------|-----|
"@
        Set-Content -Path $currentLogPath -Value $header -Force
    }

    return $currentLogPath
}

function Test-UrlStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [int]$TimeoutSeconds = 15
    )

    $statusCode = $null
    $statusDescription = $null
    $errorMessage = $null

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSeconds -MaximumRedirection 5
        $statusCode = [int]$response.StatusCode
        $statusDescription = $response.StatusDescription
    }
    catch {
        $resp = $_.Exception.Response
        if ($null -ne $resp) {
            try {
                $statusCode = [int]$resp.StatusCode
                $statusDescription = $resp.StatusDescription
            }
            catch {
                $errorMessage = $_.Exception.Message
            }
        }
        else {
            $errorMessage = $_.Exception.Message
        }
    }

    [PSCustomObject]@{
        Url               = $Url
        StatusCode        = $statusCode
        StatusDescription = $statusDescription
        ErrorMessage      = $errorMessage
    }
}

# Main processing
$linkCheckLogPath = Initialize-LinkCheckLog

if ($script:LoggingModuleLoaded) {
    Write-Log "Using URL log path '$linkCheckLogPath'." -Level INFO
}

# Compile list of files
$allFiles = @()

foreach ($inputPath in $Path) {
    if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }

    try {
        $resolved = Get-ChildItem -Path $inputPath -File -ErrorAction Stop
        if (-not $resolved) {
            throw "No files matched path '$inputPath'."
        }
        $allFiles += $resolved
    }
    catch {
        if ($script:LoggingModuleLoaded) {
            Write-Log "Failed to resolve path '$inputPath': $($_.Exception.Message)" -Level WARNING
        }
    }
}

if (-not $allFiles -or $allFiles.Count -eq 0) {
    if ($script:LoggingModuleLoaded) {
        Write-Log 'No input files to process. Exiting.' -Level WARNING
    }
    return
}

$urlRegex = [regex]'https?://[^\s''"]+'

foreach ($file in $allFiles | Sort-Object FullName -Unique) {
    if ($script:LoggingModuleLoaded) {
        Write-Log "Scanning file '$($file.FullName)' for URLs..." -Level INFO
    }

    try {
        $lines = Get-Content -Path $file.FullName -ErrorAction Stop
    }
    catch {
        if ($script:LoggingModuleLoaded) {
            Write-Log "Failed to read file '$($file.FullName)': $($_.Exception.Message)" -Level ERROR
        }
        continue
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNumber = $i + 1
        $line = $lines[$i]

        $urlMatches = $urlRegex.Matches($line)
        if (-not $urlMatches -or $urlMatches.Count -eq 0) { continue }

        foreach ($match in $urlMatches) {
            $url = $match.Value

            $result = Test-UrlStatus -Url $url -TimeoutSeconds $TimeoutSeconds

            $statusText = if ($result.StatusCode) {
                "$($result.StatusCode) $($result.StatusDescription)"
            }
            else {
                "ERROR: $($result.ErrorMessage)"
            }

            $logLevel = if ($result.StatusCode -eq 200) { 'SUCCESS' } else { 'ERROR' }

            if ($script:LoggingModuleLoaded) {
                Write-Log "[$($file.FullName):$lineNumber] $statusText - $url" -Level $logLevel
            }

            $rowTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $tableRow = "| $rowTimestamp | $($file.FullName) | $lineNumber | $statusText | $url |"
            Add-Content -Path $linkCheckLogPath -Value $tableRow -ErrorAction SilentlyContinue
        }
    }
}

if ($script:LoggingModuleLoaded) {
    Write-Log '=== Link-Check completed ===' -Level SUCCESS
}
