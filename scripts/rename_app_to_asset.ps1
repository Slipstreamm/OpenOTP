# Apple won't accept the build if you have files or directories ending with .app

# Set paths
$assetsDir = "assets/vectors"
$yamlFile = "pubspec.yaml"

# Get all directories ending with .app
$folders = Get-ChildItem -Path $assetsDir -Recurse -Directory | Where-Object { $_.Name -like '*.app' }

foreach ($folder in $folders) {
    $oldName = $folder.FullName
    $newName = $oldName -replace '\.app$', '.asset'

    # Rename the directory
    Rename-Item -Path $oldName -NewName (Split-Path $newName -Leaf)

    # Update the YAML file
    $escapedOldPath = ($oldName -replace '\\', '/').Replace($PWD.Path.Replace('\', '/') + '/', '')
    $escapedNewPath = ($newName -replace '\\', '/').Replace($PWD.Path.Replace('\', '/') + '/', '')

    # Escape for YAML (if needed)
    (Get-Content $yamlFile) | ForEach-Object {
        $_ -replace [regex]::Escape($escapedOldPath), $escapedNewPath
    } | Set-Content $yamlFile
}

Write-Host "Finished renaming .app folders and updating pubspec.yaml"
