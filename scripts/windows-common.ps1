Set-StrictMode -Version Latest

function Get-RscriptPath {
    $command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $roots = @()
    if ($env:ProgramFiles) {
        $roots += (Join-Path $env:ProgramFiles "R")
    }
    if (${env:ProgramFiles(x86)}) {
        $roots += (Join-Path ${env:ProgramFiles(x86)} "R")
    }

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) {
            continue
        }
        $versions = Get-ChildItem -Path $root -Directory | Sort-Object Name -Descending
        foreach ($version in $versions) {
            foreach ($relative in @("bin\Rscript.exe", "bin\x64\Rscript.exe")) {
                $candidate = Join-Path $version.FullName $relative
                if (Test-Path $candidate) {
                    return $candidate
                }
            }
        }
    }

    throw "Rscript.exe was not found. Install R first: winget install --id RProject.R -e"
}

function Get-PythonCommand {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($null -ne $py) {
        return [PSCustomObject]@{
            Path = $py.Source
            Prefix = @("-3")
        }
    }

    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -ne $python) {
        return [PSCustomObject]@{
            Path = $python.Source
            Prefix = @()
        }
    }

    throw "Python 3 was not found. Install it first: winget install --id Python.Python.3.12 -e"
}
