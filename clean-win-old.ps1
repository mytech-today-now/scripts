<#
.SYNOPSIS
    Deletes C:\Windows.old if it exists.

.DESCRIPTION
    Safely removes the C:\Windows.old directory using bottom-up deletion
    (files first, then directories deepest-to-shallowest).  The target path
    is hard-coded and validated so that no other directories are affected.

    The script takes ownership and grants full-control ACLs before deletion
    to handle the protected files that Windows leaves behind.

    Progress is displayed with a sticky header and a live-updating status
    line so you can see what is happening without walls of text.

.NOTES
    Author : myTech.Today
    Version: 1.3.0
    Requires: Administrator privileges

    Changelog v1.3.0:
    - Fixed progress bar exceeding 100% during ownership phase
    - Phase 1 now uses indeterminate counter (no misleading percentage)
    - Re-scans after ownership to get accurate file/dir counts for Phases 2-3
    - Fixed in-place line update for VS Code integrated terminal

    Changelog v1.2.1:
    - Use Console cursor positioning for in-place progress

    Changelog v1.2.0:
    - CLI progress UI with sticky header and live status line

    Changelog v1.1.0:
    - Hard-coded path validated via GetFullPath()
    - Added symlink guard, takeown/icacls, -LiteralPath everywhere
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Hard-coded target -- ONLY this exact path is ever touched
# ---------------------------------------------------------------------------
$folder = 'C:\Windows.old'

$resolvedFolder = [System.IO.Path]::GetFullPath($folder)
if ($resolvedFolder -ne 'C:\Windows.old') {
    Write-Host "Safety check failed: resolved path '$resolvedFolder' is not 'C:\Windows.old'." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $folder)) {
    Write-Host "'$folder' does not exist -- nothing to do." -ForegroundColor Yellow
    exit 0
}

$item = Get-Item -LiteralPath $folder -Force
if (-not $item.PSIsContainer) {
    Write-Host "'$folder' exists but is not a directory -- aborting." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$script:startTime  = [System.Diagnostics.Stopwatch]::StartNew()
$script:errors     = [System.Collections.Generic.List[string]]::new()
$script:lastUpdate = [datetime]::MinValue

function Format-Size ([long]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f [math]::Max(1, $Bytes / 1KB)
}

function Write-Header {
    param([string]$SizeText, [int]$FileCount, [int]$DirCount)
    $border = '=' * 60
    Write-Host ''
    Write-Host $border -ForegroundColor Cyan
    Write-Host '  myTech.Today - Windows.old Cleanup' -ForegroundColor White
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  Target : $folder" -ForegroundColor Gray
    Write-Host "  Size   : $SizeText" -ForegroundColor Gray
    Write-Host "  Files  : $($FileCount.ToString('N0'))    Dirs : $($DirCount.ToString('N0'))" -ForegroundColor Gray
    Write-Host $border -ForegroundColor Cyan
    Write-Host ''
}

function Write-Phase {
    param([string]$Name, [string]$Symbol = '*')
    Write-Host ''
    Write-Host "[$Symbol] $Name" -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Text, [int]$Current, [int]$Total)
    # Throttle updates to every 300ms to avoid flicker
    $now = [datetime]::UtcNow
    if (($now - $script:lastUpdate).TotalMilliseconds -lt 300) { return }
    $script:lastUpdate = $now

    $elapsed = $script:startTime.Elapsed.ToString('mm\:ss')
    $pct     = if ($Total -gt 0) { [math]::Min(100, [math]::Floor(($Current / $Total) * 100)) } else { 0 }
    $barFill = [math]::Min(40, [math]::Floor($pct / 2.5))   # 40-char max bar
    $bar     = ([string]::new([char]0x2588, $barFill)).PadRight(40)

    $width   = try { [Console]::WindowWidth } catch { 120 }
    $prefix  = "  [$bar] {0,3}%  {1}/{2}  [{3}]  " -f $pct, $Current, $Total, $elapsed
    $remain  = [math]::Max(0, $width - $prefix.Length - 1)
    if ($Text.Length -gt $remain) { $Text = $Text.Substring(0, [math]::Max(0, $remain - 3)) + '...' }
    $line    = ($prefix + $Text).PadRight($width - 1)

    # Use Write-Host with carriage return for broadest terminal compatibility
    Write-Host ("`r" + $line) -NoNewline
}

