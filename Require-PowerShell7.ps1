<#
.SYNOPSIS
    PowerShell 7+ version check and enforcement module for myTech.Today scripts.

.DESCRIPTION
    This script checks if PowerShell 7+ is installed and running. If not, it provides
    platform-specific installation instructions and optionally continues on PS 5.1 (Windows).

    Configuration via script-scope variables (set before dot-sourcing):
    - $script:PS7ContinueOnPS51 = $true  : Allow script to continue on PS 5.1 with a warning
    - $script:PS7Silent = $true          : Suppress console output

.EXAMPLE
    $script:PS7ContinueOnPS51 = $true
    . "$PSScriptRoot\..\scripts\Require-PowerShell7.ps1"

.NOTES
    Author: Kyle C. Rode
    Company: myTech.Today
    Copyright: (c) 2025 myTech.Today. All rights reserved.
#>

# Read configuration from script scope variables if set by calling script
if (-not (Test-Path variable:script:PS7ContinueOnPS51)) { $script:PS7ContinueOnPS51 = $false }
if (-not (Test-Path variable:script:PS7Silent)) { $script:PS7Silent = $false }

function Test-PowerShell7Installed {
    <#
    .SYNOPSIS
        Checks if PowerShell 7+ is installed on the system.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Check common PowerShell 7 locations
    if ($IsWindows -or $env:OS -match 'Windows') {
        $pwshPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\PowerShell\pwsh.exe"
        )
        foreach ($path in $pwshPaths) {
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        # Also check if pwsh is in PATH
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        return $null -ne $pwsh
    }
    else {
        # macOS/Linux - check if pwsh is in PATH
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        return $null -ne $pwsh
    }
}

function Get-InstallInstructions {
    <#
    .SYNOPSIS
        Returns platform-specific PowerShell 7 installation instructions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $instructions = @"

================================================================================
                    PowerShell 7+ Installation Instructions
================================================================================

"@

    # Detect platform
    if ($IsWindows -or $env:OS -match 'Windows') {
        $instructions += @"
WINDOWS:
  Option 1 - Using winget (recommended):
    winget install --id Microsoft.PowerShell --source winget

  Option 2 - Microsoft Store:
    Search for "PowerShell" in the Microsoft Store

  Option 3 - Direct download:
    https://github.com/PowerShell/PowerShell/releases

"@
    }
    elseif ($IsMacOS) {
        $instructions += @"
macOS:
  Option 1 - Using Homebrew (recommended):
    brew install --cask powershell

  Option 2 - Direct .pkg download:
    https://github.com/PowerShell/PowerShell/releases

"@
    }
    elseif ($IsLinux) {
        $instructions += @"
LINUX:
  Ubuntu/Debian:
    sudo apt update && sudo apt install -y powershell

  Fedora:
    sudo dnf install powershell

  Arch Linux:
    sudo pacman -S powershell

  Other distributions:
    https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-linux

"@
    }
    else {
        $instructions += @"
Please visit:
  https://github.com/PowerShell/PowerShell/releases

"@
    }

    $instructions += @"
================================================================================
After installation, run your script again using: pwsh <script.ps1>
================================================================================
"@

    return $instructions
}

# Main version check logic
$script:_psVer = $PSVersionTable.PSVersion
$script:_isPS7OrHigher = $script:_psVer.Major -ge 7
$script:_isPS51 = ($script:_psVer.Major -eq 5 -and $script:_psVer.Minor -ge 1)

if ($script:_isPS7OrHigher) {
    # Running on PowerShell 7+ - all good
    if (-not $script:PS7Silent) {
        Write-Verbose "[OK] PowerShell $($script:_psVer.ToString()) detected - requirements met."
    }
}
elseif ($script:_isPS51) {
    # Running on Windows PowerShell 5.1
    $script:_ps7Installed = Test-PowerShell7Installed

    if (-not $script:PS7Silent) {
        Write-Host ""
        Write-Host "[WARN] You are running Windows PowerShell $($script:_psVer.ToString())" -ForegroundColor Yellow
        Write-Host "       PowerShell 7+ is strongly recommended for full compatibility." -ForegroundColor Yellow

        if ($script:_ps7Installed) {
            Write-Host ""
            Write-Host "[INFO] PowerShell 7 is installed. Run this script with: pwsh <script.ps1>" -ForegroundColor Cyan
        }
        else {
            Write-Host (Get-InstallInstructions) -ForegroundColor Cyan
        }
    }

    if (-not $script:PS7ContinueOnPS51) {
        Write-Host ""
        Write-Host "[ERROR] This script requires PowerShell 7+. Exiting." -ForegroundColor Red
        Write-Host "        Set `$script:PS7ContinueOnPS51 = `$true before sourcing to allow PS 5.1" -ForegroundColor Gray
        exit 1
    }
    else {
        if (-not $script:PS7Silent) {
            Write-Host ""
            Write-Host "[WARN] Continuing on PowerShell 5.1 - some features may not work correctly." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}
else {
    # PowerShell version too old
    if (-not $script:PS7Silent) {
        Write-Host ""
        Write-Host "[ERROR] PowerShell $($script:_psVer.ToString()) is not supported." -ForegroundColor Red
        Write-Host "        Minimum required version: PowerShell 5.1" -ForegroundColor Red
        Write-Host "        Recommended version: PowerShell 7+" -ForegroundColor Yellow
        Write-Host (Get-InstallInstructions) -ForegroundColor Cyan
    }
    exit 1
}
