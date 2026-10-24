Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$mutexName = "Local\LocalBridgeTrayV1"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    $mutex.Dispose()
    exit
}

$script:InternalLog = "$env:LOCALAPPDATA\LocalBridge\tray-internal.log"

function Write-TrayEvent {
    param([string]$EventName, [string]$Details = "")
    try {
        $line = "$(Get-Date -Format o) PID=$PID EVENT=$EventName $Details"
        [IO.File]::AppendAllText(
            $script:InternalLog,
            $line + [Environment]::NewLine
        )
    } catch {}
}

Write-TrayEvent "START"
. "$env:LOCALAPPDATA\LocalBridge\config\paths.ps1"

$statusPath = $StatusPath

. "$env:LOCALAPPDATA\LocalBridge\bin\TrayExceptionDiagnostics.ps1"

$script:ExceptionDiagnostics = [TrayExceptionDiagnostics]::new(
    $script:InternalLog
)

$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Visible = $true
$icon.Text = "Local Bridge"
$icon.Icon = [System.Drawing.SystemIcons]::Information

$partialBitmap = New-Object System.Drawing.Bitmap(32,32)
$g = [System.Drawing.Graphics]::FromImage($partialBitmap)
$g.SmoothingMode = 'AntiAlias'

$g.DrawIcon(
    [System.Drawing.SystemIcons]::Information,
    0,0
)

$orange = New-Object System.Drawing.SolidBrush(
    [System.Drawing.Color]::DarkOrange
)
$white = New-Object System.Drawing.SolidBrush(
    [System.Drawing.Color]::White
)
$font = New-Object System.Drawing.Font(
    'Arial',11,[System.Drawing.FontStyle]::Bold
)

$g.FillEllipse($orange,16,16,15,15)
$g.DrawString('!', $font, $white, 19, 14)

$g.Dispose()
$orange.Dispose()
$white.Dispose()
$font.Dispose()

$script:partialIcon = [System.Drawing.Icon]::FromHandle(
    $partialBitmap.GetHicon()
)
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Text = "Status"

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"

$menu.Items.Add($statusItem)
$menu.Items.Add($exitItem)

$icon.ContextMenuStrip = $menu

function Update-Tray {
    if (-not (Test-Path $statusPath)) {
        return
    }

    try {
        $status = Get-Content $statusPath -Raw | ConvertFrom-Json
        $logPath = "$env:LOCALAPPDATA\LocalBridge\tray.log"
        $currentState = [string]$status.state

        if ($script:LastLoggedState -cne $currentState) {
            $previousState = if ($null -eq $script:LastLoggedState) {
                "INITIAL"
            } else {
                $script:LastLoggedState
            }

            $entry = "$(Get-Date -Format o) PID=$PID " +
                "STATE=$previousState -> $currentState"

            Add-Content -Path $logPath -Value $entry
            $script:LastLoggedState = $currentState
        }

        switch ($status.state) {
            "READY" {
                $icon.Icon = [System.Drawing.SystemIcons]::Information
            }
            "EXECUTING" {
                $icon.Icon = [System.Drawing.SystemIcons]::Warning
            }
            "RELOADING" {
                $icon.Icon = [System.Drawing.SystemIcons]::Question
            }
            "PARTIAL" {
                $icon.Icon = $script:partialIcon
            }
            "ERROR" {
                $icon.Icon = [System.Drawing.SystemIcons]::Error
            }
            default {
                $icon.Icon = [System.Drawing.SystemIcons]::Information
            }
        }

        $icon.Text = "Local Bridge: $($status.state)"
        $statusItem.Text = "Status: $($status.state)"
    }
    catch {
        Write-TrayEvent "ERROR" ($_ | Out-String)
        $icon.Text = "Local Bridge: ERROR"
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    Update-Tray
})

$timer.Start()

$exitItem.Add_Click({
    Write-TrayEvent "EXIT_REQUESTED"
    $timer.Stop()
    $icon.Visible = $false
    $icon.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

Update-Tray

try {
    [System.Windows.Forms.Application]::Run()
    Write-TrayEvent "STOP" "MESSAGE_LOOP_RETURNED"
}
catch {
    Write-TrayEvent "FATAL_ERROR" ($_ | Out-String)
    throw
}
finally {
    if ($script:ExceptionDiagnostics) {
        $script:ExceptionDiagnostics.Dispose()
    }
}





