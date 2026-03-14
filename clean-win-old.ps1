<#
.SYNOPSIS
    Deletes C:\Windows.old if it exists.

.DESCRIPTION
    Safely removes the C:\Windows.old directory using bottom-up deletion
    (files first, then directories deepest-to-shallowest).  The target path
    is hard-coded and validated so that no other directories are affected.

    The script takes ownership and grants full-control ACLs before deletion
    to handle the protected files that Windows leaves behind.

.NOTES
    Author : myTech.Today
    Version: 1.1.0
    Requires: Administrator privileges
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Hard-coded target -- ONLY this exact path is ever touched
# ---------------------------------------------------------------------------
$folder = 'C:\Windows.old'

# Safety: resolve to a full path and verify it is exactly C:\Windows.old
$resolvedFolder = [System.IO.Path]::GetFullPath($folder)
if ($resolvedFolder -ne 'C:\Windows.old') {
    Write-Host "Safety check failed: resolved path '$resolvedFolder' is not 'C:\Windows.old'." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $folder)) {
    Write-Host "'$folder' does not exist -- nothing to do." -ForegroundColor Yellow
    exit 0
}

# Confirm it is a directory (not a file that happens to have this name)
$item = Get-Item -LiteralPath $folder -Force
if (-not $item.PSIsContainer) {
    Write-Host "'$folder' exists but is not a directory -- aborting." -ForegroundColor Red
    exit 1
}

Write-Host "Deleting '$folder' ..." -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# Take ownership and grant permissions (Windows.old is often ACL-protected)
# ---------------------------------------------------------------------------
Write-Host "  Taking ownership..." -ForegroundColor Gray
& takeown /F $folder /R /A /D Y 2>&1 | Out-Null
& icacls $folder /grant Administrators:F /T /C /Q 2>&1 | Out-Null

# ---------------------------------------------------------------------------
# Bottom-up deletion: files first, then directories deepest-to-shallowest
# ---------------------------------------------------------------------------

# Remove all files
Get-ChildItem -LiteralPath $folder -Recurse -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
        # Guard: skip anything that resolved outside C:\Windows.old (e.g. symlinks)
        if ($_.FullName.StartsWith('C:\Windows.old\', [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }

# Remove directories from deepest to shallowest
Get-ChildItem -LiteralPath $folder -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        if ($_.FullName.StartsWith('C:\Windows.old\', [System.StringComparison]::OrdinalIgnoreCase)) {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not delete: $($_.FullName)"
            }
        }
    }

# Remove the root folder itself
try {
    Remove-Item -LiteralPath $folder -Force -ErrorAction Stop
    Write-Host "Successfully deleted: $folder" -ForegroundColor Green
} catch {
    Write-Host "Could not fully delete '$folder' -- some files may be locked." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
}