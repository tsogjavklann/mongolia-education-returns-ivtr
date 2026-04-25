# =============================================================================
# 05_ivtr_caner_hansen.R -- IV threshold regression with exogenous threshold
# =============================================================================
# Reference: Caner, M. & Hansen, B.E. (2004). "Instrumental Variable Estimation
#   of a Threshold Model." Econometric Theory, 20(5), 813-843.
#
# Headline fix:
#   educ_years remains the endogenous regressor instrumented by birth_aimag.
#   The threshold variable is no longer educ_years. The headline threshold is
#   predetermined birth-aimag EBS teacher supply during school ages 6-17.
#
# Interpretation:
#   Does the causal return to an extra year of schooling differ between people
#   born into lower vs higher school-age teacher-supply environments?
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"

MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

THRESHOLD_VAR <- "ebs_teachers_per_1000_school_age"
THRESHOLD_LABEL <- "EBS teachers per 1,000 students during school ages 6-17"
THRESHOLD_UNIT <- "teachers per 1,000 students"
MIN_SCHOOL_AGE_YEARS <- 3L
TRIM <- 0.15

# --- Load main IV sample ------------------------------------------------------
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
if (!THRESHOLD_VAR %in% names(dt)) {
  stop("EBS threshold variable is missing. Run R/03b_iv_construction.R first.")
}

main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience) &
             !is.na(get(THRESHOLD_VAR)) &
             ebs_school_age_years >= MIN_SCHOOL_AGE_YEARS]
cat(sprintf("IVTR sample with exogenous threshold: %d individuals\n", nrow(main)))
cat(sprintf("Threshold variable: %s\n", THRESHOLD_LABEL))

main[, birth_aimag_f := factor(birth_aimag)]
main[, marital_f := factor(marital)]
main[, q_threshold := get(THRESHOLD_VAR)]
main[, `:=`(w2021 = as.integer(wave == 2021),
            w2024 = as.integer(wave == 2024))]

cat(sprintf("  q summary: min %.2f, median %.2f, max %.2f %s\n",
            min(main$q_threshold, na.rm = TRUE),
            median(main$q_threshold, na.rm = TRUE),
            max(main$q_threshold, na.rm = TRUE),
            THRESHOLD_UNIT))
cat(sprintf("  Observed school-age EBS years: mean %.1f, min %d, max %d\n",
            mean(main$ebs_school_age_years, na.rm = TRUE),
            min(main$ebs_school_age_years, na.rm = TRUE),
            max(main$ebs_school_age_years, na.rm = TRUE)))

# --- First-stage diagnostic --------------------------------------------------
cat("\n=== STEP 1: First-stage diagnostic ===\n")
fs_model <- feols(educ_years ~ i(birth_aimag) + experience + experience_sq +
                    sex + i(marital_f) + urban + hhsize |
                    wave,
                  data = main, weights = ~hhweight, cluster = ~newaimag,
                  notes = FALSE)
cat(sprintf("  First-stage F/Wald = %.2f\n", fitstat(fs_model, "wald")$wald$stat))
cat(sprintf("  First-stage R2 = %.4f\n", fitstat(fs_model, "r2")[[1]]))

# --- Estimator helpers -------------------------------------------------------
estimate_joint_iv <- function(gamma, dat, cluster_se = FALSE) {
  dat <- copy(dat)
  dat[, below := as.integer(q_threshold <= gamma)]
  dat[, above := 1L - below]
  dat[, educ_below := educ_years * below]
  dat[, educ_above := educ_years * above]

  cluster_formula <- if (cluster_se) ~newaimag else NULL
  tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize + below |
            wave |
            educ_below + educ_above ~
              i(birth_aimag_f, below) + i(birth_aimag_f, above),
          data = dat, weights = ~hhweight, cluster = cluster_formula,
          notes = FALSE),
    error = function(e) NULL
  )
}

compute_ssr <- function(gamma, dat) {
  m <- estimate_joint_iv(gamma, dat, cluster_se = FALSE)
  if (is.null(m)) return(Inf)
  sum(dat$hhweight * resid(m)^2, na.rm = TRUE)
}

format_gamma <- function(x) sprintf("%.2f", x)

# --- Grid search -------------------------------------------------------------
cat("\n=== STEP 2: Grid search over exogenous threshold ===\n")
q_vals <- sort(unique(main$q_threshold))
gamma_grid <- q_vals[vapply(q_vals, function(g) {
  mean(main$q_threshold <= g, na.rm = TRUE) >= TRIM &&
    mean(main$q_threshold > g, na.rm = TRUE) >= TRIM
}, logical(1))]

if (length(gamma_grid) > 60) {
  gamma_grid <- as.numeric(quantile(main$q_threshold,
                                    seq(TRIM, 1 - TRIM, length.out = 40),
                                    na.rm = TRUE))
  gamma_grid <- unique(round(gamma_grid, 6))
}
if (length(gamma_grid) < 2) stop("Threshold grid is degenerate after trimming.")

cat(sprintf("  Grid: %d candidate thresholds in [%.2f, %.2f]\n",
            length(gamma_grid), min(gamma_grid), max(gamma_grid)))

