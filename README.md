# SI-Group-Project
This repository contains the documentation and the code for the project of the Statistical Inference course, Università di Roma La Sapienza
<br>
<br>
This paper asks whether expanding public health insurance causally improves health and financial security, using two complementary designs to separate correlation from causation. Part I estimates cross-sectional OLS regressions of state-level mortality on insurance coverage (2019, n = 51); the association is weak and unstable across specifications, and we argue it cannot be read causally because of omitted-variable bias, reverse causality, and the ecological fallacy. Part II replicates the Oregon Health Insurance Experiment, a 2008 lottery that randomly allowed low-income adults to apply for Medicaid, and recovers the causal effect that observational methods cannot. Winning the lottery raised Medicaid enrollment by about 25 percentage points (first stage 0.256) and, through intention-to-treat and instrumental-variable (LATE) estimation, increased health-care use, sharply reduced financial strain, and improved self-reported and mental health; effects on physical biomarkers and on mortality are precise nulls rather than evidence of no effect. Comparing observational (OLS, matching) with experimental (LATE) estimates on the same data exhibits the selection bias directly. The methodological lesson is that identification, not statistical adjustment, is what delivers credible causal estimates.

# Part 1
We examine the association between health insurance coverage rates and mortality at the state level, using 2019 cross-sectional data. The analysis builds progressively from a bivariate model to a fully specified specification controlling for median age and poverty rate, illustrating how omitted variable bias affects the estimated insurance coefficient. We also distinguish between all-cause mortality and medical-cause mortality (diabetes, hypertension, neurological conditions), which respond differently to insurance coverage.
<br>
Part I studies the cross-sectional relationship between health insurance and mortality using U.S. state-level data for 2019 (n = 51). We regress mortality on the insured share, progressively adding demographic and income controls and an income interaction, with heteroskedasticity-robust (HC3) standard errors. The estimated association is small and unstable across specifications, and once income is included it can even switch sign, a suppressor pattern. We argue that none of these estimates identifies a causal effect: omitted variables (population health, income, behaviour), reverse causality (sicker or poorer populations select differently into coverage), and the ecological fallacy all confound a state-level regression. The contribution of this section is therefore diagnostic — it shows precisely why a purely observational design fails to recover the causal parameter of interest — and it motivates the quasi-experimental strategy of Part II, where randomization removes the confounding that no amount of OLS adjustment can.




The information reated to the data retrievial for the first 

[here](docs/Part_1/acs_variables.md) 




## Setup

To ensure reproducibility, initialize the environment by loading the required libraries and setting up your federal API credentials:
```r
library(tidycensus)
library(tidyverse)

census_api_key("API_KEY", install=TRUE)
```

More information related to the data retrievial [da mettere il link]

<br>

# Part 2: Causal Inference (Oregon Health Insurance Experiment)
Oregon's 2008 Medicaid expansion was not a standard policy rollout — the state had more applicants than available slots, so it allocated coverage by lottery. This created a rare situation in which treatment (Medicaid enrollment) was effectively randomized at the household level, making the lottery a credible instrument for insurance coverage.
 
We use this design to estimate the causal effect of gaining Medicaid coverage on self-reported health, healthcare utilization, and financial strain, following the identification strategy of Finkelstein et al. (2012). The estimator is two-stage least squares (2SLS): lottery win instruments for actual enrollment, and outcomes are measured through the 12-month follow-up survey.
 
## Data Sources
 
Data come from the OHIE Public Use Files, distributed via Harvard Dataverse under open access. The full lottery list covers N = 74,922 individuals across 66,385 households. All files are linkable via `person_id`.
 
The analysis uses three of the eight available `.dta` files: `oregonhie_descriptive_vars` (treatment assignment and pre-randomization controls), `oregonhie_survey12m_vars` (12-month outcomes and survey weights), and `oregonhie_stateprograms_vars` (administrative Medicaid enrollment records).
 
The `.dta` files are not committed to this repository due to size. See [`docs/ohie_data.md`](docs/Part_2/ohie_data.md) for full variable documentation and retrieval instructions.
 
**Dataset:** OHIE Public Use Files, Harvard Dataverse — DOI: [10.7910/DVN/SJG1ED](https://doi.org/10.7910/DVN/SJG1ED)  
**Reference paper:** Finkelstein et al. (2012), QJE 127(3): 1057–1106 — DOI: [10.1093/qje/qjs020](https://doi.org/10.1093/qje/qjs020)
 
## Main Files
 
- `part2/part2_analysis.Rmd` — full analysis script (data loading, IV estimation, tables, figures)
- `docs/ohie_data.md` — variable documentation and data retrieval guide

# Disclaimer
This repository was created for academic purposes as part of the Statistical Inference course project, Università di Roma La Sapienza.  
All data sources belong to their respective owners, including the U.S. Census Bureau and CDC WONDER.


