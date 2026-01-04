# Check Chrome bookmarks structure
$chromePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"
$json = Get-Content $chromePath -Raw | ConvertFrom-Json
$myTech = $json.roots.bookmark_bar.children | Where-Object { $_.name -eq 'myTech.Today' }

Write-Host "=== myTech.Today Top-Level Folders ===" -ForegroundColor Cyan
$myTech.children | ForEach-Object { Write-Host "  - $($_.name)" }

# Check for OSINT
$osint = $myTech.children | Where-Object { $_.name -eq 'OSINT' }
if ($osint) {
    Write-Host "`n=== OSINT Structure ===" -ForegroundColor Green
    $osint.children | ForEach-Object {
        Write-Host "  > $($_.name)" -ForegroundColor Yellow
        if ($_.children) {
            $_.children | ForEach-Object { Write-Host "    - $($_.name)" }
        }
    }
} else {
    Write-Host "`nOSINT folder NOT FOUND!" -ForegroundColor Red
}

# Check News for International News
$news = $myTech.children | Where-Object { $_.name -eq 'News' }
if ($news) {
    Write-Host "`n=== News Structure ===" -ForegroundColor Green
    $news.children | ForEach-Object {
        Write-Host "  > $($_.name)" -ForegroundColor Yellow
        if ($_.name -eq 'International News' -and $_.children) {
            $_.children | Select-Object -First 5 | ForEach-Object {
                Write-Host "    - $($_.name)"
            }
            if ($_.children.Count -gt 5) {
                Write-Host "    ... and $($_.children.Count - 5) more regions"
            }
        }
    }
}

