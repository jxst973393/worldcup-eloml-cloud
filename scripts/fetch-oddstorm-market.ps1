$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
. (Join-Path $scriptDirectory "windows-common.ps1")
Set-Location $repositoryRoot

$target = Join-Path $repositoryRoot "scripts\fetch-oddstorm-market.py"
$python = Get-PythonCommand
$pythonExecutable = $python.Path
$pythonArguments = @($python.Prefix) + @($target) + @($args)
& $pythonExecutable @pythonArguments
exit $LASTEXITCODE
