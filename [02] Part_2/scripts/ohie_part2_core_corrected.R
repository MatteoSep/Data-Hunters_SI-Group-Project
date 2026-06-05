################################################################################
################################################################################
#####################   Part II - Causal Inference (RCT)   #####################
#####################   Oregon Health Insurance Experiment #####################
################################################################################
################################################################################
###                                                                           ##
###  Research question: what is the causal effect of Medicaid coverage on     ##
###  health-care use, financial strain, and health?                           ##
###                                                                           ##
###  Design: the 2008 Oregon lottery randomly selected adults to be allowed   ##
###  to apply for Medicaid -> a real randomized experiment (RCT).             ##
###                                                                           ##
###  Main method: Intention-to-Treat (ITT) = difference in mean outcomes      ##
###  between lottery winners and losers (the estimand is the effect of the    ##
###  offer of coverage, identified by randomization alone).                   ##
###                                                                           ##
###  Data: OHIE Public Use Files, Harvard Dataverse, DOI 10.7910/DVN/SJG1ED.  ##
###  Reference paper: Finkelstein et al. (2012), QJE 127(3): 1057-1106.       ##
###                                                                           ##
###  Note on sources: commands taught in the course are used natively.        ##
###  Commands not covered in the course are flagged explicitly with their     ##
###  external source.                                                         ##
###                                                                           ##
################################################################################

# ---- Packages -------------------------------------------------------------
library(ggplot2)    # all figures
library(lmtest)     # coeftest                         
library(sandwich)   # vcovHC (Lab1) + vcovCL 
library(MatchIt)    # matchit / match_data              
library(cobalt)     # love.plot                         
library(car)        # linearHypothesis                 


dt <- read.csv("dt.csv")
# Survey analysis sample: 12m survey responders with a non-zero survey weight
# (resp12 is built in the data-prep script as sample_12m_resp == 1 & weight_12m != 0).
da <- subset(dt, resp12)   # da = survey analysis sample

# Pre-randomization covariates (recorded on the lottery list, before the draw)
baseline <- c("birthyear_list","female_list","english_list","self_list",
              "first_day_list","have_phone_list","pobox_list","zip_msa")

# ----------------------------------------------------------------------------
# HELPER: clustered standard errors  (EXTENSION beyond the labs)
# ----------------------------------------------------------------------------
# Here the treatment is assigned at the HOUSEHOLD level, so observations within
# a household are not independent and we must cluster the SE on household_id.
# vcovCL() is the clustered analogue of vcovHC(), from the SAME sandwich package.
# Source: Zeileis, Koll & Graham (2020), "Various Versatile Variances: An
#         Object-Oriented Implementation of Clustered Covariances in R", JSS 95(1)
#         (sandwich::vcovCL). Methodology: Cameron & Miller (2015), J. Human
#         Resources 50(2).
#
# vcl(): returns the clustered covariance, but first aligns the cluster vector to
# the rows lm actually used. lm() drops rows with NA (na.omit), so without this
# alignment vcovCL() errors (cluster length != #obs) or mis-clusters whenever a
# variable has missing values (true here: e.g. female_list, zip_msa, and most 12m
# survey outcomes have NAs). Every call below passes the household_id of the exact
# data frame the model was fit on, so the index alignment is correct.
vcl <- function(model, cluster) {
  if (!is.null(model$na.action)) cluster <- cluster[-as.integer(model$na.action)]
  vcovCL(model, cluster = cluster, type = "HC1")
}
clx <- function(model, cluster) {
  coeftest(model, vcov. = vcl(model, cluster))
}
################################################################################
# I - RESEARCH DESIGN VALIDATION
################################################################################
# "RCT" is not a magic word: before trusting the lottery we must SHOW, on the
# data, that it behaved like an experiment. Three checks: (1A) first stage,
# (1B) balance, (1C) differential non-response.

# ---- 1A. FIRST STAGE: did winning the lottery change Medicaid enrollment? ----
# The whole experiment hinges on this. If winning did not actually raise
# coverage, the offer would be a treatment in name only and the ITT would
# measure the effect of nothing. So before anything else we check that the
# instrument bites: we regress actual enrollment on the lottery win.

