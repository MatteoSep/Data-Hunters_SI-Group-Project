# Part I: Cross-Sectional State-Level Dataset

## Overview

This script builds the final cross-sectional dataset used in Part I of the project. It combines three data sources — U.S. Census Bureau socioeconomic estimates, all-cause mortality data, and medical-cause mortality data — into a single cleaned dataset at the U.S. state level (N ≈ 51, including Washington D.C.) for the year 2019.

The resulting dataset is saved to `data/data_1/processed/mio_dataset_output.csv` and serves as the input for all OLS regression models in the analysis.

---

## Data Sources

| Source | Variables | Access Method |
|---|---|---|
| American Community Survey (ACS 1-Year, 2019) | Median income, poverty rate, insurance rate, median age | `tidycensus` R package via Census API |
| CDC WONDER — All-Cause Mortality | Crude mortality rate, age-adjusted mortality rate | Manual download, stored locally |
| CDC WONDER — Medical-Cause Mortality | Crude medical mortality rate, age-adjusted medical mortality rate | Manual download, stored locally |

Additional information related to data sources and retrieval can be found [here](../data_1/README.md)


---

## Requirements

### R Packages

```r
install.packages("tidycensus")
install.packages("tidyverse")
```

### Census API Key

A free API key from the U.S. Census Bureau is required to access ACS data via `tidycensus`. Register at [https://api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html).

Set the key once with:

```r
census_api_key("YOUR_API_KEY", install = TRUE, overwrite = TRUE)
readRenviron("~/.Renviron")
```

This stores the key permanently in your `.Renviron` file so you do not need to re-enter it in future sessions.

---

## Script Walkthrough

### Step 1: Environment Setup

```r
rm(list = ls())
```

Clears the R environment to ensure a clean session with no leftover objects from previous runs.

---

### Step 2: ACS Data Download via `tidycensus`

```r
dati_raw <- get_acs(
  geography = "state",
  variables = c(
    median_income  = "B19013_001",
    poverty_rate   = "DP03_0128PE",
    insurance_rate = "DP03_0096PE",
    median_age     = "B01002_001E"
  ),
  year   = 2019,
  survey = "acs1",
  output = "wide"
)
```

Downloads four variables from the 2019 ACS 1-Year Estimates at the state level:

| Variable Code | Description |
|---|---|
| `B19013_001` | Median household income (USD) |
| `DP03_0128PE` | Poverty rate (% of population below poverty line) |
| `DP03_0096PE` | Health insurance coverage rate (% of population covered) |
| `B01002_001E` | Median age (years) |

The `output = "wide"` argument returns one row per state with all variables as columns.

---

### Step 3: Census Data Cleaning

```r
dataset_census <- dati_raw %>%
  select(GEOID, NAME, median_income = median_incomeE,
         poverty_rate, insurance_rate, median_age) %>%
  mutate(
    poverty_per_100k   = poverty_rate * 1000,
    insurance_per_100k = insurance_rate * 1000
  ) %>%
  select(-poverty_rate, -insurance_rate)
```

- Selects and renames the relevant columns, dropping margin-of-error columns returned by `get_acs`.
- Rescales poverty rate and insurance rate by multiplying by 1,000 to express them per 100,000 inhabitants, consistent with the mortality rate units used in the CDC data.

---

### Step 4: Mortality Data Import

```r
cause_mortality <- read_csv("data/data_1/raw/Cause_of_Death.csv")
allcause_mortality_per_100k <- cause_mortality[, -c(1, 3, 4, 5)] %>%
  rename(crude_rate_mortality = 2, age_adjusted_mortality = 3)

medical_cause_per_100k <- read_csv("data/data_1/raw/medical_cause_of_death.csv")[, -c(1, 3, 4, 5)] %>%
  rename(crude_rate_medical_mortality = 2, age_adjusted_medical_mortality = 3)
```

Loads two CDC WONDER files downloaded manually:

- `Cause_of_Death.csv` — all-cause mortality (crude rate and age-adjusted rate per 100,000)
- `medical_cause_of_death.csv` — medical-cause mortality, defined as deaths attributable to diabetes, hypertension, and neurological conditions (crude rate and age-adjusted rate per 100,000)

Columns 1, 3, 4, and 5 are dropped as they contain CDC metadata not needed for the analysis. The remaining columns are renamed for clarity.

**Note on age-adjusted rates:** the analysis uses the age-adjusted mortality rate (not the crude rate) as the primary dependent variable. This corrects for differences in age structure across states — without this adjustment, states with older populations (e.g. Florida, Maine) would appear artificially more dangerous, confounding the relationship between insurance coverage and mortality.

---

### Step 5: Final Dataset Assembly

```r
dataset_finale <- dataset_census %>%
  inner_join(allcause_mortality_per_100k, by = c("NAME" = "State")) %>%
  inner_join(medical_cause_per_100k,      by = c("NAME" = "State"))
```

Merges the three cleaned datasets by state name using `inner_join`. Only states present in all three sources are retained. The script then prints a count of successfully matched states as a data quality check:

```r
print(paste("Numero di stati uniti con successo:", nrow(dataset_finale)))
```

A successful run should return 50 or 51 observations (50 states + Washington D.C., depending on CDC WONDER coverage).

---

### Step 6: Export

```r
write_csv(dataset_finale, "data/data_1/processed/mio_dataset_output.csv")
```

Saves the final dataset as a CSV file to the `processed` subfolder. This file is the direct input for all regression models in Part I. <br>
<br>
The Data Dictionary and additional information related to the output`mio_dataset_output.csv` can also be seen in the following link:

[Data Dictionary](../data_1/README.md)

---

## AI Disclosure

The development of this script was assisted by AI tools (Claude, Anthropic), primarily for code structuring, variable selection logic, and documentation. All analytical decisions were made by the research group. The use of AI assistance is disclosed in accordance with the course policy on AI tools stated in the assignment guidelines.

---

## References

- U.S. Census Bureau. (2019). *American Community Survey 1-Year Estimates*. Retrieved via `tidycensus` R package.
- CDC WONDER. (2019). *Underlying Cause of Death*. Centers for Disease Control and Prevention. [https://wonder.cdc.gov](https://wonder.cdc.gov)
- Walker K, Herman M (2024). *tidycensus: Load US Census Boundary and Attribute Data as 'tidyverse' and 'sf'-Ready Data Frames*. R package version 1.6.3.
