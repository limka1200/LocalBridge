$ErrorActionPreference = 'Stop'

$log = "$env:LOCALAPPDATA\LocalBridge\tray-registration.log"

try {
    Start-Sleep -Milliseconds 500

    $tray = @(Get-CimInstance Win32_Process |
        Where-Object {
            $_.CommandLine -match
                '[-]File\s+"?[^"]*LocalBridgeTray\.ps1'
        })

    if ($tray.Count -ne 1) {
        throw "Expected one tray, found $($tray.Count)"
    }

    $pipe = [IO.Pipes.NamedPipeClientStream]::new(
        '.',
        'ChatGPTClipboardBridgeV1',
        [IO.Pipes.PipeDirection]::InOut
    )

    try {
        $pipe.Connect(10000)

        $writer = [IO.StreamWriter]::new(
            $pipe,
            [Text.UTF8Encoding]::new($false),
            4096,
            $true
        )

        $reader = [IO.StreamReader]::new(
            $pipe,
            [Text.Encoding]::UTF8,
            $true,
            4096,
            $true
        )

        $writer.AutoFlush = $true

        $request = @{
            operation = 'TRAY_REGISTER'
            pid = [int]$tray[0].ProcessId
        } | ConvertTo-Json -Compress

        $writer.WriteLine($request)

        $response = $reader.ReadLine() |
            ConvertFrom-Json

        if (-not $response.ok) {
            throw [string]$response.text
        }

        Add-Content $log (
            "$(Get-Date -Format o) $($response.text)"
        )
    }
    finally {
        $pipe.Dispose()
    }
}
catch {
    Add-Content $log (
        "$(Get-Date -Format o) ERROR $($_.Exception.Message)"
    )
}