# =============================================================================
# 16_phase_c_extensions.R -- Methodological extensions (Phase C)
# =============================================================================
# Implements two additional methodological checks requested in the audit:
#   M8     Wild cluster bootstrap SE for the headline IV (22 < 30 clusters).
#   AR CI  Anderson-Rubin weak-IV-robust confidence interval diagnostic for
#          the birth_aimag headline IV.
#
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))

set.seed(2026)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
ROOT <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric"
OUT_TABS <- file.path(ROOT, "outputs", "tables")
IN_TABS <- file.path(ROOT, "inputs", "tables")

MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
dt[, birth_aimag_f := factor(birth_aimag)]

main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]

# =============================================================================
# M8: Wild cluster bootstrap SE for headline IV (22 aimag clusters)
# =============================================================================
cat("\n=== M8: Wild cluster bootstrap SE for headline 2SLS ===\n")

iv_main <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                   urban + hhsize | wave |
                   educ_years ~ i(birth_aimag),
                 data = main, weights = ~hhweight,
                 cluster = ~newaimag, notes = FALSE)

beta_iv <- coef(iv_main)["fit_educ_years"]
se_clust <- se(iv_main)["fit_educ_years"]
cat(sprintf("Standard cluster SE: beta = %.4f, SE = %.4f, t = %.2f\n",
            beta_iv, se_clust, beta_iv / se_clust))
cat(sprintf("Standard 95%% CI: [%.4f, %.4f]\n",
            beta_iv - 1.96 * se_clust, beta_iv + 1.96 * se_clust))

# Wild cluster bootstrap with Rademacher sign flips at the cluster level.
# This manual implementation is used because fwildclusterboot does not directly
# support this feols IV structure.
B_WCB <- as.integer(Sys.getenv("WCB_B", "499"))
cat(sprintf("Wild cluster bootstrap: B = %d (cluster level: newaimag)\n", B_WCB))

main[, resid_iv := resid(iv_main)]
fitted_iv <- fitted(iv_main)
clusters <- main$newaimag
unique_clust <- unique(clusters)
cat(sprintf("Number of clusters: %d\n", length(unique_clust)))

boot_betas <- numeric(B_WCB)
for (b in seq_len(B_WCB)) {
  rad <- sample(c(-1, 1), length(unique_clust), replace = TRUE)
  rad_map <- rad[match(clusters, unique_clust)]
  boot_dt <- copy(main)
  boot_dt[, log_wage := fitted_iv + resid_iv * rad_map]

  m <- tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize | wave |
            educ_years ~ i(birth_aimag),
          data = boot_dt, weights = ~hhweight,
          cluster = ~newaimag, notes = FALSE),
    error = function(e) NULL)
  boot_betas[b] <- if (!is.null(m)) coef(m)["fit_educ_years"] else NA_real_
  if (b %% 100 == 0) cat(sprintf("  WCB iter %d/%d\n", b, B_WCB))
}

boot_betas <- boot_betas[!is.na(boot_betas)]
wcb_se <- sd(boot_betas)
wcb_t_pct <- quantile(boot_betas - beta_iv, c(0.025, 0.975))
wcb_ci <- beta_iv - rev(wcb_t_pct)
cat(sprintf("Wild cluster bootstrap: SE = %.4f (vs %.4f standard)\n",
            wcb_se, se_clust))
cat(sprintf("Wild cluster 95%% CI: [%.4f, %.4f]\n", wcb_ci[1], wcb_ci[2]))

m8_tab <- data.table(
  estimator = c("Standard cluster SE", "Wild cluster bootstrap"),
  beta = c(beta_iv, beta_iv),
  se = c(se_clust, wcb_se),
  ci_low = c(beta_iv - 1.96 * se_clust, wcb_ci[1]),
  ci_high = c(beta_iv + 1.96 * se_clust, wcb_ci[2]),
  notes = c("fixest cluster SE",
            sprintf("WCB B=%d, %d clusters", B_WCB, length(unique_clust)))
)
print(m8_tab)
fwrite(m8_tab, file.path(OUT_TABS, "t14_m8_wild_cluster_bootstrap.csv"))
fwrite(m8_tab, file.path(IN_TABS, "t14_m8_wild_cluster_bootstrap.csv"))

# =============================================================================
# Anderson-Rubin weak-IV-robust CI for birth_aimag IV
# =============================================================================
cat("\n=== AR CI: weak-IV-robust 95% CI for birth_aimag IV ===\n")

# AR diagnostic: for a candidate beta_0, regress y - beta_0 * educ on
# instruments. Under H0, instruments should not jointly explain the transformed
# outcome after controls.
beta_grid <- seq(0.02, 0.30, by = 0.005)
ar_pvals <- numeric(length(beta_grid))

for (i in seq_along(beta_grid)) {
  b0 <- beta_grid[i]
  main[, y_tilde := log_wage - b0 * educ_years]
  m_ar <- feols(y_tilde ~ i(birth_aimag) + experience + experience_sq +
                  sex + i(marital_f) + urban + hhsize | wave,
                data = main, weights = ~hhweight, cluster = ~newaimag,
                notes = FALSE)
  w <- tryCatch({
    tmp <- NULL
    capture.output(tmp <- wald(m_ar, "^birth_aimag::"))
    tmp
  }, error = function(e) NULL)
  ar_pvals[i] <- if (!is.null(w)) w$p else NA_real_
}

ar_accept <- beta_grid[!is.na(ar_pvals) & ar_pvals > 0.05]
if (length(ar_accept) > 0) {
  ar_ci <- range(ar_accept)
  ar_status <- "non-empty"
} else {
  ar_ci <- c(NA_real_, NA_real_)
  ar_status <- "EMPTY across the tested grid"
}

cat(sprintf("Standard 2SLS 95%% CI: [%.4f, %.4f]\n",
            beta_iv - 1.96 * se_clust, beta_iv + 1.96 * se_clust))
cat(sprintf("Anderson-Rubin 95%% CI: %s\n",
            ifelse(is.na(ar_ci[1]),
                   "EMPTY across the tested grid",
                   sprintf("[%.4f, %.4f]", ar_ci[1], ar_ci[2]))))
cat(sprintf("AR CI status: %s\n", ar_status))
cat("Note: An empty AR CI is treated as a diagnostic warning, not as a\n")
cat("standalone proof. It reinforces the Sargan/exogeneity caveat for the\n")
cat("birth_aimag dummy instrument set.\n")

ar_tab <- data.table(
  estimator = c("Standard 2SLS CI", "Anderson-Rubin CI"),
  beta_point = c(beta_iv, beta_iv),
  ci_low = c(beta_iv - 1.96 * se_clust, ar_ci[1]),
  ci_high = c(beta_iv + 1.96 * se_clust, ar_ci[2])
)
print(ar_tab)
fwrite(ar_tab, file.path(OUT_TABS, "t15_ar_robust_ci.csv"))
fwrite(ar_tab, file.path(IN_TABS, "t15_ar_robust_ci.csv"))

cat("\n=== DONE: 16_phase_c_extensions.R ===\n")
