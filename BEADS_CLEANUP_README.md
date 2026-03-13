# Beads Task Removal Tools

This directory contains tools for removing tasks from Beads data sources.

## Scripts

### Remove-BeadsTasks.ps1

The main script for removing tasks from Beads data sources based on flexible filtering criteria.

**Features:**
- Remove tasks from multiple data sources: `issues.jsonl`, `coordination.json`, `beads.db`
- Filter by 17 different fields: status, id, title, spec, rule, path, file, output, related, dependencies, affected, blocks, blocked_by, parent, children, epic, story, task
- Automatic backups before modification
- WhatIf and Confirm support
- Comprehensive statistics and reporting

**Usage:**

```powershell
# Remove all closed tasks from issues.jsonl (default)
.\Remove-BeadsTasks.ps1

# Remove all closed tasks from all sources in-place
.\Remove-BeadsTasks.ps1 -Source All -FilterBy Status -FilterValue closed -InPlace

# Remove specific task by ID
.\Remove-BeadsTasks.ps1 -FilterBy Id -FilterValue "PowerShellScripts-vfz.1"

# Remove all tasks related to a spec
.\Remove-BeadsTasks.ps1 -Source All -FilterBy Spec -FilterValue "refactor-app-installer-scripts"

# Remove tasks by title pattern
.\Remove-BeadsTasks.ps1 -FilterBy Title -FilterValue "*Script Scaffolding*" -InPlace

# Preview changes without making them
.\Remove-BeadsTasks.ps1 -FilterBy Status -FilterValue closed -WhatIf
```

### bd-remove.ps1

A wrapper script that provides a `bd remove` command-like interface.

**Usage:**

```powershell
# Remove all closed tasks from all sources
.\bd-remove.ps1 -Status closed

# Remove specific task by ID
.\bd-remove.ps1 -Id "PowerShellScripts-vfz.1" -InPlace

# Remove all tasks related to a spec
.\bd-remove.ps1 -Spec "refactor-app-installer-scripts" -Source IssuesJsonl

# Remove tasks by title
.\bd-remove.ps1 -Title "*Script Scaffolding*"

# Preview changes
.\bd-remove.ps1 -Status closed -WhatIf
```

### Clean-BeadsClosedIssues.ps1 (Legacy)

The original script for removing closed issues from `issues.jsonl`. This script is now superseded by `Remove-BeadsTasks.ps1` but is kept for backward compatibility.

## Data Sources

### issues.jsonl

The primary JSONL file containing all Beads tasks. Each line is a JSON object representing a task or task update.

**Location:** `.beads/issues.jsonl`

### coordination.json

The coordination manifest that tracks relationships between specs, tasks, rules, and files.

**Location:** `.augment/coordination.json`

### beads.db

The SQLite database used by the Beads CLI for fast queries.

**Location:** `.beads/beads.db`

**Note:** Requires `sqlite3` command to be available in PATH.

## Filter Fields

The following fields can be used with `-FilterBy`:

- **Status** - Task status (e.g., 'closed', 'open', 'in-progress')
- **Id** - Task ID (e.g., 'PowerShellScripts-vfz.1')
- **Title** - Task title (supports wildcards)
- **Spec** - Related OpenSpec specification
- **Rule** - Related rule file
- **Path** - File path
- **File** - File name
- **Output** - Output file
- **Related** - Related task IDs
- **Dependencies** - Task dependencies
- **Affected** - Affected files
- **Blocks** - Tasks this task blocks
- **BlockedBy** - Tasks blocking this task
- **Parent** - Parent task ID
- **Children** - Child task IDs
- **Epic** - Epic ID
- **Story** - Story ID
- **Task** - Task ID

## Safety Features

1. **Automatic Backups** - All in-place modifications create timestamped backups
2. **WhatIf Support** - Preview changes before making them
3. **Confirm Prompts** - Confirmation required for destructive operations
4. **File Size Warnings** - Warns when processing large files (>1MB)
5. **Validation** - Validates file formats before processing

## Examples

### Remove all closed tasks from all sources

```powershell
.\Remove-BeadsTasks.ps1 -Source All -FilterBy Status -FilterValue closed -InPlace -Force
```

### Remove tasks related to a specific spec

```powershell
.\Remove-BeadsTasks.ps1 -FilterBy Spec -FilterValue "refactor-app-installer-scripts" -Source All
```

### Remove tasks by dependency

```powershell
.\Remove-BeadsTasks.ps1 -FilterBy Dependencies -FilterValue "PowerShellScripts-abc" -Source All
```

### Preview removal of closed tasks

```powershell
.\Remove-BeadsTasks.ps1 -FilterBy Status -FilterValue closed -WhatIf
```

## Notes

- Always backup your data before using `-InPlace` or `-Force` flags
- The script creates automatic backups, but manual backups are recommended for critical data
- Use `-WhatIf` to preview changes before making them
- Use `-Verbose` to see detailed processing information

