# =============================================================================
# part2_causal_inference.R      (MERGED: Stage 1 + Stage 2 -> single script)
# -----------------------------------------------------------------------------
# PROJECT PART II -- CAUSAL INFERENCE
# Effect of the ACA Medicaid expansion on working-age (25-64) mortality, via a
# staggered Difference-in-Differences design.
#
# PIPELINE (one script):
#   Sec 1   Covariates: tidycensus ACS 1-year, 2010-2019                [data]
#   Sec 2   Merge covariates -> panel_with_covariates.csv               [data]
#   Sec 3   Static two-way fixed-effects (TWFE) -- the FOIL             [Stage 1b]
#   Sec 4   Goodman-Bacon decomposition -- diagnose forbidden 2x2s      [Stage 1c]
#   Sec 5   Descriptive raw-trend figure (informal parallel trends)     [Stage 1]
#   Sec 6   Callaway & Sant'Anna att_gt() -- the CORRECTED estimator    [Stage 2A]
#   Sec 7   Aggregations (group/simple/dynamic) + main results table    [Stage 2B]
#   Sec 8   Event-study figures (amenable / placebos / all-cause)       [Stage 2C]
#   Sec 9   HonestDiD (Rambachan-Roth) sensitivity                      [Stage 2D]
#   Sec 10  Combined headline numbers
#
# INPUT : panel_state_year.csv  (510 rows = 51 states x 10 years, 2010-2019),
#         produced by the data-construction script  build_panel.R.
# OUTPUT: panel_with_covariates.csv ; twfe_{nocontrols,withcontrols}.html ;
#         bacon_scatter.{png,pdf} ; raw_trends.{png,pdf} ; cs_main_table.html ;
#         es_{amenable,placebos,allcause}.{png,pdf} ;
#         honestdid_amenable{,_smoothness}.{png,pdf}
#
# Requires a Census API key (tidycensus reads CENSUS_API_KEY automatically).
#
# >>> HOW TO RUN -- RStudio (no command line needed) <<<
#   1. Open this file in RStudio and make sure panel_state_year.csv is in the
#      SAME folder (this script setwd()s to its own location below).
#   2. Set your Census key ONCE, in the RStudio console:
#         Sys.setenv(CENSUS_API_KEY = "your_key_here")
#      (to persist across sessions: census_api_key("your_key_here", install = TRUE),
#       then restart R).
#   3. Click "Source" (Ctrl+Shift+S) to run the whole script, or run line by line.
#   Figures appear in the Plots pane (print() calls) AND are written to disk.
#
# =============================================================================
# EXTENSIONS -- METHODS & R COMMANDS BEYOND THE COURSE SYLLABUS / SLIDES
# -----------------------------------------------------------------------------
# The course syllabus lists, for causal inference: Matching / subclassification,
# Difference-in-Differences, Synthetic control, Regression Discontinuity Design.
# The labs taught (R): lm / glm, summary / coef / confint / predict,
# sandwich + lmtest (robust & clustered SE), ggplot2, dplyr / tidyr, AER, car,
# MASS, MatchIt / WeightIt / cobalt, PanelMatch, synthdid / tidysynth, mle/optim.
# Everything listed below goes BEYOND that material and is used as an honours-
# level modern staggered-DiD analysis. Each is tagged "## [EXTENSION Ex]" at its
# first use in the code.
#
#   [E1] tidycensus  (get_acs, load_variables)
#        Programmatic ACS data acquisition.  -> data tool, beyond the course.
#
#   [E2] fixest::feols  (+ coeftable)
#        Fixed-effects regression with built-in clustered SE. The robust/
#        clustered-SE CONCEPT is in scope (sandwich/lmtest); the feols command
#        itself is the extension. Used here only for the static TWFE "foil".
#
#   [E3] bacondecomp::bacon   -- Goodman-Bacon (2021)
#        Decomposes the TWFE estimate into its 2x2 building blocks and the
#        weight of "forbidden" already-treated-as-control comparisons.
#        -> not in syllabus / slides.
#
#   [E4] did::att_gt , did::aggte   -- Callaway & Sant'Anna (2021)
#        Heterogeneity-robust staggered-DiD estimator (doubly-robust:
#        Sant'Anna & Zhao 2020). DiD is in scope; THIS estimator is the
#        extension (the modern correction to TWFE). Event-study aggregation.
#
#   [E5] HonestDiD  (constructOriginalCS, basisVector,
#        createSensitivityResults, createSensitivityResults_relativeMagnitudes,
#        createSensitivityPlot, createSensitivityPlot_relativeMagnitudes)
#        -- Rambachan & Roth (2023). Sensitivity of the event-study estimate to
#        violations of parallel trends.  -> not in syllabus / slides.
#
#   [E6] modelsummary ; tinytable (tt / save_tt)
#        Publication-quality regression / results tables (the Assignment bans
#        raw console output in the PDF). Presentation tools, beyond the course.
#
#   (Plumbing only, NOT statistical methods: purrr, scales, ragg device.)
# =============================================================================

suppressPackageStartupMessages({
  # --- in scope (taught in labs) -------------------------------------------
  library(ggplot2); library(dplyr); library(tidyr); library(readr); library(stringr)
  # --- extensions (see legend above) ---------------------------------------
  library(tidycensus)    ## [EXTENSION E1]
  library(fixest)        ## [EXTENSION E2]
  library(bacondecomp)   ## [EXTENSION E3]
  library(did)           ## [EXTENSION E4]
  library(HonestDiD)     ## [EXTENSION E5]
  library(modelsummary)  ## [EXTENSION E6]
  library(tinytable)     ## [EXTENSION E6]
  # --- plumbing -------------------------------------------------------------
  library(purrr); library(scales)
})

