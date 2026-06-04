
# ACS Variables Documentation

This project uses data retrieved from the American Community Survey (ACS) 2019 1-year estimates.  
Below is a description of all variables used in the analysis.

---

## Median Household Income (```B19013_001```)

- **Definition:** Median household income in the past 12 months (inflation-adjusted dollars)
- **Type:** Detailed table variable (B-series)
- **Meaning:** Splits all households into two equal groups: half earn more, half earn less
- **Unit:** US Dollars
- **Source table:** B19013

---

## Poverty Rate (```DP03_0128PE```)

- **Definition:** Percentage of individuals below the poverty level
- **Type:** Data Profile variable (DP-series)
- **Meaning:** Share of population whose income is below the official poverty threshold
- **Unit:** Percentage 
- **Source section:** Economic Characteristics (DP03)

---

## Health Insurance Coverage Rate (```DP03_0096PE```)

- **Definition:** Percentage of population with health insurance coverage
- **Type:** Data Profile variable (DP-series)
- **Meaning:** Measures access to health insurance (public or private)
- **Unit:** Percentage 
- **Source section:** Health Insurance Coverage (DP03)

---

## Median Age (```B01002_001E```)

- **Definition:** Median age of the total population (the last letter "E" indicates estimate value)
- **Type:** Detailed table variable (B-series)
- **Meaning:** Age that divides the population into two equal halves
- **Unit:** Years
- **Source table:** B01002

---


## How to read ACS codes

- **First letter** → dataset type (B = detailed, DP = profile)
  - B-series: detailed tables (precise census breakdowns)
  - DP-series: data profile tables (pre-aggregated indicators)
- **Numbers** → thematic table
- **Numbers after the underscore** → variable index
  - Lower numbers: basis variable
  - Higher numbers: more specific variable
- **Last letter** → data type:
  - E suffix: Estimate value
  - M suffix: Margin of error
