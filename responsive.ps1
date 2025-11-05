<#
.SYNOPSIS
    Responsive GUI Helper Script for PowerShell Windows Forms Applications

.DESCRIPTION
    This helper script provides comprehensive responsive GUI functionality for PowerShell scripts.
    It automatically handles DPI scaling, resolution detection, and responsive control sizing
    for all screen resolutions from VGA (640x480) to 8K UHD (7680x4320).
    
    This script is designed to be called from other PowerShell scripts via GitHub URL or local path.
    It follows the myTech.Today GUI responsiveness standards from .augment/gui-responsiveness.md

.USAGE
    # Method 1: Call from GitHub (recommended for distributed scripts)
    $responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/responsive.ps1'
    Invoke-Expression (Invoke-WebRequest -Uri $responsiveUrl -UseBasicParsing).Content
    
    # Method 2: Dot-source from local path (for development)
    . "$PSScriptRoot\..\scripts\responsive.ps1"
    
    # Then use the functions in your script:
    $scaleInfo = Get-ResponsiveDPIScale
    $form = New-ResponsiveForm -Title "My App" -Width 800 -Height 600
    $button = New-ResponsiveButton -Text "Click Me" -X 20 -Y 20

.NOTES
    File Name      : responsive.ps1
    Author         : myTech.Today
    Prerequisite   : PowerShell 5.1 or later, Windows Forms
    Copyright      : (c) 2025 myTech.Today. All rights reserved.
    Version        : 1.0.0

.LINK
    https://github.com/mytech-today-now/PowerShellScripts
#>

#Requires -Version 5.1

# Ensure Windows Forms assemblies are loaded
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Module-level variables for caching
$script:CachedScaleInfo = $null
$script:CachedBaseDimensions = $null

#region Core DPI and Scaling Functions