set.seed(20240601)                 # reproducible multiplier bootstrap (Stage 2)
options(width = 200)
theme_set(theme_minimal(base_size = 12))
BITERS <- 2000
ctrl   <- c("log_median_income","poverty_rate","unemployment_rate","pct_black","pct_hispanic")
CTRLF  <- ~ log_median_income + poverty_rate + unemployment_rate + pct_black + pct_hispanic

# --- RStudio working directory -----------------------------------------------
# Point R at THIS script's folder so the relative paths below (read/write the
# panel CSV, ggsave the figures) resolve correctly. Requires panel_state_year.csv
# to sit in the same folder as this script. rstudioapi only exists inside RStudio,
# so the guard makes this a clean no-op elsewhere. If the wd ends up wrong (e.g.
# you sourced from the console with another file focused), set it by hand with
# setwd("path/to/folder") or use Session > Set Working Directory > To Source File Location.
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}
cat("Working directory:", getwd(), "\n")

# --- PNG export device -------------------------------------------------------
# Use ragg for sharper PNG text if installed; otherwise fall back to ggplot's
# default PNG device. The vector PDFs (what goes in the paper) are unaffected.
png_dev <- if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else "png"
if (identical(png_dev, "png"))
  message("note: 'ragg' not installed -> PNGs via default device (PDFs unaffected).")

sep <- function(ch = "=", n = 78) cat("\n", strrep(ch, n), "\n", sep = "")

# warning capture (keep console clean; report unique warnings at the end)
WARN <- character(0)
record_w <- function(w) { WARN[[length(WARN)+1L]] <<- conditionMessage(w); invokeRestart("muffleWarning") }

# retry wrapper for flaky network calls (tidycensus)
with_retry <- function(fun, tries = 3L, wait = 1) {
  for (i in seq_len(tries)) {
    out <- tryCatch(fun(), error = function(e) {message("  retry ", i, ": ", conditionMessage(e)); NULL})
    if (!is.null(out)) return(out)
    Sys.sleep(wait)
  }
  stop("network call failed after ", tries, " attempts")
}

# =============================================================================
# Sec 1 -- COVARIATES : ACS 1-year, state geography, 2010-2019
# =============================================================================
sep(); cat("Sec 1: FETCHING ACS COVARIATES (2010-2019)\n"); sep()

key <- Sys.getenv("CENSUS_API_KEY")
if (!nzchar(key)) stop("CENSUS_API_KEY not set. In the RStudio console run:  Sys.setenv(CENSUS_API_KEY = \"<your_key>\")  (or census_api_key(\"<your_key>\", install = TRUE), then restart R).")

YEARS <- 2010:2019

# --- main vars (stable across all years): income, poverty, race/ethnicity -----
vars_main <- c(medinc = "B19013_001",                       # median household income
               pov_u  = "B17001_001", pov_b = "B17001_002", # poverty universe / below
               tot    = "B03002_001",                       # total (race universe)
               black  = "B03002_004", hisp  = "B03002_012")  # Black-alone-NH / Hispanic

main <- purrr::map_dfr(YEARS, function(y) {
  cat("  main vars", y, "\n")
  suppressMessages(with_retry(function()
    get_acs("state", variables = vars_main, year = y, survey = "acs1",  ## [EXTENSION E1]
            output = "wide", key = key))) |>
    mutate(year = y)
})

# --- unemployment: B23025 for 2011-2019; B23001-derived for 2010 --------------
# B23025 (civilian labor force / unemployed) is NOT tabulated in the 2010 ACS
# 1-year. For 2010 we reconstruct the *identical* quantities from B23001
# (sex x age x employment status); this was verified to reproduce B23025 exactly
# (max abs diff = 0) in overlapping years.
get_unemp <- function(y) {
  cat("  unemployment", y, if (y < 2011) "(via B23001)" else "(via B23025)", "\n")
  if (y >= 2011) {
    b <- suppressMessages(with_retry(function()
      get_acs("state", variables = c(lf = "B23025_003", unemp = "B23025_005"),  ## [EXTENSION E1]
              year = y, survey = "acs1", output = "wide", key = key)))
    tibble(GEOID = b$GEOID, year = y, lf = b$lfE, unemp = b$unempE)
  } else {
    vv  <- suppressMessages(load_variables(y, "acs1")) |> select(name, label)    ## [EXTENSION E1]
    raw <- suppressMessages(with_retry(function()
      get_acs("state", table = "B23001", year = y, survey = "acs1", key = key))) ## [EXTENSION E1]
    raw |>
      left_join(vv, by = c("variable" = "name")) |>
      mutate(is_unemp = str_detect(label, "Unemployed"),
             is_emp   = str_detect(label, "Employed")) |>   # capital E: != "Unemployed"
      group_by(GEOID) |>
      summarise(year = y,
                lf    = sum(estimate[is_emp | is_unemp]),
                unemp = sum(estimate[is_unemp]), .groups = "drop")
  }
}
emp <- purrr::map_dfr(YEARS, get_unemp)

# --- assemble the covariate table --------------------------------------------
cov <- main |>
  left_join(emp, by = c("GEOID", "year")) |>
  transmute(
    state_fips        = as.integer(GEOID),
    year              = as.integer(year),
    log_median_income = log(medincE),
    poverty_rate      = pov_bE / pov_uE,
    unemployment_rate = unemp  / lf,
    pct_black         = blackE / totE,
    pct_hispanic      = hispE  / totE
  )

# =============================================================================
# Sec 2 -- MERGE covariates onto the base panel
# =============================================================================
panel <- read_csv("panel_state_year.csv", show_col_types = FALSE)   # from build_panel.R
P <- panel |> left_join(cov, by = c("state_fips", "year"))

