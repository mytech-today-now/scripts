#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Beads CLI wrapper for removing tasks.

.DESCRIPTION
    This script provides a 'bd remove' command wrapper that calls Remove-BeadsTasks.ps1
    with appropriate parameters. It's designed to integrate with the bd CLI workflow.

.PARAMETER Status
    Remove tasks by status (e.g., 'closed', 'archived').

.PARAMETER Id
    Remove task by specific ID.

.PARAMETER Title
    Remove tasks by title (supports wildcards).

.PARAMETER Spec
    Remove tasks related to a specific spec.

.PARAMETER Rule
    Remove tasks related to a specific rule.

.PARAMETER Source
    Data source(s) to remove from: IssuesJsonl, CoordinationJson, BeadsDb, All
    Default: All

.PARAMETER InPlace
    Modify files in-place (creates backups).

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\bd-remove.ps1 -Status closed
    
    Removes all closed tasks from all sources.

.EXAMPLE
    .\bd-remove.ps1 -Id "PowerShellScripts-vfz.1" -InPlace
    
    Removes specific task by ID from all sources in-place.

.EXAMPLE
    .\bd-remove.ps1 -Spec "refactor-app-installer-scripts" -Source IssuesJsonl
    
    Removes all tasks related to a spec from issues.jsonl only.

.NOTES
    This is a wrapper for Remove-BeadsTasks.ps1
#>

[CmdletBinding(DefaultParameterSetName = 'Status', SupportsShouldProcess = $true)]
param(
    [Parameter(ParameterSetName = 'Status')]
    [string]$Status = 'closed',

    [Parameter(ParameterSetName = 'Id', Mandatory)]
    [string]$Id,

    [Parameter(ParameterSetName = 'Title', Mandatory)]
    [string]$Title,

    [Parameter(ParameterSetName = 'Spec', Mandatory)]
    [string]$Spec,

    [Parameter(ParameterSetName = 'Rule', Mandatory)]
    [string]$Rule,

    [Parameter(ParameterSetName = 'Dependencies', Mandatory)]
    [string]$Dependencies,

    [Parameter()]
    [ValidateSet('IssuesJsonl', 'CoordinationJson', 'BeadsDb', 'All')]
    [string]$Source = 'All',

    [Parameter()]
    [switch]$InPlace,

    [Parameter()]
    [switch]$Force
)

# Determine script location
$scriptPath = Join-Path $PSScriptRoot "Remove-BeadsTasks.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Remove-BeadsTasks.ps1 not found at: $scriptPath"
    exit 1
}

# Build parameters for Remove-BeadsTasks.ps1
$params = @{
    Source = $Source
}

# Add filter parameters based on parameter set
switch ($PSCmdlet.ParameterSetName) {
    'Status' {
        $params.FilterBy = 'Status'
        $params.FilterValue = $Status
    }
    'Id' {
        $params.FilterBy = 'Id'
        $params.FilterValue = $Id
    }
    'Title' {
        $params.FilterBy = 'Title'
        $params.FilterValue = $Title
    }
    'Spec' {
        $params.FilterBy = 'Spec'
        $params.FilterValue = $Spec
    }
    'Rule' {
        $params.FilterBy = 'Rule'
        $params.FilterValue = $Rule
    }
    'Dependencies' {
        $params.FilterBy = 'Dependencies'
        $params.FilterValue = $Dependencies
    }
}

# Add switches
if ($InPlace) { $params.InPlace = $true }
if ($Force) { $params.Force = $true }
if ($WhatIfPreference) { $params.WhatIf = $true }
if ($ConfirmPreference -ne 'High') { $params.Confirm = $true }

# Call Remove-BeadsTasks.ps1
& $scriptPath @params

