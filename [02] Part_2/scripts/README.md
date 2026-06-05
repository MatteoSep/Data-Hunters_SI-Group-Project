# Part 2: Scripts Oregon Health Insurance Experiment

This script replicates the core empirical analysis of [Finkelstein et al.](../docs) (2012, *Quarterly Journal of Economics*) using the OHIE public-use files. It loads and merges the three source `.dta` files, constructs all derived variables, and prepares the analysis sample for ITT and LATE estimation.

The data files required to run this script are located in `[02] Part_2/data_2`. See the README in that folder for download instructions and variable documentation.

---

## Requirements

```r
library(lmtest)    # coeftest(): robust t-tests on lm objects
library(sandwich)  # vcovHC(), vcovCL(): robust covariance estimators
library(car)       # linearHypothesis(): joint F-tests
library(MatchIt)   # matchit(), match.data(): propensity score matching
library(cobalt)    # love.plot(): balance diagnostics
library(ggplot2)   # data visualization
library(haven)     # read_dta(): import Stata .dta files
```

---

## What the script does

The script merges the three OHIE files on `person_id` (expected output: N = 74,922, ~66,385 households), strips Stata value labels via `zap_labels()`, and constructs derived variables following the QJE replication conventions. Health outcomes are recoded so that higher always means better; financial strain variables are left in their natural direction (higher = more strain), so their ITT coefficients read with the opposite sign. The depression screen implements the PHQ-2 instrument (positive if interest + sadness score ≥ 5). The analysis sample for survey outcomes is restricted to respondents with a valid non-zero survey weight (`resp12`).

The script then estimates three quantities: the **ITT** (effect of winning the lottery), the **first stage** (effect of the lottery on Medicaid enrollment, δ₁ ≈ 0.256), and the **LATE** via 2SLS (causal effect of enrollment for compliers, ≈ 4× the ITT). All standard errors are clustered at the household level.

---

## AI disclosure

The development of this script was assisted by AI tools (Claude, Anthropic), primarily for code structuring, variable selection logic, and documentation. All analytical decisions were made by the research group. The use of AI assistance is disclosed in accordance with the course policy on AI tools stated in the assignment guidelines.


---

## Reference

Finkelstein A et al. (2012). The Oregon Health Insurance Experiment: Evidence from the First Year. *Quarterly Journal of Economics*, 127(3), 1057–1106.
