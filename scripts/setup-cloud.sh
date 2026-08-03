#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

ELOML_REF="${ELOML_REF:-11d1670379b1602b662068f7aa9cce7deba0cdf1}"

install_system_r() {
  local apt=(apt-get)
  if command -v sudo >/dev/null 2>&1; then
    apt=(sudo apt-get)
  fi

  "${apt[@]}" update
  DEBIAN_FRONTEND=noninteractive "${apt[@]}" install -y --no-install-recommends \
    r-base-core \
    r-base-dev \
    ca-certificates \
    curl \
    git \
    gfortran \
    libblas-dev \
    libcurl4-openssl-dev \
    liblapack-dev \
    libssl-dev \
    libxml2-dev \
    r-cran-data.table \
    r-cran-ggplot2 \
    r-cran-ggrepel \
    r-cran-glmnet \
    r-cran-matrix \
    r-cran-remotes
}

if ! command -v Rscript >/dev/null 2>&1; then
  install_system_r
fi

export ELOML_REF
Rscript - <<'RSCRIPT'
options(repos = c(CRAN = "https://cloud.r-project.org"))

required <- c("remotes", "data.table", "ggplot2", "ggrepel", "glmnet", "Matrix")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  install.packages(
    missing,
    dependencies = c("Depends", "Imports", "LinkingTo")
  )
}

ref <- Sys.getenv("ELOML_REF")
needs_install <- !requireNamespace("EloML", quietly = TRUE)
if (needs_install) {
  remotes::install_github(
    paste0("ModelOriented/EloML@", ref),
    dependencies = FALSE,
    upgrade = "never"
  )
}

stopifnot(requireNamespace("EloML", quietly = TRUE))
cat("EloML version:", as.character(utils::packageVersion("EloML")), "\n")
RSCRIPT

Rscript -e 'stopifnot(file.exists("data/international_results_latest.csv"))'
echo "Codex Cloud environment is ready."
