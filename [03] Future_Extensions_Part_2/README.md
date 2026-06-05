# Future Extension: Callaway & Sant'Anna DiD (incomplete)

>  **This analysis was not completed.** The material in this folder represents preliminary work developed primarily with AI assistance and was not finished due to time and resource constraints. It does not form part of the graded submission and should be interpreted accordingly.

---

## Motivation

Part 2 of our project (OHIE replication) provides experimental evidence on the effects of Medicaid on health outcomes, but its external validity is limited: the study population is specific to Portland-area low-income adults in 2008, and the 16-month follow-up window is too short to detect mortality effects with adequate statistical power (Finkelstein et al., 2012; Baicker & Finkelstein, 2011).

This extension was intended to complement the OHIE evidence by exploiting the **ACA Medicaid expansions starting in 2014**, which affected a much larger population across multiple states and allows for the estimation of longer-run mortality effects. The reference paper is:

> Borgschulte M, Vogler J (2020). Did the ACA Medicaid expansion save lives? *Journal of Health Economics*, 72, 102333. doi: [10.1016/j.jhealeco.2020.102333](https://doi.org/10.1016/j.jhealeco.2020.102333)

A copy of the paper is included in this folder as `Journal_of_Health_Economics.pdf`.

---

## Intended Design

The ACA Medicaid expansion was adopted by states at different points in time — a **staggered adoption** design. Standard two-way fixed effects (TWFE) DiD is known to produce biased estimates in this setting when treatment effects are heterogeneous across cohorts and time periods, because it implicitly uses already-treated units as controls for later-treated ones.

The planned estimator was **Callaway & Sant'Anna (2021)**, implemented in R via the `did` package. This estimator addresses the staggered adoption problem by computing group-time average treatment effects (ATTs) for each cohort separately, using only never-treated or not-yet-treated units as controls, and aggregating cohort-specific effects into interpretable summary statistics. The key identification assumption is parallel trends conditional on covariates.

The script also implements: a static TWFE as a diagnostic foil, a Goodman-Bacon decomposition to quantify the weight on "forbidden" already-treated-as-control comparisons, and HonestDiD (Rambachan & Roth, 2023) sensitivity analysis on the main event-study estimate.

---

## Structure

This folder contains two subfolders and several files at the root level. `data` holds all datasets used or produced by the scripts. `scripts` contains the two R scripts. `Journal_of_Health_Economics.pdf` is the Borgschulte & Vogler (2020) reference paper. `cdc_query_criteria.md` documents the exact CDC WONDER query filters used to download the mortality data.

---

## Scripts

### `part2_causal_inference.r` — main analysis script

The main script runs the full staggered DiD pipeline in ten sequential sections. It fetches ACS covariates via `tidycensus` (Section 1), merges them onto the base panel (Section 2), estimates static TWFE models as a diagnostic foil (Section 3), runs a Goodman-Bacon decomposition to quantify the bias problem (Section 4), plots raw weighted mortality trends by cohort (Section 5), estimates Callaway & Sant'Anna `att_gt()` for seven outcome/specification combinations (Section 6), aggregates group-time ATTs and builds the main results table (Section 7), produces event-study figures (Section 8), runs HonestDiD sensitivity on the primary estimate (Section 9), and prints headline numbers (Section 10).

It requires `panel_state_year.csv` in the working directory and a Census API key set via `Sys.setenv(CENSUS_API_KEY = "your_key")`. Outputs include `panel_with_covariates.csv`, HTML regression tables, and PNG/PDF figures for all event studies and diagnostics.

The script uses several methods beyond the course syllabus, all tagged `[EXTENSION Ex]` inline: `tidycensus` for ACS data acquisition (E1), `fixest::feols` for fixed-effects regression (E2), `bacondecomp::bacon` for the Goodman-Bacon decomposition (E3), `did::att_gt` and `did::aggte` for the Callaway & Sant'Anna estimator (E4), and `HonestDiD` for parallel-trends sensitivity analysis (E5).

### `merge_covariates.r` — deterministic merge step

A lighter standalone script that performs only the covariate merge, with no Census API call. It reads `panel_state_year.csv` and `census_acs_covariates.csv` from the working directory and writes `panel_with_covariates.csv`. It includes a partition guard that verifies the external-cause series in the base panel is the filtered version (V01–Y89 excluding Y60–Y69 and Y83–Y84), which are already counted inside the amenable series. Running this script is sufficient to reproduce the merged analysis panel without re-fetching ACS data.

---

## Data

All files are in the `data/` subfolder.

`panel_state_year.csv` is the base panel: 510 rows (51 states × 10 years, 2010–2019) with age-adjusted mortality rates per 100,000 (2000 standard population) for adults aged 25–64, built from the three CDC WONDER downloads below.

`census_acs_covariates.csv` contains the five ACS covariates fetched by the main script: log median household income, poverty rate, unemployment rate, share Black non-Hispanic, and share Hispanic. It covers 52 jurisdictions (51 states + Puerto Rico) × 10 years; Puerto Rico drops out of the merge because it is absent from the mortality panel.

`panel_with_covariates.csv` is the merged analysis-ready dataset (510 × 26), produced by either script above.

The three CDC WONDER raw files cover adults aged 25–64, grouped by state and year, 2010–2019, with age-adjusted rates per 100,000 using the 2000 U.S. standard population. `cdc_allcause_25-64_2010-2019.csv` contains all-cause mortality. `cdc_amenable_25-64_2010-2019.csv` contains amenable-cause mortality, defined following Sommers (2017) using the ICD-10 codes listed in `cdc_query_criteria.md`. `cdc_external_filtered_25-64_2010-2019.csv` contains external-cause mortality (V01–Y89) **excluding** Y60–Y69 and Y83–Y84, which overlap with the amenable definition; this filtered series ensures that amenable + external + residual partition all-cause mortality exactly.

The exact CDC WONDER query parameters for all three files are documented in `cdc_query_criteria.md`.

---

## Why this was not completed

The extension required significant additional time to correctly implement the Callaway & Sant'Anna estimator with covariate adjustment and state-level clustering, validate parallel trends across all cohorts, and cross-check results against Borgschulte & Vogler (2020). Given the submission deadline and the workload already required by Parts I and II, we were unable to bring this analysis to a standard suitable for inclusion in the paper. The preliminary data assembly and scripts are included here for transparency.

---

## AI Disclosure

This extension was developed primarily with AI assistance. The scripts, data pipeline design, and this documentation were drafted with AI support. All methodological decisions were reviewed by the research group, but given the incomplete state of the analysis, the output has not been fully validated. Disclosed per the course AI policy.

---

## References

- Borgschulte M, Vogler J (2020). Did the ACA Medicaid expansion save lives? *Journal of Health Economics*, 72, 102333.
- Callaway B, Sant'Anna PHC (2021). Difference-in-Differences with Multiple Time Periods. *Journal of Econometrics*, 225(2), 200–230.
- Finkelstein A et al. (2012). The Oregon Health Insurance Experiment: Evidence from the First Year. *Quarterly Journal of Economics*, 127(3), 1057–1106.
- Rambachan A, Roth J (2023). A More Credible Approach to Parallel Trends. *Review of Economic Studies*, 90(5), 2555–2591.
- Sommers BD (2017). State Medicaid Expansions and Mortality, Revisited: A Cost-Benefit Analysis. *American Journal of Health Economics*, 3(3), 392–421.