# --- merge assertions ---------------------------------------------------------
merge_ok_rows   <- nrow(P) == 510L
na_cov          <- sapply(P[ctrl], function(x) sum(is.na(x)))
merge_ok_na     <- all(na_cov == 0L)
matched_states  <- P |> filter(if_all(all_of(ctrl), ~ !is.na(.x))) |> distinct(state) |> nrow()
merge_ok_states <- matched_states == 51L

cat("\n[merge] rows =", nrow(P), "| states fully matched =", matched_states,
    "| NA in covariates:", if (merge_ok_na) "none" else paste(names(na_cov)[na_cov>0], collapse=", "), "\n")
stopifnot(merge_ok_rows, merge_ok_na, merge_ok_states)

write_csv(P, "panel_with_covariates.csv")
cat("[write] panel_with_covariates.csv (", nrow(P), " x ", ncol(P), ")\n", sep = "")

cat("\nCovariate summary (2010-2019, unweighted across state-years):\n")
print(as.data.frame(P |> summarise(across(all_of(ctrl),
        list(min = ~min(.x), mean = ~mean(.x), max = ~max(.x)))) |>
        pivot_longer(everything(), names_to = "stat", values_to = "value") |>
        separate(stat, into = c("covariate","fn"), sep = "_(?=[^_]+$)") |>
        pivot_wider(names_from = fn, values_from = value)), row.names = FALSE, digits = 4)

# =============================================================================
# Sec 3 -- STATIC TWFE  (the FOIL; corrected by Callaway-Sant'Anna in Sec 6)
#     Y_it = a_i + g_t + b*treated_post_it (+ controls) + e_it
#     FE | state_id + year ; clustered by state_id ; population-weighted
# =============================================================================
sep(); cat("Sec 3: STATIC TWFE (the FOIL)\n"); sep()

outcomes <- c(aa_allcause = "All-cause", aa_amenable = "Amenable",
              aa_nonamenable = "Non-amenable", aa_external = "External")

f_nc <- function(y) as.formula(sprintf("%s ~ treated_post | state_id + year", y))
f_wc <- function(y) as.formula(sprintf("%s ~ treated_post + %s | state_id + year",
                                       y, paste(ctrl, collapse = " + ")))

# (1) population-weighted, NO controls
m_nc <- lapply(names(outcomes), function(y)
  feols(f_nc(y), data = P, weights = ~population, cluster = ~state_id))   ## [EXTENSION E2]
names(m_nc) <- unname(outcomes)

# (2) population-weighted, WITH controls
m_wc <- lapply(names(outcomes), function(y)
  feols(f_wc(y), data = P, weights = ~population, cluster = ~state_id))   ## [EXTENSION E2]
names(m_wc) <- unname(outcomes)

# UNWEIGHTED, no controls (needed to match Goodman-Bacon) for amenable & all-cause
m_uw <- list(
  Amenable    = feols(f_nc("aa_amenable"),  data = P, cluster = ~state_id), ## [EXTENSION E2]
  `All-cause` = feols(f_nc("aa_allcause"), data = P, cluster = ~state_id)   ## [EXTENSION E2]
)

# --- modelsummary tables (HTML) ----------------------------------------------
gof_omit_str <- "AIC|BIC|RMSE|Log.Lik.|^R2$|R2 Adj.|R2 Pseudo|R2 Within Adj.|Std.Errors"
star_spec    <- c("*" = .1, "**" = .05, "***" = .01)
cmap         <- c("treated_post" = "Treated x Post (ACA expansion)")
note_common  <- "Age-adjusted mortality per 100,000 (2000 std). Two-way FE: state + year. Population-weighted. SE clustered by state in parentheses. * .10  ** .05  *** .01"

modelsummary(m_nc, output = "twfe_nocontrols.html",                       ## [EXTENSION E6]
  coef_map = cmap, gof_omit = gof_omit_str, stars = star_spec, vcov = ~state_id,
  title = "Static TWFE -- population-weighted, NO controls (the foil)",
  notes = note_common)

modelsummary(m_wc, output = "twfe_withcontrols.html",                     ## [EXTENSION E6]
  coef_map = cmap, gof_omit = gof_omit_str, stars = star_spec, vcov = ~state_id,
  title = "Static TWFE -- population-weighted, WITH controls (the foil)",
  notes = paste0(note_common,
    " Controls: log median income, poverty rate, unemployment rate, % Black, % Hispanic."))

cat("[write] twfe_nocontrols.html , twfe_withcontrols.html\n")

# console-only verification of the (no-controls) table content / GOF labels
cat("\n--- verification: no-controls table as data.frame (NOT for paper) ---\n")
print(modelsummary(m_nc, output = "data.frame",                           ## [EXTENSION E6]
  coef_map = cmap, gof_omit = gof_omit_str, stars = star_spec, vcov = ~state_id))

# helper to pull treated_post row (uses the model's clustered vcov)
get_tp <- function(m) {
  r <- as.data.frame(coeftable(m))["treated_post", ]                      ## [EXTENSION E2] (fixest)
  c(est = r[[1]], se = r[[2]], p = r[[4]])
}
stars  <- function(p) ifelse(p < .01, "***", ifelse(p < .05, "**", ifelse(p < .1, "*", "")))
fmt_es <- function(v) sprintf("%.3f (%.3f)%s", v["est"], v["se"], stars(v["p"]))

twfe_tab <- tibble(
  outcome       = unname(outcomes),
  no_controls   = sapply(m_nc, function(m) fmt_es(get_tp(m))),
  with_controls = sapply(m_wc, function(m) fmt_es(get_tp(m)))
)

