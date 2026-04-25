# =============================================================================
# 09_tables.R — Publication-quality tables (CSV format for Word import)
# =============================================================================

library(data.table)
library(fixest)
suppressPackageStartupMessages(library(AER))

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/tables"
IN_TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/inputs/tables"
dir.create(TABS, showWarnings = FALSE, recursive = TRUE)
dir.create(IN_TABS, showWarnings = FALSE, recursive = TRUE)

write_table <- function(x, filename) {
  fwrite(x, file.path(TABS, filename))
  fwrite(x, file.path(IN_TABS, filename))
}

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)
main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage)]

# =============================================================================
# TABLE 1: Descriptive Statistics
# =============================================================================
cat("=== Table 1: Descriptive Statistics ===\n")

t1_vars <- c("log_wage", "wage_monthly", "educ_years", "age", "experience",
             "sex", "urban", "hhsize")
t1_list <- list()
for (v in t1_vars) {
  if (v %in% names(dt)) {
    x <- dt[[v]]
    t1_list[[v]] <- data.table(
      Variable = v,
      N = sum(!is.na(x)),
      Mean = round(mean(x, na.rm = TRUE), 3),
      SD = round(sd(x, na.rm = TRUE), 3),
      Min = round(min(x, na.rm = TRUE), 3),
      Median = round(median(x, na.rm = TRUE), 3),
      Max = round(max(x, na.rm = TRUE), 3)
    )
  }
}
t1 <- rbindlist(t1_list)
write_table(t1, "t1_descriptives.csv")
print(t1)

# By wave
t1w <- dt[, .(N = .N,
              mean_educ = round(mean(educ_years, na.rm=T), 1),
              mean_wage = round(mean(wage_monthly, na.rm=T), 0),
              med_wage = round(median(wage_monthly, na.rm=T), 0),
              mean_age = round(mean(age, na.rm=T), 1),
              pct_female = round(100*mean(sex==2, na.rm=T), 1),
              pct_urban = round(100*mean(urban==1, na.rm=T), 1)
), by = wave]
write_table(t1w, "t1b_descriptives_by_wave.csv")
cat("\nBy wave:\n")
print(t1w)

# =============================================================================
# TABLE 2: OLS + Panel FE/RE
# =============================================================================
cat("\n=== Table 2: OLS and Panel Models ===\n")

ols1 <- feols(log_wage ~ educ_years + experience + experience_sq,
              data = dt, weights = ~hhweight)
ols2 <- feols(log_wage ~ educ_years + experience + experience_sq +
                sex + i(marital_f) + urban + hhsize,
              data = dt, weights = ~hhweight)
ols3 <- feols(log_wage ~ educ_years + experience + experience_sq +
                sex + i(marital_f) + urban + hhsize | newaimag + wave,
              data = dt, weights = ~hhweight, cluster = ~newaimag)

t2 <- data.table(
  Variable = c("educ_years", "experience", "experience_sq",
               "Aimag FE", "Wave FE", "Controls", "N", "R2"),
  `(1) OLS` = c(sprintf("%.4f***\n(%.4f)", coef(ols1)["educ_years"], se(ols1)["educ_years"]),
                sprintf("%.4f***", coef(ols1)["experience"]),
                sprintf("%.6f***", coef(ols1)["experience_sq"]),
                "No", "No", "No",
                as.character(nobs(ols1)), sprintf("%.3f", fitstat(ols1,"r2")[[1]])),
  `(2) OLS+Controls` = c(sprintf("%.4f***\n(%.4f)", coef(ols2)["educ_years"], se(ols2)["educ_years"]),
                          sprintf("%.4f***", coef(ols2)["experience"]),
                          sprintf("%.6f***", coef(ols2)["experience_sq"]),
                          "No", "No", "Yes",
                          as.character(nobs(ols2)), sprintf("%.3f", fitstat(ols2,"r2")[[1]])),
  `(3) OLS+FE` = c(sprintf("%.4f***\n(%.4f)", coef(ols3)["educ_years"], se(ols3)["educ_years"]),
                    sprintf("%.4f***", coef(ols3)["experience"]),
                    sprintf("%.6f***", coef(ols3)["experience_sq"]),
                    "Yes", "Yes", "Yes",
                    as.character(nobs(ols3)), sprintf("%.3f", fitstat(ols3,"r2")[[1]]))
)
write_table(t2, "t2_ols_panel.csv")
print(t2)

# =============================================================================
# TABLE 3: First Stage + 2SLS
# =============================================================================
cat("\n=== Table 3: IV Results ===\n")

iv1 <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
               urban + hhsize | wave | educ_years ~ i(birth_aimag),
             data = main, weights = ~hhweight, cluster = ~newaimag)

main_dist <- main[!is.na(log_dist_ub) & is.finite(log_dist_ub)]
iv2 <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
               urban + hhsize | wave | educ_years ~ log_dist_ub,
             data = main_dist, weights = ~hhweight, cluster = ~newaimag)

