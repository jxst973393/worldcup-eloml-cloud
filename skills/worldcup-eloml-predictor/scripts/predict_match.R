#!/usr/bin/env Rscript

# Native ModelOriented/EloML strength model plus an explicitly separate
# Poisson score layer. Designed to run locally or in Codex Cloud.

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  key <- paste0("--", name)
  position <- match(key, args)
  if (is.na(position)) {
    return(default)
  }
  if (position == length(args)) {
    stop(sprintf("Missing value after %s", key))
  }
  args[[position + 1]]
}

as_flag <- function(value) {
  tolower(as.character(value)) %in% c("1", "true", "yes", "y")
}

team_a <- arg_value("team-a")
team_b <- arg_value("team-b")
match_date <- as.Date(arg_value("match-date"))
training_start <- as.Date(arg_value("training-start", "2021-01-01"))
neutral <- as_flag(arg_value("neutral", "true"))
refresh <- as_flag(arg_value("refresh", "false"))
data_path <- arg_value("data", "")
max_goals <- as.integer(arg_value("max-goals", "10"))
top_n <- as.integer(arg_value("top", "8"))

if (is.null(team_a) || is.null(team_b) || is.na(match_date)) {
  stop(paste(
    "Usage: Rscript predict_match.R",
    "--team-a England --team-b Argentina",
    "--match-date 2026-07-15 [--neutral true] [--refresh true]"
  ))
}

if (max_goals < 5 || top_n < 3) {
  stop("--max-goals must be at least 5 and --top must be at least 3")
}

data_url <- "https://raw.githubusercontent.com/martj42/international_results/master/results.csv"
eloml_ref <- Sys.getenv(
  "ELOML_REF",
  "11d1670379b1602b662068f7aa9cce7deba0cdf1"
)
local_candidates <- c(
  file.path("data", "international_results_latest.csv"),
  file.path("data", "international_results.csv")
)

ensure_package <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

if (!requireNamespace("EloML", quietly = TRUE)) {
  ensure_package("remotes")
  remotes::install_github(
    paste0("ModelOriented/EloML@", eloml_ref),
    dependencies = TRUE,
    upgrade = "never"
  )
}

suppressPackageStartupMessages(library(EloML))

read_online <- function() {
  tryCatch(
    read.csv(data_url, stringsAsFactors = FALSE),
    error = function(error) NULL
  )
}

results <- NULL
data_source <- NULL

if (nzchar(data_path)) {
  if (!file.exists(data_path)) {
    stop(sprintf("Data file does not exist: %s", data_path))
  }
  results <- read.csv(data_path, stringsAsFactors = FALSE)
  data_source <- normalizePath(data_path, winslash = "/", mustWork = TRUE)
} else if (refresh) {
  results <- read_online()
  if (!is.null(results)) {
    data_source <- data_url
  }
}

if (is.null(results)) {
  existing <- local_candidates[file.exists(local_candidates)]
  if (length(existing) > 0) {
    results <- read.csv(existing[[1]], stringsAsFactors = FALSE)
    data_source <- normalizePath(existing[[1]], winslash = "/", mustWork = TRUE)
  } else {
    results <- read_online()
    if (is.null(results)) {
      stop("Could not read online data and no local cache was found")
    }
    data_source <- data_url
  }
}

required_columns <- c(
  "date", "home_team", "away_team", "home_score", "away_score", "neutral"
)
missing_columns <- setdiff(required_columns, names(results))
if (length(missing_columns) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_columns, collapse = ", ")))
}

results$date <- as.Date(results$date)
results$home_score <- suppressWarnings(as.numeric(results$home_score))
results$away_score <- suppressWarnings(as.numeric(results$away_score))
results$neutral_bool <- as.logical(results$neutral)

train <- subset(
  results,
  !is.na(home_score) &
    !is.na(away_score) &
    !is.na(date) &
    date >= training_start &
    date < match_date
)

if (nrow(train) < 100) {
  stop(sprintf("Too few scored matches in training window: %d", nrow(train)))
}

train$match_id <- paste(train$date, train$home_team, train$away_team, sep = "_")
home_points <- ifelse(
  train$home_score > train$away_score,
  1,
  ifelse(train$home_score == train$away_score, 0.5, 0)
)
away_points <- ifelse(home_points == 0.5, 0.5, 1 - home_points)

elo_data <- rbind(
  data.frame(
    player = train$home_team,
    round = train$match_id,
    score = home_points,
    stringsAsFactors = FALSE
  ),
  data.frame(
    player = train$away_team,
    round = train$match_id,
    score = away_points,
    stringsAsFactors = FALSE
  )
)

fit_console <- capture.output(
  suppressWarnings(
    suppressMessages(
      fit <- calculate_epp(
        elo_data,
        decreasing_metric = TRUE,
        compare_in_round = TRUE,
        estimation = "glmnet"
      )
    )
  ),
  type = "output"
)
ratings <- fit$epp

