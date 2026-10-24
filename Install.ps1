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
    'config\paths.ps1',
    'RegisterCopyQ.ps1',
    'copyq\LocalBridge.js'
)

if (Test-Path $target) {
    throw "LocalBridge already exists at $target. Installation cancelled."
}
# Validate CopyQ before copying application files.
& (Join-Path $source 'RegisterCopyQ.ps1') -CheckOnly
if (-not $?) {
    throw 'CopyQ prerequisite check failed'
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

Write-Host 'Registering CopyQ command...'
& powershell.exe -NoProfile -NonInteractive `
    -ExecutionPolicy Bypass `
    -File (Join-Path $target 'RegisterCopyQ.ps1')

if ($LASTEXITCODE -ne 0) {
    throw 'CopyQ registration failed; installation needs attention'
}

Write-Host 'Starting LocalBridge...'
& powershell.exe -NoProfile -NonInteractive `
    -ExecutionPolicy Bypass `
    -File (Join-Path $target 'LocalBridgeStart.ps1')

if ($LASTEXITCODE -ne 0) {
    throw 'LocalBridge startup failed'
}

Write-Host 'LocalBridge setup completed.'
