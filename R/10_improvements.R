# =============================================================================
# 10_improvements.R — Econometric diagnostics and final summary table
# =============================================================================

library(data.table)
library(fixest)
library(plm)
suppressPackageStartupMessages(library(AER))

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/tables"
IN_TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/inputs/tables"
dir.create(TABS, showWarnings = FALSE, recursive = TRUE)
dir.create(IN_TABS, showWarnings = FALSE, recursive = TRUE)

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]
main_dist <- main[!is.na(log_dist_ub) & is.finite(log_dist_ub)]

cat(sprintf("Main valid-birth IV sample: %d | distance-IV sample: %d\n",
            nrow(main), nrow(main_dist)))

# =============================================================================
# 1. IV DIAGNOSTICS
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  1. IV DIAGNOSTICS\n")
cat(strrep("=", 60), "\n")

iv_birth <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                    urban + hhsize |
                    wave |
                    educ_years ~ i(birth_aimag),
                  data = main, weights = ~hhweight, cluster = ~newaimag)

iv_birth_fe <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                       urban + hhsize |
                       wave + newaimag |
                       educ_years ~ i(birth_aimag),
                     data = main, weights = ~hhweight, cluster = ~newaimag)

iv_dist <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                   urban + hhsize |
                   wave |
                   educ_years ~ log_dist_ub,
                 data = main_dist, weights = ~hhweight, cluster = ~newaimag)

cat(sprintf("  Birth-aimag IV: beta = %.4f (SE %.4f), F/Wald = %.2f, N = %d\n",
            coef(iv_birth)["fit_educ_years"], se(iv_birth)["fit_educ_years"],
            fitstat(iv_birth, "ivf")$ivf1$stat, nobs(iv_birth)))
cat(sprintf("  Birth-aimag IV + current aimag FE: beta = %.4f (SE %.4f), F/Wald = %.2f, N = %d\n",
            coef(iv_birth_fe)["fit_educ_years"], se(iv_birth_fe)["fit_educ_years"],
            fitstat(iv_birth_fe, "ivf")$ivf1$stat, nobs(iv_birth_fe)))
cat(sprintf("  Distance IV alone: beta = %.4f (SE %.4f), F/Wald = %.2f, N = %d\n",
            coef(iv_dist)["fit_educ_years"], se(iv_dist)["fit_educ_years"],
            fitstat(iv_dist, "ivf")$ivf1$stat, nobs(iv_dist)))
cat("  Note: birth_aimag dummies and log_dist_ub are not combined because\n")
cat("  log_dist_ub is a deterministic function of birth_aimag after code cleanup.\n")

ivreg_birth <- ivreg(log_wage ~ educ_years + experience + experience_sq + sex +
                       marital_f + urban + hhsize + factor(wave) |
                       experience + experience_sq + sex + marital_f + urban +
                       hhsize + factor(wave) + factor(birth_aimag),
                     data = main, weights = hhweight)
ivreg_birth_fe <- ivreg(log_wage ~ educ_years + experience + experience_sq +
                          sex + marital_f + urban + hhsize + factor(wave) +
                          factor(newaimag) |
                          experience + experience_sq + sex + marital_f +
                          urban + hhsize + factor(wave) + factor(newaimag) +
                          factor(birth_aimag),
                        data = main, weights = hhweight)
