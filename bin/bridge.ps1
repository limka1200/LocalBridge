[CmdletBinding()]
param(
    [switch]$Daemon,
    [int]$ConnectTimeoutMs = 10000,
    [string]$InputText
)

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:PipeName = 'ChatGPTClipboardBridgeV1'
$script:MutexName = 'Local\ChatGPTClipboardBridgeV1'
$script:Protocol = 'LOCAL_EXEC_V1'
$script:DebugLog = "$env:LOCALAPPDATA\LocalBridge\bridge-debug.log"
Add-Content -Path $script:DebugLog -Value "$(Get-Date -Format 'HH:mm:ss.fff') BRIDGE_LOADED PID=$PID PATH=$PSCommandPath"

function Write-BridgeDebug {
    param([string]$Text)

    try {
        Add-Content -Path $script:DebugLog `
            -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Text"
    }
    catch {}
}
$script:InputTextWasBound = $null -ne $InputText
$script:InputTextValue = $InputText

function New-PipeClient {
    param([int]$TimeoutMs)
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(
        '.', $script:PipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::None
    )
    $pipe.Connect($TimeoutMs)
    $pipe
}

function Start-BridgeDaemon {
    $powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $arguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-Daemon'
    )
    Start-Process -FilePath $powershellExe -ArgumentList $arguments -WindowStyle Hidden | Out-Null
}

function Read-Request {
    $raw = if ($script:InputTextWasBound) {
        $script:InputTextValue
    } else {
        [Console]::In.ReadToEnd()
    }

$normalized = $raw -replace "`r`n", "`n"
    $lines = $normalized -split "`n"

    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne $script:Protocol) {
        throw "Clipboard text must start with $($script:Protocol)."
    }

    $operation = 'EXEC'
    $startLine = 1
    if ($lines.Count -gt 1 -and $lines[1].Trim().ToUpperInvariant() -in @('EXEC', 'STATUS', 'INFO', 'RESTART', 'RELOAD')) {
        $operation = $lines[1].Trim().ToUpperInvariant()
        $startLine = 2
    }

    $command = if ($startLine -lt $lines.Count) {
        ($lines[$startLine..($lines.Count - 1)] -join "`n").TrimEnd()
    } else {
        ''
    }
    [pscustomobject]@{
        operation = $operation
        command = $command
    }
}

function Show-BridgeNotification {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        $xml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
</toast>
"@

        $xmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xmlDoc.LoadXml($xml)

        $toast = [Windows.UI.Notifications.ToastNotification]::new($xmlDoc)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Local Bridge")

        $notifier.Show($toast)
    }
	catch {
		Set-Content "$env:TEMP\bridge_toast_error.txt" ($_ | Out-String)
	}
}
function Set-BridgeStatus {
    param(
        [string]$State,
        [string]$Message = ""
    )

    try {
        $dir = "$env:LOCALAPPDATA\LocalBridge"
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        @{
            state = $State
            message = $Message
            pid = $PID
            time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        } | ConvertTo-Json | Set-Content "$dir\status.json" -Encoding UTF8
    }
    catch {
    }
}
function Invoke-BridgeClient {
    $request = Read-Request
    $pipe = $null
	Show-BridgeNotification `
    "Local Bridge" `
    "РљРѕРјР°РЅРґР° РІС‹РїРѕР»РЅСЏРµС‚СЃСЏ"
	
    try {
        try {
            $pipe = New-PipeClient -TimeoutMs 150
        } catch {
            Start-BridgeDaemon
            $deadline = [DateTime]::UtcNow.AddMilliseconds($ConnectTimeoutMs)
            do {
                Start-Sleep -Milliseconds 75
                try { $pipe = New-PipeClient -TimeoutMs 150 } catch { $pipe = $null }
            } until ($pipe -or [DateTime]::UtcNow -ge $deadline)
            if (-not $pipe) { throw 'Bridge daemon did not start in time.' }
        }

        $writer = New-Object System.IO.StreamWriter($pipe, (New-Object System.Text.UTF8Encoding($false)), 4096, $true)
        $reader = New-Object System.IO.StreamReader($pipe, [System.Text.Encoding]::UTF8, $true, 4096, $true)
        $writer.AutoFlush = $true
        $writer.WriteLine(($request | ConvertTo-Json -Compress))
        $responseLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($responseLine)) { throw 'Bridge returned an empty response.' }
        $response = $responseLine | ConvertFrom-Json

        if ($response.kind -eq 'PARTIAL') {
            Show-BridgeNotification `
                "Local Bridge" `
                "Частичный результат"
            [Console]::Out.Write(
                "LOCAL_PARTIAL_V1`r`n{0}" -f
                [string]$response.text
            )
            exit 0
        }

        if ($response.ok) {
			Show-BridgeNotification `
			"Local Bridge" `
			"Р РµР·СѓР»СЊС‚Р°С‚ РіРѕС‚РѕРІ"
            [Console]::Out.Write([string]$response.text)
            exit 0
        }
		Show-BridgeNotification `
		"Local Bridge" `
		"РћС€РёР±РєР° РІС‹РїРѕР»РЅРµРЅРёСЏ"
        [Console]::Out.Write("LOCAL_ERROR_V1`r`n{0}" -f [string]$response.text)
        exit 1
    } finally {
        if ($pipe) { $pipe.Dispose() }
    }
}

