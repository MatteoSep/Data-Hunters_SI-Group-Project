# Part 2: OHIE Data

## Overview

The data for Part II come from the **Oregon Health Insurance Experiment (OHIE) Public Use Files**, distributed via Harvard Dataverse under open access.

The experiment stems from Oregon's 2008 Medicaid lottery, in which the state randomly selected households from a waiting list, creating exogenous variation in health insurance coverage. The full lottery list comprises **N = 74,922 individuals** across 66,385 households. All files share a common key (`person_id`) and can be merged 1:1.

---

## Citation

Two separate identifiers must be cited for different purposes:

| Resource | Description | DOI |
|----------|-------------|-----|
| **Paper (QJE)** | Finkelstein et al. (2012), *The Oregon Health Insurance Experiment: Evidence from the First Year*, QJE 127(3): 1057–1106 | [10.1093/qje/qjs020](https://doi.org/10.1093/qje/qjs020) |
| **Dataset** | OHIE Public Use Files — the `.dta` files used in this analysis | [10.7910/DVN/SJG1ED](https://doi.org/10.7910/DVN/SJG1ED) |

> **Note:** Do not cite the NBER working paper DOI (10.3386/w17190) — that is the pre-publication version. Use the QJE DOI above as the methodological reference.

---

## How to Obtain the Data

### Option A — Download from Harvard Dataverse (recommended)

1. Go to [https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/SJG1ED](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/SJG1ED)
2. Click **Access Dataset → Original Format ZIP** (or download individual files)
3. Create a free Harvard Dataverse account if prompted (required for download)
4. Extract the archive and place the three required `.dta` files (see below) in the `data/raw/` folder of this repository

### Option B — Internal sharing

The files may also be shared directly within the project group as a `.zip` archive. If received this way, extract and place the three required files in `data/raw/` as above.

---

## Files Used in This Analysis

Of the eight `.dta` files in the Public Use archive, Part II uses **three**:

| File | Role | Variables used |
|------|------|----------------|
| `oregonhie_descriptive_vars.dta` | Backbone: treatment assignment, household structure, pre-randomization controls | 13 |
| `oregonhie_survey12m_vars.dta` | 12-month survey outcomes, survey weights, demographic controls | 26 |
| `oregonhie_stateprograms_vars.dta` | Medicaid enrollment (administrative records) — first stage | 3 |

### Files available but not used

| File | Content |
|------|---------|
| `oregonhie_survey0m_vars.dta` | Baseline (pre-randomization) survey |
| `oregonhie_survey6m_vars.dta` | 6-month survey |
| `oregonhie_ed_vars.dta` | Emergency department visits (administrative) |
| `oregonhie_inperson_vars.dta` | Clinical biomarkers (in-person follow-up) |
| `oregonhie_patterns_vars.dta` | Enrollment timing and patterns |

---

## Variables Used

### From `oregonhie_descriptive_vars.dta`

| Variable | Role |
|----------|------|
| `person_id` | Merge key (1:1 across all files) |
| `household_id` | Household identifier (used for clustering SEs) |
| `treatment` | **Instrument** — lottery win (binary, randomized) |
| `numhh_list` | Household size at time of lottery (used as control and for clustering) |
| `draw_lottery` | Lottery draw number |
| `birthyear_list` | Birth year (used to compute `age12`) |
| `female_list` | Gender indicator |
| `english_list` | English as primary language |
| `self_list` | Self-reported application (vs. by another household member) |
| `first_day_list` | First day on the waiting list |
| `have_phone_list` | Has a phone (proxy for reachability) |
| `pobox_list` | PO Box address indicator |
| `zip_msa_list` | Lives in a Metropolitan Statistical Area |

### From `oregonhie_survey12m_vars.dta`

| Variable group | Variables |
|----------------|-----------|
| Survey design | `weight_12m`, `sample_12m`, `sample_12m_resp`, `returned_12m`, `wave_survey12m` |
| Healthcare use | `doc_num_mod_12m`, `er_num_mod_12m`, `rx_num_mod_12m`, `hosp_num_mod_12m` |
| Financial strain | `cost_any_oop_12m`, `cost_any_owe_12m`, `cost_borrow_12m`, `cost_refused_12m` |
| Self-reported health | `health_gen_12m`, `health_gen_bin_12m`, `health_chg_bin_12m`, `baddays_tot_12m`, `baddays_phys_12m`, `baddays_ment_12m` |
| Depression screen (PHQ-2) | `dep_interest_12m`, `dep_sad_12m` |
| Demographics (for subgroups) | `race_white_12m`, `race_black_12m`, `race_hisp_12m`, `edu_12m` |

### From `oregonhie_stateprograms_vars.dta`

| Variable | Derived name | Role |
|----------|-------------|------|
| `ohp_all_ever_matchn_30sep2009` | `ohp_admin` | Medicaid enrollment via administrative match |
| `ohp_all_ever_firstn_30sep2009` | `ohp_survey` → `insured` | **Endogenous variable** — Medicaid enrollment via survey |

---

## Derived Variables (Computed in Script)

The following variables are not read from the files but constructed in `part2_analysis.Rmd`, following the QJE replication code:

| Derived variable | Construction |
|-----------------|-------------|
| `insured` | = `ohp_survey` (binary Medicaid enrollment) |
| `resp12` | Respondent with non-zero survey weight |
| `age12` | = 2008 − `birthyear_list` |
| `older` | = 1 if age12 ∈ [50, 64] |
| `younger` | = 1 if age12 ∈ [19, 49] |
| `good_health` | Re-coded from `health_gen_12m` |
| `health_notpoor` | Re-coded from `health_gen_12m` |
| `health_improved` | = `health_chg_bin_12m` |
| `notbaddays_tot/phys/ment` | Inverted bad-days outcomes |
| `nodep_screen` | = 1 if PHQ-2 negative |
| `idx_use` | Standardized index — healthcare utilization |
| `idx_fin` | Standardized index — financial strain |
| `idx_health` | Standardized index — self-reported health |