results <- data.table(gamma = gamma_grid, ssr = NA_real_,
                      n_low_q = NA_integer_, n_high_q = NA_integer_,
                      threshold_var = THRESHOLD_VAR,
                      threshold_label = THRESHOLD_LABEL,
                      threshold_unit = THRESHOLD_UNIT)
for (i in seq_along(gamma_grid)) {
  g <- gamma_grid[i]
  results$ssr[i] <- compute_ssr(g, main)
  results$n_low_q[i] <- sum(main$q_threshold <= g, na.rm = TRUE)
  results$n_high_q[i] <- sum(main$q_threshold > g, na.rm = TRUE)
}

gamma_star <- results[which.min(ssr), gamma]
ssr_star <- results[which.min(ssr), ssr]
cat(sprintf("\n  *** SELECTED THRESHOLD: gamma* = %.4f %s ***\n",
            gamma_star, THRESHOLD_UNIT))
cat(sprintf("  Structural weighted SSR at gamma* = %.2f\n", ssr_star))

results[, LR := nrow(main) * (ssr - ssr_star) / ssr_star]
c_95 <- 7.35
ci_set <- results[LR <= c_95, gamma]
gamma_ci <- range(ci_set)
cat(sprintf("  LR-profile 95%% set for gamma*: [%.4f, %.4f]\n",
            gamma_ci[1], gamma_ci[2]))

# --- Regime coefficients at gamma* ------------------------------------------
cat("\n=== STEP 3: Regime estimates at gamma* ===\n")
main[, below := as.integer(q_threshold <= gamma_star)]
main[, above := 1L - below]
main[, educ_below := educ_years * below]
main[, educ_above := educ_years * above]

n_below <- sum(main$below)
n_above <- sum(main$above)
cat(sprintf("  Regime 1 (q <= %.2f): N = %d (%.1f%%)\n",
            gamma_star, n_below, 100 * n_below / nrow(main)))
cat(sprintf("  Regime 2 (q > %.2f):  N = %d (%.1f%%)\n",
            gamma_star, n_above, 100 * n_above / nrow(main)))

iv_joint <- estimate_joint_iv(gamma_star, main, cluster_se = TRUE)
if (is.null(iv_joint)) stop("Joint IV estimation failed at gamma*.")

b1 <- coef(iv_joint)["fit_educ_below"]
s1 <- se(iv_joint)["fit_educ_below"]
b2 <- coef(iv_joint)["fit_educ_above"]
s2 <- se(iv_joint)["fit_educ_above"]
cat(sprintf("  beta_low_q  = %.4f (SE %.4f) => %.1f%% per year\n",
            b1, s1, 100 * (exp(b1) - 1)))
cat(sprintf("  beta_high_q = %.4f (SE %.4f) => %.1f%% per year\n",
            b2, s2, 100 * (exp(b2) - 1)))

V <- vcov(iv_joint)
diff_est <- b2 - b1
diff_se <- sqrt(V["fit_educ_below", "fit_educ_below"] +
                  V["fit_educ_above", "fit_educ_above"] -
                  2 * V["fit_educ_below", "fit_educ_above"])
t_eq <- diff_est / diff_se
p_eq <- 2 * pnorm(-abs(t_eq))
cat(sprintf("  Test beta_low_q = beta_high_q: diff = %.4f (SE %.4f), t = %.2f, p = %.4f\n",
            diff_est, diff_se, t_eq, p_eq))

iv_low <- tryCatch(
  feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
          urban + hhsize |
          wave | educ_years ~ i(birth_aimag_f),
        data = main[below == 1], weights = ~hhweight, cluster = ~newaimag,
        notes = FALSE),
  error = function(e) NULL)
iv_high <- tryCatch(
  feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
          urban + hhsize |
          wave | educ_years ~ i(birth_aimag_f),
        data = main[above == 1], weights = ~hhweight, cluster = ~newaimag,
        notes = FALSE),
  error = function(e) NULL)
fs_low_sep <- if (!is.null(iv_low)) fitstat(iv_low, "ivf")$ivf1$stat else NA_real_
fs_high_sep <- if (!is.null(iv_high)) fitstat(iv_high, "ivf")$ivf1$stat else NA_real_
cat("\n  [Sensitivity: separate-regime 2SLS]\n")
cat(sprintf("    Low-q regime F/Wald = %.2f\n", fs_low_sep))
cat(sprintf("    High-q regime F/Wald = %.2f\n", fs_high_sep))

# --- SupWald-style wild bootstrap -------------------------------------------
cat("\n=== STEP 4: SupWald-style wild bootstrap ===\n")
null_iv <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                   urban + hhsize |
                   wave |
                   educ_years ~ i(birth_aimag_f),
                 data = main, weights = ~hhweight, notes = FALSE)
