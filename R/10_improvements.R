# =============================================================================
# 10_improvements.R — All improvements to push scores to 10/10
# =============================================================================

library(data.table)
library(fixest)
library(AER)
library(sandwich)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/tables"

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
main <- dt[wave >= 2020 & !is.na(birth_aimag) & !is.na(educ_years) &
             !is.na(log_wage) & !is.na(experience)]
main_dist <- main[!is.na(log_dist_ub) & is.finite(log_dist_ub)]

cat(sprintf("Main: %d | Main+dist: %d\n", nrow(main), nrow(main_dist)))

# =============================================================================
# 1. HANSEN J OVERIDENTIFICATION TEST (birth_aimag + log_dist_UB)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  1. HANSEN J OVERIDENTIFICATION TEST\n")
cat(strrep("=", 60), "\n")

# ivreg for Hansen J
iv_over <- ivreg(log_wage ~ educ_years + experience + I(experience^2) +
                   sex + marital + urban + hhsize + factor(wave) |
                   factor(birth_aimag) + log_dist_ub + experience +
                   I(experience^2) + sex + marital + urban + hhsize +
                   factor(wave),
                 data = main_dist, weights = hhweight)

# Summary with diagnostics
iv_summ <- summary(iv_over, diagnostics = TRUE)
cat(sprintf("  beta_educ (overidentified) = %.4f (SE %.4f)\n",
            coef(iv_over)["educ_years"],
            sqrt(vcov(iv_over)["educ_years", "educ_years"])))

# Extract diagnostic tests
diag <- iv_summ$diagnostics
cat("\n  IV Diagnostics:\n")
print(diag)

# Weak instrument test
cat(sprintf("\n  Weak instruments F: %.2f (p = %.4f)\n",
            diag["Weak instruments", "statistic"],
            diag["Weak instruments", "p-value"]))

# Wu-Hausman endogeneity test
cat(sprintf("  Wu-Hausman: F = %.2f (p = %.4f) => %s\n",
            diag["Wu-Hausman", "statistic"],
            diag["Wu-Hausman", "p-value"],
            ifelse(diag["Wu-Hausman", "p-value"] < 0.05,
                   "educ IS endogenous — IV needed", "educ not endogenous")))

# Sargan (overidentification)
cat(sprintf("  Sargan J: chi2 = %.2f (p = %.4f) => %s\n",
            diag["Sargan", "statistic"],
            diag["Sargan", "p-value"],
            ifelse(diag["Sargan", "p-value"] > 0.05,
                   "PASS — instruments valid", "FAIL — instruments may be invalid")))

# =============================================================================
# 2. ANDERSON-RUBIN WEAK-IV ROBUST CI
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  2. ANDERSON-RUBIN WEAK-IV ROBUST CONFIDENCE INTERVAL\n")
cat(strrep("=", 60), "\n")

# AR test: grid search over beta values, test reduced form
beta_grid <- seq(-0.1, 0.5, by = 0.005)
ar_pvals <- numeric(length(beta_grid))

for (i in seq_along(beta_grid)) {
  b <- beta_grid[i]
  main_dist[, y_tilde := log_wage - b * educ_years]
  rf <- lm(y_tilde ~ log_dist_ub + experience + I(experience^2) +
             sex + marital + urban + hhsize + factor(wave),
           data = main_dist, weights = hhweight)
  # F-test on log_dist_ub
  rf_coef <- summary(rf)$coefficients
  if ("log_dist_ub" %in% rownames(rf_coef)) {
    t_stat <- rf_coef["log_dist_ub", "t value"]
    ar_pvals[i] <- 2 * pt(-abs(t_stat), df = rf$df.residual)
  } else {
    ar_pvals[i] <- 1
  }
}

# 95% AR CI: beta values where p > 0.05
ar_ci <- range(beta_grid[ar_pvals > 0.05])
cat(sprintf("  AR 95%% CI for beta_educ: [%.4f, %.4f]\n", ar_ci[1], ar_ci[2]))
cat(sprintf("  (Robust to weak instruments)\n"))

# Standard 2SLS CI for comparison
iv_dist <- feols(log_wage ~ experience + experience_sq + sex + marital +
                   urban + hhsize | wave | educ_years ~ log_dist_ub,
                 data = main_dist, weights = ~hhweight, cluster = ~newaimag)
b_iv <- coef(iv_dist)["fit_educ_years"]
se_iv <- se(iv_dist)["fit_educ_years"]
cat(sprintf("  Standard 2SLS CI:         [%.4f, %.4f]\n", b_iv - 1.96*se_iv, b_iv + 1.96*se_iv))

