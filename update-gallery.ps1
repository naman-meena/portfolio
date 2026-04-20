# update-gallery.ps1
# Scans photo folders and updates GALLERY_DATA + PROJECTS_DATA in index.html automatically.
# Usage: .\update-gallery.ps1
#   then: git add -A; git commit -m "Add new photos"; git push

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$htmlFile = Join-Path $root "index.html"
$extensions = @('.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif')
$ignoreFolders = @('.git', '.github', 'images', 'node_modules', 'projects')

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

# Discover project story folders in /projects
$projectsRoot = Join-Path $root "projects"
$projectEntries = @()
if (Test-Path $projectsRoot) {
    Get-ChildItem -Path $projectsRoot -Directory |
        ForEach-Object {
            $projectFolder = $_.Name
            $images = Get-ChildItem -Path $_.FullName -File |
                Where-Object { $extensions -contains $_.Extension.ToLower() } |
                Sort-Object Name

            if ($images.Count -gt 0) {
                $coverPath = "projects/$projectFolder/$($images[0].Name)"
                $safeName = $projectFolder -replace '"', '\\"'
                $imagePaths = $images | ForEach-Object {
                    $path = "projects/$projectFolder/$($_.Name)"
                    "`"$($path -replace '"', '\\"')`""
                }
                $imagesManifest = "[" + ($imagePaths -join ", ") + "]"
                $projectEntries += "    { `"name`": `"$safeName`", `"cover`": `"$coverPath`", `"count`": $($images.Count), `"images`": $imagesManifest }"
            }
        }
}

$projectsManifest = if ($projectEntries.Count -gt 0) {
    "  const PROJECTS_DATA = [`n" + ($projectEntries -join ",`n") + "`n  ];"
} else {
    "  const PROJECTS_DATA = [];"
}

# Read the HTML file
$html = Get-Content $htmlFile -Raw -Encoding UTF8

# Replace the GALLERY_DATA block
$pattern = '(?s)  const GALLERY_DATA = \[.*?\];'
if ($html -match $pattern) {
    $html = $html -replace $pattern, $manifest

    $projectPattern = '(?s)  const PROJECTS_DATA = \[.*?\];|  const PROJECTS_DATA = \[\];'
    if ($html -match $projectPattern) {
        $html = $html -replace $projectPattern, $projectsManifest
    } else {
        $html = $html -replace '(?s)(  const GALLERY_DATA = \[.*?\];)', "$1`r`n`r`n$projectsManifest"
    }

    [System.IO.File]::WriteAllText($htmlFile, $html, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated GALLERY_DATA with $($entries.Count) images:" -ForegroundColor Green
    $entries | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
    Write-Host "Updated PROJECTS_DATA with $($projectEntries.Count) project(s)." -ForegroundColor Green
} else {
    Write-Host "ERROR: Could not find GALLERY_DATA in index.html" -ForegroundColor Red
}
