param(
    [int]$OldPid,
    [string]$BridgePath
)

. "$env:LOCALAPPDATA\LocalBridge\config\paths.ps1"

$log = $RestartLog

function Write-RestartLog($text) {
    if (Test-Path $log) {
        $lines = Get-Content $log
        if ($lines.Count -gt 200) {
            $lines[-200..-1] | Set-Content $log
        }
    }
    Add-Content $log $text
}

Write-RestartLog "$(Get-Date) HELPER_STARTED PID=$PID OldPid=$OldPid Bridge=$BridgePath"

Start-Sleep -Milliseconds 700

if ($OldPid) {
    Stop-Process -Id $OldPid -Force -ErrorAction SilentlyContinue
    Write-RestartLog "$(Get-Date) OLD_STOP_SENT"
}

Start-Sleep -Milliseconds 1000

Start-Process powershell.exe `
    -ArgumentList "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$BridgePath`" -Daemon" `
    -WindowStyle Hidden

Write-RestartLog "$(Get-Date) BRIDGE_START_SENT"

Start-Sleep -Seconds 2

$newBridge = Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -like "*LocalBridge\bin\bridge.ps1* -Daemon*"
    }

if ($newBridge) {
    Write-RestartLog "$(Get-Date) NEW_BRIDGE_CONFIRMED PID=$($newBridge.ProcessId)"
}
else {
    Write-RestartLog "$(Get-Date) NEW_BRIDGE_NOT_FOUND"
}

Start-Sleep -Milliseconds 500

Start-Process powershell.exe `
    -ArgumentList "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$env:LOCALAPPDATA\LocalBridge\LocalBridgeStart.ps1`"" `
    -WindowStyle Hidden

Write-RestartLog "$(Get-Date) STARTER_SENT"




