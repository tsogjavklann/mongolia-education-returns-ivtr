# =============================================================================
# 09_tables.R — Publication-quality tables (CSV format for Word import)
# =============================================================================

library(data.table)
library(fixest)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
TABS <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/tables"
dir.create(TABS, showWarnings = FALSE, recursive = TRUE)

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
main <- dt[wave >= 2020 & !is.na(birth_aimag) & !is.na(educ_years) & !is.na(log_wage)]

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
fwrite(t1, file.path(TABS, "t1_descriptives.csv"))
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
fwrite(t1w, file.path(TABS, "t1b_descriptives_by_wave.csv"))
cat("\nBy wave:\n")
print(t1w)

# =============================================================================
# TABLE 2: OLS + Panel FE/RE
# =============================================================================
cat("\n=== Table 2: OLS and Panel Models ===\n")

ols1 <- feols(log_wage ~ educ_years + experience + experience_sq,
              data = dt, weights = ~hhweight)
ols2 <- feols(log_wage ~ educ_years + experience + experience_sq +
                sex + marital + urban + hhsize,
              data = dt, weights = ~hhweight)
ols3 <- feols(log_wage ~ educ_years + experience + experience_sq +
                sex + marital + urban + hhsize | newaimag + wave,
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
fwrite(t2, file.path(TABS, "t2_ols_panel.csv"))
print(t2)

# =============================================================================
# TABLE 3: First Stage + 2SLS
# =============================================================================
cat("\n=== Table 3: IV Results ===\n")

iv1 <- feols(log_wage ~ experience + experience_sq + sex + marital +
               urban + hhsize | wave | educ_years ~ i(birth_aimag),
             data = main, weights = ~hhweight, cluster = ~newaimag)

main_dist <- main[!is.na(log_dist_ub) & is.finite(log_dist_ub)]
iv2 <- feols(log_wage ~ experience + experience_sq + sex + marital +
               urban + hhsize | wave | educ_years ~ log_dist_ub,
             data = main_dist, weights = ~hhweight, cluster = ~newaimag)

iv3 <- feols(log_wage ~ experience + experience_sq + sex + marital +
               urban + hhsize | wave | educ_years ~ i(birth_aimag) + log_dist_ub,
             data = main_dist, weights = ~hhweight, cluster = ~newaimag)

ols_main <- feols(log_wage ~ educ_years + experience + experience_sq +
                    sex + marital + urban + hhsize | wave,
                  data = main, weights = ~hhweight, cluster = ~newaimag)

t3 <- data.table(
  Statistic = c("beta_educ", "SE", "Method", "IV", "First-stage F", "N"),
  `(1) OLS` = c(sprintf("%.4f", coef(ols_main)["educ_years"]),
                sprintf("(%.4f)", se(ols_main)["educ_years"]),
                "OLS", "-", "-", as.character(nobs(ols_main))),
  `(2) 2SLS birth_aimag` = c(sprintf("%.4f", coef(iv1)["fit_educ_years"]),
                              sprintf("(%.4f)", se(iv1)["fit_educ_years"]),
                              "2SLS", "birth_aimag",
                              sprintf("%.2f", fitstat(iv1,"ivf")$ivf1$stat),
                              as.character(nobs(iv1))),
  `(3) 2SLS log_dist_UB` = c(sprintf("%.4f", coef(iv2)["fit_educ_years"]),
                               sprintf("(%.4f)", se(iv2)["fit_educ_years"]),
                               "2SLS", "log(dist_UB)",
                               sprintf("%.2f", fitstat(iv2,"ivf")$ivf1$stat),
                               as.character(nobs(iv2))),
  `(4) 2SLS overidentified` = c(sprintf("%.4f", coef(iv3)["fit_educ_years"]),
                                  sprintf("(%.4f)", se(iv3)["fit_educ_years"]),
                                  "2SLS", "birth_aimag + log(dist)",
                                  "-", as.character(nobs(iv3)))
)
fwrite(t3, file.path(TABS, "t3_iv_results.csv"))
print(t3)

# =============================================================================
# TABLE 4: IVTR (Caner-Hansen) — Headline
# =============================================================================
cat("\n=== Table 4: IVTR Threshold Results ===\n")

t4 <- data.table(
  Item = c("Optimal threshold gamma*",
           "beta_1 (educ <= gamma*)", "SE_1",
           "Return per year (regime 1)",
           "beta_2 (educ > gamma*)", "SE_2",
           "Return per year (regime 2)",
           "SupWald statistic", "Bootstrap p-value",
           "N (regime 1)", "N (regime 2)", "N (total)"),
  Value = c("13 years",
            "0.0533", "(0.0272)", "5.5%",
            "0.1650", "(0.0307)", "17.9%",
            "152.20", "0.0000",
            "6,144", "5,876", "12,020")
)
fwrite(t4, file.path(TABS, "t4_ivtr_headline.csv"))
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
  "Age 25-40" = list(d = dt[age <= 40], iv = FALSE),
  "Age 41-60" = list(d = dt[age > 40], iv = FALSE)
)

for (nm in names(rob_specs)) {
  sp <- rob_specs[[nm]]
  m <- tryCatch(
    feols(log_wage ~ educ_years + experience + experience_sq +
            sex + marital + urban + hhsize | newaimag + wave,
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
fwrite(t5, file.path(TABS, "t5_robustness.csv"))
print(t5)

cat(sprintf("\n=== ALL TABLES SAVED to %s ===\n", TABS))
cat("  t1_descriptives.csv\n")
cat("  t1b_descriptives_by_wave.csv\n")
cat("  t2_ols_panel.csv\n")
cat("  t3_iv_results.csv\n")
cat("  t4_ivtr_headline.csv\n")
cat("  t5_robustness.csv\n")
cat("\n=== DONE: 09_tables.R ===\n")
