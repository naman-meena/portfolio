# update-gallery.ps1
# Scans photo folders and updates the GALLERY_DATA in index.html automatically.
# Usage: .\update-gallery.ps1
#   then: git add -A; git commit -m "Add new photos"; git push

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$htmlFile = Join-Path $root "index.html"
$extensions = @('.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif')
$ignoreFolders = @('.git', '.github', 'images', 'node_modules')

# Discover all image files in category folders
$entries = @()
Get-ChildItem -Path $root -Directory |
    Where-Object { $ignoreFolders -notcontains $_.Name } |
    ForEach-Object {
        $category = $_.Name.ToLower()
        Get-ChildItem -Path $_.FullName -File |
            Where-Object { $extensions -contains $_.Extension.ToLower() } |
            ForEach-Object {
                $relativePath = "$category/$($_.Name)"
                $entries += "    { `"category`": `"$category`", `"file`": `"$relativePath`" }"
            }
    }

if ($entries.Count -eq 0) {
    Write-Host "No images found in any folder. Nothing to update." -ForegroundColor Yellow
    exit
}

$manifest = "  const GALLERY_DATA = [`n" + ($entries -join ",`n") + "`n  ];"

# Read the HTML file
$html = Get-Content $htmlFile -Raw -Encoding UTF8

# Replace the GALLERY_DATA block
$pattern = '(?s)  const GALLERY_DATA = \[.*?\];'
if ($html -match $pattern) {
    $html = $html -replace $pattern, $manifest
    [System.IO.File]::WriteAllText($htmlFile, $html, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated GALLERY_DATA with $($entries.Count) images:" -ForegroundColor Green
    $entries | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
} else {
    Write-Host "ERROR: Could not find GALLERY_DATA in index.html" -ForegroundColor Red
}
