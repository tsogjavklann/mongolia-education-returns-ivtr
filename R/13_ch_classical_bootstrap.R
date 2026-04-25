# =============================================================================
# 13_ch_classical_bootstrap.R -- Bootstrap test for classical CH thresholds
# =============================================================================
# This script adds a formal bootstrap p-value to the classical Caner-Hansen
# threshold sweep. It keeps educ_years endogenous, uses a pooled reduced form to
# form educ_hat, and tests threshold nonlinearity in the second-stage LS grid.
#
# The implementation uses weighted least squares matrices for speed. It is meant
# as a formal threshold-existence diagnostic, not as a search for significance.
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
B <- as.integer(Sys.getenv("CH_CLASSICAL_BOOT", "999"))
GRID_N <- as.integer(Sys.getenv("CH_CLASSICAL_GRID", "50"))

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
dt[, birth_aimag_f := factor(birth_aimag)]

aimag_cohort_means <- dt[birth_aimag %in% MN_AIMAG_CODES &
                           !is.na(birth_year) & !is.na(educ_years),
                         .(mean_educ = weighted.mean(educ_years, hhweight,
                                                     na.rm = TRUE),
                           n = .N),
                         by = .(birth_aimag, birth_year)]
setorder(aimag_cohort_means, birth_aimag, birth_year)
aimag_cohort_means[, prior_mean := {
  v <- rep(NA_real_, .N)
  csum <- 0
  cn <- 0
  for (i in seq_len(.N)) {
    v[i] <- if (cn > 0) csum / cn else NA_real_
    csum <- csum + mean_educ[i] * n[i]
    cn <- cn + n[i]
  }
  v
}, by = birth_aimag]

dt <- merge(dt,
            aimag_cohort_means[, .(birth_aimag, birth_year,
                                   aimag_prior_mean = prior_mean)],
            by = c("birth_aimag", "birth_year"), all.x = TRUE)

main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]
main[, reform2005_exp := pmax(0, pmin(12, (birth_year + 17) - 2005 + 1))]
main[, reform2008_exp := pmax(0, pmin(12, (birth_year + 17) - 2008 + 1))]
main[, age_at_2008 := 2008 - birth_year]

fit_reduced_form <- function(dat) {
  feols(educ_years ~ i(birth_aimag_f) + experience + experience_sq +
          sex + i(marital_f) + urban + hhsize |
          wave,
        data = dat, weights = ~hhweight, notes = FALSE)
}

make_grid <- function(q) {
  q_grid <- sort(unique(q))
  q_grid <- q_grid[vapply(q_grid, function(g) {
    mean(q <= g, na.rm = TRUE) >= TRIM &&
      mean(q > g, na.rm = TRUE) >= TRIM
  }, logical(1))]
  if (length(q_grid) > 80) {
    q_grid <- as.numeric(quantile(q, seq(TRIM, 1 - TRIM, length.out = GRID_N),
                                  na.rm = TRUE))
    q_grid <- unique(round(q_grid, 6))
  }
  q_grid
}

wls_ssr <- function(X, y, w) {
  fit <- lm.wfit(x = X, y = y, w = w)
  sum(w * fit$residuals^2, na.rm = TRUE)
}

null_fit_values <- function(X, y, w) {
  fit <- lm.wfit(x = X, y = y, w = w)
  y - fit$residuals
}

sup_wald_stat <- function(y, w, X_null, X_alt_list) {
  ssr_null <- wls_ssr(X_null, y, w)
  ssr_alt <- min(vapply(X_alt_list, wls_ssr, numeric(1), y = y, w = w))
  max(0, length(y) * (ssr_null - ssr_alt) / ssr_alt)
}