diag_birth <- summary(ivreg_birth, diagnostics = TRUE)$diagnostics
diag_birth_fe <- summary(ivreg_birth_fe, diagnostics = TRUE)$diagnostics
iv_diag <- data.table(
  model = c("birth_aimag", "birth_aimag + current aimag FE"),
  weak_instrument_F = c(diag_birth["Weak instruments", "statistic"],
                        diag_birth_fe["Weak instruments", "statistic"]),
  wu_hausman_p = c(diag_birth["Wu-Hausman", "p-value"],
                   diag_birth_fe["Wu-Hausman", "p-value"]),
  sargan_stat = c(diag_birth["Sargan", "statistic"],
                  diag_birth_fe["Sargan", "statistic"]),
  sargan_p = c(diag_birth["Sargan", "p-value"],
               diag_birth_fe["Sargan", "p-value"]),
  interpretation = c("Sargan rejects; report exclusion-risk caveat",
                     "Sargan rejects at 5%; report exclusion-risk caveat")
)
fwrite(iv_diag, file.path(BASE, "clean", "iv_diagnostics.csv"))
cat("  AER overidentification diagnostics saved: iv_diagnostics.csv\n")
print(iv_diag)

# =============================================================================
# 2. ANDERSON-RUBIN STYLE CI FOR DISTANCE-IV ROBUSTNESS
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  2. DISTANCE-IV ANDERSON-RUBIN STYLE CI\n")
cat(strrep("=", 60), "\n")

beta_grid <- seq(-0.1, 0.5, by = 0.005)
ar_pvals <- numeric(length(beta_grid))

for (i in seq_along(beta_grid)) {
  b <- beta_grid[i]
  main_dist[, y_tilde := log_wage - b * educ_years]
  rf <- lm(y_tilde ~ log_dist_ub + experience + I(experience^2) +
             sex + factor(marital) + urban + hhsize + factor(wave),
           data = main_dist, weights = hhweight)
  rf_coef <- summary(rf)$coefficients
  ar_pvals[i] <- if ("log_dist_ub" %in% rownames(rf_coef)) {
    2 * pt(-abs(rf_coef["log_dist_ub", "t value"]), df = rf$df.residual)
  } else {
    1
  }
}

ar_accept <- beta_grid[ar_pvals > 0.05]
ar_ci <- if (length(ar_accept) > 0) range(ar_accept) else c(NA_real_, NA_real_)
cat(sprintf("  Distance-IV AR-style 95%% CI for beta_educ: [%.4f, %.4f]\n",
            ar_ci[1], ar_ci[2]))
cat(sprintf("  Standard distance-IV 2SLS CI: [%.4f, %.4f]\n",
            coef(iv_dist)["fit_educ_years"] - 1.96 * se(iv_dist)["fit_educ_years"],
            coef(iv_dist)["fit_educ_years"] + 1.96 * se(iv_dist)["fit_educ_years"]))

# =============================================================================
# 3. PLACEBO / MECHANISM CHECK FOR DISTANCE IV
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  3. DISTANCE-IV MECHANISM CHECK\n")
cat(strrep("=", 60), "\n")

placebo_low <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                       sex + i(marital_f) + hhsize | wave,
                     data = main_dist[educ_years <= 8], weights = ~hhweight)
placebo_high <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                        sex + i(marital_f) + hhsize | wave,
                      data = main_dist[educ_years > 8], weights = ~hhweight)

cat(sprintf("  Primary-or-less (educ<=8): beta_dist = %.4f (SE %.4f), t = %.2f\n",
            coef(placebo_low)["log_dist_ub"], se(placebo_low)["log_dist_ub"],
            coef(placebo_low)["log_dist_ub"] / se(placebo_low)["log_dist_ub"]))
cat(sprintf("  Above-primary (educ>8):    beta_dist = %.4f (SE %.4f), t = %.2f\n",
            coef(placebo_high)["log_dist_ub"], se(placebo_high)["log_dist_ub"],
            coef(placebo_high)["log_dist_ub"] / se(placebo_high)["log_dist_ub"]))
cat("  Distance remains a robustness IV, not the headline instrument, because\n")
cat("  distance to Ulaanbaatar can also proxy regional labour-market access.\n")

# =============================================================================
# 4. HECKMAN TWO-STEP SELECTION CORRECTION
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  4. HECKMAN SELECTION CORRECTION\n")
cat(strrep("=", 60), "\n")

