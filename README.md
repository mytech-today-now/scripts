# Helper Scripts Directory

This directory contains reusable helper scripts that can be included in other PowerShell scripts to provide common functionality.

## Purpose

The `scripts/` directory serves as a centralized repository for:
- **Utility functions** that are used across multiple scripts
- **Helper modules** that provide specific functionality
- **Shared code** to follow DRY (Don't Repeat Yourself) principles
- **Standardized implementations** of common patterns

## Available Helper Scripts

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
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/responsive.ps1'
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
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/responsive.ps1'
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
$helperUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/responsive.ps1'
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
   $helperUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/v1.0.0/scripts/responsive.ps1'
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