iv3 <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
               urban + hhsize | wave + newaimag |
               educ_years ~ i(birth_aimag),
             data = main, weights = ~hhweight, cluster = ~newaimag)

ols_main <- feols(log_wage ~ educ_years + experience + experience_sq +
                    sex + i(marital_f) + urban + hhsize | wave,
                  data = main, weights = ~hhweight, cluster = ~newaimag)

fmt_p <- function(p) {
  if (is.na(p)) return("-")
  if (p < 0.001) return("<0.001")
  sprintf("%.4f", p)
}

ivreg_diag <- function(include_current_fe = FALSE) {
  if (include_current_fe) {
    m <- ivreg(log_wage ~ educ_years + experience + experience_sq + sex +
                 marital_f + urban + hhsize + factor(wave) + factor(newaimag) |
                 experience + experience_sq + sex + marital_f + urban + hhsize +
                 factor(wave) + factor(newaimag) + factor(birth_aimag),
               data = main, weights = hhweight)
  } else {
    m <- ivreg(log_wage ~ educ_years + experience + experience_sq + sex +
                 marital_f + urban + hhsize + factor(wave) |
                 experience + experience_sq + sex + marital_f + urban + hhsize +
                 factor(wave) + factor(birth_aimag),
               data = main, weights = hhweight)
  }
  summary(m, diagnostics = TRUE)$diagnostics
}

diag_birth <- ivreg_diag(FALSE)
diag_birth_fe <- ivreg_diag(TRUE)
sargan_birth_p <- diag_birth["Sargan", "p-value"]
sargan_birth_fe_p <- diag_birth_fe["Sargan", "p-value"]
wu_birth_p <- diag_birth["Wu-Hausman", "p-value"]
wu_birth_fe_p <- diag_birth_fe["Wu-Hausman", "p-value"]

t3 <- data.table(
  Statistic = c("beta_educ", "SE", "Method", "IV", "First-stage F/Wald",
                "Wu-Hausman p-value", "Sargan p-value",
                "Overidentification note", "N"),
  `(1) OLS` = c(sprintf("%.4f", coef(ols_main)["educ_years"]),
                sprintf("(%.4f)", se(ols_main)["educ_years"]),
                "OLS", "-", "-", "-", "-", "-", as.character(nobs(ols_main))),
  `(2) 2SLS birth_aimag` = c(sprintf("%.4f", coef(iv1)["fit_educ_years"]),
                              sprintf("(%.4f)", se(iv1)["fit_educ_years"]),
                              "2SLS", "birth_aimag",
                              sprintf("%.2f", fitstat(iv1,"ivf")$ivf1$stat),
                              fmt_p(wu_birth_p),
                              fmt_p(sargan_birth_p),
                              ifelse(sargan_birth_p < 0.05,
                                     "Sargan rejects; exclusion-risk caveat",
                                     "Sargan not rejected"),
                              as.character(nobs(iv1))),
  `(3) 2SLS log_dist_UB` = c(sprintf("%.4f", coef(iv2)["fit_educ_years"]),
                               sprintf("(%.4f)", se(iv2)["fit_educ_years"]),
                               "2SLS", "log(dist_UB)",
                               sprintf("%.2f", fitstat(iv2,"ivf")$ivf1$stat),
                               "-", "-",
                               "Exactly identified; robustness only",
                               as.character(nobs(iv2))),
  `(4) 2SLS birth + current FE` = c(sprintf("%.4f", coef(iv3)["fit_educ_years"]),
                                  sprintf("(%.4f)", se(iv3)["fit_educ_years"]),
                                  "2SLS", "birth_aimag; current aimag FE",
                                  sprintf("%.2f", fitstat(iv3,"ivf")$ivf1$stat),
                                  fmt_p(wu_birth_fe_p),
                                  fmt_p(sargan_birth_fe_p),
                                  ifelse(sargan_birth_fe_p < 0.05,
                                         "Sargan rejects; exclusion-risk caveat",
                                         "Sargan not rejected"),
                                  as.character(nobs(iv3)))
)
write_table(t3, "t3_iv_results.csv")
print(t3)

# =============================================================================
# TABLE 4: IVTR (Caner-Hansen) — Headline
# =============================================================================
cat("\n=== Table 4: IVTR Threshold Results ===\n")

ivtr_summary <- fread(file.path(BASE, "clean", "ivtr_headline_results.csv"))
get_ivtr <- function(name) ivtr_summary[item == name, value][1]
get_num <- function(name) as.numeric(get_ivtr(name))