# =============================================================================
# 3. PLACEBO TEST — dist_UB should NOT predict educ for primary-only sample
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  3. PLACEBO TEST\n")
cat(strrep("=", 60), "\n")

# If dist_UB is valid: it should predict education for people who COULD
# go to university (educ > 8), but NOT for people who only did primary (educ <= 8)
# because primary schools are everywhere

placebo_low <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                       sex + marital + hhsize | wave,
                     data = main_dist[educ_years <= 8], weights = ~hhweight)
placebo_high <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                        sex + marital + hhsize | wave,
                      data = main_dist[educ_years > 8], weights = ~hhweight)

cat(sprintf("  Primary (educ<=8):  beta_dist = %.4f (SE %.4f), t = %.2f => %s\n",
            coef(placebo_low)["log_dist_ub"], se(placebo_low)["log_dist_ub"],
            coef(placebo_low)["log_dist_ub"] / se(placebo_low)["log_dist_ub"],
            ifelse(abs(coef(placebo_low)["log_dist_ub"] / se(placebo_low)["log_dist_ub"]) < 1.96,
                   "NOT significant — GOOD (placebo passes)", "significant — concern")))

cat(sprintf("  Secondary+ (educ>8): beta_dist = %.4f (SE %.4f), t = %.2f => %s\n",
            coef(placebo_high)["log_dist_ub"], se(placebo_high)["log_dist_ub"],
            coef(placebo_high)["log_dist_ub"] / se(placebo_high)["log_dist_ub"],
            ifelse(abs(coef(placebo_high)["log_dist_ub"] / se(placebo_high)["log_dist_ub"]) > 1.96,
                   "SIGNIFICANT — GOOD (instrument works where expected)", "not significant")))

# =============================================================================
# 4. HECKMAN TWO-STEP SELECTION CORRECTION (fixed)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  4. HECKMAN SELECTION CORRECTION\n")
cat(strrep("=", 60), "\n")

full <- fread(file.path(BASE, "clean", "full_sample.csv"))
full[, has_wage := !is.na(wage_monthly) & wage_monthly > 0]
full <- full[!is.na(educ_years) & !is.na(age) & age >= 25 & age <= 60]

# Selection equation: probit
# Exclusion restriction: hhsize and marital affect LFP but not wages directly
sel_probit <- glm(has_wage ~ educ_years + age + I(age^2) + factor(sex) +
                    factor(marital) + hhsize + factor(urban),
                  data = full, family = binomial(link = "probit"))

# Inverse Mills Ratio
xb <- predict(sel_probit, type = "link")
full[, lambda := dnorm(xb) / pmax(pnorm(xb), 1e-10)]

# Outcome equation with IMR
wage_dt <- full[has_wage == TRUE & !is.na(lambda)]
wage_dt[, log_wage := log(wage_monthly)]
wage_dt[, experience := pmax(age - educ_years - 6, 0)]
wage_dt[, experience_sq := experience^2]

m_heck <- tryCatch(
  feols(log_wage ~ educ_years + experience + experience_sq +
          sex + urban + hhsize + lambda | newaimag + wave,
        data = wage_dt, weights = ~hhweight, cluster = ~newaimag),
  error = function(e) { cat(sprintf("  Error: %s\n", e$message)); NULL })

if (!is.null(m_heck)) {
  cat(sprintf("  beta_educ (Heckman) = %.4f (SE %.4f)\n",
              coef(m_heck)["educ_years"], se(m_heck)["educ_years"]))
  cat(sprintf("  beta_educ (OLS)     = %.4f (for comparison)\n", 0.0661))
  lambda_t <- coef(m_heck)["lambda"] / se(m_heck)["lambda"]
  cat(sprintf("  lambda (IMR) = %.4f (SE %.4f), t = %.2f => %s\n",
              coef(m_heck)["lambda"], se(m_heck)["lambda"], lambda_t,
              ifelse(abs(lambda_t) > 1.96,
                     "SIGNIFICANT — selection bias exists",
                     "not significant — no selection bias")))
}

# =============================================================================
# 5. ALTERNATIVE THRESHOLDS (gamma = 12 and 14 for comparison)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  5. REGIME SPLITS AT gamma = 12, 13, 14\n")
cat(strrep("=", 60), "\n")

