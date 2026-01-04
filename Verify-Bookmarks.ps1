# Verify-Bookmarks.ps1 - Check if myTech.Today bookmarks exist in browsers

Write-Host "=== CHROME ===" -ForegroundColor Cyan
$chromePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"
if (Test-Path $chromePath) {
    $json = Get-Content $chromePath -Raw | ConvertFrom-Json
    $myTechFolder = $json.roots.bookmark_bar.children | Where-Object { $_.name -eq "myTech.Today" }
    if ($myTechFolder) {
        Write-Host "  FOUND myTech.Today folder!" -ForegroundColor Green
        Write-Host "  Top-level subfolders: $($myTechFolder.children.Count)" -ForegroundColor Yellow
        $myTechFolder.children | ForEach-Object {
            Write-Host "    - $($_.name)" -ForegroundColor White
            # Show OSINT subfolders
            if ($_.name -eq 'OSINT' -and $_.children) {
                Write-Host "      OSINT subfolders:" -ForegroundColor Magenta
                $_.children | ForEach-Object {
                    Write-Host "        - $($_.name)" -ForegroundColor Gray
                }
            }
            # Show News subfolders
            if ($_.name -eq 'News' -and $_.children) {
                Write-Host "      News subfolders:" -ForegroundColor Magenta
                $_.children | ForEach-Object {
                    Write-Host "        - $($_.name)" -ForegroundColor Gray
                    # Show International News subfolders
                    if ($_.name -eq 'International News' -and $_.children) {
                        Write-Host "          International News regions:" -ForegroundColor DarkGray
                        $_.children | Select-Object -First 10 | ForEach-Object {
                            Write-Host "            - $($_.name)" -ForegroundColor DarkGray
                        }
                        if ($_.children.Count -gt 10) {
                            Write-Host "            ... and $($_.children.Count - 10) more" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "  myTech.Today folder NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "  Chrome bookmarks file not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== BRAVE ===" -ForegroundColor Cyan
$bravePath = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"
if (Test-Path $bravePath) {
    $json = Get-Content $bravePath -Raw | ConvertFrom-Json
    $myTechFolder = $json.roots.bookmark_bar.children | Where-Object { $_.name -eq "myTech.Today" }
    if ($myTechFolder) {
        Write-Host "  FOUND myTech.Today folder!" -ForegroundColor Green
        Write-Host "  Subfolders: $($myTechFolder.children.Count)"
        $myTechFolder.children | Select-Object -First 5 | ForEach-Object { Write-Host "    - $($_.name)" }
    } else {
        Write-Host "  myTech.Today folder NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "  Brave bookmarks file not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== FIREFOX ===" -ForegroundColor Cyan
$ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
if ($ffProfiles) {
    foreach ($profile in $ffProfiles) {
        $placesDb = Join-Path $profile.FullName "places.sqlite"
        if (Test-Path $placesDb) {
            Write-Host "  Found Firefox profile: $($profile.Name)" -ForegroundColor Green
            # Check the backup HTML file we created
            $backupDir = Join-Path $env:USERPROFILE "myTech.Today\Backups"
            $ffBackups = Get-ChildItem $backupDir -Directory -Filter "Firefox*" -ErrorAction SilentlyContinue
            if ($ffBackups) {
                Write-Host "  Firefox backup directories found:" -ForegroundColor Green
                foreach ($backup in $ffBackups) {
                    Write-Host "    - $($backup.Name)"
                    $htmlFiles = Get-ChildItem $backup.FullName -Filter "*.html" -ErrorAction SilentlyContinue
                    if ($htmlFiles) {
                        $content = Get-Content $htmlFiles[0].FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -match "myTech\.Today") {
                            Write-Host "      Contains myTech.Today bookmarks!" -ForegroundColor Green
                        }
                    }
                }
            }
            break
        }
    }
} else {
    Write-Host "  Firefox profiles not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Magenta