# =============================================================================
# Sec 4 -- GOODMAN-BACON decomposition (primary outcome: aa_amenable)
# =============================================================================
sep(); cat("Sec 4: GOODMAN-BACON DECOMPOSITION\n"); sep()

bd <- bacon(aa_amenable ~ treated_post, data = P,                         ## [EXTENSION E3]
            id_var = "state_id", time_var = "year", quietly = TRUE)
stopifnot(is.data.frame(bd))
cat("bacon() returned", nrow(bd), "2x2 comparisons; types present:\n  ",
    paste(sort(unique(bd$type)), collapse = " | "), "\n")

overall_bacon <- sum(bd$weight * bd$estimate)          # = unweighted TWFE
uw_coef       <- coef(m_uw[["Amenable"]])[["treated_post"]]
bacon_match   <- abs(overall_bacon - uw_coef) < 1e-4

bd_sum <- bd |>
  group_by(type) |>
  summarise(n_comparisons = n(),
            total_weight  = sum(weight),
            wavg_estimate = weighted.mean(estimate, weight), .groups = "drop") |>
  mutate(weight_pct = 100 * total_weight / sum(total_weight)) |>
  arrange(desc(total_weight))

FORBIDDEN <- "Later vs Earlier Treated"
forbidden_share <- 100 * sum(bd$weight[bd$type == FORBIDDEN]) / sum(bd$weight)

# also decompose all-cause (weights identical; estimates differ)
bd_all <- bacon(aa_allcause ~ treated_post, data = P, id_var = "state_id", time_var = "year", quietly = TRUE) ## [EXTENSION E3]
weights_identical <- isTRUE(all.equal(sort(bd$weight), sort(bd_all$weight)))
bd_all_sum <- bd_all |>
  group_by(type) |>
  summarise(total_weight = sum(weight), wavg_estimate = weighted.mean(estimate, weight), .groups="drop") |>
  arrange(desc(total_weight))

# --- canonical Goodman-Bacon scatter -----------------------------------------
type_cols <- c("Treated vs Untreated"      = "#1b9e77",   # clean (vs never-treated)
               "Earlier vs Later Treated"  = "#7570b3",   # clean (not-yet-treated control)
               "Later vs Earlier Treated"  = "#d62728")   # FORBIDDEN (already-treated control)
p_bacon <- ggplot(bd, aes(weight, estimate, color = type, shape = type)) +
  geom_hline(yintercept = overall_bacon, linetype = "dashed", linewidth = 0.6) +
  geom_point(size = 2.6, alpha = 0.85) +
  scale_color_manual(values = type_cols) +
  scale_shape_manual(values = c("Treated vs Untreated" = 16,
                                "Earlier vs Later Treated" = 17,
                                "Later vs Earlier Treated" = 15)) +
  labs(title = "Goodman-Bacon decomposition of the static TWFE (outcome: amenable mortality)",
       subtitle = sprintf("Dashed line = overall TWFE = %.3f  |  weight on forbidden \"%s\" = %.1f%%",
                          overall_bacon, FORBIDDEN, forbidden_share),
       x = "Weight of 2x2 comparison", y = "2x2 DiD estimate",
       color = "Comparison type", shape = "Comparison type") +
  theme(legend.position = "bottom")
print(p_bacon)                                                            # -> RStudio Plots pane
ggsave("bacon_scatter.png", p_bacon, width = 9, height = 6, dpi = 300, device = png_dev)
ggsave("bacon_scatter.pdf", p_bacon, width = 9, height = 6)
cat("[write] bacon_scatter.png , bacon_scatter.pdf\n")

# =============================================================================
# Sec 5 -- DESCRIPTIVE FIGURE : raw weighted trends by treatment cohort
# =============================================================================
sep(); cat("Sec 5: DESCRIPTIVE FIGURE (raw trends)\n"); sep()

grp_levels <- c("2014","2015","2016","2019","Never (0)")
trends <- P |>
  mutate(group = factor(if_else(gname == 0, "Never (0)", as.character(gname)),
                        levels = grp_levels)) |>
  select(group, year, population, aa_amenable, aa_allcause) |>
  pivot_longer(c(aa_amenable, aa_allcause), names_to = "outcome", values_to = "aa") |>
  group_by(outcome, group, year) |>
  summarise(aa_wm = weighted.mean(aa, population), .groups = "drop")

p_trends <- ggplot(trends, aes(year, aa_wm, color = group)) +
  geom_vline(xintercept = 2014, linetype = "dashed", color = "grey40") +
  geom_line(linewidth = 0.9) + geom_point(size = 1.6) +
  facet_wrap(~ outcome, scales = "free_y",
             labeller = as_labeller(c(aa_amenable = "Amenable mortality (primary)",
                                      aa_allcause = "All-cause mortality (bridge)"))) +
  scale_x_continuous(breaks = 2010:2019) +
  scale_color_brewer(palette = "Dark2") +
  labs(title = "Population-weighted age-adjusted mortality by ACA-expansion cohort",
       subtitle = "Dashed line = 2014 (main expansion wave). Informal parallel-trends preview.",
       x = NULL, y = "Age-adjusted rate / 100,000", color = "Expansion year") +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())
print(p_trends)                                                           # -> RStudio Plots pane
ggsave("raw_trends.png", p_trends, width = 10, height = 5, dpi = 300, device = png_dev)
ggsave("raw_trends.pdf", p_trends, width = 10, height = 5)
cat("[write] raw_trends.png , raw_trends.pdf\n")

