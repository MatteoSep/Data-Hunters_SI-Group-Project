# Part II: Experimental Data — Oregon Health Insurance Experiment (OHIE)

This directory contains the replication datasets from the **Oregon Health Insurance Experiment (OHIE)**, a landmark randomized controlled trial (RCT) in health economics. The study leverages a 2008 lottery system to evaluate the causal impact of expanding Medicaid coverage to low-income, uninsured adults.

> ⚠️ **Note on file previews:** These files are stored in Stata's native binary format (`.dta`). GitHub cannot display interactive previews for binary datasets. Please follow the instructions below to download and import them into R or Stata.

---

## Files in this directory

The experimental design is split across three specialized datasets, which must be merged using the unique individual identifier `person_id`. A pre-merged version is also available as `dt.csv` for convenience.

### `oregonhie_descriptive_vars.dta`
Contains baseline demographics and lottery randomization variables. The key variables are `person_id` and `household_id` (individual and household identifiers), `treatment` (the lottery selection indicator: 1 = selected, 0 = not selected — this is the **instrumental variable**), and baseline pre-treatment covariates such as `birthyear_list`, `female_list`, and `english_list`, used for balance checks and control specifications.

### `oregonhie_stateprograms_vars.dta`
Administrative records tracking actual Medicaid enrollment through state health programs. The key variable is `ohp_all_ever_matchn_30sep2009`, an indicator of whether the individual ever enrolled in Medicaid during the study window — this is the **endogenous treatment variable**. Also contains duration variables measuring months of coverage.

### `oregonhie_survey12m_vars.dta`
Data from a comprehensive mail survey administered approximately 12 months post-randomization. Contains `sample_12m` and `sample_12m_resp` (response tracking and survey weights), and all survey-based outcome variables: health care utilization (ER visits, hospitalizations, outpatient visits), self-reported health measures, and financial strain indicators (medical debt, out-of-pocket expenditures).

### `dt.csv`
Pre-merged version of the three `.dta` files above, joined on `person_id` and exported to CSV. This is the file directly used by the analysis scripts. See the scripts README for details on how it was constructed.

---

## How to download individual files from GitHub

If you are not cloning the full repository, you can download individual files manually:

1. Click on the target `.dta` file in the GitHub interface.
2. Click the **"Download raw file"** button (top right of the file preview box).
3. Right-click and select **"Save Link As..."** to save the binary file to your local machine.

---

## Importing into R and Stata

### R

```r
library(haven)

desc <- read_dta("path/to/oregonhie_descriptive_vars.dta")
sp   <- read_dta("path/to/oregonhie_stateprograms_vars.dta")
s12  <- read_dta("path/to/oregonhie_survey12m_vars.dta")

head(desc)
```

Note: `haven` imports Stata variables as `haven_labelled` objects. Strip labels before modelling with `haven::zap_labels()` — see the analysis script for details.

### Stata

```stata
use "path/to/oregonhie_descriptive_vars.dta", clear
merge 1:1 person_id using "path/to/oregonhie_stateprograms_vars.dta"
merge 1:1 person_id using "path/to/oregonhie_survey12m_vars.dta"
```

---

## Reference

Finkelstein A, Taubman S, Wright B, et al. (2012). The Oregon Health Insurance Experiment: Evidence from the First Year. *Quarterly Journal of Economics*, 127(3), 1057–1106.
