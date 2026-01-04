# Count braces in .psd1 files
$files = @('bookmarks/australasia.psd1', 'bookmarks/north_america.psd1')

foreach ($file in $files) {
    $content = Get-Content $file -Raw
    $open = ([regex]::Matches($content, '@\{')).Count
    $close = ([regex]::Matches($content, '\}')).Count
    Write-Host "$file :"
    Write-Host "  Open @{: $open"
    Write-Host "  Close }: $close"
    if ($open -ne $close) {
        $diff = $open - $close
        Write-Host "  IMBALANCE: $diff more opens than closes" -ForegroundColor Red
    }
    Write-Host ""
}

