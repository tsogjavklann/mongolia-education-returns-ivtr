# =============================================================================
# 06_panel_fe_re.R — Panel Fixed Effects / Random Effects + Hausman test
# =============================================================================

library(data.table)
library(plm)
library(fixest)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"

# --- Load pseudo-panel -------------------------------------------------------
panel <- fread(file.path(BASE, "clean", "pseudopanel.csv"))
cat(sprintf("Pseudo-panel loaded: %d cells\n", nrow(panel)))

# --- Prepare plm pdata.frame -------------------------------------------------
pdt <- pdata.frame(as.data.frame(panel),
                   index = c("panel_id", "wave"),
                   drop.index = FALSE)

cat(sprintf("Panel structure: %d units, %d periods\n",
            length(unique(pdt$panel_id)), length(unique(pdt$wave))))

# =============================================================================
# 1. POOLED OLS (on cell means)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  1. POOLED OLS (pseudo-panel)\n")
cat(strrep("=", 60), "\n")

pooled <- plm(log_wage ~ educ_years + experience + experience_sq +
                pct_female + pct_urban + pct_married + mean_hhsize,
              data = pdt, model = "pooling",
              weights = cell_n)
cat(sprintf("  β_educ (Pooled) = %.4f (SE %.4f)\n",
            coef(pooled)["educ_years"],
            sqrt(vcov(pooled)["educ_years", "educ_years"])))

# =============================================================================
# 2. FIXED EFFECTS (within estimator)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  2. FIXED EFFECTS\n")
cat(strrep("=", 60), "\n")

fe_model <- plm(log_wage ~ educ_years + experience + experience_sq +
                  pct_female + pct_urban + pct_married + mean_hhsize,
                data = pdt, model = "within",
                weights = cell_n)
cat(sprintf("  β_educ (FE) = %.4f (SE %.4f)\n",
            coef(fe_model)["educ_years"],
            sqrt(vcov(fe_model)["educ_years", "educ_years"])))

# =============================================================================
# 3. RANDOM EFFECTS (GLS)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  3. RANDOM EFFECTS\n")
cat(strrep("=", 60), "\n")

re_model <- plm(log_wage ~ educ_years + experience + experience_sq +
                  pct_female + pct_urban + pct_married + mean_hhsize,
                data = pdt, model = "random",
                weights = cell_n)
cat(sprintf("  β_educ (RE) = %.4f (SE %.4f)\n",
            coef(re_model)["educ_years"],
            sqrt(vcov(re_model)["educ_years", "educ_years"])))

# =============================================================================
# 4. HAUSMAN TEST (FE vs RE)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  4. HAUSMAN TEST\n")
cat(strrep("=", 60), "\n")

haus <- phtest(fe_model, re_model)
cat(sprintf("  Hausman chi2 = %.2f\n", haus$statistic))
cat(sprintf("  p-value = %.4f\n", haus$p.value))
if (haus$p.value < 0.05) {
  cat("  RESULT: Reject H0 => FIXED EFFECTS preferred\n")
} else {
  cat("  RESULT: Cannot reject H0 => RANDOM EFFECTS efficient\n")
}

# =============================================================================
# 5. COMPARISON TABLE
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  5. COMPARISON TABLE\n")
cat(strrep("=", 60), "\n")

cat(sprintf("\n  %-20s %10s %10s %10s\n", "", "Pooled", "FE", "RE"))
cat(sprintf("  %-20s %10.4f %10.4f %10.4f\n", "β_educ",
            coef(pooled)["educ_years"],
            coef(fe_model)["educ_years"],
            coef(re_model)["educ_years"]))
cat(sprintf("  %-20s %10.4f %10.4f %10.4f\n", "SE",
            sqrt(vcov(pooled)["educ_years","educ_years"]),
            sqrt(vcov(fe_model)["educ_years","educ_years"]),
            sqrt(vcov(re_model)["educ_years","educ_years"])))
cat(sprintf("  %-20s %10d %10d %10d\n", "N (cells)",
            nobs(pooled), nobs(fe_model), nobs(re_model)))

# =============================================================================
# 6. FIXEST FE (for comparison — two-way FE with cluster SE)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  6. TWO-WAY FE (fixest, cluster SE)\n")
cat(strrep("=", 60), "\n")

# Individual-level two-way FE (on raw data, not pseudo-panel)
ind_dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
ind_dt[, marital_f := factor(marital)]
ind_dt[, cohort_aimag := paste(
  cut(birth_year, breaks = seq(1960, 2005, by = 5), right = FALSE),
  newaimag, sep = "_")]

twfe <- feols(log_wage ~ educ_years + experience + experience_sq +
                sex + i(marital_f) + urban + hhsize |
                cohort_aimag + wave,
              data = ind_dt, weights = ~hhweight,
              cluster = ~newaimag)

cat(sprintf("  β_educ (TWFE) = %.4f (SE %.4f)\n",
            coef(twfe)["educ_years"], se(twfe)["educ_years"]))
cat(sprintf("  N = %d\n", nobs(twfe)))

# =============================================================================
# FINAL SUMMARY
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  ALL RESULTS SUMMARY\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  Pooled OLS (cell):  β = %.4f\n", coef(pooled)["educ_years"]))
cat(sprintf("  Panel FE (cell):    β = %.4f\n", coef(fe_model)["educ_years"]))
cat(sprintf("  Panel RE (cell):    β = %.4f\n", coef(re_model)["educ_years"]))
cat(sprintf("  TWFE (individual):  β = %.4f\n", coef(twfe)["educ_years"]))
cat(sprintf("  Hausman p-value:    %.4f => %s preferred\n",
            haus$p.value, ifelse(haus$p.value < 0.05, "FE", "RE")))

cat("\n=== DONE: 06_panel_fe_re.R ===\n")
