$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
. (Join-Path $scriptDirectory "windows-common.ps1")
Set-Location $repositoryRoot

$requiredFiles = @(
    "AGENTS.md",
    ".agents\skills\worldcup-eloml-predictor\SKILL.md",
    ".agents\skills\european-league-eloml-predictor\SKILL.md",
    ".agents\skills\european-league-eloml-predictor\scripts\predict_market_score.R",
    "scripts\fetch-oddstorm-market.py",
    "scripts\fetch-betexplorer-market.py",
    "data\international_results_latest.csv"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        throw "Required project file is missing: $file"
    }
}

$rscript = Get-RscriptPath
& $rscript -e "stopifnot(requireNamespace('EloML', quietly=TRUE)); cat(as.character(packageVersion('EloML')))"
if ($LASTEXITCODE -ne 0) {
    throw "EloML is not available to Rscript."
}

$oddstormHelper = Join-Path $repositoryRoot "scripts\fetch-oddstorm-market.py"
$betexplorerHelper = Join-Path $repositoryRoot "scripts\fetch-betexplorer-market.py"
$python = Get-PythonCommand
$pythonExecutable = $python.Path
$pythonPrefix = @($python.Prefix)
& $pythonExecutable @pythonPrefix $oddstormHelper --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "OddStorm helper could not start."
}
& $pythonExecutable @pythonPrefix $betexplorerHelper --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "BetExplorer helper could not start."
}

$marketScript = Join-Path $repositoryRoot ".agents\skills\european-league-eloml-predictor\scripts\predict_market_score.R"
$modelArguments = @(
    $marketScript,
    "--home-team", "Arsenal",
    "--away-team", "Coventry",
    "--home-odds", "1.20",
    "--draw-odds", "7.50",
    "--away-odds", "16.00",
    "--over-2.5-odds", "1.60",
    "--under-2.5-odds", "2.42",
    "--asian-line=-1.75",
    "--top", "3"
)
$modelOutput = (& $rscript @modelArguments 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Deterministic market-score smoke test failed.`n$modelOutput"
}

function Read-PercentField {
    param([string]$Name)
    $match = [regex]::Match($modelOutput, "(?m)^$([regex]::Escape($Name))=([0-9.]+)%$")
    if (-not $match.Success) {
        throw "Missing verification field: $Name"
    }
    return [double]$match.Groups[1].Value
}

function Read-NumberField {
    param([string]$Name)
    $match = [regex]::Match($modelOutput, "(?m)^$([regex]::Escape($Name))=([0-9.]+)$")
    if (-not $match.Success) {
        throw "Missing verification field: $Name"
    }
    return [double]$match.Groups[1].Value
}

$marketHome = Read-PercentField "market_home"
$lambdaHome = Read-NumberField "fitted_expected_goals_home"
$lambdaAway = Read-NumberField "fitted_expected_goals_away"

if ([math]::Abs($marketHome - 80.97) -gt 0.02) {
    throw "Market probability verification failed: $marketHome"
}
if ([math]::Abs($lambdaHome - 2.570) -gt 0.01 -or [math]::Abs($lambdaAway - 0.547) -gt 0.01) {
    throw "Expected-goals verification failed: $lambdaHome vs $lambdaAway"
}

$expectedScores = @("1,2-0,", "2,3-0,", "3,1-0,")
foreach ($scorePrefix in $expectedScores) {
    if (-not $modelOutput.Contains($scorePrefix)) {
        throw "Top-score verification failed. Missing: $scorePrefix"
    }
}

Write-Host "WINDOWS_LOCAL_VERIFICATION_OK"
Write-Host "market_home=$marketHome%"
Write-Host "expected_goals=$lambdaHome-$lambdaAway"
Write-Host "top_scores=2-0 / 3-0 / 1-0"
Write-Host "The local calculation chain matches the reference package."
