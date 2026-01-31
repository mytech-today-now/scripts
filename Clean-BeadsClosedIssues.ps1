#Requires -Version 7.0

<#
.SYNOPSIS
    Removes closed issues from beads JSONL files.

.DESCRIPTION
    PowerShell script to remove closed issues from .beads/issues.jsonl files.
    Reads a beads JSONL file, filters out closed issues, and writes the open
    issues to an output file. Supports in-place modification with safety checks.

.PARAMETER Path
    Path to the input beads JSONL file.
    Default: .beads/issues.jsonl

.PARAMETER OutputPath
    Path to the output file for filtered results.
    Default: .beads/issues-open.jsonl
    Ignored when -InPlace is specified.

.PARAMETER InPlace
    Modifies the input file directly instead of creating a new output file.
    WARNING: This will permanently modify the original file. Use with caution.
    Requires confirmation unless -Force is also specified.

.PARAMETER Force
    Bypasses warnings for large files (> 10 MB) and confirmation prompts.
    Use with extreme caution, especially with -InPlace.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1
    Reads .beads/issues.jsonl and writes open issues to .beads/issues-open.jsonl

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -Path custom.jsonl -OutputPath filtered.jsonl
    Reads custom.jsonl and writes open issues to filtered.jsonl

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -InPlace -Confirm
    Modifies .beads/issues.jsonl in place with confirmation prompt

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -WhatIf
    Shows what would happen without making any changes

.NOTES
    Part of the beads issue tracking system.
    Requires PowerShell 7.0 or later.
    
.LINK
    https://github.com/mytech-today-now/PowerShellScripts
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "File not found: $_"
        }
        $true
    })]
    [string]$Path = ".beads/issues.jsonl",

    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".beads/issues-open.jsonl",

    [Parameter()]
    [switch]$InPlace,

    [Parameter()]
    [switch]$Force
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize statistics
$stats = @{
    TotalLines = 0
    ClosedRemoved = 0
    OpenKept = 0
    MalformedLines = 0
    StartTime = Get-Date
}

try {
    # Resolve full path
    $inputFile = Resolve-Path $Path -ErrorAction Stop
    Write-Verbose "Input file: $inputFile"

    # Validate file format (basic check for JSONL)
    $firstLine = Get-Content $inputFile -First 1 -ErrorAction Stop
    if ($firstLine) {
        try {
            $null = $firstLine | ConvertFrom-Json -Depth 10 -ErrorAction Stop
            Write-Verbose "File appears to be valid JSONL format"
        }
        catch {
            Write-Error "File does not appear to be valid JSONL format: $_"
            exit 2
        }
    }

    # Check file size and warn if large
    $fileSize = (Get-Item $inputFile).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    if ($fileSizeMB -gt 10 -and -not $Force) {
        Write-Warning "File size is $fileSizeMB MB. Processing may take time. Use -Force to bypass this warning."
        $continue = Read-Host "Continue? (Y/N)"
        if ($continue -ne 'Y') {
            Write-Information "Operation cancelled by user"
            exit 0
        }
    }

    # Determine output file
    if ($InPlace) {
        $outputFile = $inputFile
        $tempFile = "$inputFile.tmp"

        if (-not $Force -and -not $PSCmdlet.ShouldProcess($inputFile, "Modify file in place (DESTRUCTIVE)")) {
            Write-Information "Operation cancelled"
            exit 0
        }

        Write-Warning "In-place modification will permanently alter: $inputFile"
    }
    else {
        $outputFile = $OutputPath
        $tempFile = $outputFile
    }

    # Process the file
    Write-Information "Processing: $inputFile"
    Write-Verbose "Output will be written to: $tempFile"

    if ($PSCmdlet.ShouldProcess($inputFile, "Filter closed issues")) {
        # Read and filter the file
        $filteredLines = @()

        Get-Content $inputFile -Encoding UTF8 | ForEach-Object {
            $stats.TotalLines++
            $line = $_

            Write-Debug "Processing line $($stats.TotalLines): $($line.Substring(0, [Math]::Min(50, $line.Length)))..."

            try {
                # Parse JSON
                $issue = $line | ConvertFrom-Json -Depth 10 -ErrorAction Stop

                # Check status
                if ($issue.status -eq 'closed') {
                    $stats.ClosedRemoved++
                    Write-Verbose "Removed closed issue: $($issue.id)"
                }
                else {
                    $stats.OpenKept++
                    $filteredLines += $line
                    Write-Debug "Kept open issue: $($issue.id)"
                }
            }
            catch {
                $stats.MalformedLines++
                Write-Warning "Malformed JSON on line $($stats.TotalLines): $_"
                # Keep malformed lines to avoid data loss
                $filteredLines += $line
            }
        }

        # Write output
        Write-Verbose "Writing $($filteredLines.Count) lines to output"
        $filteredLines | Set-Content -Path $tempFile -Encoding UTF8 -ErrorAction Stop

        # If in-place mode, replace original file
        if ($InPlace) {
            Write-Verbose "Replacing original file with filtered version"
            Move-Item -Path $tempFile -Destination $inputFile -Force -ErrorAction Stop
        }
    }

    # Calculate elapsed time
    $stats.EndTime = Get-Date
    $stats.ElapsedSeconds = ($stats.EndTime - $stats.StartTime).TotalSeconds

    # Output statistics
    Write-Information "`n=== Processing Complete ===" -InformationAction Continue
    Write-Information "Total lines processed: $($stats.TotalLines)" -InformationAction Continue
    Write-Information "Closed issues removed: $($stats.ClosedRemoved)" -InformationAction Continue
    Write-Information "Open issues kept: $($stats.OpenKept)" -InformationAction Continue
    Write-Information "Malformed lines: $($stats.MalformedLines)" -InformationAction Continue
    Write-Information "Elapsed time: $([math]::Round($stats.ElapsedSeconds, 2)) seconds" -InformationAction Continue
    Write-Information "Output file: $outputFile" -InformationAction Continue

    exit 0
}
catch {
    Write-Error "Error processing file: $_"
    Write-Debug $_.ScriptStackTrace

    # Determine appropriate exit code
    if ($_.Exception.Message -match "File not found|not valid JSONL") {
        exit 2
    }
    else {
        exit 1
    }
}
finally {
    # Cleanup temporary files if they exist and we're not in WhatIf mode
    if ($InPlace -and (Test-Path "$inputFile.tmp" -ErrorAction SilentlyContinue) -and -not $WhatIfPreference) {
        Write-Verbose "Cleaning up temporary file"
        Remove-Item "$inputFile.tmp" -Force -ErrorAction SilentlyContinue
    }
}