function Get-ResponsiveDPIScale {
    <#
    .SYNOPSIS
        Calculates DPI scaling factor based on screen resolution and DPI settings.

    .DESCRIPTION
        Detects screen resolution and DPI, then calculates appropriate scaling factor.
        Supports VGA through 8K UHD displays with progressive scaling.
        Results are cached for performance.

    .PARAMETER Force
        Force recalculation even if cached value exists.

    .OUTPUTS
        PSCustomObject with scaling information:
        - BaseFactor: Base DPI scaling factor
        - AdditionalScale: Resolution-specific additional scaling
        - TotalScale: Combined scaling factor to apply to all dimensions
        - ScreenWidth: Screen width in pixels
        - ScreenHeight: Screen height in pixels
        - DpiX: Horizontal DPI
        - DpiY: Vertical DPI
        - ResolutionName: Detected resolution category name
        - ResolutionCategory: Category (VGA, HD, FHD, 4K, etc.)

    .EXAMPLE
        $scale = Get-ResponsiveDPIScale
        Write-Host "Screen: $($scale.ScreenWidth)x$($scale.ScreenHeight)"
        Write-Host "Resolution: $($scale.ResolutionName)"
        Write-Host "Scale Factor: $($scale.TotalScale)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    # Return cached value if available and not forcing recalculation
    if ($script:CachedScaleInfo -and -not $Force) {
        return $script:CachedScaleInfo
    }
    
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    
    # Calculate base DPI scaling
    $dpiX = $screen.Bounds.Width / [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    $dpiY = $screen.Bounds.Height / [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
    
    # Use the larger of the two scaling factors, with a minimum of 1.0
    $baseFactor = [Math]::Max([Math]::Max($dpiX, $dpiY), 1.0)
    
    # Apply resolution-specific additional scaling
    $additionalScale = 1.0
    $resolutionName = "Unknown"
    $resolutionCategory = "Unknown"
    
    if ($screen.Bounds.Width -ge 7680) {
        $additionalScale = 2.5
        $resolutionName = "8K UHD (7680x4320)"
        $resolutionCategory = "8K"
    }
    elseif ($screen.Bounds.Width -ge 5120) {
        $additionalScale = 1.8
        $resolutionName = "5K (5120x2880)"
        $resolutionCategory = "5K"
    }
    elseif ($screen.Bounds.Width -ge 3840) {
        $additionalScale = 1.5
        $resolutionName = "4K UHD (3840x2160)"
        $resolutionCategory = "4K"
    }
    elseif ($screen.Bounds.Width -ge 3440) {
        $additionalScale = 1.3
        $resolutionName = "UWQHD (3440x1440)"
        $resolutionCategory = "UWQHD"
    }
    elseif ($screen.Bounds.Width -ge 2560) {
        $additionalScale = 1.3
        $resolutionName = "QHD (2560x1440)"
        $resolutionCategory = "QHD"
    }
    elseif ($screen.Bounds.Width -ge 1920) {
        $additionalScale = 1.2
        $resolutionName = "FHD (1920x1080)"
        $resolutionCategory = "FHD"
    }
    elseif ($screen.Bounds.Width -ge 1366) {
        $additionalScale = 1.0
        $resolutionName = "WXGA (1366x768)"
        $resolutionCategory = "WXGA"
    }
    elseif ($screen.Bounds.Width -ge 1280) {
        $additionalScale = 1.0
        $resolutionName = "HD (1280x720)"
        $resolutionCategory = "HD"
    }
    elseif ($screen.Bounds.Width -ge 1024) {
        $additionalScale = 1.0
        $resolutionName = "XGA (1024x768)"
        $resolutionCategory = "XGA"
    }
    elseif ($screen.Bounds.Width -ge 800) {
        $additionalScale = 0.9
        $resolutionName = "SVGA (800x600)"
        $resolutionCategory = "SVGA"
    }
    else {
        $additionalScale = 0.8
        $resolutionName = "VGA (640x480)"
        $resolutionCategory = "VGA"
    }
    
    $scaleFactor = $baseFactor * $additionalScale
    
    # Cache the result
    $script:CachedScaleInfo = [PSCustomObject]@{
        BaseFactor = $baseFactor
        AdditionalScale = $additionalScale
        TotalScale = $scaleFactor
        ScreenWidth = $screen.Bounds.Width
        ScreenHeight = $screen.Bounds.Height
        DpiX = $dpiX
        DpiY = $dpiY
        ResolutionName = $resolutionName
        ResolutionCategory = $resolutionCategory
    }
    
    return $script:CachedScaleInfo
}

function Get-ResponsiveBaseDimensions {
    <#
    .SYNOPSIS
        Returns standard base dimensions for responsive GUI design.

    .DESCRIPTION
        Provides a hashtable of standard base dimensions that should be scaled
        according to screen resolution. These are the recommended defaults.

    .PARAMETER CustomDimensions
        Optional hashtable to override default dimensions.

    .OUTPUTS
        Hashtable with base dimensions for GUI elements.

    .EXAMPLE
        $dims = Get-ResponsiveBaseDimensions
        $scaledMargin = [int]($dims.Margin * $scaleFactor)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$CustomDimensions = @{}
    )
    
    # Default base dimensions (before scaling)
    $defaultDimensions = @{
        # Form dimensions
        FormWidth = 800
        FormHeight = 600
        MinFormWidth = 600
        MinFormHeight = 450
        
        # Font sizes
        BaseFontSize = 10
        MinFontSize = 9
        TitleFontSize = 14
        HeaderFontSize = 12
        
        # Margins and spacing
        Margin = 20
        Spacing = 12
        SmallSpacing = 8
        LargeSpacing = 30
        
        # Control dimensions
        ControlHeight = 25
        ButtonHeight = 35
        ButtonWidth = 100
        TextBoxHeight = 25
        LabelHeight = 20
        
        # Layout
        LabelWidth = 150
        InputWidth = 250
        TabMargin = 15
        
        # Specific controls
        ProgressBarHeight = 25
        CheckBoxHeight = 20
        NumericUpDownHeight = 25
        ComboBoxHeight = 25
    }
    
    # Merge custom dimensions with defaults
    foreach ($key in $CustomDimensions.Keys) {
        $defaultDimensions[$key] = $CustomDimensions[$key]
    }
    
    return $defaultDimensions
}

function Get-ResponsiveScaledValue {
    <#
    .SYNOPSIS
        Scales a value based on the current DPI scale factor.

    .DESCRIPTION
        Applies the DPI scale factor to a base value and returns the scaled integer value.
        Optionally enforces minimum and maximum values.

    .PARAMETER BaseValue
        The base value to scale (before DPI scaling).

    .PARAMETER ScaleFactor
        The scale factor to apply. If not provided, uses cached scale info.

    .PARAMETER MinValue
        Optional minimum value to enforce.

    .PARAMETER MaxValue
        Optional maximum value to enforce.

    .OUTPUTS
        Integer scaled value.

    .EXAMPLE
        $scaledWidth = Get-ResponsiveScaledValue -BaseValue 800 -MinValue 600
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$BaseValue,
        
        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor,
        
        [Parameter(Mandatory = $false)]
        [int]$MinValue,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxValue
    )
    
    # Get scale factor if not provided
    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }
    
    # Calculate scaled value
    $scaledValue = [int]($BaseValue * $ScaleFactor)
    
    # Apply min/max constraints
    if ($MinValue -and $scaledValue -lt $MinValue) {
        $scaledValue = $MinValue
    }
    if ($MaxValue -and $scaledValue -gt $MaxValue) {
        $scaledValue = $MaxValue
    }
    
    return $scaledValue
}