# =============================================================================
# PREPARE the panel for Callaway-Sant'Anna  (did wants a base R data.frame)
#   We reuse the in-memory panel built above (== panel_with_covariates.csv).
#   Two data-specific points handled here (diagnosed empirically):
#    (i)  the `did` package uses an internal symbol `gname`; a DATA COLUMN named
#         "gname" collides with its non-standard evaluation and breaks aggte().
#         => we pass the identical, differently-named column `first_treat_year`.
#    (ii) att_gt()'s native joint Wald pre-test (att$Wpval) is not computable for
#         the full sample (singular covariance, from the 2-3 state cohorts
#         2015/2016/2019). => we also compute a robust event-study joint pre-test.
# =============================================================================
P <- as.data.frame(P)
P$aa_residual <- P$aa_nonamenable - P$aa_external   # clean placebo (tiny Y60-69/Y83-84 overlap, negligible)
stopifnot(all(P$first_treat_year == P$gname))

# =============================================================================
# Sec 6 -- CALLAWAY & SANT'ANNA  att_gt()  (the CORRECTED estimator)
# =============================================================================
sep(); cat("Sec 6: att_gt() fits (CS group-time ATTs), biters =", BITERS, "\n"); sep()

run_att <- function(yname, xformla = ~1, control_group = "nevertreated") {
  withCallingHandlers(
    att_gt(yname = yname, tname = "year", idname = "state_id", gname = "first_treat_year", ## [EXTENSION E4]
           xformla = xformla, weightsname = "population", control_group = control_group,
           est_method = "dr", bstrap = TRUE, cband = TRUE, biters = BITERS,
           clustervars = "state_id", base_period = "universal", anticipation = 0, data = P),
    warning = record_w)
}
agg <- function(att, ...) withCallingHandlers(aggte(att, ...), warning = record_w)  ## [EXTENSION E4]

safe_n <- function(a) { v <- tryCatch(a$DIDparams$n, error=function(e) NULL); if (is.null(v)||length(v)==0) length(unique(P$state_id)) else as.integer(v) }
safe_W <- function(a) { v <- a$Wpval; if (is.null(v)||length(v)==0) NA_real_ else as.numeric(v) }

# event-study joint pre-test (Wald on pre-period coefs; robust to att$Wpval singularity)
es_pretest <- function(es) {
  ife <- es$inf.function$dynamic.inf.func.e
  n <- nrow(ife); V <- t(ife) %*% ife / n / n
  pre <- which(es$egt < -1)
  if (length(pre) < 1) return(c(W = NA, df = NA, p = NA))
  b <- es$att.egt[pre]; Vp <- V[pre, pre, drop = FALSE]
  df <- length(pre)
  # guard solve(): the small cohorts (2015/2016/2019) can make Vp singular for
  # some outcomes -> return NA instead of crashing the whole results table.
  W  <- tryCatch(as.numeric(t(b) %*% solve(Vp) %*% b), error = function(e) NA_real_)
  c(W = W, df = df, p = if (is.na(W)) NA_real_ else 1 - pchisq(W, df))
}

# HonestDiD <-> CS bridge (plain function; avoids fragile S3 dispatch)
honest_cs <- function(es, e = 0, type = c("relative_magnitude","smoothness"),
                      Mbarvec = NULL, Mvec = NULL, gridPoints = 100, alpha = 0.05) {
  type <- match.arg(type)
  if (es$DIDparams$base_period != "universal") stop("need universal base period")
  ife <- es$inf.function$dynamic.inf.func.e
  n <- nrow(ife); V <- t(ife) %*% ife / n / n
  ref  <- which(es$egt == -1)
  beta <- es$att.egt[-ref]; V <- V[-ref, -ref]
  npre <- sum(es$egt < -1); npost <- length(es$egt) - npre - 1L
  lvec <- HonestDiD::basisVector(index = e + 1, size = npost)             ## [EXTENSION E5]
  orig <- HonestDiD::constructOriginalCS(betahat=beta, sigma=V,           ## [EXTENSION E5]
            numPrePeriods=npre, numPostPeriods=npost, l_vec=lvec, alpha=alpha)
  if (type == "relative_magnitude") {
    if (is.null(Mbarvec)) Mbarvec <- c(0,0.5,1,1.5,2)
    robust <- HonestDiD::createSensitivityResults_relativeMagnitudes(     ## [EXTENSION E5]
      betahat=beta, sigma=V, numPrePeriods=npre, numPostPeriods=npost,
      l_vec=lvec, Mbarvec=Mbarvec, gridPoints=gridPoints, alpha=alpha)
  } else {
    if (is.null(Mvec)) Mvec <- seq(0, 0.05, 0.01)
    robust <- HonestDiD::createSensitivityResults(                        ## [EXTENSION E5]
      betahat=beta, sigma=V, numPrePeriods=npre, numPostPeriods=npost,
      l_vec=lvec, Mvec=Mvec, alpha=alpha)
  }
  list(robust_ci = robust, orig_ci = orig, type = type)
}
breakdown_M <- function(rci, mcol) {           # largest M(bar) where robust CI excludes 0
  excl <- (rci$lb > 0) | (rci$ub < 0)
  if (any(excl, na.rm=TRUE)) max(rci[[mcol]][excl], na.rm=TRUE) else NA_real_
}