full <- fread(file.path(BASE, "clean", "full_sample.csv"))
full[, has_wage := !is.na(wage_monthly) & wage_monthly > 0]
full <- full[!is.na(educ_years) & !is.na(age) & age >= 25 & age <= 60]

sel_probit <- glm(has_wage ~ educ_years + age + I(age^2) + factor(sex) +
                    factor(marital) + hhsize + factor(urban),
                  data = full, family = binomial(link = "probit"))

xb <- predict(sel_probit, type = "link")
full[, lambda := dnorm(xb) / pmax(pnorm(xb), 1e-10)]

wage_dt <- full[has_wage == TRUE & !is.na(lambda)]
wage_dt[, log_wage := log(wage_monthly)]
wage_dt[, experience := pmax(age - educ_years - 6, 0)]
wage_dt[, experience_sq := experience^2]
wage_dt[, marital_f := factor(marital)]

m_heck <- tryCatch(
  feols(log_wage ~ educ_years + experience + experience_sq +
          sex + i(marital_f) + urban + lambda | newaimag + wave,
        data = wage_dt, weights = ~hhweight, cluster = ~newaimag),
  error = function(e) { cat(sprintf("  Error: %s\n", e$message)); NULL })

if (!is.null(m_heck)) {
  lambda_t <- coef(m_heck)["lambda"] / se(m_heck)["lambda"]
  cat(sprintf("  beta_educ (Heckman) = %.4f (SE %.4f)\n",
              coef(m_heck)["educ_years"], se(m_heck)["educ_years"]))
  cat(sprintf("  lambda (IMR) = %.4f (SE %.4f), t = %.2f\n",
              coef(m_heck)["lambda"], se(m_heck)["lambda"], lambda_t))
}

# =============================================================================
# 5. ALTERNATIVE THRESHOLD SPLITS (SENSITIVITY ONLY)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  5. SEPARATE-REGIME IV SPLITS AT gamma = 12, 13, 14\n")
cat(strrep("=", 60), "\n")

for (g in c(12, 13, 14)) {
  iv_b <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize |
            wave | educ_years ~ i(birth_aimag),
          data = main[educ_years <= g], weights = ~hhweight),
    error = function(e) NULL)
  iv_a <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize |
            wave | educ_years ~ i(birth_aimag),
          data = main[educ_years > g], weights = ~hhweight),
    error = function(e) NULL)
  if (!is.null(iv_b) && !is.null(iv_a)) {
    cat(sprintf("  gamma=%d: beta_below=%.4f, beta_above=%.4f, diff=%.4f\n",
                g, coef(iv_b)["fit_educ_years"],
                coef(iv_a)["fit_educ_years"],
                coef(iv_a)["fit_educ_years"] - coef(iv_b)["fit_educ_years"]))
  }
}

# =============================================================================
# 6. WAGE-QUANTILE OLS HETEROGENEITY
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  6. WAGE-QUANTILE OLS HETEROGENEITY\n")
cat(strrep("=", 60), "\n")

for (tau_label in c("Bottom 25%", "Middle 50%", "Top 25%")) {
  if (tau_label == "Bottom 25%") {
    sub <- dt[log_wage <= quantile(log_wage, 0.25, na.rm = TRUE)]
  } else if (tau_label == "Top 25%") {
    sub <- dt[log_wage >= quantile(log_wage, 0.75, na.rm = TRUE)]
  } else {
    sub <- dt[log_wage > quantile(log_wage, 0.25, na.rm = TRUE) &
                log_wage < quantile(log_wage, 0.75, na.rm = TRUE)]
  }
  m <- feols(log_wage ~ educ_years + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | newaimag + wave,
             data = sub, weights = ~hhweight, cluster = ~newaimag)
  cat(sprintf("  %s: beta_educ = %.4f (SE %.4f), N = %d\n",
              tau_label, coef(m)["educ_years"], se(m)["educ_years"], nobs(m)))
}

