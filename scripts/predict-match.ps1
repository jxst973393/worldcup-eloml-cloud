$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
. (Join-Path $scriptDirectory "windows-common.ps1")
Set-Location $repositoryRoot

$rscript = Get-RscriptPath
$target = Join-Path $repositoryRoot ".agents\skills\worldcup-eloml-predictor\scripts\predict_match.R"
& $rscript $target @args
exit $LASTEXITCODE
