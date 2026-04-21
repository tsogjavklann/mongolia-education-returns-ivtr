# =============================================================================
# 05_ivtr_caner_hansen.R — Caner & Hansen (2004) IV-Threshold Regression
# HEADLINE MODEL: Returns to education with structural threshold
# =============================================================================
# Reference: Caner, M. & Hansen, B.E. (2004). "Instrumental Variable Estimation
#   of a Threshold Model." Econometric Theory, 20(5), 813-843.
#
# Algorithm:
# 1. First stage: educ = f(IV, X) -> educ_hat
# 2. Grid search gamma over threshold variable q (= educ_years)
# 3. At each gamma: split sample, run 2SLS on each regime
# 4. gamma* = argmin concentrated SSR
# 5. SupWald bootstrap test for threshold significance
# =============================================================================

library(data.table)
library(fixest)
library(AER)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"

# --- Load main analysis sample (2020+2021+2024 with birth_aimag) -------------
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
main <- dt[wave >= 2020 & !is.na(birth_aimag)]
main <- main[!is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]
cat(sprintf("IVTR sample: %d individuals\n", nrow(main)))

# =============================================================================
# STEP 1: Define variables
# =============================================================================
# Threshold variable q = educ_years
# Endogenous: educ_years
# Instrument: birth_aimag dummies
# Outcome: log_wage
# Controls: experience, experience_sq, sex, marital, urban, hhsize, wave FE

# Create wave dummies
main[, `:=`(w2021 = as.integer(wave == 2021),
            w2024 = as.integer(wave == 2024))]

# Birth aimag as factor for dummies
main[, birth_aimag_f := factor(birth_aimag)]

# =============================================================================
# STEP 2: First stage (reduced form)
# =============================================================================
cat("\n=== STEP 2: First Stage ===\n")
controls <- c("experience", "experience_sq", "sex", "marital", "urban",
              "hhsize", "w2021", "w2024")

# First stage formula
fs_formula <- as.formula(paste("educ_years ~ birth_aimag_f +",
                               paste(controls, collapse = " + ")))
fs_model <- lm(fs_formula, data = main, weights = hhweight)
main[, educ_hat := predict(fs_model)]
cat(sprintf("  First stage R² = %.4f\n", summary(fs_model)$r.squared))

# =============================================================================
# STEP 3: Grid search over gamma (threshold)
# =============================================================================
cat("\n=== STEP 3: Grid Search ===\n")

q <- main$educ_years
q_vals <- sort(unique(q))
# Trim 15% at each tail
q_lo <- quantile(q, 0.15, na.rm = TRUE)
q_hi <- quantile(q, 0.85, na.rm = TRUE)
gamma_grid <- q_vals[q_vals >= q_lo & q_vals <= q_hi]
cat(sprintf("  Grid: %d candidate thresholds in [%d, %d]\n",
            length(gamma_grid), min(gamma_grid), max(gamma_grid)))

# Function: compute 2SLS SSR for a given gamma
compute_ssr <- function(gamma, dat) {
  # Split indicator
  dat[, below := as.integer(educ_years <= gamma)]
  dat[, above := 1L - below]

  # Interacted endogenous and instruments
  dat[, educ_below := educ_years * below]
  dat[, educ_above := educ_years * above]
  dat[, educ_hat_below := educ_hat * below]
  dat[, educ_hat_above := educ_hat * above]

  # Second stage with fitted values (manual 2SLS)
  ss_formula <- as.formula(paste(
    "log_wage ~ educ_hat_below + educ_hat_above +",
    paste(controls, collapse = " + ")))

  ss_model <- tryCatch(
    lm(ss_formula, data = dat, weights = hhweight),
    error = function(e) NULL)

  if (is.null(ss_model)) return(Inf)

  # Compute proper 2SLS residuals (using actual educ, not fitted)
  # e = y - X*beta_2sls (where beta from 2nd stage but applied to actual endogenous)
  coefs <- coef(ss_model)
  y_hat <- coefs["(Intercept)"] +
    coefs["educ_hat_below"] * dat$educ_below +
    coefs["educ_hat_above"] * dat$educ_above
  for (ctrl in controls) {
    if (ctrl %in% names(coefs)) {
      y_hat <- y_hat + coefs[ctrl] * dat[[ctrl]]
    }
  }
  resid <- dat$log_wage - y_hat
  ssr <- sum(dat$hhweight * resid^2, na.rm = TRUE)
  return(ssr)
}

