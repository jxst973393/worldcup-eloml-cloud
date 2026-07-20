#!/usr/bin/env Rscript

# Native EloML strength plus a separate, club-specific score layer.

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  key <- paste0("--", name)
  position <- match(key, args)
  if (is.na(position)) return(default)
  if (position == length(args)) stop(sprintf("Missing value after %s", key))
  args[[position + 1]]
}

as_flag <- function(value) {
  tolower(as.character(value)) %in% c("1", "true", "yes", "y")
}

as_optional_number <- function(name) {
  value <- arg_value(name, "")
  if (!nzchar(value)) return(NA_real_)
  parsed <- suppressWarnings(as.numeric(value))
  if (is.na(parsed)) stop(sprintf("--%s must be numeric", name))
  parsed
}

league_aliases <- c(
  epl = "E0", premierleague = "E0", england = "E0",
  laliga = "SP1", spain = "SP1",
  seriea = "I1", italy = "I1",
  bundesliga = "D1", germany = "D1",
  ligue1 = "F1", france = "F1"
)
league_names <- c(E0 = "Premier League", SP1 = "La Liga", I1 = "Serie A", D1 = "Bundesliga", F1 = "Ligue 1")

league_input <- tolower(gsub("[^a-z0-9]", "", arg_value("league", "")))
league_code <- unname(league_aliases[league_input])
home_team <- arg_value("home-team")
away_team <- arg_value("away-team")
match_date <- as.Date(arg_value("match-date", ""))
seasons <- trimws(strsplit(arg_value("seasons", "2324,2425,2526"), ",", fixed = TRUE)[[1]])
data_dir <- arg_value("data-dir", file.path("data", "leagues"))
refresh <- as_flag(arg_value("refresh", "false"))
half_life_days <- as.numeric(arg_value("half-life-days", "240"))
max_goals <- as.integer(arg_value("max-goals", "10"))
top_n <- as.integer(arg_value("top", "8"))
market_weight <- as.numeric(arg_value("market-weight", "0.25"))
home_odds <- as_optional_number("home-odds")
draw_odds <- as_optional_number("draw-odds")
away_odds <- as_optional_number("away-odds")
over_odds <- as_optional_number("over-2.5-odds")
under_odds <- as_optional_number("under-2.5-odds")
asian_line <- arg_value("asian-line", "")

if (is.na(league_code) || is.null(home_team) || is.null(away_team) || is.na(match_date)) {
  stop(paste(
    "Usage: Rscript predict_league_match.R --league epl",
    "--home-team Arsenal --away-team Liverpool --match-date 2026-08-15",
    "[--seasons 2324,2425,2526] [--refresh true]"
  ))
}
if (any(!grepl("^[0-9]{4}$", seasons))) stop("Each --seasons value must look like 2526")
if (!is.finite(half_life_days) || half_life_days <= 0) stop("--half-life-days must be positive")
if (max_goals < 6 || top_n < 3) stop("--max-goals must be at least 6 and --top at least 3")
if (!is.finite(market_weight) || market_weight < 0 || market_weight > 0.5) stop("--market-weight must be between 0 and 0.5")

eloml_ref <- Sys.getenv("ELOML_REF", "11d1670379b1602b662068f7aa9cce7deba0cdf1")

ensure_package <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
if (!requireNamespace("EloML", quietly = TRUE)) {
  ensure_package("remotes")
  remotes::install_github(paste0("ModelOriented/EloML@", eloml_ref), dependencies = TRUE, upgrade = "never")
}
suppressPackageStartupMessages(library(EloML))

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

