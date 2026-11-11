# Builds the web version and zips it for itch.io (HTML5 upload, index.html at zip root).
# Usage: ./tools/build_web.ps1
$ErrorActionPreference = "Stop"

flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }

# itch.io serves the game from a sub-path, so the base href must be relative.
$index = "build/web/index.html"
(Get-Content $index -Raw) -replace '<base href="/">', '<base href="./">' | Set-Content $index -NoNewline
if (-not (Select-String -Path $index -Pattern '<base href="./">' -Quiet)) { throw "base href rewrite failed" }

$zip = "build/itch/web.zip"
New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "build/web/*" -DestinationPath $zip
Write-Host "Created $zip"
