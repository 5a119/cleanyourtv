param(
    [Parameter(Mandatory = $true)][string]$TvHost,
    [string]$Device = 'lgtv',
    [string]$Python = (Join-Path $PSScriptRoot 'venv\Scripts\python.exe')
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$env:PYTHONUTF8 = '1'

function Invoke-Ares {
    param([string]$Command, [string[]]$Arguments)
    & npx.cmd -y -p '@webos-tools/cli' "ares-$Command" @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ares-$Command failed ($LASTEXITCODE)." }
}

if (-not (Test-Path -LiteralPath $Python)) {
    throw 'Create venv first: python -m venv venv; .\venv\Scripts\python.exe -m pip install websockets pillow'
}
& $Python sync-apps.py $TvHost
if ($LASTEXITCODE -ne 0) { throw 'TV app sync failed. Accept the pairing prompt on the TV and retry.' }

if (-not (Test-Path app/icon.png) -or -not (Test-Path app/largeIcon.png)) {
    @'
from PIL import Image
with Image.open('assets/icon.jpg') as source:
    for name, size in [('icon.png', 80), ('largeIcon.png', 130)]:
        source.convert('RGB').resize((size, size), Image.Resampling.LANCZOS).save('app/' + name)
'@ | & $Python -
    if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed; install pillow in venv.' }
}

New-Item -ItemType Directory -Path build -Force | Out-Null
Invoke-Ares 'package' @('app', '-o', 'build')
$version = (Get-Content app/appinfo.json -Raw | ConvertFrom-Json).version
$package = Join-Path $PSScriptRoot "build\com.gathin.tvhome_${version}_all.ipk"
if (-not (Test-Path -LiteralPath $package)) { throw "Package missing: $package" }
Invoke-Ares 'install' @('-d', $Device, $package)
Invoke-Ares 'launch' @('-d', $Device, 'com.gathin.tvhome')
Write-Host 'Installed. Hold a number key on the remote to assign a Quick Access shortcut.'
