Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using System.Diagnostics;

public sealed class TrayExceptionDiagnostics : IDisposable
{
    private readonly string logPath;

    public TrayExceptionDiagnostics(string path)
    {
        logPath = path;

        Application.SetUnhandledExceptionMode(
            UnhandledExceptionMode.CatchException
        );

        Application.ThreadException += OnThreadException;
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
    }

    private void OnThreadException(
        object sender, ThreadExceptionEventArgs e)
    {
        Write("THREAD_EXCEPTION", e.Exception, "");
    }

    private void OnUnhandledException(
        object sender, UnhandledExceptionEventArgs e)
    {
        Write(
            "UNHANDLED_EXCEPTION",
            e.ExceptionObject as Exception,
            " IsTerminating=" + e.IsTerminating
        );
    }

    private void Write(string kind, Exception ex, string extra)
    {
        try
        {
            string entry =
                DateTime.Now.ToString("o") +
                " PID=" + Process.GetCurrentProcess().Id +
                " EVENT=" + kind + extra +
                Environment.NewLine +
                (ex == null ? "Unknown exception" : ex.ToString()) +
                Environment.NewLine;

            File.AppendAllText(logPath, entry);
        }
        catch { }
    }

    public void Dispose()
    {
        Application.ThreadException -= OnThreadException;
        AppDomain.CurrentDomain.UnhandledException -= OnUnhandledException;
    }
}
"@ -ReferencedAssemblies @(
    'System.Windows.Forms',
    'System.Drawing'
)