es_tidy <- function(es, label) {
  tibble(outcome = label, e = es$egt, att = es$att.egt,
         se = ifelse(es$egt == -1 & is.na(es$se.egt), 0, es$se.egt), crit = es$crit.val.egt) |>
    mutate(lo = att - crit*se, hi = att + crit*se,
           period = factor(ifelse(e < 0, "pre", "post"), levels = c("pre","post")))
}
es_cols <- c(pre = "#2166ac", post = "#b2182b")
make_es_plot <- function(df, title, subtitle = NULL, facet = FALSE) {
  g <- ggplot(df, aes(e, att, color = period)) +
    geom_hline(yintercept = 0, color = "grey50") +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = "grey40") +
    geom_line(aes(group = 1), color = "grey65", linewidth = 0.4) +
    geom_pointrange(aes(ymin = lo, ymax = hi), linewidth = 0.6, size = 0.5, na.rm = TRUE) +
    scale_color_manual(values = es_cols, labels = c(pre="Pre (e<0)", post="Post (e>=0)")) +
    scale_x_continuous(breaks = -4:5) +
    labs(title = title, subtitle = subtitle, color = NULL,
         x = "Event time (years since Medicaid expansion)",
         y = "ATT, age-adjusted deaths / 100,000") +
    theme(legend.position = "bottom")
  if (facet) g <- g + facet_wrap(~ outcome, scales = "free_y")
  g
}

fits <- list(
  amenable_uncond_never = run_att("aa_amenable"),                               # A1 PRIMARY
  amenable_cond_never   = run_att("aa_amenable", xformla = CTRLF),              # A2 conditional
  amenable_uncond_nyt   = run_att("aa_amenable", control_group = "notyettreated"), # A3 not-yet-treated
  allcause_uncond_never = run_att("aa_allcause"),                               # A4 bridge
  nonamenable_placebo   = run_att("aa_nonamenable"),                            # A5 placebo
  external_placebo      = run_att("aa_external"),                               # A5 placebo
  residual_placebo      = run_att("aa_residual")                                # A5 placebo (cleanest)
)
lab <- list(
  amenable_uncond_never = c("Amenable","Uncond., never-tr. (PRIMARY)"),
  amenable_cond_never   = c("Amenable","Conditional, never-tr."),
  amenable_uncond_nyt   = c("Amenable","Uncond., not-yet-tr."),
  allcause_uncond_never = c("All-cause","Uncond., never-tr. (bridge)"),
  nonamenable_placebo   = c("Non-amenable","Uncond., never-tr. (placebo)"),
  external_placebo      = c("External","Uncond., never-tr. (placebo)"),
  residual_placebo      = c("Residual","Uncond., never-tr. (placebo)")
)
cat("fitted", length(fits), "att_gt objects.\n")
cat("att$Wpval (native joint Wald pre-test):\n")
for (k in names(fits)) cat(sprintf("  %-22s %s\n", k, ifelse(is.na(safe_W(fits[[k]])), "singular -> NA", round(safe_W(fits[[k]]),4))))

# =============================================================================
# Sec 7 -- AGGREGATIONS + main results table
# =============================================================================
sep(); cat("Sec 7: aggregations\n"); sep()
grp_list <- lapply(fits, function(a) agg(a, type = "group"))
es_list  <- lapply(fits, function(a) agg(a, type = "dynamic", min_e = -4, max_e = 5, na.rm = TRUE))
# (optional robustness, NOT the primary spec) fixed-composition dynamic path through e=3:
#   es_bal <- agg(fits$amenable_uncond_never, type = "dynamic", min_e = -4, max_e = 3, balance_e = 3, na.rm = TRUE)
simple_primary <- agg(fits$amenable_uncond_never, type = "simple")

main_tab <- imap_dfr(fits, function(a, k) {
  g <- grp_list[[k]]; pt <- es_pretest(es_list[[k]])
  tibble(Outcome = lab[[k]][1], Spec = lab[[k]][2],
         ATT = g$overall.att, SE = g$overall.se,
         `95% CI` = sprintf("[%.2f, %.2f]", g$overall.att - 1.96*g$overall.se, g$overall.att + 1.96*g$overall.se),
         `Pre-trend p` = unname(pt["p"]),
         `Wald p` = safe_W(a),
         N = safe_n(a))
})

tt_main <- main_tab |>
  mutate(ATT = round(ATT,3), SE = round(SE,3), `Pre-trend p` = round(`Pre-trend p`,3),
         `Wald p` = ifelse(is.na(`Wald p`), "—", sprintf("%.3f", `Wald p`))) |>
  tt(digits = 3,                                                          ## [EXTENSION E6]
     caption = "Callaway & Sant'Anna overall ATT (group/cohort aggregation), population-weighted, doubly-robust.",
     notes = list(
       "ATT = group-aggregated overall ATT; SE bootstrapped (2000 iters), clustered by state; 95% CI = ATT +/- 1.96 SE.",
       "Pre-trend p = joint Wald test on the estimated pre-period event-study coefficients (all e < -1) from the influence-function vcov.",
       "Wald p = did's native joint pre-test; '-' = not computable (singular covariance from the 2-3 state cohorts).",
       "N = number of units (states). Outcomes are age-adjusted mortality /100,000 (2000 std)."))
save_tt(tt_main, "cs_main_table.html", overwrite = TRUE)                  ## [EXTENSION E6]
png_ok <- tryCatch({ save_tt(tt_main, "cs_main_table.png", overwrite = TRUE); TRUE },
                   error = function(e) FALSE)
cat("[write] cs_main_table.html", if (png_ok) "+ .png" else "(png skipped: needs typst)", "\n")
cat("\nmain results table (console copy):\n"); print(as.data.frame(main_tab), row.names = FALSE, digits = 4)

# =============================================================================
# Sec 8 -- EVENT-STUDY FIGURES (custom ggplot)
# =============================================================================
sep(); cat("Sec 8: event-study figures\n"); sep()
es_amenable <- es_tidy(es_list$amenable_uncond_never, "Amenable")
es_allcause <- es_tidy(es_list$allcause_uncond_never, "All-cause")
es_placebo  <- bind_rows(
  es_tidy(es_list$residual_placebo,    "Residual (non-amenable - external)"),
  es_tidy(es_list$external_placebo,    "External"),
  es_tidy(es_list$nonamenable_placebo, "Non-amenable")
) |> mutate(outcome = factor(outcome, levels = c("Residual (non-amenable - external)","External","Non-amenable")))

