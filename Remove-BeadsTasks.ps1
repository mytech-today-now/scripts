#Requires -Version 7.0

<#
.SYNOPSIS
    Removes tasks from Beads data sources based on flexible filtering criteria.

.DESCRIPTION
    This script removes tasks from Beads data sources (issues.jsonl, coordination.json, 
    and beads.db) based on flexible filtering criteria. It supports filtering by status 
    (default: closed) or by any field value including id, title, spec, rule, path, file, 
    output, related, dependencies, affected, blocks, blocked_by, parent, children, epic, 
    story, and task.

    The script supports multiple data sources and can operate on one or all sources 
    simultaneously. It includes safety features like file size warnings, confirmation 
    prompts, and automatic backups.

.PARAMETER Source
    Data source(s) to remove tasks from.
    Valid values: 'IssuesJsonl', 'CoordinationJson', 'BeadsDb', 'All'
    Default: 'IssuesJsonl'

.PARAMETER FilterBy
    Field to filter by when removing tasks.
    Valid values: 'Status', 'Id', 'Title', 'Spec', 'Rule', 'Path', 'File', 'Output', 
                  'Related', 'Dependencies', 'Affected', 'Blocks', 'BlockedBy', 
                  'Parent', 'Children', 'Epic', 'Story', 'Task'
    Default: 'Status'

.PARAMETER FilterValue
    Value to match when filtering tasks. Supports exact match and wildcard patterns.
    Default: 'closed' (when FilterBy is 'Status')

.PARAMETER Path
    Path to the Beads issues.jsonl file to process.
    Default: .beads/issues.jsonl

.PARAMETER CoordinationPath
    Path to the coordination.json file to process.
    Default: .augment/coordination.json

.PARAMETER DatabasePath
    Path to the Beads SQLite database file.
    Default: .beads/beads.db

.PARAMETER OutputPath
    Path where the filtered output should be written.
    Default: .beads/issues-open.jsonl
    Ignored if -InPlace is specified.

.PARAMETER InPlace
    Modify the input file(s) directly instead of creating new files.
    WARNING: This will permanently remove matching tasks from the original file(s).
    Backups are created automatically before modification.

.PARAMETER Force
    Skip confirmation prompts for large files (>1MB) or database operations.
    Use with caution.

.EXAMPLE
    .\Remove-BeadsTasks.ps1
    
    Removes all closed tasks from .beads/issues.jsonl and creates .beads/issues-open.jsonl.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -Source All -FilterBy Status -FilterValue closed -InPlace
    
    Removes all closed tasks from all data sources (issues.jsonl, coordination.json, beads.db) in-place.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -FilterBy Id -FilterValue "PowerShellScripts-vfz.1"
    
    Removes the specific task with ID "PowerShellScripts-vfz.1" from issues.jsonl.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -Source All -FilterBy Spec -FilterValue "refactor-app-installer-scripts"
    
    Removes all tasks related to the "refactor-app-installer-scripts" spec from all sources.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -FilterBy Title -FilterValue "*Script Scaffolding*" -InPlace
    
    Removes all tasks with titles matching "*Script Scaffolding*" from issues.jsonl in-place.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -Source CoordinationJson -FilterBy Status -FilterValue "archived"
    
    Removes all archived tasks from coordination.json only.

.EXAMPLE
    .\Remove-BeadsTasks.ps1 -FilterBy Dependencies -FilterValue "PowerShellScripts-abc" -Source All
    
    Removes all tasks that have "PowerShellScripts-abc" in their dependencies from all sources.

.NOTES
    Author: AI Assistant
    Version: 2.0
    Requires: PowerShell 7.0+
    
    This script is designed for use with Steve Yegge's Beads issue tracking system.
    See: https://github.com/steveyegge/beads
    
    IMPORTANT: Always backup your data before using -InPlace or -Force flags.
    The script creates automatic backups, but manual backups are recommended for critical data.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateSet('IssuesJsonl', 'CoordinationJson', 'BeadsDb', 'All')]
    [string]$Source = 'IssuesJsonl',

    [Parameter()]
    [ValidateSet('Status', 'Id', 'Title', 'Spec', 'Rule', 'Path', 'File', 'Output', 
                 'Related', 'Dependencies', 'Affected', 'Blocks', 'BlockedBy', 
                 'Parent', 'Children', 'Epic', 'Story', 'Task')]
    [string]$FilterBy = 'Status',

    [Parameter()]
    [string]$FilterValue = 'closed',

    [Parameter()]
    [string]$Path = ".beads/issues.jsonl",

    [Parameter()]
    [string]$CoordinationPath = ".augment/coordination.json",

    [Parameter()]
    [string]$DatabasePath = ".beads/beads.db",

    [Parameter()]
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
    TotalProcessed = 0
    Removed = 0
    Kept = 0
    MalformedLines = 0
    StartTime = Get-Date
    Sources = @{}
}

