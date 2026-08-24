$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
. (Join-Path $scriptDirectory "windows-common.ps1")
Set-Location $repositoryRoot

$rscript = Get-RscriptPath
if ($null -eq (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Warning "Git was not found. Runtime setup can continue, but install Git for future updates: winget install --id Git.Git -e"
}

$pythonReady = (Get-Command py.exe -ErrorAction SilentlyContinue) -or (Get-Command python.exe -ErrorAction SilentlyContinue)
if (-not $pythonReady) {
    throw "Python 3 is required by the public market helpers. Install it with: winget install --id Python.Python.3.12 -e"
}

$env:ELOML_REF = if ($env:ELOML_REF) { $env:ELOML_REF } else { "11d1670379b1602b662068f7aa9cce7deba0cdf1" }
$setupFile = Join-Path ([System.IO.Path]::GetTempPath()) "eloml-windows-setup.R"

@'
options(repos = c(CRAN = "https://cloud.r-project.org"))

required <- c("remotes", "data.table", "ggplot2", "ggrepel", "glmnet", "Matrix")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  install.packages(missing, dependencies = c("Depends", "Imports", "LinkingTo"))
}

ref <- Sys.getenv("ELOML_REF")
if (!requireNamespace("EloML", quietly = TRUE)) {
  remotes::install_github(
    paste0("ModelOriented/EloML@", ref),
    dependencies = FALSE,
    upgrade = "never"
  )
}

stopifnot(requireNamespace("EloML", quietly = TRUE))
cat("EloML version:", as.character(utils::packageVersion("EloML")), "\n")
'@ | Set-Content -Path $setupFile -Encoding UTF8

& $rscript $setupFile
if ($LASTEXITCODE -ne 0) {
    throw "R dependency setup failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path "data\international_results_latest.csv")) {
    throw "Run this script from a complete repository copy; data\international_results_latest.csv is missing."
}

Write-Host "Local Windows environment is ready."
Write-Host "Open this repository folder in Codex and use the repository Skills."