p_amen <- make_es_plot(es_amenable,
  "Callaway-Sant'Anna event study: amenable mortality (PRIMARY)",
  "Population-weighted, doubly-robust, never-treated controls. Bars = 95% uniform confidence band. Ref. period e = -1.")
p_plac <- make_es_plot(es_placebo,
  "Placebo event studies (should be flat / null)",
  "Residual = cleanest placebo. Same CS specification as primary.", facet = TRUE)
p_allc <- make_es_plot(es_allcause,
  "Event study: all-cause mortality (bridge)",
  "Population-weighted, doubly-robust, never-treated controls. Bars = 95% uniform band.")

print(p_amen); print(p_plac); print(p_allc)                               # -> RStudio Plots pane
ggsave("es_amenable.png", p_amen, width = 9, height = 5.6, dpi = 300, device = png_dev)
ggsave("es_amenable.pdf", p_amen, width = 9, height = 5.6)
ggsave("es_placebos.png", p_plac, width = 11, height = 5, dpi = 300, device = png_dev)
ggsave("es_placebos.pdf", p_plac, width = 11, height = 5)
ggsave("es_allcause.png", p_allc, width = 9, height = 5.6, dpi = 300, device = png_dev)
ggsave("es_allcause.pdf", p_allc, width = 9, height = 5.6)
cat("[write] es_amenable.{png,pdf}, es_placebos.{png,pdf}, es_allcause.{png,pdf}\n")

# =============================================================================
# Sec 9 -- HonestDiD sensitivity (primary amenable event study)
# =============================================================================
sep(); cat("Sec 9: HonestDiD (Rambachan-Roth) sensitivity on the primary (e=0)\n"); sep()
es1 <- es_list$amenable_uncond_never
hd_rm <- withCallingHandlers(honest_cs(es1, e = 0, type = "relative_magnitude", Mbarvec = c(0,0.5,1,1.5,2)), warning = record_w)
hd_sm <- withCallingHandlers(honest_cs(es1, e = 0, type = "smoothness",        Mvec = seq(0,0.05,0.01)),      warning = record_w)
bd_rm <- breakdown_M(hd_rm$robust_ci, "Mbar")
bd_sm <- breakdown_M(hd_sm$robust_ci, "M")

p_hd_rm <- HonestDiD::createSensitivityPlot_relativeMagnitudes(hd_rm$robust_ci, hd_rm$orig_ci) +  ## [EXTENSION E5]
  labs(title = "HonestDiD: relative-magnitudes sensitivity (amenable, e=0)",
       subtitle = "Robust 95% CI vs Mbar (max post-period violation as a multiple of the largest pre-period violation).")
p_hd_sm <- HonestDiD::createSensitivityPlot(hd_sm$robust_ci, hd_sm$orig_ci) +                     ## [EXTENSION E5]
  labs(title = "HonestDiD: smoothness sensitivity (amenable, e=0)",
       subtitle = "Robust 95% CI vs M (max change in the slope of the trend between consecutive periods).")
print(p_hd_rm); print(p_hd_sm)                                            # -> RStudio Plots pane
ggsave("honestdid_amenable.png", p_hd_rm, width = 8.5, height = 5.5, dpi = 300, device = png_dev)
ggsave("honestdid_amenable.pdf", p_hd_rm, width = 8.5, height = 5.5)
ggsave("honestdid_amenable_smoothness.png", p_hd_sm, width = 8.5, height = 5.5, dpi = 300, device = png_dev)
ggsave("honestdid_amenable_smoothness.pdf", p_hd_sm, width = 8.5, height = 5.5)
cat("[write] honestdid_amenable.{png,pdf}, honestdid_amenable_smoothness.{png,pdf}\n")

# =============================================================================
# Sec 10 -- COMBINED HEADLINE NUMBERS
# =============================================================================
sep("#"); cat("HEADLINE NUMBERS -- STAGE 1 (the FOIL: TWFE + Goodman-Bacon)\n"); sep("#")

cat("\n[A] Covariate merge: rows =", nrow(P),
    "| 51 states fully matched =", merge_ok_states,
    "| no NA in 5 covariates =", merge_ok_na, "\n")

cat("\n[B] Static TWFE coefficient on treated_post  (est (clustered SE) stars):\n")
print(as.data.frame(twfe_tab), row.names = FALSE)
cat("    -> PRIMARY (amenable, weighted, WITH controls): ",
    fmt_es(get_tp(m_wc[["Amenable"]])), "\n", sep = "")

cat("\n[C] Bacon internal-consistency check (amenable):\n")
cat(sprintf("    unweighted TWFE coef        = %.5f\n", uw_coef))
cat(sprintf("    Bacon overall weighted avg  = %.5f\n", overall_bacon))
cat(sprintf("    difference                  = %.2e   -> MATCH = %s\n", overall_bacon - uw_coef, bacon_match))

cat("\n[D] Goodman-Bacon weight by comparison type (amenable):\n")
print(as.data.frame(bd_sum |>
        transmute(type, n_comparisons, total_weight = round(total_weight,4),
                  weight_pct = round(weight_pct,1), wavg_estimate = round(wavg_estimate,3))),
      row.names = FALSE)
cat(sprintf("\n    >>> FORBIDDEN share -- weight on \"%s\" = %.1f%%  <<<\n", FORBIDDEN, forbidden_share))

cat("\n[E] All-cause Bacon (weights identical to amenable =", weights_identical,
    "); per-type weighted estimates:\n")