null_yhat <- fitted(null_iv)
null_resid_vec <- resid(null_iv)
ssr_null <- sum(main$hhweight * null_resid_vec^2, na.rm = TRUE)
sup_wald_raw <- nrow(main) * (ssr_null - ssr_star) / ssr_star
sup_wald <- max(0, sup_wald_raw)
cat(sprintf("  SSR_null = %.2f, SSR_threshold = %.2f\n", ssr_null, ssr_star))
cat(sprintf("  SupWald-style statistic = %.2f (raw %.2f)\n",
            sup_wald, sup_wald_raw))

if (sup_wald == 0) {
  n_boot <- 0L
  p_value <- 1
  cat("  Threshold model does not improve structural SSR over the null; bootstrap skipped.\n")
} else {
  set.seed(2026)
  n_boot <- as.integer(Sys.getenv("IVTR_BOOT", "1000"))
  cat(sprintf("  Running %d bootstrap replications...\n", n_boot))

  boot_supwald <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    if (b %% 25 == 0) cat(sprintf("    bootstrap %d/%d\n", b, n_boot))

    rw <- sample(c(-1, 1), nrow(main), replace = TRUE)
    boot_dt <- copy(main)
    boot_dt[, log_wage := null_yhat + null_resid_vec * rw]

    boot_null_m <- tryCatch(
      feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
              urban + hhsize |
              wave |
              educ_years ~ i(birth_aimag_f),
            data = boot_dt, weights = ~hhweight, notes = FALSE),
      error = function(e) NULL)
    if (is.null(boot_null_m)) {
      boot_supwald[b] <- 0
      next
    }
    boot_null_ssr <- sum(boot_dt$hhweight * resid(boot_null_m)^2, na.rm = TRUE)

    boot_ssr_min <- Inf
    for (g in gamma_grid) {
      boot_ssr_min <- min(boot_ssr_min, compute_ssr(g, boot_dt))
    }

    boot_supwald[b] <- if (is.finite(boot_ssr_min)) {
      max(0, nrow(main) * (boot_null_ssr - boot_ssr_min) / boot_ssr_min)
    } else {
      0
    }
  }

  p_value <- mean(boot_supwald >= sup_wald, na.rm = TRUE)
}
cat(sprintf("\n  Bootstrap p-value = %.4f\n", p_value))

# --- Save results ------------------------------------------------------------
cat("\n", strrep("=", 60), "\n")
cat("  FINAL IV THRESHOLD RESULTS\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  Threshold variable = %s\n", THRESHOLD_LABEL))
cat(sprintf("  gamma* = %.4f %s\n", gamma_star, THRESHOLD_UNIT))
cat(sprintf("  beta_low_q  = %.4f (SE %.4f) => %.1f%% per year\n",
            b1, s1, 100 * (exp(b1) - 1)))
cat(sprintf("  beta_high_q = %.4f (SE %.4f) => %.1f%% per year\n",
            b2, s2, 100 * (exp(b2) - 1)))
cat(sprintf("  beta_high_q - beta_low_q = %.4f log points, p = %.4f\n",
            diff_est, p_eq))
p_report <- if (n_boot > 0 && p_value == 0) {
  sprintf("< %.4f", 1 / (n_boot + 1))
} else {
  sprintf("= %.4f", p_value)
}
cat(sprintf("  SupWald-style = %.2f, bootstrap p %s (B = %d)\n",
            sup_wald, p_report, n_boot))
cat("  Interpretation: threshold is exogenous/predetermined; slope difference is the key return-heterogeneity test.\n")

fwrite(results, file.path(BASE, "clean", "ivtr_grid_results.csv"))

ivtr_summary <- data.table(
  item = c("threshold_var", "threshold_label", "threshold_unit",
           "min_school_age_years",
           "gamma_star", "gamma_ci_low", "gamma_ci_high",
           "regime_1_label", "regime_2_label",
           "beta_1", "se_1", "return_1_pct",
           "beta_2", "se_2", "return_2_pct",
           "diff_beta", "diff_se", "diff_t", "diff_p",
           "fs_regime_1_separate", "fs_regime_2_separate",
           "sup_wald", "bootstrap_p", "bootstrap_B",
           "n_regime_1", "n_regime_2", "n_total",
           "limitation"),
  value = as.character(c(THRESHOLD_VAR, THRESHOLD_LABEL, THRESHOLD_UNIT,
                         MIN_SCHOOL_AGE_YEARS,
                         gamma_star, gamma_ci[1], gamma_ci[2],
                         sprintf("Low teacher-supply birth environment (q <= %.2f)", gamma_star),
                         sprintf("High teacher-supply birth environment (q > %.2f)", gamma_star),
                         b1, s1, 100 * (exp(b1) - 1),
                         b2, s2, 100 * (exp(b2) - 1),
                         diff_est, diff_se, t_eq, p_eq,
                         fs_low_sep, fs_high_sep, sup_wald, p_value, n_boot,
                         n_below, n_above, nrow(main),
                         "Threshold variable is predetermined EBS teacher supply; sample is younger cohorts with >=3 observed school-age EBS years."))
)
fwrite(ivtr_summary, file.path(BASE, "clean", "ivtr_headline_results.csv"))

cat("\n=== DONE: 05_ivtr_caner_hansen.R ===\n")
