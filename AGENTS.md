# World Cup EloML Cloud Agent Guide

This repository is a reproducible football match analysis workspace for Codex
Cloud. For any prediction, preview, live update, or post-match review:

1. Read `skills/worldcup-eloml-predictor/SKILL.md`.
2. Read both files under `skills/worldcup-eloml-predictor/references/`.
3. Confirm the fixture, kickoff time, completed results, injuries, lineups, and
   current public market snapshot from live sources. Never invent missing odds.
4. Run the native EloML plus separate Poisson layer with
   `scripts/predict-match.sh` from the repository root.
5. Keep strict EloML, Poisson scores, and market calibration clearly separated.
6. Use ordinary Markdown with no writing block, card, or bordered container.
7. Include the learning-only disclaimer and do not provide stakes, parlays,
   returns, or instructions to gamble.

For current fixtures and market data, agent internet access must be enabled in
the Codex Cloud environment. If current public data cannot be verified, say so
and stop short of presenting a current prediction as confirmed.

The project pins `ModelOriented/EloML` to the commit recorded in
`scripts/setup-cloud.sh`. Do not replace the native `calculate_epp()` and
`calculate_probability()` workflow with a simplified Elo formula.

