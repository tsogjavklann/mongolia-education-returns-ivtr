# =============================================================================
# 99_tests.R — Sanity checks and data validation
# =============================================================================

library(data.table)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))

pass <- 0L; fail <- 0L
check <- function(name, condition) {
  if (condition) {
    cat(sprintf("  PASS: %s\n", name)); pass <<- pass + 1L
  } else {
    cat(sprintf("  FAIL: %s\n", name)); fail <<- fail + 1L
  }
}

cat("=== DATA VALIDATION TESTS ===\n\n")

# 1. Row counts
check("Sample size > 40,000", nrow(dt) > 40000)
check("5 waves present", uniqueN(dt$wave) == 5)
check("Waves are 2016,2018,2020,2021,2024",
      all(sort(unique(dt$wave)) == c(2016, 2018, 2020, 2021, 2024)))

# 2. Key variables not all NA
check("educ_years not all NA", sum(!is.na(dt$educ_years)) > 40000)
check("log_wage not all NA", sum(!is.na(dt$log_wage)) > 40000)
check("age not all NA", sum(!is.na(dt$age)) > 40000)

# 3. Value ranges
check("age in [25, 60]", all(dt$age >= 25 & dt$age <= 60, na.rm = TRUE))
check("educ_years in [0, 22]", all(dt$educ_years >= 0 & dt$educ_years <= 22, na.rm = TRUE))
check("log_wage > 0", all(dt$log_wage > 0, na.rm = TRUE))

# 4. Education distribution
mean_educ <- mean(dt$educ_years, na.rm = TRUE)
check(sprintf("mean educ_years = %.1f in [8, 14]", mean_educ),
      mean_educ >= 8 & mean_educ <= 14)

# 5. Wage distribution
med_wage <- median(dt$wage_monthly, na.rm = TRUE)
check(sprintf("median wage = %.0f > 100,000 MNT", med_wage), med_wage > 100000)

# 6. Birth aimag in main waves
n_ba <- sum(!is.na(dt$birth_aimag) & dt$wave >= 2020)
check(sprintf("birth_aimag available for %d obs (>10,000)", n_ba), n_ba > 10000)

# 7. Weights
check("hhweight all positive", all(dt$hhweight > 0, na.rm = TRUE))

# 8. No duplicate IDs within wave
for (w in unique(dt$wave)) {
  n_dup <- sum(duplicated(dt[wave == w, .(identif, ind_id)]))
  check(sprintf("No duplicate (identif, ind_id) in wave %d", w), n_dup == 0)
}

# 9. OLS coefficient sanity
library(fixest)
m <- feols(log_wage ~ educ_years + experience + experience_sq | newaimag + wave,
           data = dt, weights = ~hhweight)
b <- coef(m)["educ_years"]
check(sprintf("OLS beta_educ = %.4f in [0.03, 0.20]", b), b >= 0.03 & b <= 0.20)

# 10. Output files exist
check("hses_pooled.csv exists", file.exists(file.path(BASE, "clean", "hses_pooled.csv")))
check("analysis_sample.csv exists", file.exists(file.path(BASE, "clean", "analysis_sample.csv")))
check("pseudopanel.csv exists", file.exists(file.path(BASE, "clean", "pseudopanel.csv")))
check("ivtr_grid_results.csv exists", file.exists(file.path(BASE, "clean", "ivtr_grid_results.csv")))

# 11. Figures exist
FIGS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/figures"
for (f in c("f1_education_distribution.png", "f2_wage_education_scatter.png",
            "f3_threshold_profile.png", "f4_regime_slopes.png", "f5_ols_vs_iv.png")) {
  check(sprintf("%s exists", f), file.exists(file.path(FIGS, f)))
}

cat(sprintf("\n=== RESULTS: %d PASSED, %d FAILED ===\n", pass, fail))
if (fail == 0) cat("ALL TESTS PASSED!\n")
