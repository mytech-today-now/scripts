<#
.SYNOPSIS
    Test script for enhanced Event Viewer logging

.DESCRIPTION
    This script tests the enhanced logging parameters added to logging.ps1 v2.1.0.
    It writes test events to the Windows Event Log and then reads them back to verify
    the enhanced message format is working correctly.

.NOTES
    Version: 1.0.0
    Author: myTech.Today
    Requires: Administrator privileges to write to Event Log
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Enhanced Logging Test Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load the logging module - try local first, then GitHub
$localLoggingPath = Join-Path $PSScriptRoot "logging.ps1"
$loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/logging.ps1'

try {
    if (Test-Path $localLoggingPath) {
        Write-Host "[INFO] Loading LOCAL logging module from: $localLoggingPath" -ForegroundColor Yellow
        . $localLoggingPath
        Write-Host "[OK] Local logging module loaded successfully" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Loading logging module from GitHub..." -ForegroundColor Cyan
        $loggingScript = Invoke-RestMethod -Uri $loggingUrl -UseBasicParsing
        Invoke-Expression $loggingScript
        Write-Host "[OK] GitHub logging module loaded successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "[FAIL] Failed to load logging module: $_" -ForegroundColor Red
    exit 1
}

# Initialize logging
$logPath = Initialize-Log -ScriptName "EnhancedLogging-Test" -ScriptVersion "1.0.0"
Write-Host "[OK] Log initialized at: $logPath" -ForegroundColor Green
Write-Host ""

# Test 1: Basic INFO message (no enhanced parameters)
Write-Host "[TEST 1] Writing basic INFO message..." -ForegroundColor Yellow
Write-Log "This is a basic INFO message without enhanced parameters" -Level INFO
Write-Host "[OK] Basic INFO message written" -ForegroundColor Green

# Test 2: WARNING with enhanced parameters
Write-Host "[TEST 2] Writing enhanced WARNING message..." -ForegroundColor Yellow
Write-Log "Test warning: Configuration file not found" -Level WARNING `
    -Context "Attempting to load user preferences from config.json" `
    -Solution "Create a config.json file in the application directory, or run the setup wizard to generate default settings" `
    -Component "Configuration Loader"
Write-Host "[OK] Enhanced WARNING message written" -ForegroundColor Green

# Test 3: ERROR with enhanced parameters
Write-Host "[TEST 3] Writing enhanced ERROR message..." -ForegroundColor Yellow
Write-Log "Test error: Network connection failed" -Level ERROR `
    -Context "Downloading update package from https://example.com/update.zip" `
    -Solution "1. Check your internet connection. 2. Verify firewall settings allow outbound HTTPS. 3. Try again later if the server is unavailable." `
    -Component "Update Manager"
Write-Host "[OK] Enhanced ERROR message written" -ForegroundColor Green

# Test 4: SUCCESS message
Write-Host "[TEST 4] Writing SUCCESS message..." -ForegroundColor Yellow
Write-Log "Test completed successfully" -Level SUCCESS
Write-Host "[OK] SUCCESS message written" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Reading Events from Event Viewer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read back the events
try {
    $events = Get-WinEvent -LogName 'myTech.Today' -MaxEvents 10 -ErrorAction Stop
    
    Write-Host "Found $($events.Count) recent events in myTech.Today log:" -ForegroundColor Green
    Write-Host ""
    
    foreach ($event in $events) {
        $levelColor = switch ($event.LevelDisplayName) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Cyan' }
            default { 'White' }
        }
        
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host "Time: $($event.TimeCreated)" -ForegroundColor White
        Write-Host "Level: $($event.LevelDisplayName)" -ForegroundColor $levelColor
        Write-Host "Event ID: $($event.Id)" -ForegroundColor White
        Write-Host ""
        
        # Get the message from Properties if Message is empty
        if ([string]::IsNullOrWhiteSpace($event.Message)) {
            if ($event.Properties -and $event.Properties.Count -gt 0) {
                Write-Host "Message (from Properties):" -ForegroundColor White
                foreach ($prop in $event.Properties) {
                    if (-not [string]::IsNullOrWhiteSpace($prop.Value)) {
                        Write-Host $prop.Value -ForegroundColor Gray
                    }
                }
            }
            else {
                Write-Host "Message: (empty)" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "Message:" -ForegroundColor White
            Write-Host $event.Message -ForegroundColor Gray
        }
        Write-Host ""
    }
}
catch {
    Write-Host "[WARN] Could not read events: $_" -ForegroundColor Yellow
    Write-Host "[INFO] The myTech.Today event log may not exist yet" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To view events in Event Viewer:" -ForegroundColor Cyan
Write-Host "1. Open Event Viewer (eventvwr.msc)" -ForegroundColor White
Write-Host "2. Navigate to: Applications and Services Logs > myTech.Today" -ForegroundColor White
Write-Host "3. Look for events from source 'EnhancedLogging-Test'" -ForegroundColor White
Write-Host ""

# Return the log path for reference
Write-Host "Log file: $logPath" -ForegroundColor Cyan