# Grid search
results <- data.table(gamma = gamma_grid, ssr = NA_real_)
for (i in seq_along(gamma_grid)) {
  results$ssr[i] <- compute_ssr(gamma_grid[i], copy(main))
}

# Optimal gamma
gamma_star <- results[which.min(ssr), gamma]
ssr_star <- results[which.min(ssr), ssr]
cat(sprintf("\n  *** OPTIMAL THRESHOLD: gamma* = %d years ***\n", gamma_star))
cat(sprintf("  SSR at gamma* = %.2f\n", ssr_star))

# =============================================================================
# STEP 4: Estimate regime-specific coefficients at gamma*
# =============================================================================
cat("\n=== STEP 4: Regime Estimates at gamma* ===\n")

main[, below := as.integer(educ_years <= gamma_star)]
main[, above := 1L - below]
main[, educ_below := educ_years * below]
main[, educ_above := educ_years * above]

n_below <- sum(main$below)
n_above <- sum(main$above)
cat(sprintf("  Regime 1 (educ <= %d): N = %d (%.1f%%)\n",
            gamma_star, n_below, 100 * n_below / nrow(main)))
cat(sprintf("  Regime 2 (educ > %d):  N = %d (%.1f%%)\n",
            gamma_star, n_above, 100 * n_above / nrow(main)))

# Proper 2SLS using ivreg at gamma*
iv_formula <- as.formula(paste(
  "log_wage ~ educ_below + educ_above +",
  paste(controls, collapse = " + "),
  "| birth_aimag_f * below + birth_aimag_f * above +",
  paste(controls, collapse = " + ")))

# Use fixest for cleaner IV
# Regime 1
iv_below <- tryCatch(
  feols(log_wage ~ experience + experience_sq + sex + marital + urban + hhsize |
          wave | educ_years ~ i(birth_aimag_f),
        data = main[below == 1], weights = ~hhweight),
  error = function(e) NULL)

# Regime 2
iv_above <- tryCatch(
  feols(log_wage ~ experience + experience_sq + sex + marital + urban + hhsize |
          wave | educ_years ~ i(birth_aimag_f),
        data = main[above == 1], weights = ~hhweight),
  error = function(e) NULL)

if (!is.null(iv_below)) {
  cat(sprintf("\n  β₁ (educ <= %d) = %.4f (SE %.4f) => %.1f%% per year\n",
              gamma_star,
              coef(iv_below)["fit_educ_years"],
              se(iv_below)["fit_educ_years"],
              100 * (exp(coef(iv_below)["fit_educ_years"]) - 1)))
}
if (!is.null(iv_above)) {
  cat(sprintf("  β₂ (educ > %d)  = %.4f (SE %.4f) => %.1f%% per year\n",
              gamma_star,
              coef(iv_above)["fit_educ_years"],
              se(iv_above)["fit_educ_years"],
              100 * (exp(coef(iv_above)["fit_educ_years"]) - 1)))
}

# =============================================================================
# STEP 5: SupWald Bootstrap Test for Threshold Significance
# =============================================================================
cat("\n=== STEP 5: SupWald Bootstrap Test ===\n")

# Null model (no threshold): CONSISTENT with compute_ssr — use educ_hat manual 2SLS
null_formula <- as.formula(paste("log_wage ~ educ_hat +", paste(controls, collapse = " + ")))
null_lm <- lm(null_formula, data = main, weights = hhweight)
# Proper 2SLS residuals: y - (alpha + beta_hat * educ_actual + X*gamma)
null_coefs <- coef(null_lm)
null_yhat <- null_coefs["(Intercept)"] + null_coefs["educ_hat"] * main$educ_years
for (ctrl in controls) {
  if (ctrl %in% names(null_coefs)) null_yhat <- null_yhat + null_coefs[ctrl] * main[[ctrl]]
}
null_resid_vec <- main$log_wage - null_yhat
ssr_null <- sum(main$hhweight * null_resid_vec^2, na.rm = TRUE)

