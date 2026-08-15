# Downloads the runtime binaries (yt-dlp + ffmpeg) bundled into the app.
# Binaries are staged into build/bin/ and injected into the app folder
# by the release workflow.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools/fetch-binaries.ps1

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$out = Join-Path $root "build\bin"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Download($url, $dest) {
    Write-Host "  -> $dest"
    $attempt = 0
    while ($true) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            break
        } catch {
            $attempt++
            if ($attempt -ge 5) { throw }
            Write-Host "    download failed, retrying ($attempt/5)..."
            Start-Sleep -Seconds 5
        }
    }
}

Write-Host "Fetching yt-dlp.exe..."
Download "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" (Join-Path $out "yt-dlp.exe")

Write-Host "Fetching ffmpeg.exe (Windows essentials build)..."
$zip = Join-Path $out "ffmpeg.zip"
Download "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" $zip
$extract = Join-Path $out "ffmpeg_extract"
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
Expand-Archive -Path $zip -DestinationPath $extract -Force
$ffmpeg = Get-ChildItem -Path $extract -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
if (-not $ffmpeg) { throw "ffmpeg.exe not found inside the archive" }
Copy-Item $ffmpeg.FullName (Join-Path $out "ffmpeg.exe")
$ffprobe = Get-ChildItem -Path $extract -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
if (-not $ffprobe) { throw "ffprobe.exe not found inside the archive" }
Copy-Item $ffprobe.FullName (Join-Path $out "ffprobe.exe")
Remove-Item -Recurse -Force $extract
Remove-Item -Force $zip

Get-ChildItem $out | Format-Table Name, Length
Write-Host "Done. Binaries staged in $out"