# Model: ohp_admin = b0 + b1*treatment + (draw) + (hh-size) + u
# The two sets simply reproduce HOW the lottery was run:
# - factor(draw_lottery) = lottery-draw fixed effects
# - factor(numhh_list) = household-size fixed effects
# Enrollment variable here = ohp_admin (full-sample administrative "ever enrolled",
# = ohp_all_ever_matchn_30sep2009). The LATE in Section II.4 instead instruments
# `insured` (= ohp_survey = ohp_all_ever_firstn_30sep2009), the survey-sample
# measure whose first stage is ~0.290. Using two different enrollment measures -
# full-sample first stage (~0.256) vs survey-sample LATE is intentional and
# follows the note to QJE Table III. 
fs_full <- lm(ohp_admin ~ treatment + factor(draw_lottery) + factor(numhh_list),
              data = dt)
summary(fs_full)
print(clx(fs_full, dt$household_id)["treatment", , drop = FALSE])
# We get b1 ~ 0.256: winning the lottery raises the probability of ever being on
# Medicaid by about 25 percentage points.
# This reproduces the published QJE first stage, so the "offer" is a strong, real
# treatment. Note b1 is well below 1: not every winner enrols, and some losers
# get Medicaid anyway. That imperfect take-up is exactly why the offer (ITT) and
# the effect of enrollment (LATE) are different numbers. 

# ---- 1B. BALANCE: were winners and losers comparable before the draw? --------
# Randomization implies the two arms should not differ on pre-treatment
# covariates. We test each covariate (lm of the covariate on treatment + hh-size
# FE) and report the difference.
bal_tab <- data.frame()
for (v in baseline) {
  m  <- lm(as.formula(paste(v, "~ treatment + factor(numhh_list)")), data = dt)
  ct <- clx(m, dt$household_id)["treatment", ]
  bal_tab <- rbind(bal_tab, data.frame(
    covariate    = v,
    control_mean = round(mean(dt[[v]][dt$treatment == 0], na.rm = TRUE), 4),
    diff         = round(ct["Estimate"], 4),
    se           = round(ct["Std. Error"], 4),
    p            = round(ct["Pr(>|t|)"], 3),
    row.names    = NULL))
}
print(bal_tab)

# Omnibus joint F-test: regress treatment on all baseline covariates at once and
# test that they are jointly zero. This is our addition on top of the per-row test.
omni <- lm(as.formula(paste("treatment ~", paste(baseline, collapse = " + "),
                            "+ factor(numhh_list)")), data = dt)
summary(omni)
print(car::linearHypothesis(omni, paste0(baseline, " = 0"),
                            vcov. = vcl(omni, dt$household_id)))
# A non-significant F means we cannot reject balance.

# Visual: a Love plot of standardized mean differences, full sample vs
# responders.
smd <- function(data, v) {
  t <- data[[v]][data$treatment == 1]; c <- data[[v]][data$treatment == 0]
  (mean(t, na.rm=TRUE) - mean(c, na.rm=TRUE)) /
    sqrt((var(t, na.rm=TRUE) + var(c, na.rm=TRUE)) / 2)
}
love_df <- rbind(
  data.frame(Covariate = baseline, SMD = sapply(baseline, function(v) smd(dt, v)),
             Sample = "Full sample"),
  data.frame(Covariate = baseline, SMD = sapply(baseline, function(v) smd(da, v)),
             Sample = "12m responders"))
ggplot(love_df, aes(x = SMD, y = Covariate, colour = Sample, shape = Sample)) +
  geom_vline(xintercept = 0) +
  geom_vline(xintercept = c(-0.1, 0.1), linetype = "dashed", colour = "grey60") +
  geom_point(size = 3) +
  labs(title = "Covariate balance (standardized mean differences)",
       subtitle = "Dashed lines = +/- 0.10 SD rule of thumb (as in Lab3)",
       x = "Standardized difference (treatment - control)", y = NULL) +
  theme_minimal()
# How to read it: each covariate has two points, one per sample (full vs 12m
# responders); dashed lines mark the +/- 0.10 SD rule of thumb. Almost everything
# hugs zero in both samples.
# The one exception is self_list (~ -0.25 SD full, ~ -0.13 responders): it sits
# outside the band, but this is an artefact of an unconditional SMD,
# not a broken randomization. self_list is mechanically tied to
# household size (in 1-person households you self-enrol; in larger ones one member
# signs up the rest), and household size drives the treatment probability,so a
# raw, unconditional comparison conflates the two. The authoritative balance check
# is the regression table + omnibus F just above, which condition on
# factor(numhh_list). There self_list is balanced (diff +0.0003, p = 0.273).

