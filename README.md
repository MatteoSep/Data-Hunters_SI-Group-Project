# SI-Group-Project
Within this repository we...

# Part 1
[Aggiungere titolo e overview, una sorta di riassunto]



## Data Sources 
Socioeconomic data were retrieved from the American Community Survey (ACS) using the tidycensus R package. 
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



Mortality data were retrieved from the CDC WONDER Multiple Cause of Death database:

CDC WONDER mortality data:
https://wonder.cdc.gov/


Additional information related to the variables description can be seen [here](docs/acs_variables.md) 




## Setup

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

We use the Oregon Medicaid lottery (Finkelstein et al., 2012, QJE) as a 
natural experiment to estimate the causal effect of health insurance on 
health outcomes and healthcare utilization.

**Identification strategy:** Instrumental Variables (IV/2SLS)  
- Instrument: lottery win (`treatment`)  
- Endogenous variable: Medicaid enrollment (`insured`)  
- Outcomes: self-reported health, healthcare use, financial strain  

**Data source:** OHIE Public Use Files, Harvard Dataverse  
DOI: [10.7910/DVN/SJG1ED](https://doi.org/10.7910/DVN/SJG1ED)  
Reference paper: Finkelstein et al. (2012), DOI: 10.1093/qje/qjs020

**Main files:**
- `part2/part2_analysis.Rmd` – full analysis script
- `data/raw/` – the three .dta files used (see Part II README for details)


# Disclaimer
This repository was created for academic purposes as part of the Statistical Inference course project, Università di Roma La Sapienza.  
All data sources belong to their respective owners, including the U.S. Census Bureau and CDC WONDER.


