# Part II – Causal Inference: Oregon Health Insurance Experiment

## Research Question
Does gaining Medicaid coverage causally improve health outcomes and 
reduce financial strain for low-income adults?

## Identification Strategy
The Oregon Medicaid lottery (2008) randomly selected households from 
a waiting list, creating exogenous variation in insurance coverage. 
We exploit this as an instrument for actual Medicaid enrollment.

**Estimator:** Two-Stage Least Squares (2SLS / IV)  
- First stage:  insured_i = α + π·treatment_i + X'γ + ε_i  
- Second stage: Y_i = β_0 + β_1·insured̂_i + X'δ + u_i  

**Key assumptions:**
1. Relevance – lottery win strongly predicts enrollment (F > 10)
2. Exclusion restriction – lottery affects outcomes only via insurance
3. Monotonicity – no defiers

## Data
Three files from the OHIE Public Use Files (Harvard Dataverse, 
DOI: 10.7910/DVN/SJG1ED):

| File | Role | Variables used |
|------|------|---------------|
| oregonhie_descriptive_vars.dta | Treatment, household, controls | 13 |
| oregonhie_survey12m_vars.dta | 12-month outcomes + survey weights | 26 |
| oregonhie_stateprograms_vars.dta | Medicaid enrollment (admin records) | 3 |

**Note on data access:** The .dta files are not committed to this 
repository due to size. Download from Harvard Dataverse and place in 
`data/raw/`. The script loads them with `haven::read_dta()`.

## Variables

### Treatment & Instrument
- `treatment` – lottery win (binary, randomized)
- `insured` = `ohp_survey` – Medicaid enrollment within 12 months

### Outcomes (12-month survey)
- Health: `good_health`, `health_notpoor`, `baddays_phys_12m`, 
  `baddays_ment_12m`, `dep_interest_12m`
- Healthcare use: `doc_num_mod_12m`, `er_num_mod_12m`, `rx_num_mod_12m`
- Financial: `cost_any_oop_12m`, `cost_any_owe_12m`

### Controls (pre-randomization)
- `numhh_list`, `female_list`, `birthyear_list`, `english_list`, 
  `zip_msa_list`

### Derived variables (computed in script)
- `age12` = 2008 − birthyear_list
- `older` (50–64), `younger` (19–49) – subgroup dummies
- Standardized indices: `idx_use`, `idx_fin`, `idx_health`

## How to Reproduce
1. Download the OHIE Public Use Files from Harvard Dataverse
2. Place the three .dta files in `data/raw/`
3. Open `part2/part2_analysis.Rmd` in RStudio
4. Run `rmarkdown::render("part2/part2_analysis.Rmd")`

**Required R packages:**
```r
haven, dplyr, ivreg, lmtest, sandwich, ggplot2, knitr, modelsummary
```

## Methodological Reference
Replication code aligned with:  
`OHIE_QJE_Replication_Code/oregon_hie_qje_replication.do`  
(included in Harvard Dataverse Public Use Files)
