# =============================================================================
# 04_ols_iv.R — OLS Mincer baseline + 2SLS IV
# SEZIS Econometrics VIII Olympiad — Returns to Education (IV-Threshold)
# =============================================================================

library(data.table)
library(fixest)

# --- Load analysis sample ----------------------------------------------------
BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("Loaded: %s rows\n", nrow(dt)))

# =============================================================================
# 1. OLS MINCER BASELINE — ALL WAVES
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  1. OLS MINCER BASELINE\n")
cat(strrep("=", 60), "\n")

# (a) Simple Mincer: log_wage ~ educ_years + experience + experience_sq
ols_simple <- feols(log_wage ~ educ_years + experience + experience_sq,
                    data = dt, weights = ~hhweight)

# (b) With controls: + sex + marital + urban + hhsize
ols_controls <- feols(log_wage ~ educ_years + experience + experience_sq +
                        sex + marital + urban + hhsize,
                      data = dt, weights = ~hhweight)

# (c) With aimag + wave FE
ols_fe <- feols(log_wage ~ educ_years + experience + experience_sq +
                  sex + marital + urban + hhsize |
                  newaimag + wave,
                data = dt, weights = ~hhweight,
                cluster = ~newaimag)

cat("\n=== OLS Results ===\n")
etable(ols_simple, ols_controls, ols_fe,
       headers = c("Simple", "Controls", "Aimag+Wave FE"),
       keep = c("educ_years", "experience", "experience_sq"),
       se.below = TRUE)

cat(sprintf("\n*** β_educ (FE model) = %.4f => %.1f%% return per year ***\n",
            coef(ols_fe)["educ_years"],
            100 * (exp(coef(ols_fe)["educ_years"]) - 1)))

# Sanity check
beta_educ <- coef(ols_fe)["educ_years"]
if (beta_educ < 0.03 || beta_educ > 0.20) {
  cat("\n!!! WARNING: β_educ outside expected range [0.03, 0.20] — check data !!!\n")
} else {
  cat("SANITY CHECK PASSED: β_educ in expected range [0.03, 0.20]\n")
}

# =============================================================================
# 2. OLS BY WAVE — STABILITY CHECK
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  2. OLS BY WAVE\n")
cat(strrep("=", 60), "\n")

for (w in sort(unique(dt$wave))) {
  m <- feols(log_wage ~ educ_years + experience + experience_sq +
               sex + marital + urban + hhsize | newaimag,
             data = dt[wave == w], weights = ~hhweight,
             cluster = ~newaimag)
  cat(sprintf("  Wave %d: β_educ = %.4f (SE %.4f), N = %d\n",
              w, coef(m)["educ_years"], se(m)["educ_years"], nobs(m)))
}

# =============================================================================
# 3. 2SLS IV — MAIN WAVES ONLY (2020, 2021, 2024 — birth_aimag available)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  3. 2SLS IV (Main waves: 2020+2021+2024)\n")
cat(strrep("=", 60), "\n")

main <- dt[wave >= 2020 & !is.na(birth_aimag)]
cat(sprintf("Main IV sample: %s individuals\n", nrow(main)))

# IV = birth_aimag (categorical — each aimag code is a separate instrument)
# This is the reduced form: being born in aimag X affects years of schooling
# First stage: educ_years ~ birth_aimag dummies + controls

# (a) First stage check
first_stage <- feols(educ_years ~ i(birth_aimag) + experience + experience_sq +
                       sex + marital + urban + hhsize | wave,
                     data = main, weights = ~hhweight,
                     cluster = ~newaimag)
cat("\n=== First Stage: educ_years ~ birth_aimag dummies ===\n")
cat(sprintf("  R² = %.4f\n", fitstat(first_stage, "r2")[[1]]))
cat(sprintf("  N  = %d\n", nobs(first_stage)))

# (b) 2SLS: instrument educ_years with birth_aimag
iv_birth <- feols(log_wage ~ experience + experience_sq +
                    sex + marital + urban + hhsize |
                    wave |
                    educ_years ~ i(birth_aimag),
                  data = main, weights = ~hhweight,
                  cluster = ~newaimag)

cat("\n=== 2SLS IV Results ===\n")
cat(sprintf("  β_educ (IV) = %.4f (SE %.4f)\n",
            coef(iv_birth)["fit_educ_years"], se(iv_birth)["fit_educ_years"]))

# First-stage F statistic
fs <- fitstat(iv_birth, "ivf")
fs_val <- fs$ivf1$stat
cat(sprintf("  First-stage F = %.2f\n", fs_val))
if (fs_val < 10) {
  cat("  !!! WEAK INSTRUMENT WARNING: F < 10 !!!\n")
} else {
  cat("  STRONG INSTRUMENT: F > 10\n")
}

# Compare OLS vs IV
ols_main <- feols(log_wage ~ educ_years + experience + experience_sq +
                    sex + marital + urban + hhsize | wave,
                  data = main, weights = ~hhweight,
                  cluster = ~newaimag)

cat("\n=== OLS vs IV Comparison (Main waves) ===\n")
etable(ols_main, iv_birth,
       headers = c("OLS", "2SLS IV"),
       keep = c("educ_years", "fit_educ_years"),
       se.below = TRUE)

cat(sprintf("\n  OLS β_educ = %.4f (%.1f%% return)\n",
            coef(ols_main)["educ_years"],
            100 * (exp(coef(ols_main)["educ_years"]) - 1)))
cat(sprintf("  IV  β_educ = %.4f (%.1f%% return)\n",
            coef(iv_birth)["fit_educ_years"],
            100 * (exp(coef(iv_birth)["fit_educ_years"]) - 1)))

# =============================================================================
# 4. IV WITH CURRENT AIMAG — ALL WAVES (robustness)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  4. 2SLS IV — Current aimag (all 5 waves, robustness)\n")
cat(strrep("=", 60), "\n")

iv_current <- feols(log_wage ~ experience + experience_sq +
                      sex + marital + urban + hhsize |
                      wave |
                      educ_years ~ i(newaimag),
                    data = dt, weights = ~hhweight,
                    cluster = ~newaimag)

cat(sprintf("  β_educ (IV, current aimag) = %.4f (SE %.4f)\n",
            coef(iv_current)["fit_educ_years"], se(iv_current)["fit_educ_years"]))
fs2 <- fitstat(iv_current, "ivf")
cat(sprintf("  First-stage F = %.2f\n", fs2$ivf1$stat))
cat(sprintf("  N = %d\n", nobs(iv_current)))

# =============================================================================
# 5. SAVE RESULTS
# =============================================================================
cat("\n=== DONE: 04_ols_iv.R ===\n")
