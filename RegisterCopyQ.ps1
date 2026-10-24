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

# JSON is also a valid JavaScript string literal.
$nameJson = ConvertTo-Json -InputObject $name -Compress
$cmdJson = ConvertTo-Json -InputObject $content -Compress

$script = @"
var name = $nameJson;
var content = $cmdJson;
var list = commands();
var matches = list.filter(function(c) {
    return c.name === name;
});

if (matches.length > 1) {
    throw new Error('Duplicate LocalBridge commands exist');
}

if (matches.length === 1) {
    if (matches[0].cmd !== content ||
        !matches[0].automatic) {
        throw new Error('Existing LocalBridge command differs');
    }
    print('ALREADY_REGISTERED');
} else {
    list.push({
        name: name,
        automatic: true,
        cmd: content
    });
    setCommands(list);
    print('REGISTERED');
}
"@

# CopyQ on Windows may not return a usable exit code
# when its output is captured into a PowerShell variable.
& $copyq eval -- $script | Write-Output
$invokeCode = $LASTEXITCODE

if ($invokeCode -ne 0) {
    throw "CopyQ eval failed: $invokeCode"
}

# Verify actual configuration rather than trusting output.
$verify = @"
var list = commands();
var name = $nameJson;
var content = $cmdJson;
var matches = list.filter(function(c) {
    return c.name === name;
});
if (matches.length !== 1 ||
    matches[0].cmd !== content ||
    matches[0].automatic !== true ||
    matches[0].enable === false) {
    throw new Error('LocalBridge CopyQ configuration verification failed');
}
print('VERIFIED');
"@

& $copyq eval -- $verify | Write-Output
$verifyCode = $LASTEXITCODE

if ($verifyCode -ne 0) {
    throw "CopyQ verification failed: $verifyCode"
}

"REGISTRATION_COMMAND_COMPLETED"