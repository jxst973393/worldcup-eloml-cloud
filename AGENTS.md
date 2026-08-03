# Football EloML Cloud Agent Guide

This repository contains two independent football analysis workflows for Codex
Cloud. Never merge their datasets, scripts, model assumptions, or output rules.

For World Cup or national-team analysis:

1. Use `$worldcup-eloml-predictor` and read
   `.agents/skills/worldcup-eloml-predictor/SKILL.md`.
2. Read both files under
   `.agents/skills/worldcup-eloml-predictor/references/`.
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

For Premier League, La Liga, Serie A, Bundesliga, or Ligue 1 analysis:

1. Use `$european-league-eloml-predictor` and read
   `.agents/skills/european-league-eloml-predictor/SKILL.md`.
2. Read both files under
   `.agents/skills/european-league-eloml-predictor/references/`.
3. Run `scripts/predict-league-match.sh` from the repository root.
4. Keep native EloML, the time-weighted club score model, de-vigged market
   probabilities, and the information layer clearly separated.
5. Treat Premier League and La Liga as the priority leagues. Fit every league
   independently and preserve explicit home/away effects.
6. Use ordinary Markdown with no writing block, card, or bordered container.
7. Include the learning-only disclaimer and never provide gambling actions.

The World Cup workflow remains unchanged under `worldcup-eloml-predictor`.