# SupWald statistic
sup_wald <- nrow(main) * (ssr_null - ssr_star) / ssr_star
cat(sprintf("  SSR_null = %.2f, SSR_threshold = %.2f\n", ssr_null, ssr_star))
cat(sprintf("  SupWald statistic = %.2f\n", sup_wald))

# Wild bootstrap (Rademacher weights)
set.seed(2026)
n_boot <- 300  # 300 for speed
cat(sprintf("  Running %d bootstrap replications...\n", n_boot))

boot_supwald <- numeric(n_boot)
for (b in seq_len(n_boot)) {
  if (b %% 100 == 0) cat(sprintf("    bootstrap %d/%d\n", b, n_boot))

  # Rademacher weights
  rw <- sample(c(-1, 1), nrow(main), replace = TRUE)
  boot_y <- null_yhat + null_resid_vec * rw

  # Create boot dataset
  boot_dt <- copy(main)
  boot_dt[, log_wage := boot_y]

  # Null SSR under bootstrap (same method as ssr_null)
  boot_null_m <- lm(null_formula, data = boot_dt, weights = hhweight)
  boot_null_coefs <- coef(boot_null_m)
  boot_null_yhat <- boot_null_coefs["(Intercept)"] + boot_null_coefs["educ_hat"] * boot_dt$educ_years
  for (ctrl in controls) {
    if (ctrl %in% names(boot_null_coefs)) boot_null_yhat <- boot_null_yhat + boot_null_coefs[ctrl] * boot_dt[[ctrl]]
  }
  boot_null_ssr <- sum(boot_dt$hhweight * (boot_dt$log_wage - boot_null_yhat)^2, na.rm = TRUE)

  # Grid search for best threshold under bootstrap
  boot_ssr_min <- Inf
  for (g in gamma_grid) {
    boot_ssr_g <- compute_ssr(g, copy(boot_dt))
    if (boot_ssr_g < boot_ssr_min) boot_ssr_min <- boot_ssr_g
  }

  if (boot_ssr_min < Inf) {
    boot_supwald[b] <- nrow(main) * (boot_null_ssr - boot_ssr_min) / boot_ssr_min
  } else {
    boot_supwald[b] <- 0
  }
}

# p-value
p_value <- mean(boot_supwald >= sup_wald, na.rm = TRUE)
cat(sprintf("\n  *** THRESHOLD TEST ***\n"))
cat(sprintf("  SupWald = %.2f\n", sup_wald))
cat(sprintf("  Bootstrap p-value = %.4f\n", p_value))
if (p_value < 0.01) {
  cat("  RESULT: Threshold is HIGHLY SIGNIFICANT at 1%\n")
} else if (p_value < 0.05) {
  cat("  RESULT: Threshold is SIGNIFICANT at 5%\n")
} else if (p_value < 0.10) {
  cat("  RESULT: Threshold is MARGINALLY SIGNIFICANT at 10%\n")
} else {
  cat("  RESULT: Threshold is NOT significant (linear model preferred)\n")
}

# =============================================================================
# STEP 6: Save results
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  FINAL IVTR RESULTS\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  Threshold gamma* = %d years of schooling\n", gamma_star))
if (!is.null(iv_below))
  cat(sprintf("  β₁ (educ <= %d) = %.4f (%.1f%% per year)\n",
              gamma_star, coef(iv_below)["fit_educ_years"],
              100 * (exp(coef(iv_below)["fit_educ_years"]) - 1)))
if (!is.null(iv_above))
  cat(sprintf("  β₂ (educ > %d)  = %.4f (%.1f%% per year)\n",
              gamma_star, coef(iv_above)["fit_educ_years"],
              100 * (exp(coef(iv_above)["fit_educ_years"]) - 1)))
cat(sprintf("  SupWald = %.2f, p = %.4f\n", sup_wald, p_value))

# Save grid search results for plotting
fwrite(results, file.path(BASE, "clean", "ivtr_grid_results.csv"))

cat("\n=== DONE: 05_ivtr_caner_hansen.R ===\n")
