# =============================================================================
# 07_robustness.R — Robustness checks
# =============================================================================

library(data.table)
library(fixest)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
# marital is a 6-category factor (1-6). Force factor encoding in both datasets.
dt[, marital_f := factor(marital)]
MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)
URBAN_CODE <- 1L
RURAL_CODE <- 2L
main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage)]

cat(sprintf("Full sample: %d | Main IV sample: %d\n", nrow(dt), nrow(main)))

# =============================================================================
# 1. SUBSAMPLE SPLITS — OLS by gender, urban/rural
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  1. OLS SUBSAMPLE SPLITS\n")
cat(strrep("=", 60), "\n")

specs <- list(
  "All"        = dt,
  "Male"       = dt[sex == 1],
  "Female"     = dt[sex == 2],
  "Urban"      = dt[urban == URBAN_CODE],
  "Rural"      = dt[urban == RURAL_CODE],
  "Age 25-40"  = dt[age >= 25 & age <= 40],
  "Age 41-60"  = dt[age > 40 & age <= 60]
)

cat(sprintf("\n  %-15s %8s %8s %8s\n", "Subsample", "beta", "SE", "N"))
cat(strrep("-", 50), "\n")
for (nm in names(specs)) {
  m <- tryCatch(
    feols(log_wage ~ educ_years + experience + experience_sq +
            sex + i(marital_f) + urban + hhsize | newaimag + wave,
          data = specs[[nm]], weights = ~hhweight, cluster = ~newaimag),
    error = function(e) NULL)
  if (!is.null(m)) {
    cat(sprintf("  %-15s %8.4f %8.4f %8d\n", nm,
                coef(m)["educ_years"], se(m)["educ_years"], nobs(m)))
  }
}

# =============================================================================
# 2. IV SUBSAMPLE SPLITS (main waves only)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  2. IV SUBSAMPLE SPLITS (2020+2021+2024)\n")
cat(strrep("=", 60), "\n")

iv_specs <- list(
  "All (IV)"     = main,
  "Male (IV)"    = main[sex == 1],
  "Female (IV)"  = main[sex == 2],
  "Urban (IV)"   = main[urban == URBAN_CODE],
  "Rural (IV)"   = main[urban == RURAL_CODE]
)

cat(sprintf("\n  %-15s %8s %8s %8s %8s\n", "Subsample", "beta_IV", "SE", "F-stat", "N"))
cat(strrep("-", 60), "\n")
for (nm in names(iv_specs)) {
  m <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize | wave | educ_years ~ i(birth_aimag),
          data = iv_specs[[nm]], weights = ~hhweight, cluster = ~newaimag),
    error = function(e) NULL)
  if (!is.null(m)) {
    fs <- tryCatch(fitstat(m, "ivf")$ivf1$stat, error = function(e) NA)
    cat(sprintf("  %-15s %8.4f %8.4f %8.2f %8d\n", nm,
                coef(m)["fit_educ_years"], se(m)["fit_educ_years"],
                ifelse(is.na(fs), 0, fs), nobs(m)))
  }
}

# =============================================================================
# 3. ALTERNATIVE SPECIFICATIONS
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  3. ALTERNATIVE SPECIFICATIONS\n")
cat(strrep("=", 60), "\n")

# (a) Log hourly wage instead of monthly
dt[, log_wage_hourly2 := log(wage_monthly / pmax(hours_week * 4.33, 1))]
m_hourly <- feols(log_wage_hourly2 ~ educ_years + experience + experience_sq +
                    sex + i(marital_f) + urban + hhsize | newaimag + wave,
                  data = dt[!is.na(log_wage_hourly2) & is.finite(log_wage_hourly2)],
                  weights = ~hhweight, cluster = ~newaimag)
cat(sprintf("  Log hourly wage:   β = %.4f (SE %.4f), N = %d\n",
            coef(m_hourly)["educ_years"], se(m_hourly)["educ_years"], nobs(m_hourly)))

# (b) Without aimag FE
m_no_fe <- feols(log_wage ~ educ_years + experience + experience_sq +
                   sex + i(marital_f) + urban + hhsize | wave,
                 data = dt, weights = ~hhweight)
cat(sprintf("  No aimag FE:       β = %.4f (SE %.4f), N = %d\n",
            coef(m_no_fe)["educ_years"], se(m_no_fe)["educ_years"], nobs(m_no_fe)))

# (c) With sector controls (where available)
dt_sector <- dt[!is.na(sector) & sector != ""]
m_sector <- tryCatch(
  feols(log_wage ~ educ_years + experience + experience_sq +
          sex + i(marital_f) + urban + hhsize | newaimag + wave + sector,
        data = dt_sector, weights = ~hhweight, cluster = ~newaimag),
  error = function(e) NULL)
