# From Correlation to Causation: Health Insurance, Mortality, and the Limits of Observational Inference

This repository contains the documentation and the code for the project of the Statistical Inference course, Università di Roma La Sapienza.
The assignment consist of a two-part statistic project, evaluating the causal impact of public health insurance expansion on population mortality, healthcare utilization, and financial security.<br>

---

# Abstract
This paper asks whether expanding public health insurance causally improves health and financial security, using two complementary designs to separate correlation from causation. 
<br>
### The Cross-Sectional Association Between Health Insurance and Mortality: A Diagnostic OLS Analysis of U.S. States, 2019
**Part 1** estimates cross-sectional OLS regressions of state-level mortality on insurance coverage (2019, n = 51); the association is weak and unstable across specifications, and we argue it cannot be read causally because of omitted-variable bias, reverse causality, and the ecological fallacy. 
<br>
### The Causal Effects of Medicaid Coverage: Evidence from the Oregon Health Insurance Experiment
**Part 2** replicates the Oregon Health Insurance Experiment, a 2008 lottery that randomly allowed low-income adults to apply for Medicaid, and recovers the causal effect that observational methods cannot. Winning the lottery raised Medicaid enrollment by about 25 percentage points (first stage 0.256) and, through intention-to-treat and instrumental-variable (LATE) estimation, increased health-care use, sharply reduced financial strain, and improved self-reported and mental health; effects on physical biomarkers and on mortality are precise nulls rather than evidence of no effect. <br>
Comparing observational (OLS, matching) with experimental (LATE) estimates on the same data exhibits the selection bias directly. <br>
The methodological lesson is that identification, not statistical adjustment, is what delivers credible causal estimates.

---

# Structure
**`[00] Paper/`** contains the final output: the submitted PDF report and all clean, commented R scripts used in the analysis.
 
**`[01] Part_1/`** provides additional documentation on data retrieval and processing for the cross-sectional OLS analysis, including the data pipeline script, raw CDC WONDER files, and the processed dataset.
 
**`[02] Part_2/`** provides additional documentation on data retrieval and processing for the causal analysis, including the OHIE replication script and variable construction.
 
**`future extension part_2/`** contains preliminary work on a planned but incomplete extension to Part 2.

### Future Extension: Callaway & Sant'Anna DiD (incomplete)
While working on Part 2, we explored a complementary extension based on the Callaway & Sant'Anna (2021) Difference-in-Differences estimator, which handles heterogeneous treatment effects in staggered adoption designs. <br>
<br>
The idea was to complement the OHIE RCT evidence, specific to Oregon in 2008, with a broader quasi-experimental analysis of the ACA Medicaid expansions starting in 2014, where states adopted the policy at different points in time. The Callaway & Sant'Anna estimator is methodologically appropriate for this setting because it accounts for treatment timing heterogeneity across cohorts and avoids the negative-weighting problem of standard two-way fixed effects DiD. <br>
<br>
Due to time and resource constraints, this analysis was not completed and is not part of the submitted paper. <br>
The folder `future extension part_2` contains the data assembled and the preliminary notes outlining the intended design. <br>
This material is included for transparency only and does not form part of the graded submission.

---

# Disclaimer
This repository was created for academic purposes as part of the Statistical Inference course project, Università di Roma La Sapienza.  
All data sources belong to their respective owners, including the U.S. Census Bureau and CDC WONDER.


