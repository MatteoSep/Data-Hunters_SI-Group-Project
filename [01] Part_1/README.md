# Part 1

Part 1 studies the cross-sectional relationship between health insurance and mortality using U.S. state-level data for 2019 (n = 51). <br>
We regress mortality on the insured share, progressively adding demographic and income controls and an income interaction, with heteroskedasticity-robust (HC3) standard errors. <br>
The estimated association is small and unstable across specifications, and once income is included it can even switch sign, a suppressor pattern. <br>
We argue that none of these estimates identifies a causal effect: omitted variables (population health, income, behaviour), reverse causality (sicker or poorer populations select differently into coverage), and the ecological fallacy all confound a state-level regression. <br>
The contribution of this section is therefore diagnostic (it shows precisely why a purely observational design fails to recover the causal parameter of interest) and it motivates the quasi-experimental strategy of Part II, where randomization removes the confounding that no amount of OLS adjustment can.
<br>

---

## Structure
 
This folder contains two subfolders. `data_1` holds the raw CDC WONDER files and the processed dataset used in the analysis. `scripts` contains the data pipeline and regression scripts. Each subfolder has its own README with details on data sources, variable definitions, and processing steps.