#endregion

#region Responsive Control Creation Functions

function New-ResponsiveForm {
    <#
    .SYNOPSIS
        Creates a responsive Windows Form with automatic DPI scaling.

    .DESCRIPTION
        Creates a new Windows Form with responsive sizing based on screen resolution.
        Automatically applies DPI scaling and sets appropriate minimum sizes.

    .PARAMETER Title
        The title of the form window.

    .PARAMETER Width
        Base width of the form (before scaling).

    .PARAMETER Height
        Base height of the form (before scaling).

    .PARAMETER MinWidth
        Minimum width of the form. Default: 600

    .PARAMETER MinHeight
        Minimum height of the form. Default: 450

    .PARAMETER StartPosition
        Form start position. Default: CenterScreen

    .PARAMETER Resizable
        Whether the form is resizable. Default: $false

    .OUTPUTS
        System.Windows.Forms.Form object with responsive settings applied.

    .EXAMPLE
        $form = New-ResponsiveForm -Title "My Application" -Width 800 -Height 600
        $form.ShowDialog()
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [int]$Width = 800,

        [Parameter(Mandatory = $false)]
        [int]$Height = 600,

        [Parameter(Mandatory = $false)]
        [int]$MinWidth = 600,

        [Parameter(Mandatory = $false)]
        [int]$MinHeight = 450,

        [Parameter(Mandatory = $false)]
        [string]$StartPosition = 'CenterScreen',

        [Parameter(Mandatory = $false)]
        [bool]$Resizable = $false
    )

    $scaleInfo = Get-ResponsiveDPIScale
    $scaleFactor = $scaleInfo.TotalScale

    # Calculate scaled dimensions
    $scaledWidth = Get-ResponsiveScaledValue -BaseValue $Width -MinValue $MinWidth
    $scaledHeight = Get-ResponsiveScaledValue -BaseValue $Height -MinValue $MinHeight

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($scaledWidth, $scaledHeight)
    $form.MinimumSize = New-Object System.Drawing.Size($MinWidth, $MinHeight)
    $form.StartPosition = $StartPosition
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)

    # Set form border style based on resizable parameter
    if ($Resizable) {
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $form.MaximizeBox = $true
    }
    else {
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
    }

    $form.MinimizeBox = $true

    # Set default font
    $baseDims = Get-ResponsiveBaseDimensions
    $fontSize = Get-ResponsiveScaledValue -BaseValue $baseDims.BaseFontSize -MinValue $baseDims.MinFontSize
    $form.Font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Regular)

    # Store scale info in form Tag for later use
    $form.Tag = @{
        ScaleInfo = $scaleInfo
        ScaleFactor = $scaleFactor
        BaseDimensions = $baseDims
    }

    return $form
}

