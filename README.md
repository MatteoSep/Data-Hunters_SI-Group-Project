# SI-Group-Project
This repository contains the documentation and the code for the project of the Statistical Inference course, Università di Roma La Sapienza
<br>
<br>
The first part investigates in the cross-sectional relationship between health insurance coverage and mortality across US states using OLS regression. <br>
In the second part the Oregon Medical Lottery will be used to estimate the causal effect of insurance on health outcomes via instrumental variables.
# Part 1
We examine the association between health insurance coverage rates and mortality at the state level, using 2019 cross-sectional data. The analysis builds progressively from a bivariate model to a fully specified specification controlling for median age and poverty rate, illustrating how omitted variable bias affects the estimated insurance coefficient. We also distinguish between all-cause mortality and medical-cause mortality (diabetes, hypertension, neurological conditions), which respond differently to insurance coverage.


## Data Sources 
**Socioeconomic data** were retrieved from the American Community Survey (ACS) using the tidycensus R package. <br>
State-level observations correspond to the 2019 ACS 1-year estimates.

Official ACS variable documentation:

- Median household income (`B19013_001`)  
  https://api.census.gov/data/2019/acs/acs1/variables/B19013_001E.html


- Poverty rate (`DP03_0128PE`)  
  https://api.census.gov/data/2019/acs/acs1/profile/variables/DP03_0128PE.html

- Health insurance coverage (`DP03_0096PE`)  
  https://api.census.gov/data/2019/acs/acs1/profile/variables/DP03_0096PE.html
  
- Median age (`B01002_001E`)  
  https://api.census.gov/data/2019/acs/acs1/variables/B01002_001E.html

<br>

**Mortality data** were retrieved from the CDC WONDER Multiple Cause of Death database:

CDC WONDER mortality data:
https://wonder.cdc.gov/


Additional information related to the variables description can be seen [here](docs/acs_variables.md) 




## Setup

This script automates the API data ingestion from the US Census Bureau, harmonizes the metrics, and merges them with the epidemiological data from CDC WONDER.

```r
library(tidycensus)
library(tidyverse)

census_api_key("API_KEY", install=TRUE)
```

## Variables selection and Data retrieval

```r
dati_raw <- get_acs(
  geography = "state",
  variables = c(median_income = "B19013_001",
                poverty_rate   = "DP03_0128PE",
                insurance_rate = "DP03_0096PE",
                median_age = "B01002_001E"),
  year      = anno_studio,
  survey    = "acs1",
  output    = "wide",
)
```

<br>

# Part 2: Causal Inference (Oregon Health Insurance Experiment)
Oregon's 2008 Medicaid expansion was not a standard policy rollout — the state had more applicants than available slots, so it allocated coverage by lottery. This created a rare situation in which treatment (Medicaid enrollment) was effectively randomized at the household level, making the lottery a credible instrument for insurance coverage.
 
We use this design to estimate the causal effect of gaining Medicaid coverage on self-reported health, healthcare utilization, and financial strain, following the identification strategy of Finkelstein et al. (2012). The estimator is two-stage least squares (2SLS): lottery win instruments for actual enrollment, and outcomes are measured through the 12-month follow-up survey.
 
## Data Sources
 
Data come from the OHIE Public Use Files, distributed via Harvard Dataverse under open access. The full lottery list covers N = 74,922 individuals across 66,385 households. All files are linkable via `person_id`.
 
The analysis uses three of the eight available `.dta` files: `oregonhie_descriptive_vars` (treatment assignment and pre-randomization controls), `oregonhie_survey12m_vars` (12-month outcomes and survey weights), and `oregonhie_stateprograms_vars` (administrative Medicaid enrollment records).
 
The `.dta` files are not committed to this repository due to size. See [`docs/ohie_data.md`](docs/ohie_data.md) for full variable documentation and retrieval instructions.
 
**Dataset:** OHIE Public Use Files, Harvard Dataverse — DOI: [10.7910/DVN/SJG1ED](https://doi.org/10.7910/DVN/SJG1ED)  
**Reference paper:** Finkelstein et al. (2012), QJE 127(3): 1057–1106 — DOI: [10.1093/qje/qjs020](https://doi.org/10.1093/qje/qjs020)
 
## Main Files
 
- `part2/part2_analysis.Rmd` — full analysis script (data loading, IV estimation, tables, figures)
- `docs/ohie_data.md` — variable documentation and data retrieval guide

# Disclaimer
This repository was created for academic purposes as part of the Statistical Inference course project, Università di Roma La Sapienza.  
All data sources belong to their respective owners, including the U.S. Census Bureau and CDC WONDER.


