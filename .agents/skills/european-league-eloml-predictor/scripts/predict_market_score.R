#!/usr/bin/env Rscript

# Market-only score fallback for promoted clubs missing from top-flight data.

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  key <- paste0("--", name)
  position <- match(key, args)
  if (!is.na(position)) {
    if (position == length(args)) stop(sprintf("Missing value after %s", key))
    return(args[[position + 1]])
  }
  inline_prefix <- paste0(key, "=")
  inline <- args[startsWith(args, inline_prefix)]
  if (length(inline) > 1) stop(sprintf("Duplicate value for %s", key))
  if (length(inline) == 1) return(sub(inline_prefix, "", inline, fixed = TRUE))
  default
}

required_number <- function(name) {
  value <- suppressWarnings(as.numeric(arg_value(name, "")))
  if (!is.finite(value) || value <= 1) stop(sprintf("--%s must be a decimal odd greater than 1", name))
  value
}

home_team <- arg_value("home-team")
away_team <- arg_value("away-team")
home_odds <- required_number("home-odds")
draw_odds <- required_number("draw-odds")
away_odds <- required_number("away-odds")
over_odds <- required_number("over-2.5-odds")
under_odds <- required_number("under-2.5-odds")
asian_line <- arg_value("asian-line", "")
snapshot_time <- arg_value("snapshot-time", "")
source_note <- arg_value("source-note", "")
max_goals <- suppressWarnings(as.integer(arg_value("max-goals", "12")))
top_n <- suppressWarnings(as.integer(arg_value("top", "8")))

if (is.null(home_team) || is.null(away_team) || !nzchar(home_team) || !nzchar(away_team)) {
  stop("--home-team and --away-team are required")
}
if (!is.finite(max_goals) || max_goals < 8) stop("--max-goals must be at least 8")
if (!is.finite(top_n) || top_n < 3) stop("--top must be at least 3")

devig <- function(values) {
  inverse <- 1 / values
  inverse / sum(inverse)
}

market_1x2 <- devig(c(home = home_odds, draw = draw_odds, away = away_odds))
market_totals <- devig(c(over = over_odds, under = under_odds))
goals <- 0:max_goals

score_matrix <- function(lambda_home, lambda_away) {
  matrix <- outer(dpois(goals, lambda_home), dpois(goals, lambda_away), FUN = "*")
  matrix / sum(matrix)
}

matrix_probabilities <- function(matrix) {
  c(
    home = sum(matrix[row(matrix) > col(matrix)]),
    draw = sum(diag(matrix)),
    away = sum(matrix[row(matrix) < col(matrix)])
  )
}

matrix_over_2_5 <- function(matrix) {
  totals <- outer(goals, goals, FUN = "+")
  sum(matrix[totals > 2])
}

objective <- function(log_lambdas) {
  lambdas <- exp(log_lambdas)
  matrix <- score_matrix(lambdas[[1]], lambdas[[2]])
  fitted <- c(matrix_probabilities(matrix), over = matrix_over_2_5(matrix))
  target <- c(market_1x2, over = market_totals[["over"]])
  sum((fitted - target)^2)
}

home_strength <- max(0.2, market_1x2[["home"]] / market_1x2[["away"]])
away_strength <- max(0.2, market_1x2[["away"]] / market_1x2[["home"]])
initial_total <- 2.7
initial <- log(c(
  max(0.15, initial_total * sqrt(home_strength) / (sqrt(home_strength) + sqrt(away_strength))),
  max(0.15, initial_total * sqrt(away_strength) / (sqrt(home_strength) + sqrt(away_strength)))
))

fit <- optim(
  par = initial,
  fn = objective,
  method = "L-BFGS-B",
  lower = log(c(0.05, 0.05)),
  upper = log(c(6, 6))
)
if (fit$convergence != 0) stop(sprintf("Market Poisson optimization failed: %s", fit$message))

lambdas <- exp(fit$par)
names(lambdas) <- c("home", "away")
matrix <- score_matrix(lambdas[["home"]], lambdas[["away"]])
fitted_1x2 <- matrix_probabilities(matrix)
fitted_over <- matrix_over_2_5(matrix)
fitted_btts <- sum(matrix[row(matrix) > 1 & col(matrix) > 1])
target <- c(market_1x2, over = market_totals[["over"]])
fitted <- c(fitted_1x2, over = fitted_over)
fit_rmse <- sqrt(mean((fitted - target)^2))

score_rows <- expand.grid(home = goals, away = goals)
score_rows$probability <- as.vector(matrix)
score_rows <- head(score_rows[order(score_rows$probability, decreasing = TRUE), ], top_n)
score_rows$score <- paste0(score_rows$home, "-", score_rows$away)

pct <- function(value) sprintf("%.2f%%", 100 * value)
num <- function(value) sprintf("%.3f", value)

cat("MARKET_SCORE_RESULT_BEGIN\n")
cat("layer=market_only_independent_poisson\n")
cat("strict_eloml=unavailable\n")
cat("club_history_score_layer=unavailable\n")
cat("home_team=", home_team, "\n", sep = "")
cat("away_team=", away_team, "\n", sep = "")
cat("snapshot_time=", snapshot_time, "\n", sep = "")
cat("source_note=", source_note, "\n", sep = "")
cat("home_odds=", num(home_odds), "\n", sep = "")
cat("draw_odds=", num(draw_odds), "\n", sep = "")
cat("away_odds=", num(away_odds), "\n", sep = "")
cat("over_2_5_odds=", num(over_odds), "\n", sep = "")
cat("under_2_5_odds=", num(under_odds), "\n", sep = "")
cat("asian_line=", asian_line, "\n", sep = "")
cat("market_home=", pct(market_1x2[["home"]]), "\n", sep = "")
cat("market_draw=", pct(market_1x2[["draw"]]), "\n", sep = "")
cat("market_away=", pct(market_1x2[["away"]]), "\n", sep = "")
cat("market_over_2_5=", pct(market_totals[["over"]]), "\n", sep = "")
cat("market_under_2_5=", pct(market_totals[["under"]]), "\n", sep = "")
cat("fitted_expected_goals_home=", num(lambdas[["home"]]), "\n", sep = "")
cat("fitted_expected_goals_away=", num(lambdas[["away"]]), "\n", sep = "")
cat("fitted_home_win=", pct(fitted_1x2[["home"]]), "\n", sep = "")
cat("fitted_draw=", pct(fitted_1x2[["draw"]]), "\n", sep = "")
cat("fitted_away_win=", pct(fitted_1x2[["away"]]), "\n", sep = "")
cat("fitted_over_2_5=", pct(fitted_over), "\n", sep = "")
cat("fitted_both_teams_score=", pct(fitted_btts), "\n", sep = "")
cat("fit_rmse=", num(fit_rmse), "\n", sep = "")
cat("fit_warning=", ifelse(fit_rmse > 0.04, "market_constraints_fit_poorly_lower_confidence", "none"), "\n", sep = "")
cat("top_scores=\n")
for (index in seq_len(nrow(score_rows))) {
  cat(sprintf("%d,%s,%s\n", index, score_rows$score[[index]], pct(score_rows$probability[[index]])))
}
cat("MARKET_SCORE_RESULT_END\n")
