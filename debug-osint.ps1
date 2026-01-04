# Debug script to test recursive bookmark loading
Write-Host "=== Testing Recursive ConvertTo-BookmarkNodes ===" -ForegroundColor Cyan

# Test with banned-links.psd1 (3 levels deep)
Write-Host "`n--- banned-links.psd1 ---" -ForegroundColor Yellow
$data = Import-PowerShellDataFile 'bookmarks/banned-links.psd1'
Write-Host "Root keys: $($data.Keys -join ', ')"

function Show-Structure {
    param($Data, $Indent = 0)
    $prefix = "  " * $Indent

    if ($Data -is [array]) {
        Write-Host "$prefix[Array with $($Data.Count) bookmarks]" -ForegroundColor Green
        foreach ($item in $Data | Select-Object -First 2) {
            Write-Host "$prefix  - $($item.Title)" -ForegroundColor DarkGray
        }
        if ($Data.Count -gt 2) { Write-Host "$prefix  ... and $($Data.Count - 2) more" -ForegroundColor DarkGray }
    }
    elseif ($Data -is [hashtable]) {
        foreach ($key in $Data.Keys) {
            Write-Host "$prefix$key" -ForegroundColor White
            Show-Structure -Data $Data[$key] -Indent ($Indent + 1)
        }
    }
}

Show-Structure -Data $data

# Test with europe.ps1 (4 levels deep)
Write-Host "`n--- europe.ps1 (first country only) ---" -ForegroundColor Yellow
$europeData = Invoke-Expression (Get-Content 'bookmarks/europe.ps1' -Raw)
Write-Host "Root keys: $($europeData.Keys -join ', ')"
$firstCountry = $europeData['Europe'].Keys | Select-Object -First 1
Write-Host "First country: $firstCountry"
$countryData = @{ $firstCountry = $europeData['Europe'][$firstCountry] }
Show-Structure -Data $countryData

# Test with africa.psd1 (2 levels)
Write-Host "`n--- africa.psd1 ---" -ForegroundColor Yellow
$africaData = Import-PowerShellDataFile 'bookmarks/africa.psd1'
Write-Host "Root keys: $($africaData.Keys -join ', ')"
Show-Structure -Data $africaData

