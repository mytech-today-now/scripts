#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

# Remove ALL Hyper-V VMs (stop first if running, then remove VM and VHDX files)
$vms = Get-VM
if ($vms) {
    foreach ($vm in $vms) {
        Write-Host "Processing VM: $($vm.Name) (State: $($vm.State))" -ForegroundColor Yellow

        # Stop if running
        if ($vm.State -eq 'Running' -or $vm.State -eq 'Paused') {
            Write-Host "  Stopping VM..." -ForegroundColor Cyan
            Stop-VM -Name $vm.Name -Force -TurnOff
        }

        # Get VHD paths before removing VM
        $vhds = Get-VMHardDiskDrive -VMName $vm.Name | Select-Object -ExpandProperty Path

        # Remove the VM
        Write-Host "  Removing VM..." -ForegroundColor Cyan
        Remove-VM -Name $vm.Name -Force

        # Remove associated VHDX files
        foreach ($vhd in $vhds) {
            if (Test-Path $vhd) {
                Write-Host "  Removing VHDX: $vhd" -ForegroundColor Cyan
                Remove-Item -LiteralPath $vhd -Force
            }
        }

        Write-Host "  Done." -ForegroundColor Green
    }
    Write-Host "`nAll VMs removed." -ForegroundColor Green
} else {
    Write-Host "No VMs found." -ForegroundColor Green
}

