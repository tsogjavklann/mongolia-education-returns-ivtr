# =============================================================================
# 15_sensitivity_checks.R -- Robustness/sensitivity checks (Phase B audit fixes)
# =============================================================================
# Implements the audit recommendations:
#   H3  EBS extreme-value robustness: trim top/bottom 1% of EBS supply and
#       refit the headline D1 (school-age teachers per 1,000) IV-threshold.
#   M7  educ_years==0 outlier sensitivity: re-estimate the linear IV without
#       the 145 zero-schooling wage-earners and verify beta is stable.
#   M5  D6 EBS_2000 full-sample sensitivity: re-fit threshold on the older-
#       cohort full sample using EBS_2000 as initial-condition proxy.
#   B-additional  Bonferroni and effective-tests adjustment: report adjusted
#       alpha for 6 nominal proxies and 3 effective proxy families
#       (cohort/supply/geography), plus a separate diagnostic family.
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))

set.seed(2026)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
ROOT <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric"
OUT_TABS <- file.path(ROOT, "outputs", "tables")
IN_TABS <- file.path(ROOT, "inputs", "tables")
dir.create(OUT_TABS, recursive = TRUE, showWarnings = FALSE)
dir.create(IN_TABS, recursive = TRUE, showWarnings = FALSE)

MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)
TRIM <- 0.15

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
dt[, birth_aimag_f := factor(birth_aimag)]

main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]

# =============================================================================
# H3: EBS extreme-value robustness
# =============================================================================
cat("\n=== H3: EBS extreme-value robustness (trim p1-p99) ===\n")

ebs_var <- "ebs_teachers_per_1000_school_age"
sub_full <- main[ebs_school_age_years >= 3 & !is.na(get(ebs_var))]
cat(sprintf("D1 full sample: %d\n", nrow(sub_full)))

p1  <- quantile(sub_full[[ebs_var]], 0.01, na.rm = TRUE)
p99 <- quantile(sub_full[[ebs_var]], 0.99, na.rm = TRUE)
cat(sprintf("D1 EBS supply p1 = %.3f, p99 = %.3f\n", p1, p99))
cat(sprintf("D1 EBS supply min = %.3f, max = %.3f (raw)\n",
            min(sub_full[[ebs_var]]), max(sub_full[[ebs_var]])))

sub_trim <- sub_full[get(ebs_var) >= p1 & get(ebs_var) <= p99]
cat(sprintf("After trimming p1-p99: %d (dropped %d)\n",
            nrow(sub_trim), nrow(sub_full) - nrow(sub_trim)))

run_d1 <- function(sub) {
  q <- sub[[ebs_var]]
  q_grid <- sort(unique(q))
  q_grid <- q_grid[vapply(q_grid, function(g) {
    mean(q <= g, na.rm = TRUE) >= TRIM &&
      mean(q > g, na.rm = TRUE) >= TRIM
  }, logical(1))]
  if (length(q_grid) > 60) {
    q_grid <- as.numeric(quantile(q, seq(TRIM, 1 - TRIM, length.out = 40),
                                  na.rm = TRUE))
    q_grid <- unique(round(q_grid, 6))
  }

  fit_at <- function(g) {
    s <- copy(sub)
    s[, below := as.integer(get(ebs_var) <= g)]
    s[, above := 1L - below]
    s[, educ_below := educ_years * below]
    s[, educ_above := educ_years * above]
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize + below |
            wave |
            educ_below + educ_above ~
              i(birth_aimag_f, below) + i(birth_aimag_f, above),
          data = s, weights = ~hhweight, cluster = ~newaimag,
          notes = FALSE)
  }
  ssrs <- vapply(q_grid, function(g) {
    m <- tryCatch(fit_at(g), error = function(e) NULL)
    if (is.null(m)) Inf else sum(sub$hhweight * resid(m)^2, na.rm = TRUE)
  }, numeric(1))
  best <- which.min(ssrs)
  list(gamma_star = q_grid[best], model = fit_at(q_grid[best]))
}

r_full <- run_d1(sub_full)
r_trim <- run_d1(sub_trim)

extract <- function(r, label) {
  m <- r$model
  b1 <- coef(m)["fit_educ_below"]
  s1 <- se(m)["fit_educ_below"]
  b2 <- coef(m)["fit_educ_above"]
  s2 <- se(m)["fit_educ_above"]
  V <- vcov(m)
  diff_se <- sqrt(V["fit_educ_below","fit_educ_below"] +
                    V["fit_educ_above","fit_educ_above"] -
                    2 * V["fit_educ_below","fit_educ_above"])
  data.table(spec = label,
             gamma_star = r$gamma_star,
             beta_low = b1, se_low = s1,
             beta_high = b2, se_high = s2,
             diff = b2 - b1, diff_se = diff_se,
             diff_p = 2 * pnorm(-abs((b2 - b1) / diff_se)))
}

h3_tab <- rbind(extract(r_full, "D1 full (extreme-included)"),
                extract(r_trim, "D1 trimmed (p1-p99)"))
print(h3_tab)
fwrite(h3_tab, file.path(OUT_TABS, "t10_h3_ebs_outlier_sensitivity.csv"))
fwrite(h3_tab, file.path(IN_TABS, "t10_h3_ebs_outlier_sensitivity.csv"))

# =============================================================================
# M7: educ_years==0 outlier sensitivity
# =============================================================================
cat("\n=== M7: educ_years==0 outlier sensitivity (linear IV) ===\n")
n_zero <- nrow(main[educ_years == 0])
cat(sprintf("Obs with educ_years==0 in IV sample: %d (median wage = %s MNT)\n",
            n_zero, format(median(main[educ_years == 0, wage_monthly]),
                          big.mark = ",")))

