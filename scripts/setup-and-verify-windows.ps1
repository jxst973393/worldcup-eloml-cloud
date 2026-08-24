$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $scriptDirectory "setup-windows.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Windows setup failed with exit code $LASTEXITCODE"
}

& (Join-Path $scriptDirectory "verify-windows-local.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Windows verification failed with exit code $LASTEXITCODE"
}