function New-ResponsiveLabel {
    <#
    .SYNOPSIS
        Creates a responsive Label control.

    .PARAMETER Text
        The text to display in the label.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 150

    .PARAMETER Height
        Base height (before scaling). Default: 20

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.Label object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 150,

        [Parameter(Mandatory = $false)]
        [int]$Height = 20,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $label.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )
    $label.AutoSize = $false

    return $label
}

function New-ResponsiveTextBox {
    <#
    .SYNOPSIS
        Creates a responsive TextBox control.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 250

    .PARAMETER Height
        Base height (before scaling). Default: 25

    .PARAMETER Text
        Initial text value.

    .PARAMETER Multiline
        Whether the textbox is multiline. Default: $false

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.TextBox object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 250,

        [Parameter(Mandatory = $false)]
        [int]$Height = 25,

        [Parameter(Mandatory = $false)]
        [string]$Text = '',

        [Parameter(Mandatory = $false)]
        [bool]$Multiline = $false,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Text = $Text
    $textBox.Multiline = $Multiline
    $textBox.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $textBox.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )

    return $textBox
}

function New-ResponsiveButton {
    <#
    .SYNOPSIS
        Creates a responsive Button control.

    .PARAMETER Text
        The text to display on the button.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 100

    .PARAMETER Height
        Base height (before scaling). Default: 35

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.Button object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 100,

        [Parameter(Mandatory = $false)]
        [int]$Height = 35,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $button.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )
    $button.UseVisualStyleBackColor = $true

    return $button
}

function New-ResponsiveCheckBox {
    <#
    .SYNOPSIS
        Creates a responsive CheckBox control.

    .PARAMETER Text
        The text to display next to the checkbox.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 200

    .PARAMETER Height
        Base height (before scaling). Default: 20

    .PARAMETER Checked
        Initial checked state. Default: $false

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.CheckBox object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 200,

        [Parameter(Mandatory = $false)]
        [int]$Height = 20,

        [Parameter(Mandatory = $false)]
        [bool]$Checked = $false,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Text = $Text
    $checkBox.Checked = $Checked
    $checkBox.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $checkBox.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )
    $checkBox.UseVisualStyleBackColor = $true

    return $checkBox
}

function New-ResponsiveComboBox {
    <#
    .SYNOPSIS
        Creates a responsive ComboBox control.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 200

    .PARAMETER Height
        Base height (before scaling). Default: 25

    .PARAMETER Items
        Array of items to add to the combobox.

    .PARAMETER SelectedIndex
        Initial selected index. Default: -1 (none selected)

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.ComboBox object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 200,

        [Parameter(Mandatory = $false)]
        [int]$Height = 25,

        [Parameter(Mandatory = $false)]
        [array]$Items = @(),

        [Parameter(Mandatory = $false)]
        [int]$SelectedIndex = -1,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBox.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $comboBox.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )

    if ($Items.Count -gt 0) {
        $comboBox.Items.AddRange($Items)
    }

    if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $comboBox.Items.Count) {
        $comboBox.SelectedIndex = $SelectedIndex
    }

    return $comboBox
}

function New-ResponsiveProgressBar {
    <#
    .SYNOPSIS
        Creates a responsive ProgressBar control.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 300

    .PARAMETER Height
        Base height (before scaling). Default: 25

    .PARAMETER Value
        Initial progress value (0-100). Default: 0

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.ProgressBar object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 300,

        [Parameter(Mandatory = $false)]
        [int]$Height = 25,

        [Parameter(Mandatory = $false)]
        [int]$Value = 0,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = $Value
    $progressBar.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $progressBar.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )

    return $progressBar
}