function New-SecurePipeServer {
    $security = New-Object System.IO.Pipes.PipeSecurity
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object System.IO.Pipes.PipeAccessRule(
        $sid,
        [System.IO.Pipes.PipeAccessRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $security.SetAccessRuleProtection($true, $false)
    $security.AddAccessRule($rule)
    New-Object System.IO.Pipes.NamedPipeServerStream(
        $script:PipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte,
        [System.IO.Pipes.PipeOptions]::None,
        4096,
        4096,
        $security
    )
}

function New-PersistentRunspace {
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace
}

function Invoke-InRunspace {
    param($Runspace, [string]$Code)
    if ([string]::IsNullOrWhiteSpace($Code)) {
        return [pscustomobject]@{ ok = $false; text = 'EXEC requires a PowerShell command.' }
    }

    $shell = [System.Management.Automation.PowerShell]::Create()
    try {
        $shell.Runspace = $Runspace
        [void]$shell.AddScript($Code)
        $output = $shell.Invoke()
        $stdout = ($output | Out-String -Width 4096).TrimEnd()
        $stderr = ($shell.Streams.Error | Out-String -Width 4096).TrimEnd()
        $parts = @()
        if ($stdout) { $parts += $stdout }
        if ($stderr) { $parts += "[stderr]`r`n$stderr" }
        [pscustomobject]@{
            ok = -not $shell.HadErrors
            kind = if (-not $shell.HadErrors) {
                'SUCCESS'
            } elseif ($stdout) {
                'PARTIAL'
            } else {
                'ERROR'
            }
            text = if ($parts.Count) { $parts -join "`r`n" } else { '[no output]' }
        }
    } catch {
        [pscustomobject]@{ ok = $false; text = ($_ | Out-String).TrimEnd() }
    } finally {
        $shell.Dispose()
    }
}

function Run-BridgeDaemon {
    $createdNew = $false
    $mutex = New-Object System.Threading.Mutex($true, $script:MutexName, [ref]$createdNew)
    if (-not $createdNew) { $mutex.Dispose(); return }

    Set-BridgeStatus "READY" "Bridge started"

    $runspace = New-PersistentRunspace
    $script:TrayWatcher = $null
    try {
        . "$env:LOCALAPPDATA\LocalBridge\bin\TrayWatcher.ps1"
    } catch {
        Write-BridgeDebug "TRAY_WATCHER_INIT_ERROR $($_.Exception.Message)"
    }
    try {
        while ($true) {
            $server = New-SecurePipeServer
            try {
                $server.WaitForConnection()
                $reader = New-Object System.IO.StreamReader($server, [System.Text.Encoding]::UTF8, $true, 4096, $true)
                $writer = New-Object System.IO.StreamWriter($server, (New-Object System.Text.UTF8Encoding($false)), 4096, $true)
                $writer.AutoFlush = $true
                try {
                    $request = $reader.ReadLine() | ConvertFrom-Json
                    switch ([string]$request.operation) {
                        'TRAY_REGISTER' {
                            $trayPid = [int]$request.pid
                            if ($trayPid -le 0) {
                                throw "Invalid tray PID"
                            }

                            $actual = Get-CimInstance Win32_Process `
                                -Filter "ProcessId=$trayPid"

                            if (-not $actual -or
                                $actual.CommandLine -notmatch
                                '[-]File\s+"?[^"]*LocalBridgeTray\.ps1') {
                                throw "PID is not a LocalBridge tray"
                            }

                            if ($script:TrayWatcher -and
                                $script:WatchedTrayPid -eq $trayPid) {
                                $result = 'ALREADY_REGISTERED'
                            } else {
                                $newWatcher = [BridgeTrayWatcher]::new(
                                    $trayPid,
                                    "$env:LOCALAPPDATA\LocalBridge\tray-lifecycle.log"
                                )
                                $oldWatcher = $script:TrayWatcher
                                $script:TrayWatcher = $newWatcher
                                $script:WatchedTrayPid = $trayPid
                                if ($oldWatcher) {
                                    $oldWatcher.Dispose()
                                }
                                $result = 'REGISTERED'
                            }

                            $response = [pscustomobject]@{
                                ok = $true
                                text = "TRAY_REGISTER=$result PID=$trayPid"
                            }
                        }
                        'STATUS' {
                            $response = [pscustomobject]@{
                                ok = $true
                                text = "LOCAL_STATUS_V1`r`nRUNNING`r`nPID=$PID`r`nPOWERSHELL=$($PSVersionTable.PSVersion)"
                            }
                        }
                        'INFO' {
                            . "$env:LOCALAPPDATA\LocalBridge\config\paths.ps1"

                            $response = [pscustomobject]@{
                                ok = $true
                                text = @"
LOCAL_INFO_V1

ROOT=$LocalBridgeRoot

BRIDGE_PATH=$BridgePath

PID=$PID

POWERSHELL=$($PSVersionTable.PSVersion)

STATUS_FILE=$(if (Test-Path $StatusPath) { "OK" } else { "MISSING" })

RESTART_LOG=$(if (Test-Path $RestartLog) { "OK" } else { "MISSING" })

TRAY_LOG=$(if (Test-Path $TrayLog) { "OK" } else { "MISSING" })
"@
                            }
                        }
                        'RESTART' {
                            $runspace.Dispose()
                            $runspace = New-PersistentRunspace
                            $response = [pscustomobject]@{ ok = $true; text = "LOCAL_STATUS_V1`r`nRESTARTED" }
                        }
                        'RELOAD' {
    $oldPid = $PID
    $bridgePath = $PSCommandPath
    $helperPath = "$env:LOCALAPPDATA\LocalBridge\LocalBridgeRestart.ps1"

    Set-BridgeStatus "RELOADING" "Bridge reload"

    $args = @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        "`"$helperPath`"",
        '-OldPid',
        $oldPid,
        '-BridgePath',
        "`"$bridgePath`""
    )

    Start-Process powershell.exe `
        -ArgumentList $args `
        -WindowStyle Hidden

    $response = [pscustomobject]@{
        ok = $true
        text = "LOCAL_STATUS_V1`r`nRELOAD_STARTED`r`nOLD_PID=$oldPid"
    }
}'EXEC' {
    Set-BridgeStatus "EXECUTING" ([string]$request.command)

    $response = Invoke-InRunspace -Runspace $runspace -Code ([string]$request.command)

    if ($response.kind -eq 'PARTIAL') {
        Set-BridgeStatus "PARTIAL" "Command completed with errors"
    }
    elseif ($response.ok) {
        Set-BridgeStatus "READY" "Command completed"
    }
    else {
        Set-BridgeStatus "ERROR" ([string]$response.text)
    }
}
                        default { $response = [pscustomobject]@{ ok = $false; text = 'Unknown operation.' } }
                    }
                } catch {
                    $response = [pscustomobject]@{ ok = $false; text = ($_ | Out-String).TrimEnd() }
                }
                $writer.WriteLine(($response | ConvertTo-Json -Compress -Depth 4))
            } finally {
                $server.Dispose()
            }
        }
    } finally {
        if ($script:TrayWatcher) {
            $script:TrayWatcher.Dispose()
        }
        $runspace.Dispose()
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}

if ($Daemon) { Run-BridgeDaemon } else { Invoke-BridgeClient }





