# =============================================================================
# 7. FINAL SUMMARY TABLE
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("  COMPLETE RESULTS SUMMARY\n")
cat(strrep("=", 60), "\n")

ols_simple <- feols(log_wage ~ educ_years + experience + experience_sq,
                    data = dt, weights = ~hhweight)
ols_fe_sum <- feols(log_wage ~ educ_years + experience + experience_sq +
                      sex + i(marital_f) + urban + hhsize | newaimag + wave,
                    data = dt, weights = ~hhweight, cluster = ~newaimag)

panel <- fread(file.path(BASE, "clean", "pseudopanel.csv"))
pdt <- pdata.frame(as.data.frame(panel), index = c("panel_id", "wave"),
                   drop.index = FALSE)
pfe <- plm(log_wage ~ educ_years + experience + experience_sq +
             pct_female + pct_urban + pct_married + mean_hhsize,
           data = pdt, model = "within", weights = cell_n)
pre <- plm(log_wage ~ educ_years + experience + experience_sq +
             pct_female + pct_urban + pct_married + mean_hhsize,
           data = pdt, model = "random", weights = cell_n)

ivtr_summary_path <- file.path(BASE, "clean", "ivtr_headline_results.csv")
if (file.exists(ivtr_summary_path)) {
  ivtr_summary <- fread(ivtr_summary_path)
  get_ivtr_num <- function(name) as.numeric(ivtr_summary[item == name, value][1])
  get_ivtr_chr <- function(name) ivtr_summary[item == name, value][1]
  ivtr_b1 <- get_ivtr_num("beta_1")
  ivtr_b2 <- get_ivtr_num("beta_2")
  ivtr_n1 <- get_ivtr_num("n_regime_1")
  ivtr_n2 <- get_ivtr_num("n_regime_2")
  ivtr_label1 <- "IV threshold regime 1 (low EBS supply)"
  ivtr_label2 <- "IV threshold regime 2 (high EBS supply)"
} else {
  ivtr_b1 <- NA_real_; ivtr_b2 <- NA_real_; ivtr_n1 <- NA_real_; ivtr_n2 <- NA_real_
  ivtr_label1 <- "IV threshold regime 1"
  ivtr_label2 <- "IV threshold regime 2"
}

summary_dt <- data.table(
  Model = c("OLS (simple)",
            "OLS (aimag+wave FE)",
            "Panel FE (pseudo-panel)",
            "Panel RE (pseudo-panel)",
            "2SLS IV (birth_aimag)",
            "2SLS IV (birth_aimag + current aimag FE)",
            "2SLS IV (log dist_UB, robustness)",
            ivtr_label1,
            ivtr_label2,
            "Heckman corrected"),
  beta = c(coef(ols_simple)["educ_years"],
           coef(ols_fe_sum)["educ_years"],
           coef(pfe)["educ_years"],
           coef(pre)["educ_years"],
           coef(iv_birth)["fit_educ_years"],
           coef(iv_birth_fe)["fit_educ_years"],
           coef(iv_dist)["fit_educ_years"],
           ivtr_b1,
           ivtr_b2,
           ifelse(!is.null(m_heck), coef(m_heck)["educ_years"], NA)),
  return_pct = NA_real_,
  N = c(nobs(ols_simple), nobs(ols_fe_sum), nobs(pfe), nobs(pre),
        nobs(iv_birth), nobs(iv_birth_fe), nobs(iv_dist),
        ivtr_n1, ivtr_n2,
        ifelse(!is.null(m_heck), nobs(m_heck), NA))
)
summary_dt[, return_pct := round(100 * (exp(beta) - 1), 1)]

fwrite(summary_dt, file.path(TABS, "t6_full_summary.csv"))
fwrite(summary_dt, file.path(IN_TABS, "t6_full_summary.csv"))
print(summary_dt)

cat("\n=== ALL DIAGNOSTICS DONE: 10_improvements.R ===\n")
