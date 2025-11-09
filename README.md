# Helper Scripts Directory

**Repository Location:** `https://github.com/mytech-today-now/scripts`

This directory contains reusable helper scripts that can be included in other PowerShell scripts to provide common functionality.

**Note:** The canonical version of these helper scripts is hosted in the separate `scripts` repository on GitHub. This allows scripts from any repository to load the helpers via GitHub URL.

## Purpose

The helper scripts repository serves as a centralized location for:
- **Utility functions** that are used across multiple scripts
- **Helper modules** that provide specific functionality
- **Shared code** to follow DRY (Don't Repeat Yourself) principles
- **Standardized implementations** of common patterns
- **Remote loading** - Scripts can load helpers from GitHub URL

## Available Helper Scripts

### 📝 `logging.ps1` - Generic Logging Module

**Purpose:** Provides centralized logging functionality for all myTech.Today PowerShell scripts.

**Features:**
- Centralized logging to `C:\mytech.today\logs\`
- Monthly log rotation (one file per month)
- Cyclical logging with 10MB size limit
- Markdown table format for structured logging
- ASCII-only indicators (no emoji) - `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`
- Console output with color coding
- Can be imported from GitHub URL
- PowerShell 5.1+ compatible

**Usage:**

```powershell
# Method 1: Load from GitHub (recommended for distributed scripts)
$loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/logging.ps1'
Invoke-Expression (Invoke-WebRequest -Uri $loggingUrl -UseBasicParsing).Content

# Method 2: Dot-source from local path (for development)
. "$PSScriptRoot\..\scripts\logging.ps1"

# Initialize logging
Initialize-Log -ScriptName "MyScript" -ScriptVersion "1.0.0"

# Write log entries
Write-Log "Script started" -Level INFO
Write-Log "Operation completed successfully" -Level SUCCESS
Write-Log "Warning: Configuration file not found" -Level WARNING
Write-Log "Error: Failed to connect to server" -Level ERROR

# Get current log path
$logPath = Get-LogPath
Write-Host "Logging to: $logPath"
```

**Available Functions:**

#### Core Functions:
- `Initialize-Log` - Initializes logging for a script with monthly rotation
- `Write-Log` - Writes log entries to console and file
- `Get-LogPath` - Returns the current log file path

**Log Levels:**

| Level | Indicator | Console Color | Description |
|-------|-----------|---------------|-------------|
| `INFO` | `[INFO]` | Cyan | Informational messages |
| `SUCCESS` | `[OK]` | Green | Success messages |
| `WARNING` | `[WARN]` | Yellow | Warning messages |
| `ERROR` | `[ERROR]` | Red | Error messages |

**Log File Format:**

```markdown
# MyScript Log

**Script Version:** 1.0.0
**Log Started:** 2025-11-09 12:00:00
**Computer:** HOSTNAME
**User:** USERNAME

---

## Activity Log

| Timestamp | Level | Message |
|-----------|-------|---------|
| 2025-11-09 12:00:01 | [INFO] | Script started |
| 2025-11-09 12:00:02 | [OK] | Operation completed successfully |
| 2025-11-09 12:00:03 | [WARN] | Warning: Configuration file not found |
| 2025-11-09 12:00:04 | [ERROR] | Error: Failed to connect to server |
```

**Example:**

```powershell
# Load the logging module
$loggingUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/logging.ps1'
Invoke-Expression (Invoke-WebRequest -Uri $loggingUrl -UseBasicParsing).Content

# Initialize logging
Initialize-Log -ScriptName "BackupScript" -ScriptVersion "1.0.0"

# Script logic with logging
Write-Log "Starting backup process..." -Level INFO

try {
    Write-Log "Backing up files..." -Level INFO
    # ... backup logic ...
    Write-Log "Backup completed successfully" -Level SUCCESS
}
catch {
    Write-Log "Backup failed: $_" -Level ERROR
    throw
}
```

---

### 📐 `responsive.ps1` - Responsive GUI Helper

**Purpose:** Provides comprehensive responsive GUI functionality for PowerShell Windows Forms applications.

**Features:**
- Automatic DPI detection and scaling
- Support for all screen resolutions from VGA (640x480) to 8K UHD (7680x4320)
- Helper functions for creating responsive controls
- Standardized base dimensions and scaling patterns
- Caching for performance optimization

**Usage:**

```powershell
# Method 1: Load from GitHub (recommended for distributed scripts)
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/responsive.ps1'
Invoke-Expression (Invoke-WebRequest -Uri $responsiveUrl -UseBasicParsing).Content

# Method 2: Dot-source from local path (for development)
. "$PSScriptRoot\..\scripts\responsive.ps1"

# Then use the functions:
$scaleInfo = Get-ResponsiveDPIScale
$form = New-ResponsiveForm -Title "My App" -Width 800 -Height 600
$button = New-ResponsiveButton -Text "Click Me" -X 20 -Y 20
```

**Available Functions:**

#### Core Functions:
- `Get-ResponsiveDPIScale` - Detects screen resolution and calculates DPI scale factor
- `Get-ResponsiveBaseDimensions` - Returns standard base dimensions for GUI elements
- `Get-ResponsiveScaledValue` - Scales a value based on DPI scale factor

#### Control Creation Functions:
- `New-ResponsiveForm` - Creates a responsive Windows Form
- `New-ResponsiveLabel` - Creates a responsive Label control
- `New-ResponsiveTextBox` - Creates a responsive TextBox control
- `New-ResponsiveButton` - Creates a responsive Button control
- `New-ResponsiveCheckBox` - Creates a responsive CheckBox control
- `New-ResponsiveComboBox` - Creates a responsive ComboBox control
- `New-ResponsiveProgressBar` - Creates a responsive ProgressBar control
- `New-ResponsiveNumericUpDown` - Creates a responsive NumericUpDown control

**Example:**

```powershell
# Load the helper
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/responsive.ps1'
Invoke-Expression (Invoke-WebRequest -Uri $responsiveUrl -UseBasicParsing).Content

# Create a responsive form
$form = New-ResponsiveForm -Title "User Information" -Width 500 -Height 300

# Add controls
$lblName = New-ResponsiveLabel -Text "Name:" -X 20 -Y 20 -Width 100
$txtName = New-ResponsiveTextBox -X 130 -Y 20 -Width 250

$lblAge = New-ResponsiveLabel -Text "Age:" -X 20 -Y 60 -Width 100
$numAge = New-ResponsiveNumericUpDown -X 130 -Y 60 -Width 120 -Minimum 0 -Maximum 120

$btnOK = New-ResponsiveButton -Text "OK" -X 20 -Y 100 -Width 100
$btnCancel = New-ResponsiveButton -Text "Cancel" -X 130 -Y 100 -Width 100

# Add to form
$form.Controls.AddRange(@($lblName, $txtName, $lblAge, $numAge, $btnOK, $btnCancel))

# Show the form
$form.ShowDialog()
```

---

## How to Use Helper Scripts

### From GitHub (Recommended for Production)

Load helper scripts directly from GitHub to ensure you always have the latest version:

```powershell
# Load a helper script from GitHub
$helperUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/HELPER_NAME.ps1'
try {
    Invoke-Expression (Invoke-WebRequest -Uri $helperUrl -UseBasicParsing).Content
    Write-Host "Helper loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load helper: $_"
    exit 1
}
```

### From Local Path (For Development)

When developing locally, you can dot-source the helper script:

```powershell
# Assuming your script is in a subdirectory of the repository
. "$PSScriptRoot\..\scripts\HELPER_NAME.ps1"
```

### With Caching (For Performance)

Cache the helper script locally to avoid repeated downloads:

```powershell
$helperUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/responsive.ps1'
$cacheFile = Join-Path $env:TEMP 'responsive-helper.ps1'

# Download if not cached or older than 1 day
if (-not (Test-Path $cacheFile) -or ((Get-Item $cacheFile).LastWriteTime -lt (Get-Date).AddDays(-1))) {
    Invoke-WebRequest -Uri $helperUrl -OutFile $cacheFile -UseBasicParsing
}

# Load from cache
. $cacheFile
```

---

## Best Practices

1. **Version Pinning:** For production scripts, consider pinning to a specific commit or tag:
   ```powershell
   $helperUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/v1.0.0/responsive.ps1'
   ```

2. **Error Handling:** Always wrap helper loading in try-catch blocks:
   ```powershell
   try {
       Invoke-Expression (Invoke-WebRequest -Uri $helperUrl -UseBasicParsing).Content
   }
   catch {
       Write-Error "Failed to load helper: $_"
       exit 1
   }
   ```

3. **Offline Support:** Provide fallback for offline scenarios:
   ```powershell
   $localHelper = "$PSScriptRoot\..\scripts\responsive.ps1"
   if (Test-Path $localHelper) {
       . $localHelper
   }
   else {
       # Try to download from GitHub
       Invoke-Expression (Invoke-WebRequest -Uri $helperUrl -UseBasicParsing).Content
   }
   ```

4. **Documentation:** Always document which helper scripts your script depends on in the script header.

---

## Adding New Helper Scripts

When creating new helper scripts for this directory:

1. **Follow naming conventions:** Use descriptive, lowercase names with hyphens (e.g., `responsive.ps1`, `logging-utils.ps1`)

2. **Include comprehensive documentation:**
   - Synopsis and description
   - Parameter documentation
   - Usage examples
   - Version information

3. **Export functions explicitly:** Use `Export-ModuleMember` to clearly define the public API

4. **Add to this README:** Document the new helper script in this file

5. **Update `.augment/` guidelines:** Add the new helper to the Augment AI guidelines

---

## Contributing

When adding or modifying helper scripts:
- Ensure backward compatibility when possible
- Update version numbers in script headers
- Add comprehensive examples
- Test with multiple PowerShell versions
- Document breaking changes in CHANGELOG

---

## License

All helper scripts in this directory are part of the PowerShellScripts repository and are subject to the repository's license terms.

Copyright (c) 2025 myTech.Today. All rights reserved.