print(as.data.frame(bd_all_sum |>
        transmute(type, total_weight = round(total_weight,4), wavg_estimate = round(wavg_estimate,3))),
      row.names = FALSE)

sep("#"); cat("HEADLINE NUMBERS -- STAGE 2 (PRIMARY: Callaway & Sant'Anna)\n"); sep("#")
g1 <- grp_list$amenable_uncond_never; g2 <- grp_list$amenable_cond_never; g3 <- grp_list$amenable_uncond_nyt
ci <- function(g) sprintf("%.3f  (SE %.3f)  95%% CI [%.3f, %.3f]",
                          g$overall.att, g$overall.se, g$overall.att-1.96*g$overall.se, g$overall.att+1.96*g$overall.se)

cat("\n[1] PRIMARY overall ATT  (aa_amenable, unconditional, never-treated, GROUP aggregation):\n")
cat("      ", ci(g1), "\n")
cat("      simple aggregation        : ", sprintf("%.3f (SE %.3f)", simple_primary$overall.att, simple_primary$overall.se), "\n")
cat("      conditional (A2)          : ", ci(g2), "\n")
cat("      not-yet-treated (A3)      : ", ci(g3), "\n")

cat("\n[2] PRE-TRENDS (amenable, primary):\n")
pt1 <- es_pretest(es1)
cat(sprintf("      did native Wald (att$Wpval) : %s\n", ifelse(is.na(safe_W(fits$amenable_uncond_never)),"singular -> NA",round(safe_W(fits$amenable_uncond_never),4))))
cat(sprintf("      event-study joint pre-test  : W=%.2f, df=%d, p=%.4f %s\n", pt1["W"], pt1["df"], pt1["p"],
            ifelse(pt1["p"]<0.05,"  <- pre-trend signal (p<0.05)","")))
cat("      individual pre-period ES estimates (uniform 95% band):\n")
pre_df <- es_amenable |> filter(e < 0) |> transmute(e, att=round(att,3), lo=round(lo,3), hi=round(hi,3),
              flag = ifelse(e!=-1 & (lo>0|hi<0), " *", ""))
print(as.data.frame(pre_df), row.names = FALSE)

cat("\n[3] POST dynamics (amenable, e = 0..5):\n")
post_df <- es_amenable |> filter(e >= 0) |> transmute(e, att=round(att,3), lo=round(lo,3), hi=round(hi,3),
              sig = ifelse(lo>0|hi<0, " *", ""))
print(as.data.frame(post_df), row.names = FALSE)

cat("\n[4] HonestDiD (Rambachan-Roth) on e=0:\n")
cat("      relative-magnitudes robust 95% CIs:\n")
print(as.data.frame(hd_rm$robust_ci |> transmute(Mbar, lb=round(lb,3), ub=round(ub,3))), row.names = FALSE)
cat("      original CS 95% CI: ", sprintf("[%.3f, %.3f]", hd_rm$orig_ci$lb, hd_rm$orig_ci$ub), "\n")
cat(sprintf("      BREAKDOWN Mbar (largest Mbar s.t. robust CI excludes 0): %s\n",
            ifelse(is.na(bd_rm), "NA -- CI covers 0 even at Mbar=0 (effect not distinguishable from 0)", round(bd_rm,3))))
cat(sprintf("      smoothness: breakdown M = %s; FLCI at M=0 = [%.3f, %.3f]\n",
            ifelse(is.na(bd_sm),"NA (covers 0)",round(bd_sm,3)),
            hd_sm$robust_ci$lb[1], hd_sm$robust_ci$ub[1]))

cat("\n[5] PLACEBOS (overall group ATT; expect null/flat, esp. residual):\n")
for (k in c("residual_placebo","external_placebo","nonamenable_placebo")) {
  g <- grp_list[[k]]; covers0 <- (g$overall.att-1.96*g$overall.se) <= 0 & (g$overall.att+1.96*g$overall.se) >= 0
  cat(sprintf("      %-26s ATT=%.3f (SE %.3f)  %s\n", lab[[k]][1], g$overall.att, g$overall.se,
              ifelse(covers0, "-> NULL (95% CI covers 0)", "-> NON-null (!)")))
}

cat("\n[6] ROBUSTNESS AGREEMENT (amenable):\n")
sign_agree <- sign(g1$overall.att)==sign(g2$overall.att) & sign(g1$overall.att)==sign(g3$overall.att)
cat(sprintf("      never-treated %.3f  vs  not-yet-treated %.3f  vs  conditional %.3f\n",
            g1$overall.att, g3$overall.att, g2$overall.att))
cat(sprintf("      same sign across specs: %s ; all 95%% CIs cover 0: %s\n",
            sign_agree,
            all(sapply(list(g1,g2,g3), function(g) (g$overall.att-1.96*g$overall.se)<=0 & (g$overall.att+1.96*g$overall.se)>=0))))

if (length(WARN)) { cat("\nUnique warnings captured (expected -- small cohorts & singular Wald):\n"); for (w in unique(WARN)) cat("   -", w, "\n") }

sep("#")
cat("DELIVERABLES: panel_with_covariates.csv ; twfe_{nocontrols,withcontrols}.html ;\n")
cat("  bacon_scatter.{png,pdf} ; raw_trends.{png,pdf} ; cs_main_table.html",
    if (png_ok) "(+png)" else "", "; es_{amenable,placebos,allcause}.{png,pdf} ;\n")
cat("  honestdid_amenable{,_smoothness}.{png,pdf}\n")
cat("INTERPRETATION: Sec 3-4 (TWFE/Bacon) is the FOIL; Sec 6-9 (Callaway-Sant'Anna) is PRIMARY.\n")
sep("#")
