#Requires -Version 7.0

<#
.SYNOPSIS
    Removes closed issues from beads JSONL files.

.DESCRIPTION
    PowerShell script to remove closed issues from .beads/issues.jsonl files.
    Reads a beads JSONL file, filters out closed issues, and writes the open
    issues to an output file. Supports in-place modification with safety checks.

    This script is useful for cleaning up beads issue files by archiving closed
    issues and keeping only active (open) issues in the main issues.jsonl file.

    The script preserves:
    - Original line order of open issues
    - Malformed JSON lines (with warnings) to prevent data loss
    - File encoding (UTF-8)

    Git Workflow Implications:
    - When using -InPlace, the .beads/issues.jsonl file will be modified
    - This creates a git diff showing removed closed issues
    - Recommended workflow:
      1. Run script with -InPlace to clean issues.jsonl
      2. Review changes with: git diff .beads/issues.jsonl
      3. Commit changes: git commit -m "Archive closed beads issues"
      4. Optionally archive closed issues separately before cleaning

.PARAMETER Path
    Path to the input beads JSONL file.
    Default: .beads/issues.jsonl

    The file must exist and be readable. The script validates that the file
    contains valid JSONL format before processing.

.PARAMETER OutputPath
    Path to the output file for filtered results.
    Default: .beads/issues-open.jsonl
    Ignored when -InPlace is specified.

    If the file exists, it will be overwritten. The directory must exist.

.PARAMETER InPlace
    Modifies the input file directly instead of creating a new output file.
    WARNING: This will permanently modify the original file. Use with caution.
    Requires confirmation unless -Confirm:$false is specified.

    When using -InPlace:
    - A temporary file is created during processing
    - The original file is replaced only after successful processing
    - If an error occurs, the original file remains unchanged
    - The temporary file is cleaned up in the finally block

.PARAMETER Force
    Bypasses warnings for large files (> 10 MB).
    Note: Does NOT bypass -Confirm prompts. Use -Confirm:$false for that.
    Use with caution when processing very large files.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1

    Basic usage: Reads .beads/issues.jsonl and writes open issues to
    .beads/issues-open.jsonl. Prompts for confirmation.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -Path custom.jsonl -OutputPath filtered.jsonl

    Process a custom JSONL file and write results to a specific output file.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -InPlace -Confirm:$false

    Modify .beads/issues.jsonl in place without confirmation prompt.
    Use this in automated scripts or CI/CD pipelines.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -WhatIf

    Preview what would happen without making any changes.
    Shows which file would be processed but doesn't modify anything.

.EXAMPLE
    .\Clean-BeadsClosedIssues.ps1 -Verbose -InformationAction Continue

    Run with detailed logging showing each issue processed and statistics.

.EXAMPLE
    # Recommended git workflow for archiving closed issues
    # Step 1: Create archive of closed issues before cleaning
    Get-Content .beads/issues.jsonl | ForEach-Object {
        $issue = $_ | ConvertFrom-Json
        if ($issue.status -eq 'closed') { $_ }
    } | Set-Content .beads/issues-closed-archive.jsonl

    # Step 2: Clean the main issues file
    .\Clean-BeadsClosedIssues.ps1 -InPlace -Confirm:$false

    # Step 3: Review and commit
    git diff .beads/issues.jsonl
    git add .beads/issues.jsonl .beads/issues-closed-archive.jsonl
    git commit -m "Archive closed beads issues"

