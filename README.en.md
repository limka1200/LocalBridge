# LocalBridge

[Русский](README.md) | **English**

LocalBridge is a lightweight bridge between ChatGPT Web and a local Windows computer. It uses the clipboard to exchange commands and execution results.

A free clipboard manager, [CopyQ](https://hluk.github.io/CopyQ/), automatically handles copied commands.

LocalBridge requires no OpenAI API key, browser extension, or separate chat interface.

## How it works

1. ChatGPT generates a command beginning with `LOCAL_EXEC_V1`.
2. The user clicks the copy button.
3. CopyQ detects the clipboard change.
4. LocalBridge executes the command in a persistent PowerShell session.
5. The execution result is returned to the clipboard.

A named pipe connects the client to the background process.

## Features

- Execute PowerShell commands directly from a regular chat.
- Persistent PowerShell runspace with state retention.
- Access to files, processes, and other Windows functionality.
- Named-pipe communication.
- System tray status indicator.
- Distinct success, partial-error, and error responses.
- Tray process lifecycle diagnostics.
- Restart the execution session or background daemon.

## Requirements

- Windows.
- Windows PowerShell 5.1.
- [CopyQ](https://hluk.github.io/CopyQ/).

## Installation

Both installation methods require [CopyQ](https://hluk.github.io/CopyQ/). Install and launch CopyQ first.

### Quick installation (recommended)

Open Windows PowerShell and run:

    irm https://raw.githubusercontent.com/limka1200/LocalBridge/main/bootstrap.ps1 | iex

The script downloads LocalBridge, registers the automatic CopyQ command, and starts the bridge.

### Installation from source

Download or clone the repository, open Windows PowerShell in the project directory, and run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

The installer performs the same setup using the local project files.

### File location and limitations

LocalBridge is installed at `%LOCALAPPDATA%\LocalBridge`.

If that directory already exists, the installer stops without overwriting files. Automatic updates of existing installations are not yet supported.

## Usage

Provide the model with the [LocalBridge protocol contract](docs/PROTOCOL.ru.md) so it can format executable commands correctly.

Example command to copy:

    LOCAL_EXEC_V1
    Get-Date
    Get-Location

When the command is copied, CopyQ forwards it to LocalBridge. The execution result is returned to the clipboard.

### Interaction protocol

**[Read the LOCAL_EXEC_V1 protocol contract](docs/PROTOCOL.ru.md)**

The contract describes instructions for the model, `EXEC`, `STATUS`, `INFO`, `RESTART`, and `RELOAD` operations, response formats, and limitations.

The protocol document is currently available in Russian.

## Security

LocalBridge executes PowerShell code with the permissions of the current Windows user.

Only copy executable requests when you understand their purpose and trust their contents. The clipboard is not a security boundary.

## Project status

**Experimental.**

LocalBridge has been verified on the primary computer and independently on a Windows 11 laptop. The fully automated installation procedure, including CopyQ configuration, is still undergoing testing.

Issues, feedback, and pull requests are welcome.

## License

MIT. See [LICENSE](LICENSE).