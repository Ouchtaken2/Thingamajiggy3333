# Refreshes the HTML shell bundled in the IPA from the standalone browser
# loader. The game runtime/assets themselves are fetched from the pinned CDN
# at runtime, so there is no longer any web-build download step.
#
# Run from PowerShell:  .\Scripts\sync-loader.ps1

$ErrorActionPreference = "Stop"

$source = Join-Path (Split-Path -Parent $PSScriptRoot) "..\frickbears3-4ld-v215-loader\index.html"
$dest = Join-Path (Split-Path -Parent $PSScriptRoot) "Game\index.html"

if (-not (Test-Path $source)) {
    throw "Could not find the browser loader at $source"
}

Copy-Item -Force $source $dest
Write-Host "Copied $source -> $dest"
Write-Host "Remember to commit Game/index.html and re-run the IPA workflow."