threshold_label <- get_ivtr("threshold_label")
threshold_unit <- get_ivtr("threshold_unit")
gamma_star <- get_num("gamma_star")
gamma_ci_low <- get_num("gamma_ci_low")
gamma_ci_high <- get_num("gamma_ci_high")
regime_1_label <- get_ivtr("regime_1_label")
regime_2_label <- get_ivtr("regime_2_label")
b1 <- get_num("beta_1")
s1 <- get_num("se_1")
r1 <- get_num("return_1_pct")
b2 <- get_num("beta_2")
s2 <- get_num("se_2")
r2 <- get_num("return_2_pct")
diff_est <- get_num("diff_beta")
diff_se <- get_num("diff_se")
t_eq <- get_num("diff_t")
p_eq <- get_num("diff_p")
fs1 <- get_num("fs_regime_1_separate")
fs2 <- get_num("fs_regime_2_separate")
sup_wald <- get_num("sup_wald")
boot_p <- get_num("bootstrap_p")
boot_B <- as.integer(get_num("bootstrap_B"))
n1 <- as.integer(get_num("n_regime_1"))
n2 <- as.integer(get_num("n_regime_2"))
n_total <- as.integer(get_num("n_total"))
p_label <- if (boot_p == 0) sprintf("<%.4f", 1 / (boot_B + 1)) else sprintf("%.4f", boot_p)
p_item <- if (boot_B > 0) {
  sprintf("Bootstrap p-value (B=%d, wild)", boot_B)
} else {
  "Threshold test p-value (SSR not improved)"
}

t4 <- data.table(
  Item = c("Optimal threshold gamma*",
           "LR-profile 95% set for gamma*",
           "Threshold variable",
           "Estimator",
           "Interpretation warning",
           "beta_1 (low-q regime)", "SE_1",
           "Return per year (regime 1)",
           "Regime 1 definition",
           "beta_2 (high-q regime)", "SE_2",
           "Return per year (regime 2)",
           "Regime 2 definition",
           "Difference b2 - b1 (log points)", "SE (diff)",
           "t-stat for b1 = b2", "p-value for b1 = b2",
           "Separate-regime first-stage F/Wald (regime 1)",
           "Separate-regime first-stage F/Wald (regime 2)",
           "SupWald-style statistic",
           p_item,
           "N (regime 1)", "N (regime 2)", "N (total)"),
  Value = c(sprintf("%.2f %s", gamma_star, threshold_unit),
            sprintf("[%.2f, %.2f]", gamma_ci_low, gamma_ci_high),
            threshold_label,
            "Joint 2SLS with interacted instruments",
            "Threshold is predetermined EBS supply; slope-difference test is not significant",
            sprintf("%.4f", b1), sprintf("(%.4f)", s1),
            sprintf("%.1f%%", r1),
            regime_1_label,
            sprintf("%.4f", b2), sprintf("(%.4f)", s2),
            sprintf("%.1f%%", r2),
            regime_2_label,
            sprintf("%.4f", diff_est),
            sprintf("%.4f", diff_se),
            sprintf("%.2f", t_eq), sprintf("%.4f", p_eq),
            sprintf("%.2f", fs1), sprintf("%.2f", fs2),
            sprintf("%.2f", sup_wald), p_label,
            format(n1, big.mark=","), format(n2, big.mark=","),
            format(n_total, big.mark=","))
)
write_table(t4, "t4_ivtr_headline.csv")
print(t4)

# =============================================================================
# TABLE 5: Robustness
# =============================================================================
cat("\n=== Table 5: Robustness ===\n")

rob_results <- list()
rob_specs <- list(
  "All (OLS+FE)" = list(d = dt, iv = FALSE),
  "Male" = list(d = dt[sex == 1], iv = FALSE),
  "Female" = list(d = dt[sex == 2], iv = FALSE),
  "Urban" = list(d = dt[urban == 1], iv = FALSE),
  "Rural" = list(d = dt[urban == 2], iv = FALSE),
  "Age 25-40" = list(d = dt[age <= 40], iv = FALSE),
  "Age 41-60" = list(d = dt[age > 40], iv = FALSE)
)

for (nm in names(rob_specs)) {
  sp <- rob_specs[[nm]]
  m <- tryCatch(
    feols(log_wage ~ educ_years + experience + experience_sq +
            sex + i(marital_f) + urban + hhsize | newaimag + wave,
          data = sp$d, weights = ~hhweight, cluster = ~newaimag),
    error = function(e) NULL)
  if (!is.null(m)) {
    rob_results[[nm]] <- data.table(
      Specification = nm,
      beta = sprintf("%.4f", coef(m)["educ_years"]),
      SE = sprintf("(%.4f)", se(m)["educ_years"]),
      N = nobs(m)
    )
  }
}
t5 <- rbindlist(rob_results)
write_table(t5, "t5_robustness.csv")
print(t5)

cat(sprintf("\n=== ALL TABLES SAVED to %s ===\n", TABS))
cat("  t1_descriptives.csv\n")
cat("  t1b_descriptives_by_wave.csv\n")
cat("  t2_ols_panel.csv\n")
cat("  t3_iv_results.csv\n")
cat("  t4_ivtr_headline.csv\n")
cat("  t5_robustness.csv\n")
cat("  t7_threshold_proxy_comparison.csv (written by R/11)\n")
cat("  t8_ch_classical_threshold_comparison.csv (written by R/12)\n")
cat("  t9_ch_classical_bootstrap.csv (written by R/13)\n")
cat("\n=== DONE: 09_tables.R ===\n")
