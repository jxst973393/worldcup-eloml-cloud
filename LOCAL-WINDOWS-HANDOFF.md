# Windows Local Handoff

This package runs locally on a Windows PC. It does not require Codex Cloud or
Git after the files have been copied.

## Required software

Install R and Python 3 from PowerShell:

```powershell
winget install --id RProject.R -e
winget install --id Python.Python.3.12 -e
```

Restart Codex after those installers finish so the local terminal receives the
updated PATH.

## One-command setup and verification

Open PowerShell in the extracted repository root and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-and-verify-windows.ps1
```

Successful migration ends with:

```text
WINDOWS_LOCAL_VERIFICATION_OK
market_home=80.97%
expected_goals=2.57-0.547
top_scores=2-0 / 3-0 / 1-0
```

## Open in Codex

Open the extracted `worldcup-eloml-cloud` folder as a local workspace. Do not
select or create a Cloud Environment. Repository Skills under `.agents/skills`
are discovered from the workspace.

Use this short prompt:

```text
This is a local Windows task. Do not use Codex Cloud.

Use $european-league-eloml-predictor and the latest repository rules to analyze
today's match for [team]. Run the local PowerShell, R, and Python entrypoints.
Verify the official fixture, current 1X2, Asian handicap, totals, injuries, and
expected lineup. Probabilities, expected goals, and Top 3 scores must come from
the raw script output and must not be manually reordered.
```

Natural-language wording can vary by Codex model. With the same inputs and
market snapshot, the deterministic script values and Top-score ordering should
match the reference package.
