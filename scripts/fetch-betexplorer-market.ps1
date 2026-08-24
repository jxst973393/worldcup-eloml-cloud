$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
. (Join-Path $scriptDirectory "windows-common.ps1")
Set-Location $repositoryRoot

$target = Join-Path $repositoryRoot "scripts\fetch-betexplorer-market.py"
$exitCode = Invoke-LocalPython -ScriptPath $target -Arguments $args
exit $exitCode