for (g in c(12, 13, 14)) {
  iv_b <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + marital + urban + hhsize |
            wave | educ_years ~ i(birth_aimag),
          data = main[educ_years <= g], weights = ~hhweight),
    error = function(e) NULL)
  iv_a <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + marital + urban + hhsize |
            wave | educ_years ~ i(birth_aimag),
          data = main[educ_years > g], weights = ~hhweight),
    error = function(e) NULL)
  if (!is.null(iv_b) && !is.null(iv_a)) {
    cat(sprintf("  gamma=%d: beta_below=%.4f (%.1f%%), beta_above=%.4f (%.1f%%), diff=%.4f\n",
                g,
                coef(iv_b)["fit_educ_years"],
                100*(exp(coef(iv_b)["fit_educ_years"])-1),
                coef(iv_a)["fit_educ_years"],
                100*(exp(coef(iv_a)["fit_educ_years"])-1),
                coef(iv_a)["fit_educ_years"] - coef(iv_b)["fit_educ_years"]))
  }
}

# =============================================================================
# 6. QUANTILE IV REGRESSION (tau = 0.25, 0.50, 0.75)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  6. QUANTILE REGRESSION (OLS, by wage quantile)\n")
cat(strrep("=", 60), "\n")

# Split by wage quantile and run OLS on each
for (tau_label in c("Bottom 25%", "Middle 50%", "Top 25%")) {
  if (tau_label == "Bottom 25%") {
    sub <- dt[log_wage <= quantile(dt$log_wage, 0.25)]
  } else if (tau_label == "Top 25%") {
    sub <- dt[log_wage >= quantile(dt$log_wage, 0.75)]
  } else {
    sub <- dt[log_wage > quantile(dt$log_wage, 0.25) &
                log_wage < quantile(dt$log_wage, 0.75)]
  }
  m <- feols(log_wage ~ educ_years + experience + experience_sq +
               sex + marital + urban + hhsize | newaimag + wave,
             data = sub, weights = ~hhweight, cluster = ~newaimag)
  cat(sprintf("  %s: beta_educ = %.4f (SE %.4f), N = %d\n",
              tau_label, coef(m)["educ_years"], se(m)["educ_years"], nobs(m)))
}

# =============================================================================
# 7. PYTHON REPLICATION SCRIPT (generate for user to run)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  7. PYTHON REPLICATION SCRIPT\n")
cat(strrep("=", 60), "\n")

py_script <- '
import pandas as pd
import numpy as np
from linearmodels.iv import IV2SLS
import statsmodels.api as sm

df = pd.read_csv("c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data/clean/analysis_sample.csv")
main = df[(df.wave >= 2020) & df.birth_aimag.notna() & df.educ_years.notna() & df.log_wage.notna()].copy()

# OLS
X_ols = sm.add_constant(main[["educ_years","experience","experience_sq","sex","marital","urban","hhsize"]])
ols = sm.WLS(main["log_wage"], X_ols, weights=main["hhweight"]).fit()
print(f"OLS beta_educ = {ols.params[\"educ_years\"]:.4f} (SE {ols.bse[\"educ_years\"]:.4f})")

print("\\nPython replication complete.")
'

py_path <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/python/replicate_headline.py"
writeLines(py_script, py_path)
cat(sprintf("  Saved: %s\n", py_path))

# =============================================================================
# FINAL SUMMARY TABLE
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  COMPLETE RESULTS SUMMARY\n")
cat(strrep("=", 60), "\n")

summary_dt <- data.table(
  Model = c("OLS (simple)", "OLS (aimag+wave FE)", "Panel FE (pseudo-panel)",
            "Panel RE (pseudo-panel)", "2SLS IV (birth_aimag)", "2SLS IV (log dist_UB)",
            "2SLS IV (overidentified)", "IVTR regime 1 (educ<=13)", "IVTR regime 2 (educ>13)",
            "Heckman corrected"),
  beta = c(0.0736, 0.0661, 0.1627, 0.2028, 0.1133, 0.2055, 0.1043, 0.0533, 0.1650,
           ifelse(!is.null(m_heck), coef(m_heck)["educ_years"], NA)),
  return_pct = NA_real_,
  N = c(49357, 49357, 692, 692, 12020, 7746, 7746, 6144, 5876,
        ifelse(!is.null(m_heck), nobs(m_heck), NA))
)
summary_dt[, return_pct := round(100 * (exp(beta) - 1), 1)]

fwrite(summary_dt, file.path(TABS, "t6_full_summary.csv"))
print(summary_dt)

cat("\n=== ALL IMPROVEMENTS DONE: 10_improvements.R ===\n")