# ---- 1C. DIFFERENTIAL NON-RESPONSE: does the survey reintroduce selection? ---
# Outcomes come from a voluntary survey. If winning changed who answers, the
# respondent subsample is no longer randomized. We test whether treatment
# predicts responding (among those mailed the survey).
nonresp <- lm(returned_12m ~ treatment + factor(numhh_list),
              data = subset(dt, sample_12m == 1))
summary(nonresp)
print(clx(nonresp, subset(dt, sample_12m == 1)$household_id)["treatment", , drop = FALSE])
# We hoped for ~ 0: if treatment did not move response, answering would be "as
# good as random" given the design, and the respondent subsample would inherit the
# experimental balance untouched. Instead the gap is a small negative number:
# winners respond ~1.7 pp LESS. It is significant only because N is huge.
# So a differential response does exist, and we do not wave it away just
# because it is small. This is a limitation of the model
# that can re-introduce the threat of selection bias on observables when we move
# from the offer to enrollment (non-compliers).

# Visual: response rate by lottery arm.
rr <- aggregate(returned_12m ~ treatment, data = subset(dt, sample_12m == 1), FUN = mean)
rr$Arm <- ifelse(rr$treatment == 1, "Treatment (won)", "Control (lost)")
ggplot(rr, aes(x = Arm, y = returned_12m, fill = Arm)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f%%", 100 * returned_12m)), vjust = -0.4) +
  labs(title = "12-month survey response rate by lottery arm",
       y = "Response rate", x = NULL) +
  theme_minimal()
# How to read it: the two bars are almost the same height (~41.5% control vs
# ~39.9% treatment). The small gap matches the tiny negative coefficient in the
# regression just above: winning nudges response down by less than 2 points.
# Small but real, which is why we lean on the survey weights and still flag
# residual selection among responders as a limitation.

################################################################################
# II - SELECTION BIAS: why we need the experiment  
################################################################################
# On the same data we estimate the effect three ways
# and watch the observational answer fail:
#   (1) Naive OLS        : compare insured vs uninsured, "controlling" for demographics
#   (2) Matching         : pair similar units (still blind to unobservables)
#   (3) ITT              : compare lottery winners vs losers 
#   (4) LATE/2SLS        : effect of enrollment for compliers
#
# Estimand note: OLS, Matching and LATE estimate the effect of
# enrollment; the ITT estimates the effect of the offer (~ LATE x first stage).
# So the valid selection-bias contrast is OLS/Matching vs LATE.

# Demographic controls that are plausibly pre-determined (used by OLS/Matching).
dem <- "age12 + female_list + english_list + race_white_12m + race_black_12m + race_hisp_12m + factor(edu_12m)"

## ---- (1) NAIVE OLS (observational, biased) ---------------------------------
# Model:  outcome = b0 + b1*insured + (demographics) + u
# We compare the insured and the uninsured, throwing in demographic controls and
# hoping that is enough. The estimand is the effect of enrollment.
ols_h <- lm(as.formula(paste("good_health     ~ insured +", dem)), data = da)
summary(ols_h)
print(clx(ols_h, da$household_id)["insured", , drop = FALSE])  # good health
ols_d <- lm(as.formula(paste("cost_any_owe_12m ~ insured +", dem)), data = da)
summary(ols_d)
print(clx(ols_d, da$household_id)["insured", , drop = FALSE])  # owe medical debt
# Reading: on good_health the coefficient is basically 0 (and not significant),
# observationally, the insured look no healthier than the uninsured.

## ---- (2) MATCHING  -------------------
# Goal of matching is balance.
# Note: Matching is our addition. It is not in the QJE paper. We include it to
# show that even a "good" observational method cannot fix unobserved selection.
dm <- na.omit(da[, c("insured","good_health","cost_any_owe_12m","age12","female_list",
                     "english_list","race_white_12m","race_black_12m","race_hisp_12m",
                     "edu_12m","household_id")])
# (a) imbalance before matching
m_out0 <- matchit(insured ~ age12 + female_list + english_list +
                    race_white_12m + race_black_12m + race_hisp_12m + factor(edu_12m),
                  data = dm, method = NULL)
summary(m_out0)   # large Std. Mean Diff. = treated/control not comparable

# (b) 1:1 nearest-neighbour PS matching
m_out1 <- matchit(insured ~ age12 + female_list + english_list +
                    race_white_12m + race_black_12m + race_hisp_12m + factor(edu_12m),
                  data = dm, method = "nearest", link = "logit",
                  distance = "glm", estimand = "ATT")
summary(m_out1)

# (c) balance diagnostics
# (c.1) Love plot: standardized mean differences, before vs after matching.
#  stars = "std" labels which differences are standardized vs raw - this silences
#  cobalt's (innocuous) mixed continuous/binary warning.
love.plot(m_out1, stats = "mean.diffs", threshold = 0.1, abs = TRUE,
          var.order = "unadjusted", stars = "std",
          title = "Covariate Balance Before/After NN Matching (Medicaid)")
# How to read it: each covariate has two dots. The "Unadjusted" dots (raw data)
# sit out to the right; after matching the "Adjusted" dots collapse inside the
# 0.10 rule-of-thumb band. So on observables the matched sample is now well
# balanced.

# (c.2) Jitter plot: where matched/unmatched units sit on the PS support.
plot(m_out1, type = "jitter", interactive = FALSE)
# How to read it: matched treated and matched control units cover the same range
# of propensity scores (good common support). The unmatched controls are the
# ones with no nearby treated unit, so they are dropped.

# (c.3) Density plot: the actual covariate distributions.
# It makes balance tangible. Instead of one number per covariate, we see the
# whole treated vs control distribution line up after matching.
plot(m_out1, type = "density", interactive = FALSE,
     which.xs = ~ age12 + female_list + race_white_12m)
# How to read it: before matching the treated (solid) and control (dashed)
# curves can sit apart (imbalance). After matching they overlap almost on top of
# each other. Same message as the Love plot, but on the full distribution rather
# than just the mean.

# (d) ATT after matching
m.data <- match_data(m_out1)
att_h <- lm(good_health      ~ insured, data = m.data, weights = weights)
att_d <- lm(cost_any_owe_12m ~ insured, data = m.data, weights = weights)
print(clx(att_h, m.data$household_id)["insured", , drop = FALSE])
print(clx(att_d, m.data$household_id)["insured", , drop = FALSE])
# Reading: after all that balancing work, the matched estimate is essentially
# the same as the naive OLS - still ~0 for good_health. This is the key lesson:
# matching fixes the observables (we just saw the Love/density plots prove it),
# but enrollment is selected on unobservables (health, motivation, expected
# need) that no observational method can see. Good balance on X is not the same
# as identification.

## ---- (3) ITT (effect of the offer) ---------------------------------
# Now the clean estimate. We compare lottery winners vs losers, assignment was
# random. The factor(wave_survey12m) FE only sharpen precision, but the
# factor(numhh_list) FE are required for identification: the lottery gave larger
# households a higher win probability, so randomization holds only CONDITIONAL on
# household size. The estimand here is the effect of the offer of coverage, not of
# enrollment.

# Model:  outcome = b0 + b1*treatment + (wave x hh-size FE) + u
# factor(wave_survey12m)*factor(numhh_list) = survey-wave x household-size FE
#   weights = weight_12m (survey design / non-response weights).
itt_h <- lm(good_health      ~ treatment + factor(wave_survey12m)*factor(numhh_list),
            data = da, weights = weight_12m)
itt_d <- lm(cost_any_owe_12m ~ treatment + factor(wave_survey12m)*factor(numhh_list),
            data = da, weights = weight_12m)
print(clx(itt_h, da$household_id)["treatment", , drop = FALSE])
print(clx(itt_d, da$household_id)["treatment", , drop = FALSE])

## ---- (4) LATE / 2SLS   ---------------
# Source: Imbens & Angrist (1994), Econometrica 62(2) [LATE]; Angrist & Pischke
#         (2009), "Mostly Harmless Econometrics", ch.4; ivreg() from the AER
#         package (Kleiber & Zeileis 2008). 
# The lottery (treatment) instruments actual enrollment (insured). For a single
# instrument the 2SLS estimate equals the ITT divided by the first stage, i.e.
# the effect of enrollment for the compliers (those who enrol because they won).
if (requireNamespace("AER", quietly = TRUE)) {
  library(AER)
  late_h <- ivreg(good_health ~ insured + factor(wave_survey12m)*factor(numhh_list) |
                    treatment + factor(wave_survey12m)*factor(numhh_list),
                  data = da, weights = weight_12m)
  print(clx(late_h, da$household_id)["insured", , drop = FALSE])
}
# Reading: observational methods (OLS/Matching) understate the effect on
# self-reported health and understate the effect on debt; the clean experimental
# estimates are larger. Two faces of the same lesson: observational
# identification is unreliable here.

# ---- Figure: observational vs experimental ---------
# Everything above, on one axis. For the two headline outcomes we line up the
# estimators that all target the same estimand,the effect of enrollment, and
# let the reader see the selection bias directly.
# Important: we deliberately do not put the ITT on this axis. The ITT is the
# effect of the offer (a different estimand).
# LATE was only estimated for good_health above, so it appears only in 
# that panel.
mk <- function(out, meth, model, clus) {
  ct <- clx(model, clus)["insured", ]
  data.frame(Outcome = out, Method = meth,
             est = ct["Estimate"], se = ct["Std. Error"], row.names = NULL)
}
cmp <- rbind(
  mk("Good health",      "OLS (obs.)",      ols_h, da$household_id),
  mk("Good health",      "Matching (obs.)", att_h, m.data$household_id),
  mk("Owe medical debt", "OLS (obs.)",      ols_d, da$household_id),
  mk("Owe medical debt", "Matching (obs.)", att_d, m.data$household_id))
if (exists("late_h")) {
  cmp <- rbind(cmp, mk("Good health", "LATE = 2SLS (exp.)", late_h, da$household_id))
}
cmp$ci_l <- cmp$est - 1.96 * cmp$se
cmp$ci_h <- cmp$est + 1.96 * cmp$se
cmp$Method <- factor(cmp$Method,
                     levels = c("OLS (obs.)", "Matching (obs.)", "LATE = 2SLS (exp.)"))
ggplot(cmp, aes(x = est, y = Method, colour = Method)) +
  geom_vline(xintercept = 0) +
  geom_pointrange(aes(xmin = ci_l, xmax = ci_h), show.legend = FALSE) +
  facet_wrap(~ Outcome, scales = "free_x", ncol = 1) +
  labs(title = "Effect of Medicaid ENROLLMENT: observational vs experimental",
       subtitle = "OLS & Matching (blind to unobservables) vs LATE (lottery-identified). ITT omitted on purpose: different estimand.",
       x = "Effect on the outcome (95% CI)", y = NULL) +
  theme_minimal()
# How to read it: focus on the good_health panel, where all three estimators are
# present. OLS and Matching agree with each other (both ~0) but sit faar from the
# experimental LATE (~+0.13), and the gap is much wider than the confidence
# intervals. So it is selection bias, not noise. In the debt panel we only have
# the two observational estimates (no late was run for debt). They agree with
# each other, which is reassuring but says nothing about unobserved selection.
# Bottom line: adjusting for observables does not recover the
# experimental answer, because enrollment is selected on unobservables.

################################################################################
# III - MAIN RESULT: ITT across the three outcome domains
################################################################################
# We estimate the ITT for every outcome in three QJE families and summarise each
# family with one standardized index (so that many outcomes do not inflate the
# number of tests). Each ITT is a single lm() with clustered SE, as above.

fam <- list(
  "Health care use"  = c("rx_num_mod_12m","doc_num_mod_12m","er_num_mod_12m","hosp_num_mod_12m"),
  "Financial strain" = c("cost_any_oop_12m","cost_any_owe_12m","cost_borrow_12m","cost_refused_12m"),
  "Health"           = c("good_health","health_notpoor","health_improved",
                         "notbaddays_tot","notbaddays_phys","notbaddays_ment","nodep_screen"))

# --- ITT per outcome ---------------------------------------------------------
itt_one <- function(y) {
  m  <- lm(as.formula(paste(y, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
           data = da, weights = weight_12m)
  ct <- clx(m, da$household_id)["treatment", ]
  cm <- weighted.mean(da[[y]][da$treatment == 0], da$weight_12m[da$treatment == 0], na.rm = TRUE)
  data.frame(outcome = y, control_mean = cm,
             est = ct["Estimate"], se = ct["Std. Error"], p = ct["Pr(>|t|)"])
}
res <- data.frame()
for (k in names(fam)) {
  block <- do.call(rbind, lapply(fam[[k]], itt_one))
  block$domain <- k
  res <- rbind(res, block)
}
res$ci_l <- res$est - 1.96 * res$se
res$ci_h <- res$est + 1.96 * res$se
cat("\n--- ITT by outcome (control mean, estimate, SE, p) ---\n")
print(round(res[, c("est","se","p","control_mean")], 4))

# --- Standardized treatment-effect index per domain --------------------------
# index = mean of the z-scored components, standardized on the control group.
# This is the QJE multiple-testing summary (Kling, Liebman & Katz 2007, ECMA):
# one test per domain instead of many. (Standardizing/weighted moments are
# base-R. The index construction itself follows the QJE code.)
make_index <- function(vars, data) {
  ctrl <- subset(data, treatment == 0)
  Z <- sapply(vars, function(v) {
    mu  <- weighted.mean(ctrl[[v]], ctrl$weight_12m, na.rm = TRUE)
    sdv <- sqrt(weighted.mean((ctrl[[v]] - mu)^2, ctrl$weight_12m, na.rm = TRUE))
    (data[[v]] - mu) / sdv
  })
  rowMeans(Z, na.rm = TRUE)
}
da$idx_use    <- make_index(fam[["Health care use"]],  da)
da$idx_fin    <- make_index(fam[["Financial strain"]], da)
da$idx_health <- make_index(fam[["Health"]],           da)
# Orientation:
# the health items are oriented in the data-prep script (prep_data_oregon.R) so that
# "higher = better". The financial-strain items were deliberately not flipped.
# They keep their natural direction, so higher = more strain (more out-of-pocket,
# more debt, more borrowing, refused care). Therefore a negative ITT on idx_fin is
# a good outcome: the offer reduces financial strain. Do not misread the minus sign as "harm".

idx_tab <- data.frame()
for (ix in c("idx_use","idx_fin","idx_health")) {
  m  <- lm(as.formula(paste(ix, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
           data = da, weights = weight_12m)
  ct <- clx(m, da$household_id)["treatment", ]
  idx_tab <- rbind(idx_tab, data.frame(index = ix,
                   est = ct["Estimate"], se = ct["Std. Error"], p = ct["Pr(>|t|)"]))
}
idx_tab$ci_l <- idx_tab$est - 1.96 * idx_tab$se
idx_tab$ci_h <- idx_tab$est + 1.96 * idx_tab$se
print(round(idx_tab[, c("est","se","p")], 4))

# Figure: domain-index effects with 95% CI (comparable across domains).
idx_tab$label <- c("Health care use","Financial strain","Health")
ggplot(idx_tab, aes(x = est, y = label)) +
  geom_vline(xintercept = 0) +
  geom_pointrange(aes(xmin = ci_l, xmax = ci_h)) +
  labs(title = "ITT on standardized domain indices",
       subtitle = "Effect in control-group SD units (95% CI)",
       x = "ITT (SD units)", y = NULL) +
  theme_minimal()
# How to read it: each dot is the ITT on one domain index, the bar is its 95% CI,
# the vertical line is the zero (no-effect) reference. Units are control-group
# SDs, so the three effects are directly comparable in size.
#   - Health care use  -> dot & CI to the RIGHT of 0  => the offer raises use
#   - Health           -> dot & CI to the RIGHT of 0  => self-reported health up
#   - Financial strain -> dot & CI to the LEFT of 0   => less strain 
# A CI that does not cross the zero line is what "significant at 5%" looks like.

# Figure: per-component ITT, faceted by domain 
res$domain <- factor(res$domain, levels = names(fam))
ggplot(res, aes(x = est, y = outcome)) +
  geom_vline(xintercept = 0) +
  geom_pointrange(aes(xmin = ci_l, xmax = ci_h)) +
  facet_wrap(~ domain, scales = "free", ncol = 1) +
  labs(title = "Intention-to-treat effects by outcome and domain",
       x = "ITT (native units, 95% CI)", y = NULL) +
  theme_minimal()
# How to read it: same coefficient-plot logic, now one row per raw outcome,
# faceted by domain (native units, free x-scales so each domain is legible).
# Reading: care use is up, driven by doctor visits and prescriptions; financial
# strain is down across the board (the most robust result); health is up,but
# the health gain is concentrated in mental health and self-reported measures.
# Be honest about the limit here: the OHIE in-person exam found no significant
# change in objective physical biomarkers (blood pressure, cholesterol, HbA1c)
# (Baicker et al. 2013, NEJM 368:1713-1722). So "health improved" means mainly
# perceived and mental health, not measured physical disease.

################################################################################
# IV - HETEROGENEITY BY AGE  (CATE)
################################################################################
# Is the effect stronger for some groups, e.g. the older (50-64), who have more
# chronic conditions? We compare the ITT in two subgroups and test the
# difference formally with an interaction term treatment x older.

cate_one <- function(ix) {
  # subgroup ITTs
  m_y <- lm(as.formula(paste(ix, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
            data = subset(da, younger == 1), weights = weight_12m)
  m_o <- lm(as.formula(paste(ix, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
            data = subset(da, older == 1),   weights = weight_12m)
  cy <- clx(m_y, subset(da, younger == 1)$household_id)["treatment", ]
  co <- clx(m_o, subset(da, older   == 1)$household_id)["treatment", ]
  # formal heterogeneity test: coefficient on treatment:older
  m_i <- lm(as.formula(paste(ix, "~ treatment*older + factor(wave_survey12m)*factor(numhh_list)")),
            data = da, weights = weight_12m)
  ci <- clx(m_i, da$household_id)["treatment:older", ]
  data.frame(index = ix,
             itt_young = cy["Estimate"], itt_old = co["Estimate"],
             diff = ci["Estimate"], se_diff = ci["Std. Error"], p_het = ci["Pr(>|t|)"])
}
cate <- do.call(rbind, lapply(c("idx_use","idx_fin","idx_health"), cate_one))
print(round(cate[, c("itt_young","itt_old","diff","p_het")], 4))

# Figure: subgroup ITT by age (dodged point-ranges).
cate$label <- c("Health care use","Financial strain","Health")
# helper: clustered SE of the subgroup ITT, recomputed for the error bars
get_se <- function(ix, keep) {
  sub <- subset(da, keep)
  m <- lm(as.formula(paste(ix, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
          data = sub, weights = weight_12m)
  clx(m, sub$household_id)["treatment", "Std. Error"]
}
indices <- c("idx_use","idx_fin","idx_health")
plot_df <- rbind(
  data.frame(label = cate$label, Group = "Younger (19-49)", est = cate$itt_young,
             se = sapply(indices, function(ix) get_se(ix, da$younger == 1))),
  data.frame(label = cate$label, Group = "Older (50-64)",   est = cate$itt_old,
             se = sapply(indices, function(ix) get_se(ix, da$older   == 1))))
plot_df$ci_l <- plot_df$est - 1.96 * plot_df$se
plot_df$ci_h <- plot_df$est + 1.96 * plot_df$se
ggplot(plot_df, aes(x = est, y = label, colour = Group, shape = Group)) +
  geom_vline(xintercept = 0) +
  geom_pointrange(aes(xmin = ci_l, xmax = ci_h),
                  position = position_dodge(width = 0.5)) +
  labs(title = "Heterogeneous ITT by age",
       subtitle = "Standardized indices, control SD units (95% CI)",
       x = "ITT (SD units)", y = NULL) +
  theme_minimal()
# Reading: point estimates suggest larger effects for the older;
# financial protection is essentially age-invariant.
# Caution: subgroups split the sample -> low power -> a non-significant
# interaction is not proof of "no heterogeneity". 

################################################################################
# V - RANDOMIZATION INFERENCE  (robustness of the inference)
################################################################################
# Instead of relying only on the (asymptotic) clustered SE, we rebuild the null
# distribution from the design itself. We re-run the lottery thousands of times
# on placebo, preserving how it was randomized (at the household level, within
# household-size strata), and see how often a placebo effect is as large as ours.
# This is finite-sample valid inference.
# It is out robustness check, built on the Fisher randomization-test logic 
# in Imbens & Rubin (2015), ch.5.
# Note this is not the same as what the QJE does for multiple
# testing: that paper uses the Westfall-Young free step-down correction, which
# serves a different purpose (controlling family-wise error across many
# outcomes). 

ri_pvalue <- function(ix, data, n_perm = 2000, seed = 42) {
  set.seed(seed)
  d   <- data[!is.na(data[[ix]]), ]
  # observed ITT (point estimate from the same weighted lm)
  obs <- coef(lm(as.formula(paste(ix, "~ treatment + factor(wave_survey12m)*factor(numhh_list)")),
                 data = d, weights = weight_12m))["treatment"]
  # household-level table with empirical treatment probability within hh-size
  hh  <- aggregate(treatment ~ household_id + numhh_list, data = d, FUN = function(x) x[1])
  pr  <- tapply(hh$treatment, hh$numhh_list, mean)         # P(treat) per stratum
  hh$p     <- pr[as.character(hh$numhh_list)]
  row_hh   <- match(d$household_id, hh$household_id)        # map each row -> its household
  count <- 0
  for (i in seq_len(n_perm)) {
    sim_hh   <- as.numeric(runif(nrow(hh)) <= hh$p)         # placebo treatment per household
    d$sim    <- sim_hh[row_hh]                              # propagate to all members
    b <- coef(lm(as.formula(paste(ix, "~ sim + factor(wave_survey12m)*factor(numhh_list)")),
                 data = d, weights = weight_12m))["sim"]
    if (!is.na(b) && abs(b) >= abs(obs)) count <- count + 1
  }
  c(observed = unname(obs), ri_p = (1 + count) / (1 + n_perm))
}
for (ix in c("idx_use","idx_fin","idx_health")) {
  out <- ri_pvalue(ix, da)
  cat(sprintf("%-11s observed ITT = %+.4f   RI p-value = %.4f\n", ix, out["observed"], out["ri_p"]))
}
# Note: this loop refits the model 2000x per index.
# Reading: the observed effects are more extreme than essentially all placebos
# (p ~ 0.0005), confirming the clustered-SE conclusions without leaning on the
# normal approximation.

################################################################################
# VI - BRIDGE TO PART I: MORTALITY 
################################################################################
# Part I studied insurance -> mortality on state-level cross-sectional OLS and
# could not credibly identify an effect (OVB, reverse causality, selection on
# unobservables). Here we estimate the same outcome under randomization.
# Mortality (postn_death = died after lottery notification) is administrative and
# observed for everyone, so we use the full lottery sample with draw + household-
# size FE and clustered SE - NOT the weighted survey sample. This is lm + clustered
# SE only: no method beyond what is already used above (no biomarkers, no Lee bounds).
dt$alive <- 1 - dt$postn_death           # 1 = alive at the end of the study window
mort <- lm(alive ~ treatment + factor(draw_lottery) + factor(numhh_list), data = dt)
print(clx(mort, dt$household_id)["treatment", , drop = FALSE])
# Reading: ITT on survival = +0.0003 (clustered SE 0.0007, p = 0.64),a precise
# null, not evidence of "no effect". Control-arm mortality is only ~0.85%, so the
# study is underpowered for a rare event over a ~16-month horizon. The 95% CI on
# survival [-0.0010, +0.0017], re-expressed against control mortality, spans
# roughly a 19% mortality reduction to a 12% increase: it cannot rule out a
# clinically meaningful mortality benefit. This mirrors Finkelstein et al. (2012),
# who likewise could not detect a mortality effect, and it is the cleanest bridge
# to Part I: the exact outcome that cross-sectional OLS could not pin down, now
# estimated from a randomized experiment.

################################################################################
# CONCLUSION
################################################################################
# The core forms one arc:
#   (I)   the lottery is a valid experiment  -> first stage, balance, non-response
#   (II)  observational methods fail         -> OLS/Matching vs LATE 
#   (III) the causal effects                 -> ITT + standardized domain indices
#   (IV)  for whom                           -> CATE by age 
#   (V)   how sure we are                    -> randomization inference
#   (VI)  shared-outcome bridge              -> mortality ITT 
#
# Faithful replication of the survey core of Finkelstein et al. (2012, QJE), plus
# our own selection-bias demonstration (OLS/Matching vs LATE) as the conceptual
# and empirical bridge to Part I.
################################################################################
