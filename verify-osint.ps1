# Verify OSINT folder in Chrome bookmarks
$chromePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"
$json = Get-Content $chromePath -Raw | ConvertFrom-Json
$myTech = $json.roots.bookmark_bar.children | Where-Object { $_.name -eq 'myTech.Today' }

Write-Host "=== myTech.Today Top-Level Folders ===" -ForegroundColor Cyan
$myTech.children | ForEach-Object { Write-Host "  - $($_.name)" }

# Check for OSINT
$osint = $myTech.children | Where-Object { $_.name -eq 'OSINT' }
if ($osint) {
    Write-Host "`n=== OSINT Structure ===" -ForegroundColor Green
    Write-Host "OSINT type: $($osint.type)"
    Write-Host "OSINT children count: $($osint.children.Count)"
    $osint.children | ForEach-Object {
        Write-Host "  > $($_.name) (type: $($_.type))" -ForegroundColor Yellow
        if ($_.children) {
            $_.children | ForEach-Object { 
                Write-Host "    - $($_.name) (type: $($_.type))"
                if ($_.children) {
                    $_.children | Select-Object -First 3 | ForEach-Object {
                        Write-Host "      * $($_.name)"
                    }
                }
            }
        }
    }
} else {
    Write-Host "`nOSINT folder NOT FOUND!" -ForegroundColor Red
}

# Check International News
$news = $myTech.children | Where-Object { $_.name -eq 'News' }
if ($news) {
    $intlNews = $news.children | Where-Object { $_.name -eq 'International News' }
    if ($intlNews) {
        Write-Host "`n=== International News Regions ===" -ForegroundColor Green
        Write-Host "Region count: $($intlNews.children.Count)"
        $intlNews.children | Select-Object -First 10 | ForEach-Object {
            Write-Host "  - $($_.name)"
        }
        if ($intlNews.children.Count -gt 10) {
            Write-Host "  ... and $($intlNews.children.Count - 10) more"
        }
    }
}

