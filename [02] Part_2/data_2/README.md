# Part 2: Experimental Data – Oregon Health Insurance Experiment (Oregon HIE)

This directory contains the replication datasets from the **Oregon Health Insurance Experiment (Oregon HIE)**, a landmark randomized controlled trial (RCT) in health economics. The study leverages a 2008 lottery system to evaluate the causal impact of expanding Medicaid coverage to low-income, uninsured adults.

> ⚠️ **Note on File Previews:** These files are stored in Stata's native binary format (`.dta`). GitHub cannot display interactive previews for binary datasets. Please follow the instructions below to download and import them into your statistical software (R or Stata).

## Directory Structure & File Content

The experimental design is broken down into three core specialized datasets, which must be combined via relational joins using the unique identifier `person_id`.

### 1. `oregonhie_descriptive_vars.dta`
* **Core Purpose:** Contains baseline demographics and lottery randomization tracking parameters.
* **Key Variables:**
    * `person_id` & `household_id`: Primary and relational cryptographic identifiers.
    * `treatment`: The foundational lottery selection indicator ($1 = \text{Selected/Won}$, $0 = \text{Not Selected}$). This is your **Instrumental Variable (IV)**.
    * `birthyear_list`, `female_list`, `english_list`: Baseline pre-treatment covariates used to check balancing properties and control specifications.

### 2. `oregonhie_stateprograms_vars.dta`
* **Core Purpose:** Administrative longitudinal tracking of actual insurance enrollment through state health programs (Medicaid/OHP).
* **Key Variables:**
    * `ohp_all_ever_matchn_30sep2009`: Indicator of whether the individual actually enrolled in health insurance during the study window. This is your endogenous treatment variable.
    * `six_mos`, `twelve_mos`, `inp_mos`: Total duration parameters measuring institutional exposure and enrollment intensity (months of coverage).

### 3. `oregonhie_survey12m_vars.dta`
* **Core Purpose:** Out-of-sample data collected via a comprehensive mail survey administered approximately 12 months post-randomization.
* **Key Variables:**
    * `sample_12m` & `sample_12m_resp`: Sampling matrices and non-response tracking weights.
    * **Outcomes:** Contains survey answers regarding health service utilization (ER visits, hospitalizations), self-reported health metrics, and financial distress measures (medical debt).

---

## How to Download the Files from GitHub

If you are not cloning the entire repository via Git, you can extract individual datasets manually through the web browser:
1. Click on the target `.dta` file inside the GitHub repository interface.
2. Look for the **"Download raw file"** button (or the `Download` button located on the top right of the file box).
3. Right-click the button and select **"Save Link As..."** to download the original binary file directly to your local workspace.

---

## Ingestion Setup: Importing into R & Stata

To successfully parse and load these Stata binary data structures into your current analytical pipeline, implement the following script initializations.

### Importing into R
To read `.dta` files in R while preserving variable labels and format specifications, use the `haven` package:

```r
# Install haven if not already present
if(!require(haven)) install.packages("haven")
library(haven)

# Load the datasets into your environment
descriptive <- read_dta("path/to/folder/oregonhie_descriptive_vars.dta")
state_programs <- read_dta("path/to/folder/oregonhie_stateprograms_vars.dta")
survey_12m <- read_dta("path/to/folder/oregonhie_survey12m_vars.dta")

# Inspect structure
head(descriptive)
