# Copies the small curated slice of recovered GameMaker assets needed by the
# native port. The full ~1 GB dump stays where it is; only these files are
# embedded into the IPA via PortAssets/.
#
# Run from PowerShell:  .\Scripts\import-port-assets.ps1
# Override the dump location with -SourceRoot if your folder layout differs.
# See Scripts/export-port-assets.ps1 for how to reproduce the source exports.

param(
    [string]$SourceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "..\frickbears3-4ld-v2.2.2"),
    [string]$RoomPngRoot,
    [string]$VanillaLabel = "Vanilla-2.2.2"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $SourceRoot "Open AI stuff"
$spriteRoot = Join-Path $assetRoot "Sprites"
$soundRoot = Join-Path $assetRoot "SoundEffects"
$codeRoot = Join-Path $SourceRoot "Export_Code"
$destRoot = Join-Path $projectRoot "PortAssets"
if (-not $RoomPngRoot) {
    $RoomPngRoot = Join-Path $SourceRoot "Export_Rooms"
}

foreach ($required in @($assetRoot, $spriteRoot, $soundRoot, $codeRoot)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Could not find export at $required"
    }
}

# The flat sprite export from UMT 0.9.2.0 writes sName_0.png at the root of
# Sprites\. Older dumps used one folder per sprite. Support both layouts.
function Copy-SpriteSet {
    param(
        [string]$Prefix,
        [string]$Destination,
        [int]$ExpectedCount
    )

    $nested = Join-Path $spriteRoot $Prefix.TrimEnd("_")
    if (Test-Path -LiteralPath $nested) {
        $files = @(Get-ChildItem -LiteralPath $nested -File -Filter "*.png")
    }
    else {
        $files = @(Get-ChildItem -LiteralPath $spriteRoot -File -Filter "$Prefix*.png")
    }

    if ($files.Count -lt $ExpectedCount) {
        throw "Expected at least $ExpectedCount frames for $Prefix, found $($files.Count)"
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Destination -File -Filter "*.png" | Remove-Item -Force
    $files | Copy-Item -Destination $Destination -Force
    Write-Host "Sprites: $($files.Count) frames -> $Destination"
}

Copy-SpriteSet "sFFS_Tiles_"      (Join-Path $destRoot "Fredsweeper\Sprites\sFFS_Tiles")     17
Copy-SpriteSet "sFFS_TilesSmall_" (Join-Path $destRoot "Fredsweeper\Sprites\sFFS_TilesSmall") 15
Copy-SpriteSet "sFontGameboy_"    (Join-Path $destRoot "Fredsweeper\Fonts\sFontGameboy")      80

New-Item -ItemType Directory -Force -Path (Join-Path $destRoot "Fredsweeper\Audio") | Out-Null
foreach ($name in @("sfxBitCrunch.ogg", "sfxBitExplosion.ogg", "sfxBitPlace.ogg")) {
    $from = Join-Path $soundRoot $name
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing sound: $from" }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destRoot "Fredsweeper\Audio") -Force
}
Write-Host "Sounds: 3 SFX copied"

# Room previews are the one export that needs the UMT GUI renderer. If a fresh
# Export_Rooms folder is available, use it; otherwise keep the existing legacy
# previews so the curated bundle stays complete.
$roomNames = @("Office.png", "MinigameMap.png", "FredbearMinigames.png", "Fredbear_MonitorMinigame.png")
$roomFiles = @()
if (Test-Path -LiteralPath $RoomPngRoot) {
    $roomFiles = @($roomNames | ForEach-Object { Join-Path $RoomPngRoot $_ } | Where-Object { Test-Path -LiteralPath $_ })
}
if ($roomFiles.Count -eq $roomNames.Count) {
    New-Item -ItemType Directory -Force -Path (Join-Path $destRoot "Rooms") | Out-Null
    $roomFiles | Copy-Item -Destination (Join-Path $destRoot "Rooms") -Force
    Write-Host "Rooms: copied 2.2.2 previews from $RoomPngRoot"
}
else {
    Write-Host "Rooms: no complete 2.2.2 export at $RoomPngRoot; keeping existing previews"
}

# Code/Reference holds hand-edited touch-control GML and is NEVER overwritten.
# Vanilla decompilation goes to its own folder for comparison only.
$referenceRoot = Join-Path $destRoot "Code\Reference"
if (-not (Test-Path -LiteralPath $referenceRoot)) {
    throw "Missing custom code reference at $referenceRoot"
}
$vanillaRoot = Join-Path $destRoot "Code\$VanillaLabel"
New-Item -ItemType Directory -Force -Path $vanillaRoot | Out-Null
Get-ChildItem -LiteralPath $vanillaRoot -File -Filter "*.gml" | Remove-Item -Force
$referenceGml = @(
    "gml_GlobalScript_MinigameData.gml",
    "gml_Object_oMinigameParent_Create_0.gml",
    "gml_Object_oMinigameParent_Step_1.gml",
    "gml_Object_oMinigame_FreddyFazsweep_Create_0.gml",
    "gml_Object_oMinigame_FreddyFazsweep_Draw_0.gml",
    "gml_Object_oMinigame_GoldenFazsweep_Create_0.gml",
    "gml_Object_oMinigame_GoldenFazsweep_Draw_0.gml"
)
foreach ($name in $referenceGml) {
    $from = Join-Path $codeRoot $name
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing reference GML: $from" }
    Copy-Item -LiteralPath $from -Destination $vanillaRoot -Force
}
Write-Host "Code: preserved $referenceRoot; copied $($referenceGml.Count) vanilla files -> $vanillaRoot"

Write-Host "Imported curated assets into $destRoot"
Write-Host "Remember to commit PortAssets/ and re-run the IPA workflow when shipping a native build."
