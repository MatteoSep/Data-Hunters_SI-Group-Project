# Data Directory

This folder contains the raw and processed datasets used for Part 1 (Observational Baseline) of the project.

## Directory Structure

* `raw/`: Contains the files downloaded directly from the sources, as well as the queries:
    * `Cause_of_Death.csv`: All-cause mortality data by state (2019) from CDC WONDER.
    * `medical_cause_of_death.csv`: Medical-cause mortality data by state (2019) from CDC WONDER.
* `processed/`: Contains the final analytical dataset:
    * `mio_dataset_output.csv`: The merged dataset combining US Census ACS covariates and CDC mortality rates.

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



## Data Dictionary (`mio_dataset_output.csv`)

| Variable Name | Description | Source | Unit |
| :--- | :--- | :--- | :--- |
| `GEOID` | State Federal Information Processing Standard (FIPS) code | US Census | Numeric ID |
| `NAME` | US State Name | US Census | String |
| `median_income` | Median Household Income | ACS 2019 (B19013_001) | USD ($) |
| `median_age` | Median Age of the State Population | ACS 2019 (B01002_001E) | Years |
| `poverty_per_100k` | Number of people living below the poverty line per 100k pop | ACS 2019 (DP03_0128PE) | Rate per 100k |
| `insurance_per_100k` | Number of people with health insurance coverage per 100k pop | ACS 2019 (DP03_0096PE) | Rate per 100k |
| `crude_rate_mortality` | Total deaths per 100,000 population | CDC WONDER | Rate per 100k |
| `age_adjusted_mortality` | Age-adjusted total deaths per 100,000 population | CDC WONDER | Rate per 100k |
| `crude_rate_medical_mortality` | Medical deaths per 100,000 population | CDC WONDER | Rate per 100k |
| `age_adjusted_medical_mortality` | Age-adjusted medical deaths per 100,000 population | CDC WONDER | Rate per 100k |
