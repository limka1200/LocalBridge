[CmdletBinding()]
param(
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root 'copyq\LocalBridge.js'
$name = 'Local PowerShell Bridge'

$paths = @(
    "$env:ProgramFiles\CopyQ\copyq.exe",
    "${env:ProgramFiles(x86)}\CopyQ\copyq.exe",
    "$env:LOCALAPPDATA\Programs\CopyQ\copyq.exe"
)

$command = Get-Command copyq.exe -ErrorAction SilentlyContinue
$copyq = if ($command) {
    $command.Source
} else {
    $paths |
        Where-Object { $_ -and (Test-Path $_) } |
        Select-Object -First 1
}

if (-not $copyq) {
    throw 'CopyQ is not installed or could not be found'
}

if (-not (Test-Path $source)) {
    throw "Missing CopyQ script: $source"
}

$content = [IO.File]::ReadAllText($source).
    TrimStart([char]0xFEFF)

if (-not $content.StartsWith('copyq:')) {
    throw 'CopyQ script is missing copyq: prefix'
}

if ($CheckOnly) {
    "COPYQ_FOUND=$copyq"
    "SCRIPT_VALID=True"
    "REGISTRATION=NOT_ATTEMPTED"
    return
}

# Windows PowerShell 5.1 strips embedded double quotes
# when passing JavaScript to a native executable.
# Encode string literals as character codes instead.

function ConvertTo-CopyQString {
    param([string]$Value)

    $numbers = @(
        foreach ($character in $Value.ToCharArray()) {
            [int][char]$character
        }
    )

    'String.fromCharCode(' + ($numbers -join ',') + ')'
}

$nameExpr = ConvertTo-CopyQString $name
$contentExpr = ConvertTo-CopyQString $content

$script = @"
var name = $nameExpr;
var content = $contentExpr;
var list = commands();
var matches = [];

for (var i = 0; i < list.length; i++) {
    if (list[i].name === name)
        matches.push(list[i]);
}

if (matches.length > 1)
    throw new Error(name);

if (matches.length === 1) {
    if (matches[0].cmd !== content ||
        matches[0].automatic !== true ||
        matches[0].enable === false)
        throw new Error(name);

    print(String.fromCharCode(65,76,82,69,65,68,89,95,82,69,71,73,83,84,69,82,69,68));
} else {
    list.push({
        name: name,
        automatic: true,
        enable: true,
        cmd: content
    });
    setCommands(list);

    print(String.fromCharCode(82,69,71,73,83,84,69,82,69,68));
}
"@

& $copyq eval -- $script | Write-Output
$invokeCode = $LASTEXITCODE

if ($invokeCode -ne 0) {
    throw "CopyQ registration failed: $invokeCode"
}

$verify = @"
var name = $nameExpr;
var content = $contentExpr;
var list = commands();
var matches = [];

for (var i = 0; i < list.length; i++) {
    if (list[i].name === name)
        matches.push(list[i]);
}

if (matches.length !== 1 ||
    matches[0].cmd !== content ||
    matches[0].automatic !== true ||
    matches[0].enable === false)
    throw new Error(name);

print(String.fromCharCode(86,69,82,73,70,73,69,68));
"@

& $copyq eval -- $verify | Write-Output
$verifyCode = $LASTEXITCODE

if ($verifyCode -ne 0) {
    throw "CopyQ verification failed: $verifyCode"
}

"REGISTRATION_COMMAND_COMPLETED"