run_boot_candidate <- function(candidate) {
  q_var <- candidate$var
  sub <- main[!is.na(get(q_var))]
  if (!is.null(candidate$min_school_age_years)) {
    sub <- sub[ebs_school_age_years >= candidate$min_school_age_years]
  }
  if (nrow(sub) < 500) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "insufficient_N", N = nrow(sub)))
  }

  fs <- fit_reduced_form(sub)
  sub[, educ_hat := fitted(fs)]
  grid <- make_grid(sub[[q_var]])
  if (length(grid) < 2) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "degenerate_grid", N = nrow(sub)))
  }

  y <- sub$log_wage
  w <- sub$hhweight
  q <- sub[[q_var]]
  X_base <- model.matrix(~ experience + experience_sq + sex + marital_f +
                           urban + hhsize + factor(wave),
                         data = sub)
  X_null <- cbind(X_base, educ_hat = sub$educ_hat)
  X_alt_list <- lapply(grid, function(g) {
    below <- as.integer(q <= g)
    cbind(X_base,
          below = below,
          educ_hat_below = sub$educ_hat * below,
          educ_hat_above = sub$educ_hat * (1L - below))
  })

  ssrs <- vapply(X_alt_list, wls_ssr, numeric(1), y = y, w = w)
  best <- which.min(ssrs)
  gamma_star <- grid[best]
  obs_sup <- sup_wald_stat(y, w, X_null, X_alt_list)

  y0 <- null_fit_values(X_null, y, w)
  u0 <- y - y0
  boot_stats <- numeric(B)
  for (b in seq_len(B)) {
    yb <- y0 + u0 * sample(c(-1, 1), length(y), replace = TRUE)
    boot_stats[b] <- sup_wald_stat(yb, w, X_null, X_alt_list)
    if (b %% 50 == 0) {
      cat(sprintf("    %s: bootstrap %d/%d\n", candidate$short, b, B))
    }
  }

  p_boot <- (1 + sum(boot_stats >= obs_sup, na.rm = TRUE)) / (B + 1)
  data.table(
    proxy = candidate$label,
    q_var = q_var,
    status = "ok",
    N = nrow(sub),
    B = B,
    grid_n = length(grid),
    gamma_star = gamma_star,
    observed_sup_wald = obs_sup,
    bootstrap_p = p_boot,
    bootstrap_mean = mean(boot_stats, na.rm = TRUE),
    bootstrap_p50 = as.numeric(quantile(boot_stats, 0.50, na.rm = TRUE)),
    bootstrap_p90 = as.numeric(quantile(boot_stats, 0.90, na.rm = TRUE)),
    bootstrap_p95 = as.numeric(quantile(boot_stats, 0.95, na.rm = TRUE)),
    defensibility = candidate$defensibility,
    note = candidate$note
  )
}

candidates <- list(
  list(var = "ebs_teachers_per_1000_school_age",
       short = "D1",
       label = "D1: EBS school-age teachers per 1,000 students",
       defensibility = "Best theory",
       note = "Headline school-supply threshold.",
       min_school_age_years = 3L),
  list(var = "ebs_student_teacher_ratio_school_age",
       short = "D3",
       label = "D3: EBS school-age student-teacher ratio",
       defensibility = "Strong theory",
       note = "School-age class-size/school-quality threshold.",
       min_school_age_years = 3L),
  list(var = "ebs_student_teacher_ratio_age12",
       short = "D5",
       label = "D5: EBS age-12 student-teacher ratio",
       defensibility = "Strong but smaller N",
       note = "Exact age-12 school-quality threshold; smaller young-cohort sample.",
       min_school_age_years = NULL),
  # H4 fix: C2 (reform2005_exp) is another cohort/reform timing proxy;
  # we omit it and keep cohort variation in C1/C3 only.
  # H5 fix: C3 (reform2008_exp) is effectively a binary post-1991 cohort
  # indicator under the 15% trim, so we relabel accordingly.
  list(var = "reform2008_exp",
       short = "C3",
       label = "C3: 2008 reform cohort dummy (effectively binary; born >= 1991)",
       defensibility = "Exogenous binary cohort indicator",
       note = "Single trim-feasible cut at gamma=0; cohort-difference test, not continuous CH threshold.",
       min_school_age_years = NULL),
  list(var = "log_dist_ub",
       short = "G1",
       label = "G1: log distance to UB",
       defensibility = "Geographic diagnostic",
       note = "Predetermined remoteness, but may directly affect wages.",
       min_school_age_years = NULL),
  list(var = "aimag_prior_mean",
       short = "B1",
       label = "B1: birth-aimag prior-cohort mean education",
       defensibility = "Diagnostic only",
       note = "Prior regional education environment, but constructed from HSES outcomes.",
       min_school_age_years = NULL)
)

cat(sprintf("Classical CH bootstrap: B=%d, grid target=%d\n", B, GRID_N))
results <- rbindlist(lapply(candidates, function(candidate) {
  cat(sprintf("  Running bootstrap: %s\n", candidate$label))
  tryCatch(run_boot_candidate(candidate),
           error = function(e) data.table(proxy = candidate$label,
                                          q_var = candidate$var,
                                          status = paste("error:", e$message)))
}), fill = TRUE)

cat("\n=== Classical CH bootstrap results ===\n")
print(results[, .(proxy, status, N, B, gamma_star,
                  observed_sup_wald = round(observed_sup_wald, 2),
                  bootstrap_p = round(bootstrap_p, 4),
                  bootstrap_p95 = round(bootstrap_p95, 2),
                  defensibility)])

fwrite(results, file.path(BASE, "clean", "ch_classical_bootstrap.csv"))
fwrite(results, file.path(OUT_TABS, "t9_ch_classical_bootstrap.csv"))
fwrite(results, file.path(IN_TABS, "t9_ch_classical_bootstrap.csv"))

cat("\nSaved: ch_classical_bootstrap.csv and t9_ch_classical_bootstrap.csv\n")
