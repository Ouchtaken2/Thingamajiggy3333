# Copies the small curated slice of recovered GameMaker assets needed by the
# native port. The full 1 GB dump stays where it is; only these files are
# embedded into the IPA via PortAssets/.
#
# Run from PowerShell:  .\Scripts\import-port-assets.ps1
# Override the dump location with -SourceRoot if your folder layout differs.

param(
    [string]$SourceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "..\frickbears3-4ld-v2.1.5")
)

$ErrorActionPreference = "Stop"

$assetRoot = Join-Path $SourceRoot "Open AI stuff"
$codeRoot = Join-Path $SourceRoot "Export_Code"
$destRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "PortAssets"

if (-not (Test-Path -LiteralPath $assetRoot)) {
    throw "Could not find asset dump at $assetRoot"
}
if (-not (Test-Path -LiteralPath $codeRoot)) {
    throw "Could not find code export at $codeRoot"
}

function Copy-PngFolder {
    param([string]$From, [string]$To)

    if (-not (Test-Path -LiteralPath $From)) {
        throw "Missing sprite folder: $From"
    }
    New-Item -ItemType Directory -Force -Path $To | Out-Null
    Get-ChildItem -LiteralPath $From -File -Filter "*.png" | Copy-Item -Destination $To -Force
}

Copy-PngFolder (Join-Path $assetRoot "sFFS_Tiles")      (Join-Path $destRoot "Fredsweeper\Sprites\sFFS_Tiles")
Copy-PngFolder (Join-Path $assetRoot "sFFS_TilesSmall") (Join-Path $destRoot "Fredsweeper\Sprites\sFFS_TilesSmall")
Copy-PngFolder (Join-Path $assetRoot "sFontGameboy")    (Join-Path $destRoot "Fredsweeper\Fonts\sFontGameboy")

New-Item -ItemType Directory -Force -Path (Join-Path $destRoot "Fredsweeper\Audio") | Out-Null
foreach ($name in @("sfxBitCrunch.ogg", "sfxBitExplosion.ogg", "sfxBitPlace.ogg")) {
    $from = Join-Path $assetRoot "SoundEffects\$name"
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing sound: $from" }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destRoot "Fredsweeper\Audio") -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $destRoot "Rooms") | Out-Null
foreach ($name in @("Office.png", "MinigameMap.png", "FredbearMinigames.png", "Fredbear_MonitorMinigame.png")) {
    $from = Join-Path $assetRoot $name
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing room image: $from" }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destRoot "Rooms") -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $destRoot "Code\Reference") | Out-Null
foreach ($name in @(
    "gml_GlobalScript_MinigameData.gml",
    "gml_Object_oMinigameParent_Create_0.gml",
    "gml_Object_oMinigameParent_Step_1.gml",
    "gml_Object_oMinigame_FreddyFazsweep_Create_0.gml",
    "gml_Object_oMinigame_FreddyFazsweep_Draw_0.gml",
    "gml_Object_oMinigame_GoldenFazsweep_Create_0.gml",
    "gml_Object_oMinigame_GoldenFazsweep_Draw_0.gml"
)) {
    $from = Join-Path $codeRoot $name
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing reference GML: $from" }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destRoot "Code\Reference") -Force
}

Write-Host "Imported curated assets into $destRoot"
Write-Host "Remember to commit PortAssets/ and re-run the IPA workflow."
