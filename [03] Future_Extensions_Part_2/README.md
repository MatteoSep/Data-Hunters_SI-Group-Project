# Future Extension — ACA Medicaid Expansion and Mortality (Incomplete)

> **This analysis was not completed.** The material in this folder represents preliminary work that was developed primarily with AI assistance and was not finished due to time and resource constraints. It does not form part of the graded submission and should be interpreted accordingly.

---

## Motivation

Part 2 of our project (OHIE replication) provides experimental evidence on the effects of Medicaid on health outcomes, but its external validity is limited: the study population is specific to Portland-area low-income adults in 2008, and the 16-month follow-up window is too short to detect mortality effects with adequate statistical power (Finkelstein et al., 2012; Baicker & Finkelstein, 2011).

This extension was intended to complement the OHIE evidence by exploiting the **ACA Medicaid expansions starting in 2014**, which affected a much larger population across multiple states and allows for the estimation of longer-run mortality effects. The reference paper for this extension is:

> Borgschulte M, Vogler J (2020). Did the ACA Medicaid expansion save lives? *Journal of Health Economics*, 72, 102333. doi: [10.1016/j.jhealeco.2020.102333](https://doi.org/10.1016/j.jhealeco.2020.102333)

A copy of the paper is included in this folder as `Journal_of_Health_Economics.pdf`.

---

## Intended Design

The ACA Medicaid expansion was adopted by states at different points in time — a **staggered adoption** design. Standard two-way fixed effects (TWFE) difference-in-differences is known to produce biased estimates in this setting when treatment effects are heterogeneous across cohorts and time periods, because it implicitly uses already-treated units as controls for later-treated ones.

The planned estimator was the **Callaway & Sant'Anna (2021)** DiD, implemented in R via the `did` package. This estimator addresses the staggered adoption problem by:

- computing group-time average treatment effects (ATTs) for each cohort (defined by first treatment year) separately;
- using only clean controls — never-treated or not-yet-treated units — as the comparison group;
- aggregating cohort-specific effects into interpretable summary statistics.

The key identification assumption is **parallel trends conditional on covariates**: in the absence of the Medicaid expansion, mortality trends in expansion and non-expansion counties would have evolved similarly, after controlling for observable county-level characteristics.

---

## Files in this folder

`Journal_of_Health_Economics.pdf` is the Borgschulte & Vogler (2020) paper, which serves as the methodological and empirical reference for this extension.

`panel_state_year.csv` is the main panel dataset assembled for the analysis. It contains annual county-level mortality rates and socioeconomic covariates for U.S. counties from 2010 to 2019, merged from CDC WONDER and U.S. Census sources. The `data/` subfolder contains the three underlying CDC WONDER mortality files used to construct it: all-cause mortality (`cdc_allcause_25-64_2010-2019.csv`), amenable-cause mortality (`cdc_amenable_25-64_2010-2019.csv`), and external-cause-filtered mortality (`cdc_external_filtered_25-64_2010-2019.csv`), all for adults aged 25–64.

An R script implementing the preliminary Callaway & Sant'Anna estimation will be added to this folder separately.

---

## Why this was not completed

The extension required a significant additional investment of time to: 
- correctly implement the Callaway & Sant'Anna estimator with county-level clustering and covariate adjustment;
- validate pre-trend parallel assumptions across cohorts;
- reproduce and cross-check results against Borgschulte & Vogler (2020). Given the deadline and the workload already required by Parts 1 and 2, we were unable to bring this analysis to a standard we considered suitable for submission.

The preliminary data assembly and design notes are included here for transparency and to document the direction we had explored.

---

## References

- Borgschulte M, Vogler J (2020). Did the ACA Medicaid expansion save lives? *Journal of Health Economics*, 72, 102333.
- Callaway B, Sant'Anna PHC (2021). Difference-in-Differences with Multiple Time Periods. *Journal of Econometrics*, 225(2), 200–230.
- Finkelstein A et al. (2012). The Oregon Health Insurance Experiment: Evidence from the First Year. *Quarterly Journal of Economics*, 127(3), 1057–1106.
