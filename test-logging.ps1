<#
.SYNOPSIS
    Test script for the logging.ps1 module.

.DESCRIPTION
    Demonstrates how to use the generic logging module in your scripts.
    Tests all logging functions and features.

.NOTES
    Name:           test-logging.ps1
    Author:         myTech.Today
    Version:        1.0.0
    DateCreated:    2025-11-09
#>

# Method 1: Load from local path (for development/testing)
Write-Host "Loading logging module from local path..." -ForegroundColor Cyan
. "$PSScriptRoot\logging.ps1"

# Method 2: Load from GitHub (uncomment to test)
# Write-Host "Loading logging module from GitHub..." -ForegroundColor Cyan
# $loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/logging.ps1'
# try {
#     Invoke-Expression (Invoke-WebRequest -Uri $loggingUrl -UseBasicParsing).Content
#     Write-Host "Logging module loaded successfully from GitHub" -ForegroundColor Green
# }
# catch {
#     Write-Error "Failed to load logging module from GitHub: $_"
#     exit 1
# }

Write-Host ""
Write-Host "=== Testing Logging Module ===" -ForegroundColor Yellow
Write-Host ""

# Test 1: Initialize logging
Write-Host "Test 1: Initialize logging" -ForegroundColor Yellow
$logPath = Initialize-Log -ScriptName "TestScript" -ScriptVersion "1.0.0"

if ($logPath) {
    Write-Host "SUCCESS: Logging initialized to: $logPath" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not initialize logging" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Write log entries with different levels
Write-Host "Test 2: Write log entries with different levels" -ForegroundColor Yellow
Write-Log "This is an informational message" -Level INFO
Write-Log "This is a success message" -Level SUCCESS
Write-Log "This is a warning message" -Level WARNING
Write-Log "This is an error message" -Level ERROR

Write-Host ""

# Test 3: Get log path
Write-Host "Test 3: Get current log path" -ForegroundColor Yellow
$currentLogPath = Get-LogPath
Write-Host "Current log path: $currentLogPath" -ForegroundColor Cyan

Write-Host ""

# Test 4: Write multiple log entries
Write-Host "Test 4: Write multiple log entries" -ForegroundColor Yellow
for ($i = 1; $i -le 10; $i++) {
    Write-Log "Processing item $i of 10" -Level INFO
}
Write-Log "All items processed successfully" -Level SUCCESS

Write-Host ""

# Test 5: Simulate different scenarios
Write-Host "Test 5: Simulate different scenarios" -ForegroundColor Yellow

Write-Log "Starting application initialization..." -Level INFO
Start-Sleep -Milliseconds 500

Write-Log "Loading configuration file..." -Level INFO
Start-Sleep -Milliseconds 500

Write-Log "Configuration loaded successfully" -Level SUCCESS
Start-Sleep -Milliseconds 500

Write-Log "Connecting to database..." -Level INFO
Start-Sleep -Milliseconds 500

Write-Log "Warning: Database connection slow (timeout: 5s)" -Level WARNING
Start-Sleep -Milliseconds 500

Write-Log "Database connection established" -Level SUCCESS
Start-Sleep -Milliseconds 500

Write-Log "Processing data..." -Level INFO
Start-Sleep -Milliseconds 500

Write-Log "Error: Failed to process record #42 - Invalid data format" -Level ERROR
Start-Sleep -Milliseconds 500

Write-Log "Retrying record #42 with fallback parser..." -Level INFO
Start-Sleep -Milliseconds 500

Write-Log "Record #42 processed successfully" -Level SUCCESS
Start-Sleep -Milliseconds 500

Write-Log "Application completed successfully" -Level SUCCESS

Write-Host ""

# Test 6: Display log file contents
Write-Host "Test 6: Display log file contents" -ForegroundColor Yellow
Write-Host "Opening log file in notepad..." -ForegroundColor Cyan

if (Test-Path $logPath) {
    # Display first 30 lines of log file
    Write-Host ""
    Write-Host "--- Log File Preview (first 30 lines) ---" -ForegroundColor Cyan
    Get-Content -Path $logPath -TotalCount 30 | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
    }
    Write-Host "--- End of Preview ---" -ForegroundColor Cyan
    Write-Host ""
    
    # Open in notepad
    Start-Process notepad.exe -ArgumentList $logPath
} else {
    Write-Host "ERROR: Log file not found at: $logPath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Testing Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - Log file location: $logPath" -ForegroundColor Cyan
Write-Host "  - Log file size: $((Get-Item $logPath).Length / 1KB) KB" -ForegroundColor Cyan
Write-Host "  - Total log entries: $((Get-Content $logPath | Select-String '^\|').Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "The log file has been opened in Notepad for your review." -ForegroundColor Green
Write-Host ""

