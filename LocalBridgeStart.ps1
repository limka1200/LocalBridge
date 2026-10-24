param(
    [switch]$Status
)

$ErrorActionPreference = "SilentlyContinue"

. "$env:LOCALAPPDATA\LocalBridge\config\paths.ps1"

$bridge = $BridgePath
$tray = $TrayPath

$bridgeRunning = Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -like "*LocalBridge\bin\bridge.ps1* -Daemon*"
    }

if (-not $bridgeRunning) {
    Start-Process powershell.exe `
        -ArgumentList "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$bridge`" -Daemon" `
        -WindowStyle Hidden
}

$trayRunning = Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -like "*LocalBridgeTray.ps1*"
    }

$trayStarted = $false

if (-not $trayRunning) {
    Start-Process powershell.exe `
        -ArgumentList "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$tray`"" `
        -WindowStyle Hidden

    $trayStarted = $true
}

if ($trayStarted) {
    $helper = "$env:LOCALAPPDATA\LocalBridge\bin\RegisterTray.ps1"

    Start-Process powershell.exe `
        -ArgumentList @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            "`"$helper`""
        ) `
        -WindowStyle Hidden
}
if ($Status) {

    "`nLOCALBRIDGE_START_STATUS"

    $bridgeRunning = Get-CimInstance Win32_Process |
        Where-Object {
            $_.CommandLine -like "*LocalBridge\bin\bridge.ps1* -Daemon*"
        }

    $trayRunning = Get-CimInstance Win32_Process |
        Where-Object {
            $_.CommandLine -like "*LocalBridgeTray.ps1*"
        }

    if ($bridgeRunning) {
        "BRIDGE=RUNNING PID=$($bridgeRunning.ProcessId)"
    }
    else {
        "BRIDGE=STOPPED"
    }

    if ($trayRunning) {
        "TRAY=RUNNING PID=$($trayRunning.ProcessId)"
    }
    else {
        "TRAY=STOPPED"
    }
}



