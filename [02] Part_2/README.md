# The Causal Effects of Medicaid Coverage: Evidence from the Oregon Health Insurance Experiment

Part 2 replicates the Oregon Health Insurance Experiment (Finkelstein et al., 2012), exploiting the 2008 Medicaid lottery as a randomized experiment. We first validate the design on the data: the first stage is strong (winning the lottery raises "ever enrolled" by 0.256), pre-randomization covariates are balanced conditional on household size, and differential survey non-response is small (about 1.7 pp). <br>
<br>
The main estimates are intention-to-treat (the effect of the offer of coverage), summarized by standardized indices over three domains; an instrumental-variable LATE (2SLS) recovers the effect of enrollment for compliers. Medicaid raised health-care use, substantially reduced financial strain (the most robust result), and improved self-reported and mental health; consistent with the OHIE in-person study, effects on physical biomarkers are null, and the full-sample mortality ITT is a precise null whose confidence interval does not exclude a roughly 20% reduction, underpowered, not zero. <br>
Estimating the same enrollment effect by OLS and matching yields near-zero coefficients far from the experimental LATE, demonstrating selection on unobservables directly. Inference relies on household-clustered standard errors and is corroborated by randomization inference. <br>
<br>
We flag residual limitations: underpowered subgroups, differential non-response, and selection among responders.

---

# Structure
 
This folder contains three subfolders. `data_2` holds the OHIE public-use files and any processed datasets used in the analysis. `scripts` contains the replication and estimation scripts. `docs` contains additional documentation on the data sources, variable construction, and methodological notes. Each subfolder has its own README with further details.
 
