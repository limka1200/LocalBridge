Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Diagnostics;

public sealed class BridgeTrayWatcher : IDisposable
{
    private Process process;
    private readonly string logPath;

    public BridgeTrayWatcher(int pid, string path)
    {
        logPath = path;
        process = Process.GetProcessById(pid);
        process.EnableRaisingEvents = true;
        process.Exited += OnExited;
        Log("WATCH_START PID=" + pid);
    }

    private void OnExited(object sender, EventArgs args)
    {
        int pid = process.Id;
        string code = "UNAVAILABLE";

        try { code = process.ExitCode.ToString(); }
        catch { }

        Log("PROCESS_EXIT PID=" + pid +
            " EXIT_CODE=" + code);
    }

    private void Log(string message)
    {
        try {
            File.AppendAllText(logPath,
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") +
                " " + message + Environment.NewLine);
        }
        catch { }
    }

    public void Dispose()
    {
        if (process == null) return;
        process.Exited -= OnExited;
        Log("WATCH_STOP PID=" + process.Id);
        process.Dispose();
        process = null;
    }
}
"@

$tray = Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -match
            '[-]File\s+"?[^"]*LocalBridgeTray\.ps1'
    } |
    Select-Object -First 1

if ($tray) {
    $script:TrayWatcher = New-Object BridgeTrayWatcher(
        [int]$tray.ProcessId,
        "$env:LOCALAPPDATA\LocalBridge\tray-lifecycle.log"
    )
    $script:WatchedTrayPid = [int]$tray.ProcessId
}