#region Helper Functions

function Test-TaskMatch {
    <#
    .SYNOPSIS
        Tests if a task matches the filter criteria.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Task,

        [Parameter(Mandatory)]
        [string]$FilterBy,

        [Parameter(Mandatory)]
        [string]$FilterValue
    )

    # Convert FilterBy to lowercase property name
    $propertyName = switch ($FilterBy) {
        'Id' { 'id' }
        'Title' { 'title' }
        'Status' { 'status' }
        'Spec' { 'spec' }
        'Rule' { 'rule' }
        'Path' { 'path' }
        'File' { 'file' }
        'Output' { 'output' }
        'Related' { 'related' }
        'Dependencies' { 'dependencies' }
        'Affected' { 'affected' }
        'Blocks' { 'blocks' }
        'BlockedBy' { 'blocked_by' }
        'Parent' { 'parent' }
        'Children' { 'children' }
        'Epic' { 'epic' }
        'Story' { 'story' }
        'Task' { 'task' }
        default { $FilterBy.ToLower() }
    }

    # Check if property exists
    if (-not $Task.PSObject.Properties[$propertyName]) {
        return $false
    }

    $propertyValue = $Task.$propertyName

    # Handle array properties (dependencies, blocks, etc.)
    if ($propertyValue -is [Array]) {
        foreach ($item in $propertyValue) {
            if ($item -like $FilterValue) {
                return $true
            }
        }
        return $false
    }

    # Handle string properties with wildcard support
    return $propertyValue -like $FilterValue
}

function New-Backup {
    <#
    .SYNOPSIS
        Creates a backup of a file before modification.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = "$FilePath.backup_$timestamp"

    Copy-Item -Path $FilePath -Destination $backupPath -Force
    Write-Verbose "Created backup: $backupPath"

    return $backupPath
}

function Remove-FromIssuesJsonl {
    <#
    .SYNOPSIS
        Removes tasks from issues.jsonl file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$FilterBy,

        [Parameter(Mandatory)]
        [string]$FilterValue,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [bool]$InPlace,

        [Parameter()]
        [bool]$Force
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "Issues file not found: $FilePath"
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    Write-Verbose "Processing issues.jsonl: $FilePath"

    # Check file size
    $fileSize = (Get-Item $FilePath).Length
    if ($fileSize -gt 1MB -and -not $Force) {
        $sizeMB = [math]::Round($fileSize / 1MB, 2)
        Write-Warning "File size is $sizeMB MB. Consider using -Force to skip this warning."
        if (-not $PSCmdlet.ShouldContinue("Process large file ($sizeMB MB)?", "Large File Warning")) {
            throw "Operation cancelled by user"
        }
    }

    # Create backup if in-place
    if ($InPlace) {
        $backup = New-Backup -FilePath $FilePath
        Write-Host "Backup created: $backup" -ForegroundColor Green
    }

    # Read and process file
    $filteredLines = @()
    $removed = 0
    $kept = 0
    $malformed = 0

    # Build task map (latest state for each ID)
    $taskMap = @{}

    Get-Content $FilePath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            return
        }

        try {
            $task = $line | ConvertFrom-Json -Depth 10

            if ($task.id) {
                # Merge with existing task state
                if ($taskMap.ContainsKey($task.id)) {
                    $existing = $taskMap[$task.id]
                    foreach ($prop in $task.PSObject.Properties) {
                        $existing.($prop.Name) = $prop.Value
                    }
                } else {
                    $taskMap[$task.id] = $task
                }
            }
        } catch {
            Write-Warning "Malformed JSON line: $line"
            $malformed++
        }
    }

    # Filter tasks
    foreach ($taskId in $taskMap.Keys) {
        $task = $taskMap[$taskId]

        if (Test-TaskMatch -Task $task -FilterBy $FilterBy -FilterValue $FilterValue) {
            $removed++
            Write-Verbose "Removing task: $taskId ($($task.title))"
        } else {
            $kept++
            $filteredLines += ($task | ConvertTo-Json -Depth 10 -Compress)
        }
    }

    # Write output
    $outputFile = if ($InPlace) { $FilePath } else { $OutputPath }

    if ($PSCmdlet.ShouldProcess($outputFile, "Write filtered tasks")) {
        $filteredLines | Set-Content -Path $outputFile -Encoding UTF8 -Force
        Write-Host "Wrote $kept tasks to: $outputFile" -ForegroundColor Green
    }

    return @{
        Removed = $removed
        Kept = $kept
        Malformed = $malformed
    }
}

