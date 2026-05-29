# SI-Group-Project

# Overview
[Aggiungere titolo e overview, una sorta di riassunto]



# Data Sources 
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


### Notes on ACS Variable Codes

ACS variables follow the Census Bureau naming convention.

Examples:

* `B19013_001`

  * `B` = detailed table
  * `19013` = median household income table
  * `_001` = main estimate

* `DP03_0128PE`

  * `DP` = data profile table
  * `03` = economic characteristics
  * `PE` = percentage estimate

Variables ending in `E` indicate point estimates, while variables ending in `M` indicate margins of error.


# Setup

```r
library(tidycensus)
library(tidyverse)

census_api_key("API_KEY", install=TRUE)
```

# Variables selection and Data retrieval

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





# References



