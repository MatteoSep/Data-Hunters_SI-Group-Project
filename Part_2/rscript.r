# ----------------------------------------------------------------------------
# PACKAGES
# ----------------------------------------------------------------------------
# --- used in the course labs ---
library(lmtest)     # coeftest() for t-tests on lm objects        
library(sandwich)   # robust covariance estimators (vcovHC/vcovCL) 
library(car)        # linearHypothesis() for joint F-tests        
library(MatchIt)    # matchit(), match_data()                       
library(cobalt)     # love.plot() balance diagnostics              
library(ggplot2)    # data visualization                           
library(haven)      # read_dta(): import Stata .dta files

################################################################################
# 0 - DATA: LOAD, MERGE, PREPARE
################################################################################
# The OHIE distributes several .dta files keyed on person_id. We use the three
# that contain the design backbone, the 12-month survey outcomes, and Medicaid
# enrollment. (The other PUF files - ED admin, in-person exam, 0m/6m surveys -
# are not used here; see the Data section of the paper.)

path <- "OHIE_Public_Use_Files/OHIE_Data"  

desc <- read_dta("oregonhie_descriptive_vars.dta")   # treatment, household, controls
s12  <- read_dta("oregonhie_survey12m_vars.dta")   # 12-month outcomes + weights
sp   <- read_dta("oregonhie_stateprograms_vars.dta") # Medicaid enrollment (admin)

dt <- merge(desc, s12, by = "person_id")
dt <- merge(dt,   sp,  by = "person_id")
cat("Merged sample size N =", nrow(dt),
    "| households =", length(unique(dt$household_id)), "\n")
# Expected: N = 74,922 ; ~66,385 households. The lottery was run at the
# household level, which is why we will cluster on household_id later.

# --- Rename the two enrollment variables to readable names (QJE conventions) --
# Heads-up: the OHIE ships TWO "ever on Medicaid" variables and we keep BOTH on
# purpose. ohp_admin is the administrative measure on the FULL
# sample. We use it for the first stage. 
# ohp_survey is the measure aligned to the survey sample 
# We use it as the endogenous "treatment" in the OLS/Matching/LATE on survey 
# outcomes. This split follows the note to QJE Table III (full-sample first stage vs survey-sample
# LATE).

dt$ohp_admin  <- dt$ohp_all_ever_matchn_30sep2009  
dt$ohp_survey <- dt$ohp_all_ever_firstn_30sep2009 
dt$zip_msa    <- dt$zip_msa_list

# haven imports columns as "labelled" (they carry Stata value labels). We strip
# the labels so the variables behave as plain numeric vectors in lm()/plots.
lab_cols <- sapply(dt, function(x) inherits(x, "haven_labelled"))
dt[lab_cols] <- lapply(dt[lab_cols], haven::zap_labels)

# --- Derived variables (constructed exactly as in the QJE replication code) ---
# We orient every health outcome so that "higher = better/more of the construct"
# (the raw survey bins are coded the opposite way for some items). 
# NOTE: the financial-strain items are deliberately LEFT in their natural direction
# (higher = MORE strain), so their ITT sign reads the opposite way. See the
# SIGN note in Step III.
dt$insured  <- dt$ohp_survey                       # endogenous "treatment" = ever enrolled
dt$age12     <- 2008 - dt$birthyear_list            # age at the lottery
dt$older     <- as.numeric(dt$birthyear_list >= 1945 & dt$birthyear_list <= 1958) # 50-64
dt$younger   <- as.numeric(dt$birthyear_list >= 1959 & dt$birthyear_list <= 1989) # 19-49

dt$good_health     <- 1 - dt$health_gen_bin_12m     # 1 = good/very good/excellent
dt$health_notpoor  <- ifelse(is.na(dt$health_gen_12m), NA,
                             as.numeric(dt$health_gen_12m != 1))   # 1 = not "poor"
dt$health_improved <- 1 - dt$health_chg_bin_12m     # 1 = health improved vs last year
dt$notbaddays_tot  <- 30 - dt$baddays_tot_12m       # # good days (physical+mental), last 30
dt$notbaddays_phys <- 30 - dt$baddays_phys_12m
dt$notbaddays_ment <- 30 - dt$baddays_ment_12m
# PHQ-2 depression screen: positive if (interest + sad) >= 5; we keep the "good" side
dt$nodep_screen    <- ifelse(is.na(dt$dep_interest_12m) | is.na(dt$dep_sad_12m), NA,
                             as.numeric((dt$dep_interest_12m + dt$dep_sad_12m) < 5))

# --- Analysis sample for the 12-month survey ---------------------------------
# Outcomes come from a survey: we keep respondents with a non-zero survey weight.
# (sample_12m_resp and weight_12m are provided by the OHIE study)
dt$resp12 <- with(dt, sample_12m_resp == 1 & !is.na(weight_12m) & weight_12m != 0)
