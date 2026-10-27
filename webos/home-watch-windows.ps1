param(
    [ValidateSet('Install', 'Run', 'Status', 'Uninstall')][string]$Mode = 'Run',
    [string]$TvHost = $env:TV_HOST
)

$ErrorActionPreference = 'Stop'
$watcher = Join-Path $PSScriptRoot 'home-watch.py'
$python = Join-Path $PSScriptRoot 'venv\Scripts\python.exe'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'WebOSTvHome'

function Get-WatcherProcess {
    Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine.Contains($watcher) }
}

if ($Mode -eq 'Uninstall') {
    Remove-ItemProperty -LiteralPath $runKey -Name $runName -ErrorAction SilentlyContinue
    Get-WatcherProcess | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    Write-Host 'Home watcher stopped and Windows startup entry removed.'
    exit
}

if ($Mode -eq 'Status') {
    $processes = @(Get-WatcherProcess)
    Write-Host "Watcher processes: $($processes.Count)"
    Write-Host "Starts at sign-in: $([bool](Get-ItemProperty -LiteralPath $runKey -Name $runName -ErrorAction SilentlyContinue))"
    if (Test-Path (Join-Path $PSScriptRoot '.home-watch.log')) {
        Get-Content -LiteralPath (Join-Path $PSScriptRoot '.home-watch.log') -Tail 10
    }
    exit
}

if (-not (Test-Path -LiteralPath $python)) { throw 'Python venv missing. Run the Windows installation steps first.' }
if (-not $TvHost) { throw 'Pass -TvHost with your TV address, or set TV_HOST.' }
if ($TvHost -notmatch '^[a-zA-Z0-9.:-]+$') { throw 'Invalid TV host.' }

if ($Mode -eq 'Install') {
    $shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}" -Mode Run -TvHost "{2}"' -f $shell, $PSCommandPath, $TvHost
    New-Item -Path $runKey -Force | Out-Null
    New-ItemProperty -LiteralPath $runKey -Name $runName -Value $command -PropertyType String -Force | Out-Null
}

if (@(Get-WatcherProcess).Count -eq 0) {
    Start-Process -FilePath $python -ArgumentList @('-u', ('"{0}"' -f $watcher), $TvHost) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $PSScriptRoot '.home-watch.log') -RedirectStandardError (Join-Path $PSScriptRoot '.home-watch.error.log') | Out-Null
    Write-Host 'Home watcher started in the background.'
} else {
    Write-Host 'Home watcher is already running.'
}
if ($Mode -eq 'Install') { Write-Host 'Home watcher will start automatically when you sign into Windows.' }
