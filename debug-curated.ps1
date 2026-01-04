# Debug script to check curated bookmarks loading
$scriptDir = Split-Path -Parent $PSScriptRoot
$bookmarksDir = Join-Path $scriptDir 'bookmarks'

# Load banned-links.psd1
$bannedLinksPath = Join-Path $bookmarksDir 'banned-links.psd1'
Write-Host "Loading: $bannedLinksPath" -ForegroundColor Cyan

try {
    $data = Import-PowerShellDataFile $bannedLinksPath
    Write-Host "SUCCESS! Top-level keys: $($data.Keys -join ', ')" -ForegroundColor Green
    
    if ($data.ContainsKey('OSINT')) {
        Write-Host "`nOSINT structure:" -ForegroundColor Yellow
        Write-Host "  Type: $($data.OSINT.GetType().Name)"
        Write-Host "  Keys: $($data.OSINT.Keys -join ', ')"
        
        foreach ($key in $data.OSINT.Keys) {
            $value = $data.OSINT[$key]
            Write-Host "`n  $key :" -ForegroundColor Cyan
            Write-Host "    Type: $($value.GetType().Name)"
            if ($value -is [hashtable]) {
                Write-Host "    Keys: $($value.Keys -join ', ')"
            } elseif ($value -is [array]) {
                Write-Host "    Count: $($value.Count)"
            }
        }
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Now simulate what bookmarks.ps1 does
Write-Host "`n=== Simulating bookmarks.ps1 merge ===" -ForegroundColor Magenta

$CuratedBookmarks = @{}

# Simulate loading with MergePath = ''
$dataToMerge = $data
$mergeTarget = $CuratedBookmarks

foreach ($key in $dataToMerge.Keys) {
    if ($mergeTarget.ContainsKey($key)) {
        Write-Host "Merging into existing key: $key"
    } else {
        $mergeTarget[$key] = $dataToMerge[$key]
        Write-Host "Added new key: $key"
    }
}

Write-Host "`nCuratedBookmarks keys: $($CuratedBookmarks.Keys -join ', ')" -ForegroundColor Green

if ($CuratedBookmarks.ContainsKey('OSINT')) {
    Write-Host "OSINT is present in CuratedBookmarks!" -ForegroundColor Green
    Write-Host "OSINT type: $($CuratedBookmarks.OSINT.GetType().Name)"
    Write-Host "OSINT keys: $($CuratedBookmarks.OSINT.Keys -join ', ')"
} else {
    Write-Host "OSINT is NOT in CuratedBookmarks!" -ForegroundColor Red
}

