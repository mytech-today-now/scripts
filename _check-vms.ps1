#Requires -RunAsAdministrator
$outFile = Join-Path $PSScriptRoot '_check-output.txt'
try {
    Write-Host "=== Copying VM-01 to VM-02 ===" -ForegroundColor Cyan
    & "$PSScriptRoot\Copy-VM.ps1" -SourceVMName 'VM-01' -DestinationVMName 'VM-02' -Confirm:$false 2>&1 | Tee-Object -Variable output
    $output | Out-String | Set-Content $outFile
    Write-Host "`nDone." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    "ERROR: $_" | Set-Content $outFile
}
Write-Host "`nPress any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

