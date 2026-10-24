copyq:
var input = str(clipboard()).replace(/\r\n/g, '\n');

if (input.indexOf('LOCAL_EXEC_V1\n') !== 0)
    abort();

var script = str(env('LOCALAPPDATA')).replace(/\\/g, '/') +
    '/LocalBridge/bin/bridge.ps1';

var result = execute(
    'powershell.exe',
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script,
    '-InputText',
    input
);

var output = str(result.stdout);

if (!output)
    output = 'LOCAL_ERROR_V1\nExit code: ' +
             result.exit_code + '\n' +
             str(result.stderr);

copy(output);
ignore();