function New-ResponsiveNumericUpDown {
    <#
    .SYNOPSIS
        Creates a responsive NumericUpDown control.

    .PARAMETER X
        Base X position (before scaling).

    .PARAMETER Y
        Base Y position (before scaling).

    .PARAMETER Width
        Base width (before scaling). Default: 120

    .PARAMETER Height
        Base height (before scaling). Default: 25

    .PARAMETER Minimum
        Minimum value. Default: 0

    .PARAMETER Maximum
        Maximum value. Default: 100

    .PARAMETER Value
        Initial value. Default: 0

    .PARAMETER ScaleFactor
        Optional scale factor. If not provided, uses cached value.

    .OUTPUTS
        System.Windows.Forms.NumericUpDown object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $false)]
        [int]$Width = 120,

        [Parameter(Mandatory = $false)]
        [int]$Height = 25,

        [Parameter(Mandatory = $false)]
        [decimal]$Minimum = 0,

        [Parameter(Mandatory = $false)]
        [decimal]$Maximum = 100,

        [Parameter(Mandatory = $false)]
        [decimal]$Value = 0,

        [Parameter(Mandatory = $false)]
        [double]$ScaleFactor
    )

    if (-not $ScaleFactor) {
        $scaleInfo = Get-ResponsiveDPIScale
        $ScaleFactor = $scaleInfo.TotalScale
    }

    $numericUpDown = New-Object System.Windows.Forms.NumericUpDown
    $numericUpDown.Minimum = $Minimum
    $numericUpDown.Maximum = $Maximum
    $numericUpDown.Value = $Value
    $numericUpDown.Location = New-Object System.Drawing.Point(
        (Get-ResponsiveScaledValue -BaseValue $X -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Y -ScaleFactor $ScaleFactor)
    )
    $numericUpDown.Size = New-Object System.Drawing.Size(
        (Get-ResponsiveScaledValue -BaseValue $Width -ScaleFactor $ScaleFactor),
        (Get-ResponsiveScaledValue -BaseValue $Height -ScaleFactor $ScaleFactor)
    )

    return $numericUpDown
}

#endregion

#region Usage Example (commented out - for reference)

<#
.EXAMPLE - Complete Responsive GUI Script

# At the top of your script, load the responsive helper:
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/PowerShellScripts/main/scripts/responsive.ps1'
try {
    Invoke-Expression (Invoke-WebRequest -Uri $responsiveUrl -UseBasicParsing).Content
    Write-Host "Responsive GUI helper loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load responsive GUI helper: $_"
    exit 1
}

# Get scale information
$scaleInfo = Get-ResponsiveDPIScale
Write-Host "Detected: $($scaleInfo.ResolutionName) - Scale Factor: $($scaleInfo.TotalScale)"

# Create responsive form
$form = New-ResponsiveForm -Title "My Responsive Application" -Width 800 -Height 600

# Add responsive controls
$label1 = New-ResponsiveLabel -Text "Name:" -X 20 -Y 20 -Width 100
$textBox1 = New-ResponsiveTextBox -X 130 -Y 20 -Width 250

$label2 = New-ResponsiveLabel -Text "Age:" -X 20 -Y 60 -Width 100
$numAge = New-ResponsiveNumericUpDown -X 130 -Y 60 -Width 120 -Minimum 0 -Maximum 120 -Value 25

$checkBox1 = New-ResponsiveCheckBox -Text "Enable notifications" -X 20 -Y 100 -Width 300

$btnOK = New-ResponsiveButton -Text "OK" -X 20 -Y 140 -Width 100
$btnCancel = New-ResponsiveButton -Text "Cancel" -X 130 -Y 140 -Width 100

# Add controls to form
$form.Controls.AddRange(@($label1, $textBox1, $label2, $numAge, $checkBox1, $btnOK, $btnCancel))

# Add event handlers
$btnOK.Add_Click({
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})

$btnCancel.Add_Click({
    $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Close()
})

# Show the form
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Name: $($textBox1.Text)"
    Write-Host "Age: $($numAge.Value)"
    Write-Host "Notifications: $($checkBox1.Checked)"
}
#>

#endregion

# Note: Functions are automatically available when this script is dot-sourced or loaded via Invoke-Expression
# No Export-ModuleMember needed (that's only for .psm1 module files)

# Script loaded successfully
Write-Verbose "Responsive GUI Helper Script loaded successfully (v1.0.0)"
Write-Verbose "Detected: $((Get-ResponsiveDPIScale).ResolutionName) - Scale Factor: $((Get-ResponsiveDPIScale).TotalScale)"

