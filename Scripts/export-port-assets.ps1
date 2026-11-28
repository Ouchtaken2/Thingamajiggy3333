# Reproduces the curated asset exports from a recovered GameMaker package with
# UndertaleModTool CLI 0.9.2.0, then refreshes PortAssets/.
#
# Run from PowerShell:  .\Scripts\export-port-assets.ps1
# Requires the 2.2.2 Windows package at ../frickbears3-4ld-v2.2.2.
# The CLI is downloaded to %TEMP% on first run. Nothing is written back to
# data.win.

param(
    [string]$SourceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "..\frickbears3-4ld-v2.2.2"),
    [string]$CliRoot = (Join-Path $env:TEMP "UTMT_CLI_v0.9.2.0-Windows")
)

$ErrorActionPreference = "Stop"

$dataFile = Join-Path $SourceRoot "data.win"
if (-not (Test-Path -LiteralPath $dataFile)) {
    throw "Missing GameMaker data file: $dataFile"
}

$cli = Join-Path $CliRoot "UndertaleModCli.exe"
if (-not (Test-Path -LiteralPath $cli)) {
    $url = "https://github.com/UnderminersTeam/UndertaleModTool/releases/download/0.9.2.0/UTMT_CLI_v0.9.2.0-Windows.zip"
    $zip = Join-Path $env:TEMP "UTMT_CLI_v0.9.2.0-Windows.zip"
    Write-Host "Downloading UndertaleModTool CLI 0.9.2.0..."
    Invoke-WebRequest -Uri $url -OutFile $zip
    if (Test-Path -LiteralPath $CliRoot) { Remove-Item -LiteralPath $CliRoot -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $CliRoot
}

$exporters = Join-Path $CliRoot "Scripts\Resource Exporters"
$logs = Join-Path $env:TEMP "fb3-exports"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Invoke-Export {
    param(
        [string]$Name,
        [string]$Script,
        [string]$Out,
        [string[]]$Answers
    )

    New-Item -ItemType Directory -Force -Path $Out | Out-Null
    $scriptPath = Join-Path $exporters $Script
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Missing exporter script: $scriptPath"
    }

    $inputText = ($Answers -join "`n") + "`n"
    $log = Join-Path $logs "$Name.log"
    Push-Location $CliRoot
    try {
        $inputText | & $cli load $dataFile -s $scriptPath 2>&1 | Tee-Object -FilePath $log | Out-Null
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($code -ne 0) {
        throw "$Name failed (exit $code). See $log"
    }
    $count = @(Get-ChildItem -LiteralPath $Out -File).Count
    Write-Host "$Name : $count files -> $Out"
}

$dump = Join-Path $SourceRoot "Open AI stuff"

Invoke-Export "Export_Code" "ExportAllCode.csx" `
    (Join-Path $SourceRoot "Export_Code") @((Join-Path $SourceRoot "Export_Code"))

Invoke-Export "Export_EmbeddedTextures" "ExportAllEmbeddedTextures.csx" `
    (Join-Path $dump "EmbeddedTextures") @((Join-Path $dump "EmbeddedTextures"))

Invoke-Export "Export_Tilesets" "ExportAllTilesets.csx" `
    (Join-Path $dump "Tilesets") @((Join-Path $dump "Tilesets"))

Invoke-Export "Export_Fonts" "ExportAllFonts.csx" `
    (Join-Path $dump "Fonts") @((Join-Path $dump "Fonts"))

# Sprites: output folder, no padding, no subdirectories (flat frames).
Invoke-Export "Export_Sprites" "ExportAllSprites.csx" `
    (Join-Path $dump "Sprites") @((Join-Path $dump "Sprites"), "n", "n")

# Sounds: output folder, no external audio copies, no audio-group folders.
Invoke-Export "Export_Sounds" "ExportAllSounds.csx" `
    (Join-Path $dump "SoundEffects") @((Join-Path $dump "SoundEffects"), "n", "n")

Write-Host @"

Room previews are the one step that needs the UMT GUI: ExportAllRoomsToPNG.csx
uses the WPF room renderer and deadlocks when driven from the CLI/command box.
In UndertaleModTool 0.9.2.0, open data.win and choose
Scripts > Resource Exporters > ExportAllRoomsToPNG.csx, then select:
$SourceRoot\Export_Rooms
Answer No to "Draw room grid?" and No to "Use the memory economy mode?".
"@

& (Join-Path $PSScriptRoot "import-port-assets.ps1") -SourceRoot $SourceRoot
