#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

# Step 1: Create the source VM (VM-01)
Write-Host "`n=== Creating source VM with vm-new.ps1 ===" -ForegroundColor Magenta
& "$PSScriptRoot\vm-new.ps1"

# Step 2: Clone VM-01 six times to create VM-02 through VM-07
$source = 'VM-01'
for ($i = 2; $i -le 7; $i++) {
    $dest = 'VM-{0:D2}' -f $i
    Write-Host "`n=== Cloning $source -> $dest ($($i-1) of 6) ===" -ForegroundColor Magenta
    & "$PSScriptRoot\vm-copy.ps1" -SourceVMName $source -DestinationVMName $dest -Confirm:$false -Append
}

Write-Host "`n=== All done ===" -ForegroundColor Magenta
Get-VM | Format-Table Name, State, Generation, MemoryStartup -AutoSize

