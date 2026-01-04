# Debug script to test ConvertTo-BookmarkNodes with OSINT data
$scriptDir = Split-Path -Parent $PSScriptRoot
$bookmarksDir = Join-Path $scriptDir 'bookmarks'

# Load banned-links.psd1
$bannedLinksPath = Join-Path $bookmarksDir 'banned-links.psd1'
$data = Import-PowerShellDataFile $bannedLinksPath

Write-Host "OSINT data structure:" -ForegroundColor Cyan
Write-Host "  OSINT type: $($data.OSINT.GetType().Name)"
Write-Host "  OSINT keys: $($data.OSINT.Keys -join ', ')"

# Define the helper functions from bookmarks.ps1
function New-BookmarkUrlNode {
    param([string]$Name, [string]$Url, [string]$Icon)
    $node = [PSCustomObject]@{
        type = 'url'
        name = $Name
        url  = $Url
    }
    if ($Icon) { $node | Add-Member -NotePropertyName 'icon' -NotePropertyValue $Icon }
    return $node
}

function New-BookmarkSubfolder {
    param([string]$Name, [array]$Children)
    return [PSCustomObject]@{
        type     = 'folder'
        name     = $Name
        children = $Children
    }
}

function ConvertTo-BookmarkNodes {
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        [int]$Depth = 0
    )

    $nodes = @()
    $indent = "  " * $Depth

    if ($Data -is [array]) {
        Write-Host "${indent}Processing ARRAY with $($Data.Count) items" -ForegroundColor Yellow
        foreach ($bookmark in $Data) {
            if (-not $bookmark) { continue }
            $title = $bookmark.Title
            $url   = $bookmark.URL
            if ($null -eq $title -or $null -eq $url) { continue }
            $nodes += New-BookmarkUrlNode -Name $title -Url $url
            Write-Host "${indent}  Created URL node: $title" -ForegroundColor Gray
        }
    }
    elseif ($Data -is [hashtable]) {
        Write-Host "${indent}Processing HASHTABLE with keys: $($Data.Keys -join ', ')" -ForegroundColor Cyan
        foreach ($key in $Data.Keys) {
            $value = $Data[$key]
            if (-not $value) { continue }
            Write-Host "${indent}  Key: $key (value type: $($value.GetType().Name))" -ForegroundColor White
            $childNodes = ConvertTo-BookmarkNodes -Data $value -Depth ($Depth + 1)
            Write-Host "${indent}  Got $($childNodes.Count) child nodes for '$key'" -ForegroundColor Magenta
            if ($childNodes.Count -gt 0) {
                $subfolder = New-BookmarkSubfolder -Name $key -Children $childNodes
                $nodes += $subfolder
            }
        }
    }
    else {
        Write-Host "${indent}UNKNOWN type: $($Data.GetType().Name)" -ForegroundColor Red
    }

    return $nodes
}

Write-Host "`n=== Converting OSINT data ===" -ForegroundColor Green
$osintData = $data.OSINT
$result = ConvertTo-BookmarkNodes -Data $osintData -Depth 0

Write-Host "`n=== Result ===" -ForegroundColor Green
Write-Host "Result type: $($result.GetType().Name)"
Write-Host "Result is null: $($null -eq $result)"
Write-Host "Result count: $($result.Count)"

if ($result) {
    # Force array context
    $resultArray = @($result)
    Write-Host "Result array count: $($resultArray.Count)"
    foreach ($node in $resultArray) {
        Write-Host "  - $($node.name) (type: $($node.type))"
        if ($node.children) {
            foreach ($child in $node.children) {
                Write-Host "    - $($child.name) (type: $($child.type))"
            }
        }
    }
} else {
    Write-Host "NO NODES CREATED!" -ForegroundColor Red
}

