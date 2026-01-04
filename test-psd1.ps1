# Test parsing of .psd1 files
$files = @(
    'bookmarks/australasia.psd1',
    'bookmarks/north_america.psd1',
    'bookmarks/south_america.psd1',
    'bookmarks/banned-links.psd1'
)

foreach ($file in $files) {
    Write-Host "Testing: $file" -ForegroundColor Cyan
    try {
        $content = Get-Content $file -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  ERROR: File is empty" -ForegroundColor Red
            continue
        }
        $data = Invoke-Expression $content
        if ($data -is [hashtable]) {
            Write-Host "  OK - Root keys: $($data.Keys -join ', ')" -ForegroundColor Green
        } else {
            Write-Host "  ERROR: Not a hashtable (type: $($data.GetType().Name))" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