function Remove-FromCoordinationJson {
    <#
    .SYNOPSIS
        Removes tasks from coordination.json file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$FilterBy,

        [Parameter(Mandatory)]
        [string]$FilterValue,

        [Parameter()]
        [bool]$InPlace,

        [Parameter()]
        [bool]$Force
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "Coordination file not found: $FilePath"
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    Write-Verbose "Processing coordination.json: $FilePath"

    # Create backup if in-place
    if ($InPlace) {
        $backup = New-Backup -FilePath $FilePath
        Write-Host "Backup created: $backup" -ForegroundColor Green
    }

    # Read coordination manifest
    try {
        $manifest = Get-Content $FilePath -Raw | ConvertFrom-Json -Depth 20
    } catch {
        Write-Error "Failed to parse coordination.json: $_"
        return @{ Removed = 0; Kept = 0; Malformed = 1 }
    }

    if (-not $manifest.tasks) {
        Write-Warning "No tasks found in coordination.json"
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    $removed = 0
    $kept = 0
    $tasksToRemove = @()

    # Find tasks to remove
    foreach ($taskId in $manifest.tasks.PSObject.Properties.Name) {
        $task = $manifest.tasks.$taskId

        # Create a task object for matching
        $taskObj = [PSCustomObject]@{
            id = $taskId
            title = if ($task.PSObject.Properties['title']) { $task.title } else { $null }
            status = if ($task.PSObject.Properties['status']) { $task.status } else { $null }
            spec = if ($task.relatedSpecs -and $task.relatedSpecs.Count -gt 0) { $task.relatedSpecs[0] } else { $null }
            dependencies = if ($task.PSObject.Properties['dependencies']) { $task.dependencies } else { $null }
            output = if ($task.PSObject.Properties['outputFiles']) { $task.outputFiles } else { $null }
        }

        if (Test-TaskMatch -Task $taskObj -FilterBy $FilterBy -FilterValue $FilterValue) {
            $tasksToRemove += $taskId
            $removed++
            Write-Verbose "Removing task from coordination: $taskId ($($task.title))"
        } else {
            $kept++
        }
    }

    # Remove tasks
    foreach ($taskId in $tasksToRemove) {
        $manifest.tasks.PSObject.Properties.Remove($taskId)
    }

    # Update lastUpdated timestamp
    $manifest.lastUpdated = (Get-Date).ToUniversalTime().ToString('o')

    # Write output
    if ($PSCmdlet.ShouldProcess($FilePath, "Write filtered coordination manifest")) {
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -Path $FilePath -Encoding UTF8 -Force
        Write-Host "Removed $removed tasks from coordination.json" -ForegroundColor Green
    }

    return @{
        Removed = $removed
        Kept = $kept
        Malformed = 0
    }
}

function Remove-FromBeadsDb {
    <#
    .SYNOPSIS
        Removes tasks from beads.db SQLite database.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [string]$FilterBy,

        [Parameter(Mandatory)]
        [string]$FilterValue,

        [Parameter()]
        [bool]$Force
    )

    if (-not (Test-Path $DatabasePath)) {
        Write-Warning "Database file not found: $DatabasePath"
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    Write-Verbose "Processing beads.db: $DatabasePath"

    # Create backup
    $backup = New-Backup -FilePath $DatabasePath
    Write-Host "Backup created: $backup" -ForegroundColor Green

    # Check if sqlite3 is available
    $sqliteCmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqliteCmd) {
        Write-Warning "sqlite3 command not found. Skipping database cleanup."
        Write-Warning "Install SQLite to enable database cleanup: https://www.sqlite.org/download.html"
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    # Build SQL query based on filter
    $whereClause = switch ($FilterBy) {
        'Id' { "id LIKE '$FilterValue'" }
        'Title' { "title LIKE '$FilterValue'" }
        'Status' { "status LIKE '$FilterValue'" }
        'Spec' { "spec LIKE '$FilterValue'" }
        default { "status = 'closed'" }
    }

    # Count tasks to remove
    $countQuery = "SELECT COUNT(*) FROM issues WHERE $whereClause;"
    $countResult = & sqlite3 $DatabasePath $countQuery 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to query database: $countResult"
        return @{ Removed = 0; Kept = 0; Malformed = 1 }
    }

    $removed = [int]$countResult

    if ($removed -eq 0) {
        Write-Host "No tasks found matching filter in database" -ForegroundColor Yellow
        return @{ Removed = 0; Kept = 0; Malformed = 0 }
    }

    # Delete tasks
    if ($PSCmdlet.ShouldProcess($DatabasePath, "Delete $removed tasks from database")) {
        $deleteQuery = "DELETE FROM issues WHERE $whereClause;"
        $deleteResult = & sqlite3 $DatabasePath $deleteQuery 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to delete from database: $deleteResult"
            return @{ Removed = 0; Kept = 0; Malformed = 1 }
        }

        # Vacuum database to reclaim space
        & sqlite3 $DatabasePath "VACUUM;" 2>&1 | Out-Null

        Write-Host "Removed $removed tasks from database" -ForegroundColor Green
    }

    return @{
        Removed = $removed
        Kept = 0
        Malformed = 0
    }
}

