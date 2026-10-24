# LocalBridge

[Русский](README.md) | **English**

A lightweight, clipboard-driven bridge between ChatGPT Web
and a persistent local Windows PowerShell session.

Automatic execution of copied commands is handled by [CopyQ](https://hluk.github.io/CopyQ/), a free clipboard manager.

LocalBridge requires no OpenAI API key, browser extension, or custom chat UI.

## How it works

1. ChatGPT generates a command beginning with `LOCAL_EXEC_V1`.
2. The user copies the command manually.
3. CopyQ detects the clipboard change.
4. LocalBridge executes the command in a persistent PowerShell runspace.
5. The result is returned to the clipboard.

LocalBridge uses a named pipe for communication between
the client and its background daemon.

## Requirements

- Windows
- Windows PowerShell 5.1
- CopyQ

## Installation

Download or clone this repository.

From Windows PowerShell, run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

The installer copies the application to:

    %LOCALAPPDATA%\LocalBridge

It refuses to overwrite an existing installation.

Next, open CopyQ, create a new command named
`Local PowerShell Bridge`, enable automatic execution,
and paste the contents of `copyq/LocalBridge.js`
into its command editor.

Start LocalBridge:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\LocalBridge\LocalBridgeStart.ps1"

## Command format

Every execution request begins with the protocol marker
`LOCAL_EXEC_V1` on the first line, followed by PowerShell code.

For example, the code after the marker may be:

    Get-Date
    Get-Location

The command output is placed back into the clipboard.

## Features

- Persistent PowerShell runspace
- Named-pipe client/server communication
- Tray status indicator
- Execution error reporting
- Partial-error indication
- Tray process lifecycle diagnostics
- Manual restart and reload operations

## Security

LocalBridge executes PowerShell code with the permissions
of the current Windows user.

Only copy LocalBridge execution requests when you trust
their contents and intended effects.

The clipboard is not a security boundary.

## Project status

Experimental. Developed and tested on a single Windows
installation. Clean-machine installation and compatibility
testing are still pending.

## License

MIT. See [LICENSE](LICENSE).