read_season <- function(season) {
  url <- sprintf("https://www.football-data.co.uk/mmz4281/%s/%s.csv", season, league_code)
  cache <- file.path(data_dir, sprintf("%s-%s.csv", league_code, season))
  source <- cache

  if (refresh || !file.exists(cache)) {
    temporary <- tempfile(fileext = ".csv")
    downloaded <- tryCatch({
      suppressWarnings(download.file(url, temporary, mode = "wb", quiet = TRUE))
      file.copy(temporary, cache, overwrite = TRUE)
    }, error = function(error) FALSE)
    unlink(temporary)
    if (!isTRUE(downloaded) && !file.exists(cache)) {
      stop(sprintf("Could not download %s and no cache exists", url))
    }
    if (isTRUE(downloaded)) source <- url
  }

  frame <- read.csv(cache, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8-BOM")
  required <- c("Date", "HomeTeam", "AwayTeam", "FTHG", "FTAG")
  missing <- setdiff(required, names(frame))
  if (length(missing) > 0) stop(sprintf("%s is missing: %s", cache, paste(missing, collapse = ", ")))
  frame$season <- season
  attr(frame, "source") <- source
  frame
}

parse_date <- function(values) {
  parsed <- as.Date(values, format = "%d/%m/%Y")
  unresolved <- is.na(parsed)
  parsed[unresolved] <- as.Date(values[unresolved], format = "%d/%m/%y")
  parsed
}

season_frames <- lapply(seasons, read_season)
data_sources <- vapply(season_frames, function(frame) attr(frame, "source"), character(1))
results <- do.call(rbind, lapply(season_frames, function(frame) {
  data.frame(
    date = parse_date(frame$Date),
    home_team = trimws(frame$HomeTeam),
    away_team = trimws(frame$AwayTeam),
    home_goals = suppressWarnings(as.numeric(frame$FTHG)),
    away_goals = suppressWarnings(as.numeric(frame$FTAG)),
    season = frame$season,
    stringsAsFactors = FALSE
  )
}))

train <- subset(
  results,
  !is.na(date) & !is.na(home_goals) & !is.na(away_goals) & date < match_date
)
train <- train[order(train$date), ]
row.names(train) <- NULL
if (nrow(train) < 100) stop(sprintf("Too few completed matches before target date: %d", nrow(train)))

teams <- sort(unique(c(train$home_team, train$away_team)))
resolve_team <- function(team) {
  if (team %in% teams) return(team)
  suggestions <- agrep(team, teams, value = TRUE, max.distance = 0.35)
  hint <- if (length(suggestions)) paste0(" Did you mean: ", paste(head(suggestions, 5), collapse = ", "), "?") else ""
  stop(sprintf("Could not find team '%s'.%s", team, hint))
}
home_team <- resolve_team(home_team)
away_team <- resolve_team(away_team)

# Strict native EloML: no home advantage, draw probability, or score prediction.
train$match_id <- paste(train$date, train$home_team, train$away_team, seq_len(nrow(train)), sep = "_")
home_points <- ifelse(train$home_goals > train$away_goals, 1, ifelse(train$home_goals == train$away_goals, 0.5, 0))
away_points <- ifelse(home_points == 0.5, 0.5, 1 - home_points)
elo_data <- rbind(
  data.frame(player = train$home_team, round = train$match_id, score = home_points, stringsAsFactors = FALSE),
  data.frame(player = train$away_team, round = train$match_id, score = away_points, stringsAsFactors = FALSE)
)
fit_console <- capture.output(suppressWarnings(suppressMessages(
  elo_fit <- calculate_epp(elo_data, decreasing_metric = TRUE, compare_in_round = TRUE, estimation = "glmnet")
)), type = "output")

get_epp <- function(team) {
  value <- elo_fit$epp$epp[elo_fit$epp$player == team]
  if (length(value) != 1) stop(sprintf("No unique EloML EPP for %s", team))
  as.numeric(value)
}
home_epp <- get_epp(home_team)
away_epp <- get_epp(away_team)
strict_home <- as.numeric(calculate_probability(home_epp, away_epp))
strict_away <- 1 - strict_home

# Time-weighted home/away attack-defense model, separate from native EloML.
age_days <- as.numeric(match_date - train$date)
match_weights <- exp(-log(2) * age_days / half_life_days)
n_matches <- nrow(train)
long <- rbind(
  data.frame(goals = train$home_goals, is_home = 1, attack = train$home_team, defense = train$away_team, weight = match_weights),
  data.frame(goals = train$away_goals, is_home = 0, attack = train$away_team, defense = train$home_team, weight = match_weights)
)
long$attack <- factor(long$attack, levels = teams)
long$defense <- factor(long$defense, levels = teams)
score_fit <- glm(goals ~ is_home + attack + defense, family = poisson(), data = long, weights = weight)

predict_lambda <- function(attack, defense, is_home) {
  newdata <- data.frame(
    is_home = is_home,
    attack = factor(attack, levels = teams),
    defense = factor(defense, levels = teams)
  )
  as.numeric(predict(score_fit, newdata = newdata, type = "response"))
}
raw_lambda_home <- predict_lambda(home_team, away_team, 1)
raw_lambda_away <- predict_lambda(away_team, home_team, 0)

# Estimate Dixon-Coles rho on weighted low-score outcomes.
fitted_values <- fitted(score_fit)
historical_home_lambda <- fitted_values[seq_len(n_matches)]
historical_away_lambda <- fitted_values[n_matches + seq_len(n_matches)]
dc_tau <- function(home_goals, away_goals, lambda_home, lambda_away, rho) {
  tau <- rep(1, length(home_goals))
  tau[home_goals == 0 & away_goals == 0] <- 1 - lambda_home[home_goals == 0 & away_goals == 0] * lambda_away[home_goals == 0 & away_goals == 0] * rho
  tau[home_goals == 0 & away_goals == 1] <- 1 + lambda_home[home_goals == 0 & away_goals == 1] * rho
  tau[home_goals == 1 & away_goals == 0] <- 1 + lambda_away[home_goals == 1 & away_goals == 0] * rho
  tau[home_goals == 1 & away_goals == 1] <- 1 - rho
  tau
}
rho_objective <- function(rho) {
  tau <- dc_tau(train$home_goals, train$away_goals, historical_home_lambda, historical_away_lambda, rho)
  if (any(!is.finite(tau)) || any(tau <= 0)) return(Inf)
  -sum(match_weights * log(tau))
}
rho <- optimize(rho_objective, interval = c(-0.18, 0.18))$minimum

score_matrix <- function(lambda_home, lambda_away) {
  goals <- 0:max_goals
  matrix <- outer(dpois(goals, lambda_home), dpois(goals, lambda_away), FUN = "*")
  matrix[1, 1] <- matrix[1, 1] * (1 - lambda_home * lambda_away * rho)
  matrix[1, 2] <- matrix[1, 2] * (1 + lambda_home * rho)
  matrix[2, 1] <- matrix[2, 1] * (1 + lambda_away * rho)
  matrix[2, 2] <- matrix[2, 2] * (1 - rho)
  matrix / sum(matrix)
}

raw_matrix <- score_matrix(raw_lambda_home, raw_lambda_away)
matrix_probabilities <- function(matrix) {
  c(
    home = sum(matrix[row(matrix) > col(matrix)]),
    draw = sum(diag(matrix)),
    away = sum(matrix[row(matrix) < col(matrix)])
  )
}
matrix_over_2_5 <- function(matrix) {
  goal_total <- outer(0:max_goals, 0:max_goals, FUN = "+")
  sum(matrix[goal_total > 2])
}
matrix_btts <- function(matrix) {
  sum(matrix[row(matrix) > 1 & col(matrix) > 1])
}
raw_1x2 <- matrix_probabilities(raw_matrix)
raw_over <- matrix_over_2_5(raw_matrix)

valid_odds <- function(values) all(is.finite(values) & values > 1)
market_1x2 <- rep(NA_real_, 3)
names(market_1x2) <- c("home", "draw", "away")
if (valid_odds(c(home_odds, draw_odds, away_odds))) {
  inverse <- 1 / c(home = home_odds, draw = draw_odds, away = away_odds)
  market_1x2 <- inverse / sum(inverse)
}
market_totals <- c(over = NA_real_, under = NA_real_)
if (valid_odds(c(over_odds, under_odds))) {
  inverse <- 1 / c(over = over_odds, under = under_odds)
  market_totals <- inverse / sum(inverse)
}

calibrated_lambda_home <- raw_lambda_home
calibrated_lambda_away <- raw_lambda_away
if (all(is.finite(market_totals))) {
  target_over <- (1 - market_weight) * raw_over + market_weight * market_totals[["over"]]
  target_total <- uniroot(function(value) 1 - ppois(2, value) - target_over, interval = c(0.05, 12))$root
  scale <- target_total / (raw_lambda_home + raw_lambda_away)
  calibrated_lambda_home <- raw_lambda_home * scale
  calibrated_lambda_away <- raw_lambda_away * scale
}
calibrated_matrix <- score_matrix(calibrated_lambda_home, calibrated_lambda_away)
calibrated_1x2 <- matrix_probabilities(calibrated_matrix)
if (all(is.finite(market_1x2))) {
  calibrated_1x2 <- (1 - market_weight) * calibrated_1x2 + market_weight * market_1x2
  current_1x2 <- matrix_probabilities(calibrated_matrix)
  home_cells <- row(calibrated_matrix) > col(calibrated_matrix)
  draw_cells <- row(calibrated_matrix) == col(calibrated_matrix)
  away_cells <- row(calibrated_matrix) < col(calibrated_matrix)
  calibrated_matrix[home_cells] <- calibrated_matrix[home_cells] * calibrated_1x2[["home"]] / current_1x2[["home"]]
  calibrated_matrix[draw_cells] <- calibrated_matrix[draw_cells] * calibrated_1x2[["draw"]] / current_1x2[["draw"]]
  calibrated_matrix[away_cells] <- calibrated_matrix[away_cells] * calibrated_1x2[["away"]] / current_1x2[["away"]]
  calibrated_matrix <- calibrated_matrix / sum(calibrated_matrix)
  calibrated_1x2 <- matrix_probabilities(calibrated_matrix)
}

goals <- 0:max_goals
score_rows <- expand.grid(home = goals, away = goals)
score_rows$probability <- as.vector(calibrated_matrix)
score_rows <- head(score_rows[order(score_rows$probability, decreasing = TRUE), ], top_n)
score_rows$score <- paste0(score_rows$home, "-", score_rows$away)

team_form <- function(team, count = 8) {
  matches <- train[train$home_team == team | train$away_team == team, ]
  matches <- tail(matches[order(matches$date), ], count)
  is_home <- matches$home_team == team
  goals_for <- ifelse(is_home, matches$home_goals, matches$away_goals)
  goals_against <- ifelse(is_home, matches$away_goals, matches$home_goals)
  points <- ifelse(goals_for > goals_against, 3, ifelse(goals_for == goals_against, 1, 0))
  c(matches = nrow(matches), points = sum(points), goals_for = sum(goals_for), goals_against = sum(goals_against))
}
home_form <- team_form(home_team)
away_form <- team_form(away_team)
home_sample <- sum(train$home_team == home_team | train$away_team == home_team)
away_sample <- sum(train$home_team == away_team | train$away_team == away_team)

pct <- function(value) ifelse(is.na(value), "NA", sprintf("%.2f%%", 100 * value))
num <- function(value) ifelse(is.na(value), "NA", sprintf("%.3f", value))

cat("LEAGUE_ELOML_RESULT_BEGIN\n")
cat("league=", unname(league_names[league_code]), "\n", sep = "")
cat("league_code=", league_code, "\n", sep = "")
cat("home_team=", home_team, "\n", sep = "")
cat("away_team=", away_team, "\n", sep = "")
cat("match_date=", as.character(match_date), "\n", sep = "")
cat("seasons=", paste(seasons, collapse = ","), "\n", sep = "")
cat("data_sources=", paste(data_sources, collapse = " | "), "\n", sep = "")
cat("eloml_ref=", eloml_ref, "\n", sep = "")
cat("completed_matches=", n_matches, "\n", sep = "")
cat("latest_scored_date=", as.character(max(train$date)), "\n", sep = "")
cat("half_life_days=", num(half_life_days), "\n", sep = "")
cat("home_sample_matches=", home_sample, "\n", sep = "")
cat("away_sample_matches=", away_sample, "\n", sep = "")
cat("home_last8=matches:", home_form[["matches"]], ",points:", home_form[["points"]], ",gf:", home_form[["goals_for"]], ",ga:", home_form[["goals_against"]], "\n", sep = "")
cat("away_last8=matches:", away_form[["matches"]], ",points:", away_form[["points"]], ",gf:", away_form[["goals_for"]], ",ga:", away_form[["goals_against"]], "\n", sep = "")
cat("strict_epp_home=", num(home_epp), "\n", sep = "")
cat("strict_epp_away=", num(away_epp), "\n", sep = "")
cat("strict_binary_home=", pct(strict_home), "\n", sep = "")
cat("strict_binary_away=", pct(strict_away), "\n", sep = "")
cat("dixon_coles_rho=", num(rho), "\n", sep = "")
cat("raw_expected_goals_home=", num(raw_lambda_home), "\n", sep = "")
cat("raw_expected_goals_away=", num(raw_lambda_away), "\n", sep = "")
cat("raw_home_win=", pct(raw_1x2[["home"]]), "\n", sep = "")
cat("raw_draw=", pct(raw_1x2[["draw"]]), "\n", sep = "")
cat("raw_away_win=", pct(raw_1x2[["away"]]), "\n", sep = "")
cat("raw_over_2_5=", pct(raw_over), "\n", sep = "")
cat("market_home=", pct(market_1x2[["home"]]), "\n", sep = "")
cat("market_draw=", pct(market_1x2[["draw"]]), "\n", sep = "")
cat("market_away=", pct(market_1x2[["away"]]), "\n", sep = "")
cat("market_over_2_5=", pct(market_totals[["over"]]), "\n", sep = "")
cat("market_under_2_5=", pct(market_totals[["under"]]), "\n", sep = "")
cat("market_weight=", num(market_weight), "\n", sep = "")
cat("asian_line=", asian_line, "\n", sep = "")
cat("calibrated_expected_goals_home=", num(calibrated_lambda_home), "\n", sep = "")
cat("calibrated_expected_goals_away=", num(calibrated_lambda_away), "\n", sep = "")
cat("calibrated_home_win=", pct(calibrated_1x2[["home"]]), "\n", sep = "")
cat("calibrated_draw=", pct(calibrated_1x2[["draw"]]), "\n", sep = "")
cat("calibrated_away_win=", pct(calibrated_1x2[["away"]]), "\n", sep = "")
cat("calibrated_over_2_5=", pct(matrix_over_2_5(calibrated_matrix)), "\n", sep = "")
cat("both_teams_score=", pct(matrix_btts(calibrated_matrix)), "\n", sep = "")
cat("top_scores=\n")
for (index in seq_len(nrow(score_rows))) {
  cat(sprintf("%d,%s,%s\n", index, score_rows$score[[index]], pct(score_rows$probability[[index]])))
}
cat("LEAGUE_ELOML_RESULT_END\n")
