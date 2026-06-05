# Part II – Causal Inference: Oregon Health Insurance Experiment
# `ohie_analysis.R` — Part II: Oregon Health Insurance Experiment

This script replicates the core empirical analysis of Finkelstein et al. (2012,
*Quarterly Journal of Economics*) using the Oregon Health Insurance Experiment
(OHIE) public-use files. It loads, merges, and prepares the individual-level
data, then constructs all derived variables needed for ITT and LATE estimation
in Part II of the project.

**Reference paper:** Finkelstein A, Taubman S, Wright B, et al. (2012).
"The Oregon Health Insurance Experiment: Evidence from the First Year."
*Quarterly Journal of Economics*, 127(3), 1057–1106.
doi: [10.1093/qje/qjs020](https://doi.org/10.1093/qje/qjs020)

---

## Experiment background

In early 2008, Oregon reopened its Medicaid program (OHP Standard) to new
enrollment after closing it in 2004 due to budget constraints. Demand far
exceeded the 10,000 available slots, so the state assigned eligibility
**by lottery**: names were drawn at random from a list of 89,824 applicants.
Selected individuals (and their household members) won the opportunity to apply
for Medicaid; those not selected served as the control group.

This design generates **random variation** in insurance coverage, allowing
causal identification that is impossible with observational data alone. The
unit of randomization is the **household**, not the individual — a design
feature that drives key modelling choices throughout the analysis (clustering,
household-size fixed effects).

**Study population:** 74,922 individuals (29,834 treated, 45,088 controls),
representing 66,385 households. All are low-income uninsured adults aged 19–64
in Oregon, not otherwise eligible for public insurance.

---

## Requirements

### R packages

```r
library(lmtest)    # coeftest(): robust t-tests on lm objects
library(sandwich)  # vcovHC(), vcovCL(): robust covariance estimators
library(car)       # linearHypothesis(): joint F-tests
library(MatchIt)   # matchit(), match.data(): propensity score matching
library(cobalt)    # love.plot(): balance diagnostics
library(ggplot2)   # data visualization
library(haven)     # read_dta(): import Stata .dta files
```

### Data files

The OHIE Public Use Files (PUF) must be downloaded from the NBER data
repository and placed in the path defined by the `path` variable at the top
of the script. Three `.dta` files are used:

| File | Content |
|---|---|
| `oregonhie_descriptive_vars.dta` | Treatment assignment, household structure, lottery list controls |
| `oregonhie_survey12m_vars.dta` | 12-month mail survey outcomes and survey weights |
| `oregonhie_stateprograms_vars.dta` | Administrative Medicaid enrollment records |

The remaining PUF files (ED administrative data, in-person exam data, 0- and
6-month surveys) are **not used** in this script. See Finkelstein et al. (2012),
Section III and Online Appendix 1, for full documentation of all files.

---

## Step-by-step walkthrough

### Step 0 — Load data and merge

```r
path <- "OHIE_Public_Use_Files/OHIE_Data"

desc <- read_dta("oregonhie_descriptive_vars.dta")
s12  <- read_dta("oregonhie_survey12m_vars.dta")
sp   <- read_dta("oregonhie_stateprograms_vars.dta")

dt <- merge(desc, s12, by = "person_id")
dt <- merge(dt,   sp,  by = "person_id")
```

Merges the three files on the unique individual identifier `person_id`.

**Expected output:**
```
Merged sample size N = 74,922 | households = 66,385
```

If the count differs, check that all three files come from the same PUF
release version and that no pre-exclusion filters have been applied manually
to the raw files.

---

### Step 1 — Rename enrollment variables

```r
dt$ohp_admin  <- dt$ohp_all_ever_matchn_30sep2009
dt$ohp_survey <- dt$ohp_all_ever_firstn_30sep2009
```

The OHIE ships two distinct "ever on Medicaid" variables. Both are retained
because they serve different roles in the analysis:

| Variable | Source | Used for |
|---|---|---|
| `ohp_admin` | Administrative enrollment match — full sample | **First stage** (equation 4 of Finkelstein et al.) |
| `ohp_survey` | Administrative enrollment, aligned to survey sample | **Endogenous treatment** in OLS/Matching/LATE on survey outcomes |

This distinction follows the note to QJE Table III: the full-sample first stage
uses `ohp_admin`; the survey-sample LATE uses `ohp_survey`. Conflating the two
would produce a first-stage estimate on the wrong sample.

---

### Step 2 — Strip Stata labels

```r
lab_cols <- sapply(dt, function(x) inherits(x, "haven_labelled"))
dt[lab_cols] <- lapply(dt[lab_cols], haven::zap_labels)
```

`haven` imports Stata `.dta` columns as `haven_labelled` objects, which carry
Stata value labels. These are stripped with `zap_labels()` so all variables
behave as plain numeric vectors in `lm()`, `ivreg()`, and plotting functions.
Failing to do this step causes unexpected type errors in downstream modelling.

---

### Step 3 — Construct derived variables

#### Treatment and age variables

```r
dt$insured <- dt$ohp_survey          # endogenous treatment for survey LATE
dt$age12   <- 2008 - dt$birthyear_list
dt$older   <- as.numeric(dt$birthyear_list >= 1945 & dt$birthyear_list <= 1958)
dt$younger <- as.numeric(dt$birthyear_list >= 1959 & dt$birthyear_list <= 1989)
```

Age cohorts (`older`: 50–64; `younger`: 19–49) are used for heterogeneity
analysis. Age at the lottery is 2008 minus birth year.

#### Health outcomes — sign convention

All health outcomes are constructed so that **higher = better health**,
following QJE equation (2) and the standardized treatment effect convention.
Raw survey responses for some items are coded in the opposite direction and
must be flipped:

```r
dt$good_health     <- 1 - dt$health_gen_bin_12m    # 1 = good/very good/excellent
dt$health_notpoor  <- ifelse(is.na(dt$health_gen_12m), NA,
                             as.numeric(dt$health_gen_12m != 1))  # 1 = not "poor"
dt$health_improved <- 1 - dt$health_chg_bin_12m    # 1 = improved vs. last year
dt$notbaddays_tot  <- 30 - dt$baddays_tot_12m       # good days (physical + mental)
dt$notbaddays_phys <- 30 - dt$baddays_phys_12m
dt$notbaddays_ment <- 30 - dt$baddays_ment_12m
```

**Financial strain variables are deliberately NOT flipped.** They remain in
their natural direction (higher = more strain). ITT coefficients on these
outcomes therefore have the *opposite* sign interpretation: a negative
coefficient means insurance *reduced* financial strain, which is the
beneficial direction. This is noted explicitly in the QJE paper (Section IV.A,
"SIGN note").

#### Depression screen

```r
dt$nodep_screen <- ifelse(
  is.na(dt$dep_interest_12m) | is.na(dt$dep_sad_12m), NA,
  as.numeric((dt$dep_interest_12m + dt$dep_sad_12m) < 5)
)
```

Implements the **PHQ-2** two-item depression screening tool. A score of 5 or
above on the sum of the interest and sadness items indicates a positive screen
for depression. The variable is coded 1 = *did not* screen positive (consistent
with the "higher = better" convention) and 0 = screened positive. Missing
values are propagated if either component item is missing. The PHQ-2 correlates
highly with clinical diagnoses of depression (Kroenke, Spitzer & Williams 2003,
cited in Finkelstein et al. 2012, p. 1095).

---

### Step 4 — Define the analysis sample

```r
dt$resp12 <- with(dt,
  sample_12m_resp == 1 & !is.na(weight_12m) & weight_12m != 0
)
```

Survey outcomes are only available for respondents to the 12-month mail survey.
`resp12` flags individuals who: (i) responded to the survey (`sample_12m_resp == 1`),
(ii) have a non-missing survey weight, and (iii) have a strictly positive weight.

**Sample sizes by analysis type:**

| Analysis | Sample | N |
|---|---|---|
| First stage (admin) | Full sample | 74,922 |
| Hospital utilization | Full sample | 74,922 |
| Credit report / financial strain | Credit report subsample | ~49,980 |
| Survey outcomes (ITT, LATE) | Survey respondents (`resp12 == TRUE`) | ~23,741 |

The ~50% effective survey response rate is the primary source of potential
non-response bias in the survey analyses. See Finkelstein et al. (2012),
Table II and Online Appendix 2.2, for balance tests and Lee (2009) attrition
bounds.

---

## Key variables — reference table

### Treatment and instrument

| Variable | Description | Notes |
|---|---|---|
| `LOTTERY` | 1 = selected by lottery (household-level) | Main instrument (equation 4) |
| `insured` / `ohp_survey` | 1 = ever enrolled in Medicaid (survey period) | Endogenous treatment for LATE |
| `ohp_admin` | 1 = ever enrolled in Medicaid (admin match, full sample) | Used for full-sample first stage |

### Household structure controls (always included)

| Variable | Description | Why included |
|---|---|---|
| `household_id` | Household identifier | Used for clustering SEs |
| Household size dummies | Indicator variables for # household members on lottery list | Lottery was drawn at household level; larger households over-represented in treatment |
| Survey wave dummies | Indicator for which of the 7 survey waves the individual received | Treatment probability varies by wave |

### Health outcomes (higher = better, all 12-month survey)

| Variable | Description |
|---|---|
| `good_health` | Self-reported health good/very good/excellent |
| `health_notpoor` | Self-reported health not "poor" |
| `health_improved` | Health same or improved vs. 6 months ago |
| `notbaddays_tot` | Days physical + mental health good (of last 30) |
| `notbaddays_phys` | Days physical health good (of last 30) |
| `notbaddays_ment` | Days mental health good (of last 30) |
| `nodep_screen` | Did not screen positive for depression (PHQ-2) |

### Financial strain outcomes (higher = MORE strain)

| Variable | Description |
|---|---|
| Raw survey items | Out-of-pocket expenses, money owed, borrowing to pay bills, refused treatment |

---

## Estimation framework (summary)

The script prepares data for three estimators, following Finkelstein et al.
(2012), Section IV:

**ITT — Intent-to-Treat (equation 1):**
Regresses each outcome on `LOTTERY`, household size dummies, and survey wave
dummies, with standard errors clustered on `household_id`. Identifies the
average effect of *winning the lottery* (i.e., the offer of Medicaid), regardless
of whether the individual actually enrolled. This is the most conservative and
internally valid estimate.

**First Stage (equation 4):**
Regresses `insured` (or `ohp_admin`) on `LOTTERY` plus controls. The
coefficient on `LOTTERY` is δ₁ — the fraction of compliers. From Table III of
Finkelstein et al. (2012): δ₁ ≈ **0.256** (full sample), F-statistic ≫ 500.
Instrument validity is confirmed by the strong first stage.

**LATE — Local Average Treatment Effect (equation 3, estimated via 2SLS):**
Uses `LOTTERY` as an instrument for `insured`. The LATE is interpreted as the
causal effect of Medicaid enrollment among **compliers** — those who enrolled
because they won the lottery and would not have enrolled otherwise. Because only
~25% of lottery winners enrolled, the LATE is approximately **4× the ITT**
(LATE = ITT / δ₁). The exclusion restriction requires that winning the lottery
affects outcomes only through insurance coverage; Finkelstein et al. (2012,
p. 1081) discuss one partial violation via food stamp co-enrollment, judged
substantively negligible.

---

## Threats to identification and robustness checks

| Threat | Description | Mitigation in the analysis |
|---|---|---|
| **Non-random attrition** | Survey response rate ~50%; treated individuals 1.6pp less likely to respond | Lee (2009) attrition bounds reported in Online Appendix Table A14 |
| **Exclusion restriction violation** | Lottery win triggers food stamp co-enrollment (~$60 over 16 months) | Judged negligible; TANF and food stamp first stages reported in Table III |
| **Household-level clustering** | Lottery randomized at household, not individual, level | All SEs clustered on `household_id` throughout |
| **External validity** | Population: white, low-income, Portland-area, voluntary sign-up, 2008 recession | Explicitly discussed in Finkelstein et al. (2012), Section VI.B |

---

## AI disclosure

The development of this script was assisted by AI tools (Claude, Anthropic), primarily for code structuring, variable selection logic, and documentation. All analytical decisions were made by the research group. The use of AI assistance is disclosed in accordance with the course policy on AI tools stated in the assignment guidelines.

---

## References

- Finkelstein A, Taubman S, Wright B, Bernstein M, Gruber J, Newhouse JP,
  Allen H, Baicker K, Oregon Health Study Group (2012). The Oregon Health
  Insurance Experiment: Evidence from the First Year. *Quarterly Journal of
  Economics*, 127(3), 1057–1106.
- Kroenke K, Spitzer RL, Williams JB (2003). The Patient Health Questionnaire-2:
  Validity of a Two-Item Depression Screener. *Medical Care*, 41(11), 1284–1292.
- Lee DS (2009). Training, Wages, and Sample Selection: Estimating Sharp Bounds
  on Treatment Effects. *Review of Economic Studies*, 76(3), 1071–1102.
- Imbens GW, Angrist JD (1994). Identification and Estimation of Local Average
  Treatment Effects. *Econometrica*, 62(2), 467–475. 