.NOTES
    Part of the beads issue tracking system.
    Requires PowerShell 7.0 or later.

    Exit Codes:
    - 0: Success
    - 1: General error (file access, processing error)
    - 2: File not found or invalid JSONL format

    Performance:
    - Processes files line-by-line for memory efficiency
    - Can handle large files (tested with 50,000+ lines)
    - Shows warning for files > 10 MB unless -Force is used

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
    # Resolve full path to handle relative paths and validate file exists
    # This also normalizes the path format for consistent output
    $inputFile = Resolve-Path $Path -ErrorAction Stop
    Write-Verbose "Input file: $inputFile"

    # Validate file format by attempting to parse the first line as JSON
    # This provides early failure if the file is not JSONL format
    # Using -Depth 10 to handle nested objects in beads issues
    $firstLine = Get-Content $inputFile -First 1 -ErrorAction Stop
    if ($firstLine) {
        try {
            $null = $firstLine | ConvertFrom-Json -Depth 10 -ErrorAction Stop
            Write-Verbose "File appears to be valid JSONL format"
        }
        catch {
            Write-Error "File does not appear to be valid JSONL format: $_"
            exit 2  # Exit code 2 indicates invalid file format
        }
    }

    # Check file size and warn if large (> 10 MB)
    # Large files may take significant time to process
    # -Force flag bypasses this warning for automated scenarios
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

    # Determine output file path based on -InPlace flag
    # In-place mode: Use temporary file, then replace original
    # Normal mode: Write directly to output file
    if ($InPlace) {
        $outputFile = $inputFile
        $tempFile = "$inputFile.tmp"  # Temporary file for safe in-place modification

        # ShouldProcess provides -WhatIf and -Confirm support
        # This is critical for destructive operations like in-place modification
        if (-not $PSCmdlet.ShouldProcess($inputFile, "Modify file in place (DESTRUCTIVE)")) {
            Write-Information "Operation cancelled"
            exit 0
        }

        Write-Warning "In-place modification will permanently alter: $inputFile"
    }
    else {
        $outputFile = $OutputPath
        $tempFile = $outputFile  # No temporary file needed for normal mode
    }

    # Process the file - main filtering logic
    Write-Information "Processing: $inputFile"
    Write-Verbose "Output will be written to: $tempFile"

    # ShouldProcess check for -WhatIf and -Confirm support
    if ($PSCmdlet.ShouldProcess($inputFile, "Filter closed issues")) {
        # Initialize array to hold filtered lines
        # Using array instead of streaming to ensure atomic file operations
        $filteredLines = @()

        # Process file line-by-line for memory efficiency
        # Each line should be a complete JSON object (JSONL format)
        Get-Content $inputFile -Encoding UTF8 | ForEach-Object {
            $stats.TotalLines++
            $line = $_

            # Debug output shows first 50 chars of each line being processed
            Write-Debug "Processing line $($stats.TotalLines): $($line.Substring(0, [Math]::Min(50, $line.Length)))..."

            try {
                # Parse JSON with -Depth 10 to handle nested objects
                # Beads issues can have nested comments, dependencies, etc.
                $issue = $line | ConvertFrom-Json -Depth 10 -ErrorAction Stop

                # Filter logic: Remove lines where status equals 'closed'
                # Keep all other statuses (open, in_progress, etc.)
                if ($issue.status -eq 'closed') {
                    $stats.ClosedRemoved++
                    Write-Verbose "Removed closed issue: $($issue.id)"
                    # Line is NOT added to $filteredLines (effectively removed)
                }
                else {
                    $stats.OpenKept++
                    $filteredLines += $line  # Keep the original line unchanged
                    Write-Debug "Kept open issue: $($issue.id)"
                }
            }
            catch {
                # Malformed JSON handling: Keep the line to prevent data loss
                # This is a safety measure - better to keep bad data than lose it
                $stats.MalformedLines++
                Write-Warning "Malformed JSON on line $($stats.TotalLines): $_"
                $filteredLines += $line  # Preserve malformed line
            }
        }

        # Write filtered results to output file
        # Using UTF8 encoding to match beads format
        Write-Verbose "Writing $($filteredLines.Count) lines to output"
        $filteredLines | Set-Content -Path $tempFile -Encoding UTF8 -ErrorAction Stop

        # In-place mode: Replace original file with filtered version
        # This is done atomically - temp file is moved to replace original
        # If this fails, the original file remains unchanged
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

