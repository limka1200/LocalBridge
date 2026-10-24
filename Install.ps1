[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $env:LOCALAPPDATA 'LocalBridge'

$files = @(
    'LocalBridgeStart.ps1',
    'LocalBridgeRestart.ps1',
    'LocalBridgeTray.ps1',
    'bin\bridge.ps1',
    'bin\RegisterTray.ps1',
    'bin\TrayExceptionDiagnostics.ps1',
    'bin\TrayWatcher.ps1',
    'config\paths.ps1'
)

if (Test-Path $target) {
    throw "LocalBridge already exists at $target. Installation cancelled."
}

foreach ($name in $files) {
    $path = Join-Path $source $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing source file: $name"
    }
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'Windows PowerShell 5.1 or newer is required.'
}

foreach ($name in $files) {
    $path = Join-Path $source $name
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $path, [ref]$tokens, [ref]$errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
        throw "Invalid PowerShell syntax: $name"
    }
}

try {
    New-Item -ItemType Directory -Path $target -ErrorAction Stop |
        Out-Null

    foreach ($name in $files) {
        $destination = Join-Path $target $name

        New-Item -ItemType Directory `
            -Path (Split-Path $destination -Parent) `
            -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $source $name) `
            -Destination $destination -ErrorAction Stop
    }
}
catch {
    Write-Warning "Installation failed. Inspect: $target"
    throw
}

Write-Host "LocalBridge installed at: $target"
Write-Host 'Configure the CopyQ command as described in README.md.'
Write-Host 'Installation does not start the daemon automatically.'
