# Packs rendered frames into a sprite sheet + JSON with the Aseprite CLI.
# Usage: ./tools/export_aseprite.ps1 -Name tram -Source art/aseprite/export/tram_raw
param(
  [Parameter(Mandatory)] [string] $Name,
  [Parameter(Mandatory)] [string] $Source,
  [string] $OutDir = "assets/images/trams",
  [string] $Aseprite = "aseprite"
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $OutDir | Out-Null

& $Aseprite -b "$Source/*.png" `
  --sheet "$OutDir/$Name.png" `
  --sheet-type rows `
  --data "$OutDir/$Name.json" --format json-array `
  --list-tags
