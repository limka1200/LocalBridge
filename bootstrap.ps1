[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$target = Join-Path $env:LOCALAPPDATA 'LocalBridge'
$url = 'https://github.com/limka1200/LocalBridge/archive/refs/heads/main.zip'

if (Test-Path $target) {
    throw "LocalBridge is already installed: $target"
}

$temp = Join-Path $env:TEMP (
    'LocalBridge-Install-' + [guid]::NewGuid().ToString('N')
)

New-Item -ItemType Directory -Path $temp |
    Out-Null

try {
    $zip = Join-Path $temp 'LocalBridge.zip'
    $destination = Join-Path $temp 'extracted'

    Write-Host 'Downloading LocalBridge...'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Expand-Archive -LiteralPath $zip `
        -DestinationPath $destination -ErrorAction Stop

    $installer = Join-Path $destination 'LocalBridge-main\Install.ps1'

    if (-not (Test-Path $installer)) {
        throw 'Install.ps1 not found in downloaded archive'
    }

    Write-Host 'Installing LocalBridge...'

    & $installer

    Write-Host 'Installation completed.'
    Write-Host 'Configure CopyQ as described in README.md.'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force `
        -ErrorAction SilentlyContinue
}