get_epp <- function(team) {
  value <- ratings$epp[ratings$player == team]
  if (length(value) != 1) {
    teams <- sort(unique(c(train$home_team, train$away_team)))
    suggestions <- agrep(team, teams, value = TRUE, max.distance = 0.35)
    hint <- if (length(suggestions) > 0) {
      paste0(" Did you mean: ", paste(head(suggestions, 5), collapse = ", "), "?")
    } else {
      ""
    }
    stop(sprintf("Could not find team '%s'.%s", team, hint))
  }
  as.numeric(value)
}

epp_a <- get_epp(team_a)
epp_b <- get_epp(team_b)
strict_a <- as.numeric(calculate_probability(epp_a, epp_b))
strict_b <- 1 - strict_a

train$home_epp <- vapply(train$home_team, get_epp, numeric(1))
train$away_epp <- vapply(train$away_team, get_epp, numeric(1))
train$epp_diff <- train$home_epp - train$away_epp
train$neutral_factor <- factor(train$neutral_bool, levels = c(FALSE, TRUE))

home_goal_model <- glm(
  home_score ~ epp_diff + neutral_factor,
  family = poisson(),
  data = train
)
away_goal_model <- glm(
  away_score ~ epp_diff + neutral_factor,
  family = poisson(),
  data = train
)

newdata <- data.frame(
  epp_diff = epp_a - epp_b,
  neutral_factor = factor(neutral, levels = c(FALSE, TRUE))
)
lambda_a <- as.numeric(predict(home_goal_model, newdata = newdata, type = "response"))
lambda_b <- as.numeric(predict(away_goal_model, newdata = newdata, type = "response"))

goals <- 0:max_goals
score_probs <- outer(dpois(goals, lambda_a), dpois(goals, lambda_b), FUN = "*")
probability_mass <- sum(score_probs)
p_a_win <- sum(score_probs[row(score_probs) > col(score_probs)]) / probability_mass
p_draw <- sum(diag(score_probs)) / probability_mass
p_b_win <- sum(score_probs[row(score_probs) < col(score_probs)]) / probability_mass

score_rows <- expand.grid(a = goals, b = goals)
score_rows$probability <- as.vector(score_probs)
score_rows <- score_rows[order(score_rows$probability, decreasing = TRUE), ]
score_rows <- head(score_rows, top_n)
score_rows$score <- paste0(score_rows$a, "-", score_rows$b)

lambda_total <- lambda_a + lambda_b
p_under_2_5 <- ppois(2, lambda_total)
p_over_2_5 <- 1 - p_under_2_5
p_btts <- 1 - exp(-lambda_a) - exp(-lambda_b) + exp(-lambda_total)

pct <- function(value) sprintf("%.2f%%", 100 * value)

cat("ELOML_RESULT_BEGIN\n")
cat("team_a=", team_a, "\n", sep = "")
cat("team_b=", team_b, "\n", sep = "")
cat("match_date=", as.character(match_date), "\n", sep = "")
cat("neutral=", tolower(as.character(neutral)), "\n", sep = "")
cat("data_source=", data_source, "\n", sep = "")
cat("eloml_ref=", eloml_ref, "\n", sep = "")
cat("training_start=", as.character(training_start), "\n", sep = "")
cat("training_cutoff_before=", as.character(match_date), "\n", sep = "")
cat("scored_matches=", nrow(train), "\n", sep = "")
cat("latest_scored_date=", as.character(max(train$date)), "\n", sep = "")
cat("epp_a=", sprintf("%.6f", epp_a), "\n", sep = "")
cat("epp_b=", sprintf("%.6f", epp_b), "\n", sep = "")
cat("strict_binary_a=", pct(strict_a), "\n", sep = "")
cat("strict_binary_b=", pct(strict_b), "\n", sep = "")
cat("expected_goals_a=", sprintf("%.3f", lambda_a), "\n", sep = "")
cat("expected_goals_b=", sprintf("%.3f", lambda_b), "\n", sep = "")
cat("poisson_a_win=", pct(p_a_win), "\n", sep = "")
cat("poisson_draw=", pct(p_draw), "\n", sep = "")
cat("poisson_b_win=", pct(p_b_win), "\n", sep = "")
cat("under_2_5=", pct(p_under_2_5), "\n", sep = "")
cat("over_2_5=", pct(p_over_2_5), "\n", sep = "")
cat("both_teams_score=", pct(p_btts), "\n", sep = "")
cat("score_matrix_tail=", pct(1 - probability_mass), "\n", sep = "")
cat("top_scores=\n")
for (index in seq_len(nrow(score_rows))) {
  cat(sprintf(
    "%d,%s,%s\n",
    index,
    score_rows$score[[index]],
    pct(score_rows$probability[[index]])
  ))
}
cat("ELOML_RESULT_END\n")