iv_full <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                   urban + hhsize | wave | educ_years ~ i(birth_aimag),
                 data = main, weights = ~hhweight, cluster = ~newaimag,
                 notes = FALSE)
iv_drop0 <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                    urban + hhsize | wave | educ_years ~ i(birth_aimag),
                  data = main[educ_years > 0], weights = ~hhweight,
                  cluster = ~newaimag, notes = FALSE)

m7_tab <- data.table(
  spec = c("IV full sample (incl. educ=0)", "IV excluding educ_years==0"),
  N = c(nobs(iv_full), nobs(iv_drop0)),
  beta_iv = c(coef(iv_full)["fit_educ_years"], coef(iv_drop0)["fit_educ_years"]),
  se_iv = c(se(iv_full)["fit_educ_years"], se(iv_drop0)["fit_educ_years"]),
  fs_F = c(fitstat(iv_full, "ivf")$ivf1$stat,
           fitstat(iv_drop0, "ivf")$ivf1$stat)
)
print(m7_tab)
cat(sprintf("Beta change: %.4f -> %.4f (%.2f%% change)\n",
            m7_tab$beta_iv[1], m7_tab$beta_iv[2],
            100 * (m7_tab$beta_iv[2] - m7_tab$beta_iv[1]) / m7_tab$beta_iv[1]))
fwrite(m7_tab, file.path(OUT_TABS, "t11_m7_educ_zero_sensitivity.csv"))
fwrite(m7_tab, file.path(IN_TABS, "t11_m7_educ_zero_sensitivity.csv"))

# =============================================================================
# M5: D6 EBS_2000 full-sample sensitivity (older cohort coverage)
# =============================================================================
cat("\n=== M5: D6 EBS_2000 full-sample sensitivity ===\n")
ebs2000 <- "ebs_teachers_per_1000_2000"
sub2000 <- main[!is.na(get(ebs2000))]
cat(sprintf("D6 EBS_2000 full sample: %d (covers all cohorts)\n", nrow(sub2000)))

run_general <- function(sub, q_var) {
  q <- sub[[q_var]]
  q_grid <- sort(unique(q))
  q_grid <- q_grid[vapply(q_grid, function(g) {
    mean(q <= g, na.rm = TRUE) >= TRIM &&
      mean(q > g, na.rm = TRUE) >= TRIM
  }, logical(1))]
  if (length(q_grid) > 60) {
    q_grid <- as.numeric(quantile(q, seq(TRIM, 1 - TRIM, length.out = 40),
                                  na.rm = TRUE))
    q_grid <- unique(round(q_grid, 6))
  }
  fit_at <- function(g) {
    s <- copy(sub)
    s[, below := as.integer(get(q_var) <= g)]
    s[, above := 1L - below]
    s[, educ_below := educ_years * below]
    s[, educ_above := educ_years * above]
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize + below |
            wave |
            educ_below + educ_above ~
              i(birth_aimag_f, below) + i(birth_aimag_f, above),
          data = s, weights = ~hhweight, cluster = ~newaimag,
          notes = FALSE)
  }
  ssrs <- vapply(q_grid, function(g) {
    m <- tryCatch(fit_at(g), error = function(e) NULL)
    if (is.null(m)) Inf else sum(sub$hhweight * resid(m)^2, na.rm = TRUE)
  }, numeric(1))
  best <- which.min(ssrs)
  list(gamma_star = q_grid[best], model = fit_at(q_grid[best]))
}
r2000 <- run_general(sub2000, ebs2000)
m5_tab <- extract(r2000, "D6 EBS_2000 full sample")
print(m5_tab)
fwrite(m5_tab, file.path(OUT_TABS, "t12_m5_ebs2000_full_sensitivity.csv"))
fwrite(m5_tab, file.path(IN_TABS, "t12_m5_ebs2000_full_sensitivity.csv"))

# =============================================================================
# Bonferroni: 6 nominal tests vs 3 effective proxy families
# =============================================================================
cat("\n=== Bonferroni / effective-tests reporting ===\n")
t9 <- fread(file.path(BASE, "clean", "ch_classical_bootstrap.csv"))

family_map <- data.table(
  proxy_short = c("D1", "D3", "D5", "C3", "G1", "B1"),
  family = c("Supply", "Supply", "Supply",
             "Cohort", "Geography", "Diagnostic"))

bonf_tab <- data.table(
  proxy = t9$proxy,
  bootstrap_p = t9$bootstrap_p,
  alpha_6 = 0.05 / 6,
  alpha_3_families = 0.05 / 3,
  pass_bonf_6 = t9$bootstrap_p < (0.05 / 6),
  pass_bonf_3 = t9$bootstrap_p < (0.05 / 3))
print(bonf_tab)
fwrite(bonf_tab, file.path(OUT_TABS, "t13_bonferroni_reporting.csv"))
fwrite(bonf_tab, file.path(IN_TABS, "t13_bonferroni_reporting.csv"))

cat(sprintf("\nWith 6 nominal tests Bonferroni alpha = %.4f, %d/%d pass.\n",
            0.05/6, sum(bonf_tab$pass_bonf_6), nrow(bonf_tab)))
cat(sprintf("With 3 effective families Bonferroni alpha = %.4f, %d/%d pass.\n",
            0.05/3, sum(bonf_tab$pass_bonf_3), nrow(bonf_tab)))

cat("\n=== DONE: 15_sensitivity_checks.R ===\n")
