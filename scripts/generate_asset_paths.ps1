# Target path relative to project root
$AssetRoot = "assets/vectors"

# Fallback path if primary doesn't exist
$FallbackRoot = "../assets/vectors"

function Get-RelativeDirs {
    param($basePath)
    return Get-ChildItem -Path $basePath -Directory | ForEach-Object {
        $relative = Join-Path $basePath $_.Name
        "    - $relative/"
    }
}

if (Test-Path $AssetRoot) {
    $dirs = Get-RelativeDirs -basePath $AssetRoot
}
elseif (Test-Path $FallbackRoot) {
    Write-Host "Primary path not found. Using fallback path: $FallbackRoot"
    $dirs = Get-RelativeDirs -basePath $FallbackRoot
}
else {
    Write-Error "Neither '$AssetRoot' nor '$FallbackRoot' could be found."
    exit 1
}

$dirs | Set-Content -Encoding UTF8 asset_paths.txt
Write-Host "Generated asset_paths.txt with $($dirs.Count) entries."
