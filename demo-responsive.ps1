<#
.SYNOPSIS
    Demo script showing how to use the responsive.ps1 helper script.

.DESCRIPTION
    This demo script demonstrates how to load and use the responsive.ps1 helper
    to create a fully responsive Windows Forms GUI that works on all screen
    resolutions from VGA (640x480) to 8K UHD (7680x4320).

.NOTES
    File Name      : demo-responsive.ps1
    Author         : myTech.Today
    Prerequisite   : PowerShell 5.1 or later
    Copyright      : (c) 2025 myTech.Today. All rights reserved.
    Version        : 1.0.0

.LINK
    https://github.com/mytech-today-now/PowerShellScripts
#>

#Requires -Version 5.1

# Method 1: Load from GitHub (recommended for production)
Write-Host "[INFO] Loading responsive GUI helper from GitHub..." -ForegroundColor Cyan
$responsiveUrl = 'https://raw.githubusercontent.com/mytech-today-now/scripts/refs/heads/main/responsive.ps1'

try {
    Invoke-Expression (Invoke-WebRequest -Uri $responsiveUrl -UseBasicParsing).Content
    Write-Host "[OK] Responsive GUI helper loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Failed to load from GitHub, trying local path..." -ForegroundColor Yellow
    
    # Method 2: Fallback to local path
    $localPath = Join-Path $PSScriptRoot "responsive.ps1"
    if (Test-Path $localPath) {
        . $localPath
        Write-Host "[OK] Responsive GUI helper loaded from local path" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] Failed to load responsive GUI helper: $_" -ForegroundColor Red
        exit 1
    }
}

# Get and display scale information
$scaleInfo = Get-ResponsiveDPIScale
Write-Host "`n[INFO] Screen Information:" -ForegroundColor Cyan
Write-Host "  Resolution: $($scaleInfo.ScreenWidth)x$($scaleInfo.ScreenHeight)" -ForegroundColor White
Write-Host "  Category: $($scaleInfo.ResolutionName)" -ForegroundColor White
Write-Host "  Scale Factor: $($scaleInfo.TotalScale)x" -ForegroundColor White
Write-Host "  Base DPI: $($scaleInfo.BaseFactor)x" -ForegroundColor White
Write-Host "  Additional Scale: $($scaleInfo.AdditionalScale)x`n" -ForegroundColor White

# Create a responsive form
Write-Host "[INFO] Creating responsive GUI..." -ForegroundColor Cyan
$form = New-ResponsiveForm -Title "Responsive GUI Demo - myTech.Today" -Width 600 -Height 400

# Add title label
$lblTitle = New-ResponsiveLabel -Text "Responsive GUI Demo" -X 20 -Y 20 -Width 560 -Height 30
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

# Add info label
$lblInfo = New-ResponsiveLabel -Text "This GUI automatically adapts to your screen resolution!" -X 20 -Y 60 -Width 560 -Height 25
$lblInfo.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

# Add resolution info label
$lblResolution = New-ResponsiveLabel -Text "Detected: $($scaleInfo.ResolutionName) - Scale: $($scaleInfo.TotalScale)x" -X 20 -Y 90 -Width 560 -Height 25
$lblResolution.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblResolution.ForeColor = [System.Drawing.Color]::Blue

# Add separator line (using a label)
$lblSeparator = New-ResponsiveLabel -Text "" -X 20 -Y 125 -Width 560 -Height 2
$lblSeparator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D

# Add form fields
$yPos = 140

# Name field
$lblName = New-ResponsiveLabel -Text "Name:" -X 20 -Y $yPos -Width 120
$txtName = New-ResponsiveTextBox -X 150 -Y $yPos -Width 430
$yPos += 40

# Email field
$lblEmail = New-ResponsiveLabel -Text "Email:" -X 20 -Y $yPos -Width 120
$txtEmail = New-ResponsiveTextBox -X 150 -Y $yPos -Width 430
$yPos += 40

# Age field
$lblAge = New-ResponsiveLabel -Text "Age:" -X 20 -Y $yPos -Width 120
$numAge = New-ResponsiveNumericUpDown -X 150 -Y $yPos -Width 120 -Minimum 0 -Maximum 120 -Value 25
$yPos += 40

# Role dropdown
$lblRole = New-ResponsiveLabel -Text "Role:" -X 20 -Y $yPos -Width 120
$cmbRole = New-ResponsiveComboBox -X 150 -Y $yPos -Width 200 -Items @("Administrator", "User", "Guest", "Developer") -SelectedIndex 1
$yPos += 40

# Notifications checkbox
$chkNotifications = New-ResponsiveCheckBox -Text "Enable email notifications" -X 150 -Y $yPos -Width 300 -Checked $true
$yPos += 40

# Progress bar (just for demo)
$lblProgress = New-ResponsiveLabel -Text "Progress:" -X 20 -Y $yPos -Width 120
$progressBar = New-ResponsiveProgressBar -X 150 -Y $yPos -Width 430 -Value 75
$yPos += 50

# Buttons
$btnOK = New-ResponsiveButton -Text "OK" -X 150 -Y $yPos -Width 120
$btnCancel = New-ResponsiveButton -Text "Cancel" -X 280 -Y $yPos -Width 120
$btnTest = New-ResponsiveButton -Text "Test Progress" -X 410 -Y $yPos -Width 120

# Add all controls to form
$form.Controls.AddRange(@(
    $lblTitle, $lblInfo, $lblResolution, $lblSeparator,
    $lblName, $txtName,
    $lblEmail, $txtEmail,
    $lblAge, $numAge,
    $lblRole, $cmbRole,
    $chkNotifications,
    $lblProgress, $progressBar,
    $btnOK, $btnCancel, $btnTest
))

# Add event handlers
$btnOK.Add_Click({
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})

$btnCancel.Add_Click({
    $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Close()
})

$btnTest.Add_Click({
    # Animate progress bar
    for ($i = 0; $i -le 100; $i += 5) {
        $progressBar.Value = $i
        $form.Refresh()
        Start-Sleep -Milliseconds 50
    }
    [System.Windows.Forms.MessageBox]::Show("Progress test complete!", "Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    $progressBar.Value = 75
})

# Show the form
Write-Host "[INFO] Displaying responsive GUI..." -ForegroundColor Cyan
$result = $form.ShowDialog()

# Display results
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "`n[OK] Form submitted successfully!" -ForegroundColor Green
    Write-Host "`nForm Data:" -ForegroundColor Cyan
    Write-Host "  Name: $($txtName.Text)" -ForegroundColor White
    Write-Host "  Email: $($txtEmail.Text)" -ForegroundColor White
    Write-Host "  Age: $($numAge.Value)" -ForegroundColor White
    Write-Host "  Role: $($cmbRole.SelectedItem)" -ForegroundColor White
    Write-Host "  Notifications: $($chkNotifications.Checked)" -ForegroundColor White
}
else {
    Write-Host "`n[INFO] Form cancelled by user" -ForegroundColor Yellow
}

Write-Host "`n[INFO] Demo complete!" -ForegroundColor Cyan

