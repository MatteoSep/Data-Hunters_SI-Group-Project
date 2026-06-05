# =============================================================================
# merge_covariates.R
# -----------------------------------------------------------------------------
# Deterministic merge step, extracted verbatim from fetch_census_acs.R, sec. (4).
# Joins the ALREADY-FETCHED ACS covariates onto the (verified, external-FILTERED)
# mortality panel to produce the analysis panel. No Census API call: it reads the
# saved covariate CSV, so the result is fully reproducible offline and identical
# every run.
#
# Inputs (same working directory):
#   - panel_state_year.csv        510 = 51 states x 10 yrs (2010-2019);
#                                  external = V01-Y89 EXCLUDING Y60-Y69 & Y83-Y84
#                                  (so amenable + external + residual partition
#                                  all-cause exactly).
#   - census_acs_covariates.csv   520 = 52 jurisdictions (incl. Puerto Rico) x
#                                  10 yrs; the 5 ACS controls built by
#                                  fetch_census_acs.R.
# Output:
#   - panel_with_covariates.csv   510 x 26  (21 panel cols + 5 covariates)
#
# Join key : (state_fips, year) -- numeric, unambiguous. The covariate `state`
#            (NAME) is dropped to avoid a name collision with the panel's `state`.
#            Puerto Rico (fips 72) has no match in the 51-state panel and is
#            therefore dropped by the left_join, leaving exactly 510 rows.
#
# Run:  Rscript merge_covariates.R     (or open in RStudio and click Source)
# =============================================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr)
})

ctrl <- c("log_median_income", "poverty_rate", "unemployment_rate",
          "pct_black", "pct_hispanic")

f_panel <- "panel_state_year.csv"
f_cov   <- "census_acs_covariates.csv"
need <- c(f_panel, f_cov); miss <- need[!file.exists(need)]
if (length(miss))
  stop("Missing input(s) in\n  ", getwd(), "\n  ", paste(miss, collapse = "\n  "))

panel <- read_csv(f_panel, show_col_types = FALSE)
cov   <- read_csv(f_cov,   show_col_types = FALSE)

# ---- GUARD: the base panel's external MUST be the FILTERED series -------------
#  amenable + external_filtered + residual partition all-cause, so the residual
#  (= all - amenable - external) is >= 0 in every cell. The external SHARE is the
#  filtered-vs-unfiltered tell: ~19.25% filtered vs ~19.38% unfiltered (the latter
#  double-counts Y60-Y69/Y83-Y84, which already live inside amenable). This guard
#  is exactly what prevents re-creating a stale panel_with_covariates.csv.
resid     <- panel$deaths_allcause - panel$deaths_amenable - panel$deaths_external
ext_share <- 100 * sum(panel$deaths_external) / sum(panel$deaths_allcause)
cat(sprintf("Base panel: %d rows | external share = %.2f%% (expect ~19.25 filtered) | residual min = %d\n",
            nrow(panel), ext_share, min(resid)))
if (any(resid < 0))
  stop("Partition violated (residual < 0): the base panel's external looks UNFILTERED.\n",
       "  Rebuild panel_state_year.csv with build_panel.R (filtered external) before merging.")

# ---- THE MERGE (verbatim logic from fetch_census_acs.R) ----------------------
P <- panel |>
  left_join(select(cov, -state), by = c("state_fips", "year"))

# ---- VALIDATION --------------------------------------------------------------
na_cov  <- sapply(P[ctrl], function(x) sum(is.na(x)))
matched <- P |> filter(if_all(all_of(ctrl), ~ !is.na(.x))) |> distinct(state) |> nrow()
stopifnot(
  nrow(P) == 510L,                        # 51 states x 10 years
  ncol(P) == ncol(panel) + length(ctrl),  # 21 + 5 = 26
  all(na_cov == 0L),                      # every covariate fully populated
  matched == 51L                          # all 51 jurisdictions matched
)

write_csv(P, "panel_with_covariates.csv")
cat(sprintf("[write] panel_with_covariates.csv (%d x %d) -- merge OK: 510 rows, 51 states, 0 NA in covariates.\n",
            nrow(P), ncol(P)))
