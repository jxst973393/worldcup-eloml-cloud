#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

exec Rscript .agents/skills/european-league-eloml-predictor/scripts/predict_league_match.R "$@"
