param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64"
)
$ErrorActionPreference = "Stop"
$windowsRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $windowsRoot "src\NotchMuse.App\NotchMuse.App.csproj"
$output = Join-Path $windowsRoot "artifacts\release"
New-Item -ItemType Directory -Force $output | Out-Null
$env:LIB = $null
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
& $dotnet publish $project -c $Configuration -r $Runtime --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:IncludeAllContentForSelfExtract=true -o (Join-Path $output "publish")
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
$portable = Join-Path $output "NotchMuse-Windows-win-x64-portable.exe"
Copy-Item (Join-Path $output "publish\NotchMuse.App.exe") $portable -Force
$hash = (Get-FileHash $portable -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path $portable -Leaf)" | Set-Content (Join-Path $output "SHA256SUMS.txt")
$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($iscc) {
    & $iscc.Source (Join-Path $PSScriptRoot "..\installer\NotchMuse.iss")
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed" }
}
Write-Output "Portable: $portable"
Write-Output "SHA256: $hash"
