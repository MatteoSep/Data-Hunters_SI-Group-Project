### Notes on ACS Variable Codes

# ACS Variables Documentation

This project uses data from the American Community Survey (ACS) 2019 1-year estimates.  
Below is a description of all variables used in the analysis.

---

## B19013_001 — Median Household Income

- **Definition:** Median household income in the past 12 months (inflation-adjusted dollars)
- **Type:** Detailed table variable (B-series)
- **Meaning:** Splits all households into two equal groups: half earn more, half earn less
- **Unit:** US Dollars
- **Source table:** B19013

---

## DP03_0128PE — Poverty Rate

- **Definition:** Percentage of individuals below the poverty level
- **Type:** Data Profile variable (DP-series)
- **Meaning:** Share of population whose income is below the official poverty threshold
- **Unit:** Percentage (%)
- **Source section:** Economic Characteristics (DP03)

---

## DP03_0096PE — Health Insurance Coverage Rate

- **Definition:** Percentage of population with health insurance coverage
- **Type:** Data Profile variable (DP-series)
- **Meaning:** Measures access to health insurance (public or private)
- **Unit:** Percentage (%)
- **Source section:** Health Insurance Coverage (DP03)

---

## B01002_001E — Median Age

- **Definition:** Median age of the total population
- **Type:** Detailed table variable (B-series)
- **Meaning:** Age that divides the population into two equal halves
- **Unit:** Years
- **Note:** "E" indicates estimate value (not margin of error)
- **Source table:** B01002

---

# Notes on ACS Variable Naming

- **B-series:** Detailed tables (precise census breakdowns)
- **DP-series:** Data Profile tables (pre-aggregated indicators)
- **E suffix:** Estimate value
- **M suffix:** Margin of error
