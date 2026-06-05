# Part 1

Part I studies the cross-sectional relationship between health insurance and mortality using U.S. state-level data for 2019 (n = 51). <br>
We regress mortality on the insured share, progressively adding demographic and income controls and an income interaction, with heteroskedasticity-robust (HC3) standard errors. <br>
The estimated association is small and unstable across specifications, and once income is included it can even switch sign, a suppressor pattern. <br>
We argue that none of these estimates identifies a causal effect: omitted variables (population health, income, behaviour), reverse causality (sicker or poorer populations select differently into coverage), and the ecological fallacy all confound a state-level regression. <br>
The contribution of this section is therefore diagnostic (it shows precisely why a purely observational design fails to recover the causal parameter of interest) and it motivates the quasi-experimental strategy of Part II, where randomization removes the confounding that no amount of OLS adjustment can.
<br>
## Setup

To ensure reproducibility, initialize the environment by loading the required libraries and setting up your federal API credentials:
```r
library(tidycensus)
library(tidyverse)

census_api_key("API_KEY", install=TRUE)
```


<br>