if (!is.null(m_sector)) {
  cat(sprintf("  With sector FE:    β = %.4f (SE %.4f), N = %d\n",
              coef(m_sector)["educ_years"], se(m_sector)["educ_years"], nobs(m_sector)))
}

# (d) Quadratic education (test for nonlinearity without threshold)
m_quad <- feols(log_wage ~ educ_years + I(educ_years^2) + experience +
                  experience_sq + sex + i(marital_f) + urban + hhsize | newaimag + wave,
                data = dt, weights = ~hhweight, cluster = ~newaimag)
quad_name <- grep("educ_years\\^2", names(coef(m_quad)), value = TRUE)
cat(sprintf("  Quadratic educ:    β₁ = %.4f, β₂ = %.6f\n",
            coef(m_quad)["educ_years"], coef(m_quad)[quad_name[1]]))

# =============================================================================
# 4. THRESHOLD AT ALTERNATIVE GAMMA VALUES
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  4. RETURNS BY EDUCATION LEVEL (split regressions)\n")
cat(strrep("=", 60), "\n")

thresholds <- c(8, 10, 12, 13, 14)
cat(sprintf("\n  %-12s %8s %8s %8s %8s\n", "Threshold", "β_below", "β_above", "diff", "N"))
cat(strrep("-", 55), "\n")
for (g in thresholds) {
  m_b <- tryCatch(
    feols(log_wage ~ educ_years + experience + experience_sq +
            sex + i(marital_f) + urban + hhsize | newaimag + wave,
          data = dt[educ_years <= g], weights = ~hhweight, cluster = ~newaimag),
    error = function(e) NULL)
  m_a <- tryCatch(
    feols(log_wage ~ educ_years + experience + experience_sq +
            sex + i(marital_f) + urban + hhsize | newaimag + wave,
          data = dt[educ_years > g], weights = ~hhweight, cluster = ~newaimag),
    error = function(e) NULL)
  if (!is.null(m_b) && !is.null(m_a)) {
    b_b <- coef(m_b)["educ_years"]
    b_a <- coef(m_a)["educ_years"]
    cat(sprintf("  educ %s %2d   %8.4f %8.4f %8.4f %8d\n",
                "<=/>", g, b_b, b_a, b_a - b_b, nobs(m_b) + nobs(m_a)))
  }
}

# =============================================================================
# 5. HECKMAN SELECTION (probit for LFP + OLS on selected)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  5. HECKMAN SELECTION CORRECTION (simplified)\n")
cat(strrep("=", 60), "\n")

full <- fread(file.path(BASE, "clean", "full_sample.csv"))
full[, has_wage := !is.na(wage_monthly) & wage_monthly > 0]
full[, marital_f := factor(marital)]

# Selection equation (probit): identification relies on exclusion of hhsize
# (household size plausibly affects labour force participation through caregiving
# burden, but should not directly affect the wage of those who work). marital
# could affect wages too (married premium), so we INCLUDE it both in selection
# and outcome equations — identification then rests on hhsize alone plus the
# nonlinearity of the probit link. We drop marital from the exclusion set.
sel <- glm(has_wage ~ educ_years + age + I(age^2) + sex + marital_f +
             hhsize + urban,
           data = full[!is.na(educ_years)], family = binomial(link = "probit"),
           weights = hhweight)

# Inverse Mills Ratio
full[!is.na(educ_years), lambda := dnorm(predict(sel)) / pnorm(predict(sel))]

# Outcome equation with lambda (hhsize excluded from outcome → identification)
wage_sel <- full[has_wage == TRUE & !is.na(lambda) & !is.na(log(wage_monthly))]
wage_sel[, log_wage := log(wage_monthly)]
wage_sel[, experience := pmax(age - educ_years - 6, 0)]
wage_sel[, experience_sq := experience^2]
m_heck <- tryCatch(
  feols(log_wage ~ educ_years + experience + experience_sq +
          sex + i(marital_f) + urban + lambda | newaimag + wave,
        data = wage_sel[!is.na(experience)], weights = ~hhweight, cluster = ~newaimag),
  error = function(e) NULL)

if (!is.null(m_heck)) {
  cat(sprintf("  β_educ (Heckman) = %.4f (SE %.4f)\n",
              coef(m_heck)["educ_years"], se(m_heck)["educ_years"]))
  cat(sprintf("  λ (IMR)          = %.4f (SE %.4f) %s\n",
              coef(m_heck)["lambda"], se(m_heck)["lambda"],
              ifelse(abs(coef(m_heck)["lambda"] / se(m_heck)["lambda"]) > 1.96,
                     "SIGNIFICANT => selection bias exists", "not significant")))
}

cat("\n=== DONE: 07_robustness.R ===\n")