#endregion

#region Main Execution

try {
    Write-Host "`n=== Beads Task Removal Tool ===" -ForegroundColor Cyan
    Write-Host "Filter: $FilterBy = '$FilterValue'" -ForegroundColor Cyan
    Write-Host "Source: $Source" -ForegroundColor Cyan
    Write-Host ""

    # Determine which sources to process
    $sourcesToProcess = switch ($Source) {
        'All' { @('IssuesJsonl', 'CoordinationJson', 'BeadsDb') }
        default { @($Source) }
    }

    # Process each source
    foreach ($sourceType in $sourcesToProcess) {
        Write-Host "Processing $sourceType..." -ForegroundColor Yellow

        $result = switch ($sourceType) {
            'IssuesJsonl' {
                Remove-FromIssuesJsonl `
                    -FilePath $Path `
                    -FilterBy $FilterBy `
                    -FilterValue $FilterValue `
                    -OutputPath $OutputPath `
                    -InPlace $InPlace.IsPresent `
                    -Force $Force.IsPresent
            }

            'CoordinationJson' {
                Remove-FromCoordinationJson `
                    -FilePath $CoordinationPath `
                    -FilterBy $FilterBy `
                    -FilterValue $FilterValue `
                    -InPlace $true `
                    -Force $Force.IsPresent
            }

            'BeadsDb' {
                Remove-FromBeadsDb `
                    -DatabasePath $DatabasePath `
                    -FilterBy $FilterBy `
                    -FilterValue $FilterValue `
                    -Force $Force.IsPresent
            }
        }

        # Update statistics (only if result is valid)
        if ($result) {
            $stats.Sources[$sourceType] = $result
            $stats.TotalProcessed += ($result.Removed + $result.Kept)
            $stats.Removed += $result.Removed
            $stats.Kept += $result.Kept
            $stats.MalformedLines += $result.Malformed
        }

        Write-Host ""
    }

    # Display summary
    $duration = (Get-Date) - $stats.StartTime

    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total Processed: $($stats.TotalProcessed)" -ForegroundColor White
    Write-Host "Removed: $($stats.Removed)" -ForegroundColor Red
    Write-Host "Kept: $($stats.Kept)" -ForegroundColor Green

    if ($stats.MalformedLines -gt 0) {
        Write-Host "Malformed: $($stats.MalformedLines)" -ForegroundColor Yellow
    }

    Write-Host "Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    Write-Host ""

    # Per-source breakdown
    if ($sourcesToProcess -is [Array] -and $sourcesToProcess.Count -gt 1) {
        Write-Host "=== Per-Source Breakdown ===" -ForegroundColor Cyan
        foreach ($sourceType in $sourcesToProcess) {
            if ($stats.Sources.ContainsKey($sourceType)) {
                $result = $stats.Sources[$sourceType]
                Write-Host "$sourceType : Removed=$($result.Removed), Kept=$($result.Kept)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    Write-Host "Operation completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "An error occurred: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}

#endregion