function Write-StatusIndeterminate {
    param([string]$Text, [int]$Current)
    # Throttle updates to every 300ms
    $now = [datetime]::UtcNow
    if (($now - $script:lastUpdate).TotalMilliseconds -lt 300) { return }
    $script:lastUpdate = $now

    $elapsed = $script:startTime.Elapsed.ToString('mm\:ss')
    # Spinner animation instead of percentage bar
    $spinChars = @('|', '/', '-', '\')
    $spin = $spinChars[$Current % 4]

    $width   = try { [Console]::WindowWidth } catch { 120 }
    $prefix  = "  [$spin] {0:N0} items  [{1}]  " -f $Current, $elapsed
    $remain  = [math]::Max(0, $width - $prefix.Length - 1)
    if ($Text.Length -gt $remain) { $Text = $Text.Substring(0, [math]::Max(0, $remain - 3)) + '...' }
    $line    = ($prefix + $Text).PadRight($width - 1)

    Write-Host ("`r" + $line) -NoNewline
}

function Write-PhaseDone {
    param([string]$Message)
    $width = try { [Console]::WindowWidth } catch { 120 }
    # Overwrite the status line with the success message
    Write-Host ("`r" + (' ' * ($width - 1))) -NoNewline
    Write-Host "`r  [OK] $Message" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Scan: count files and directories so we can show progress
# ---------------------------------------------------------------------------
Write-Host 'Scanning...' -NoNewline -ForegroundColor DarkGray
$allFiles = @(Get-ChildItem -LiteralPath $folder -Recurse -File -Force -ErrorAction SilentlyContinue)
$allDirs  = @(Get-ChildItem -LiteralPath $folder -Recurse -Directory -Force -ErrorAction SilentlyContinue)
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
$blank = ' ' * 20
Write-Host "`r$blank`r" -NoNewline

Write-Header -SizeText (Format-Size $totalSize) -FileCount $allFiles.Count -DirCount $allDirs.Count

# ---------------------------------------------------------------------------
# Phase 1: Take ownership and grant permissions
# ---------------------------------------------------------------------------
Write-Phase 'Phase 1/3 — Taking ownership & setting permissions'

# Stream takeown output with indeterminate spinner (count is unknown because
# Get-ChildItem can't see items it doesn't have permission to enumerate)
$tkCount = 0
& takeown /F $folder /R /A /D Y 2>&1 | ForEach-Object {
    $tkCount++
    if ($tkCount % 50 -eq 0) {
        Write-StatusIndeterminate -Text "$_" -Current $tkCount
    }
}
Write-PhaseDone "Ownership taken ($($tkCount.ToString('N0')) items)"

& icacls $folder /grant Administrators:F /T /C /Q 2>&1 | Out-Null
Write-PhaseDone 'ACLs updated'

# ---------------------------------------------------------------------------
# Re-scan after ownership: now we can see everything
# ---------------------------------------------------------------------------
Write-Host '  Rescanning...' -NoNewline -ForegroundColor DarkGray
$allFiles = @(Get-ChildItem -LiteralPath $folder -Recurse -File -Force -ErrorAction SilentlyContinue)
$allDirs  = @(Get-ChildItem -LiteralPath $folder -Recurse -Directory -Force -ErrorAction SilentlyContinue)
Write-Host ("`r" + (' ' * 40) + "`r") -NoNewline
Write-Host "  [OK] Rescan: $($allFiles.Count.ToString('N0')) files, $($allDirs.Count.ToString('N0')) dirs" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Phase 2: Delete files (bottom-up)
# ---------------------------------------------------------------------------
Write-Phase 'Phase 2/3 — Removing files'
$filesDone   = 0
$filesTotal  = $allFiles.Count
$filesFailed = 0

foreach ($f in $allFiles) {
    $filesDone++
    if (-not $f.FullName.StartsWith('C:\Windows.old\', [System.StringComparison]::OrdinalIgnoreCase)) {
        continue  # symlink guard
    }
    try {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
    } catch {
        $filesFailed++
        $script:errors.Add("FILE  $($f.FullName): $($_.Exception.Message)")
    }
    Write-Status -Text $f.FullName -Current $filesDone -Total $filesTotal
}
Write-PhaseDone "Files removed: $($filesDone - $filesFailed) OK, $filesFailed failed"

# ---------------------------------------------------------------------------
# Phase 3: Delete directories (deepest first)
# ---------------------------------------------------------------------------
Write-Phase 'Phase 3/3 — Removing directories'
$sortedDirs  = $allDirs | Sort-Object { $_.FullName.Length } -Descending
$dirsDone    = 0
$dirsTotal   = $sortedDirs.Count
$dirsFailed  = 0

foreach ($d in $sortedDirs) {
    $dirsDone++
    if (-not $d.FullName.StartsWith('C:\Windows.old\', [System.StringComparison]::OrdinalIgnoreCase)) {
        continue  # symlink guard
    }
    try {
        Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
    } catch {
        $dirsFailed++
        $script:errors.Add("DIR   $($d.FullName): $($_.Exception.Message)")
    }
    Write-Status -Text $d.FullName -Current $dirsDone -Total $dirsTotal
}
Write-PhaseDone "Directories removed: $($dirsDone - $dirsFailed) OK, $dirsFailed failed"

# ---------------------------------------------------------------------------
# Final: remove root folder
# ---------------------------------------------------------------------------
Write-Host ''
try {
    Remove-Item -LiteralPath $folder -Force -ErrorAction Stop
    $elapsed = $script:startTime.Elapsed.ToString('mm\:ss')
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  SUCCESS  C:\Windows.old deleted  [$elapsed elapsed]" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} catch {
    $script:errors.Add("ROOT  ${folder}: $($_.Exception.Message)")
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  PARTIAL  Root folder could not be fully removed." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Error summary (if any)
# ---------------------------------------------------------------------------
if ($script:errors.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($script:errors.Count) error(s) encountered:" -ForegroundColor Red
    # Show first 15; rest are noise
    $show = [math]::Min($script:errors.Count, 15)
    for ($i = 0; $i -lt $show; $i++) {
        Write-Host "    $($script:errors[$i])" -ForegroundColor DarkRed
    }
    if ($script:errors.Count -gt $show) {
        Write-Host "    ... and $($script:errors.Count - $show) more" -ForegroundColor DarkRed
    }
}
Write-Host ''