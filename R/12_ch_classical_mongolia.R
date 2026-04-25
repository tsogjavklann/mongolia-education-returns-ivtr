# =============================================================================
# 12_ch_classical_mongolia.R -- Classical Caner-Hansen threshold sweep
# =============================================================================
# Implements the three-step logic in Caner & Hansen (2004):
#   1. Pooled reduced form for the endogenous regressor educ_years.
#   2. Grid-search threshold using fitted educ_years in the structural equation.
#   3. Estimate regime-specific slopes by 2SLS on the split samples.
#
# The threshold variable q must be predetermined/exogenous. This script tests a
# Mongolia-focused set of threshold proxies motivated by official education
# reforms, regional school supply, distance/remoteness, and prior regional
# education environment. It does not select a threshold merely by significance.
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))

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

# Prior-cohort mean education in birth aimag, diagnostic only.
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

# Mongolia-specific education reform exposure:
# 2005 shifted general secondary education from 10 to 11 years; 2008 shifted it
# to 12 years and lowered school-entry age. These are exogenous cohort states.
main[, reform2005_exp := pmax(0, pmin(12, (birth_year + 17) - 2005 + 1))]
main[, reform2008_exp := pmax(0, pmin(12, (birth_year + 17) - 2008 + 1))]
main[, age_at_2008 := 2008 - birth_year]
cat(sprintf("Classical CH main IV sample: %d\n", nrow(main)))

fit_reduced_form <- function(dat) {
  feols(educ_years ~ i(birth_aimag_f) + experience + experience_sq +
          sex + i(marital_f) + urban + hhsize |
          wave,
        data = dat, weights = ~hhweight, notes = FALSE)
}

fit_ch_ls <- function(dat, gamma, q_var) {
  x <- copy(dat)
  x[, below := as.integer(get(q_var) <= gamma)]
  x[, above := 1L - below]
  x[, educ_hat_below := educ_hat * below]
  x[, educ_hat_above := educ_hat * above]
  tryCatch(
    feols(log_wage ~ educ_hat_below + educ_hat_above + below +
            experience + experience_sq + sex + i(marital_f) + urban + hhsize |
            wave,
          data = x, weights = ~hhweight, notes = FALSE),
    error = function(e) NULL
  )
}

weighted_ssr <- function(model, dat) {
  if (is.null(model)) return(Inf)
  sum(dat$hhweight * resid(model)^2, na.rm = TRUE)
}

fit_split_iv <- function(dat, q_var, gamma) {
  x <- copy(dat)
  x[, below := as.integer(get(q_var) <= gamma)]
  fit_one <- function(sub) {
    if (nrow(sub) < 300 || uniqueN(sub$birth_aimag) < 4) return(NULL)
    tryCatch(
      feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
              urban + hhsize |
              wave |
              educ_years ~ i(birth_aimag_f),
            data = sub, weights = ~hhweight, cluster = ~newaimag,
            notes = FALSE),
      error = function(e) NULL
    )
  }
  low <- fit_one(x[below == 1])
  high <- fit_one(x[below == 0])
  list(low = low, high = high,
       n_low = nrow(x[below == 1]), n_high = nrow(x[below == 0]))
}

fit_joint_iv_at_gamma <- function(dat, q_var, gamma) {
  x <- copy(dat)
  x[, below := as.integer(get(q_var) <= gamma)]
  x[, above := 1L - below]
  x[, educ_below := educ_years * below]
  x[, educ_above := educ_years * above]
  tryCatch(
    feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
            urban + hhsize + below |
            wave |
            educ_below + educ_above ~
              i(birth_aimag_f, below) + i(birth_aimag_f, above),
          data = x, weights = ~hhweight, cluster = ~newaimag,
          notes = FALSE),
    error = function(e) NULL
  )
}

joint_diff_test <- function(model) {
  if (is.null(model)) {
    return(list(diff = NA_real_, se = NA_real_, t = NA_real_, p = NA_real_))
  }
  cn <- names(coef(model))
  if (!all(c("fit_educ_below", "fit_educ_above") %in% cn)) {
    return(list(diff = NA_real_, se = NA_real_, t = NA_real_, p = NA_real_))
  }
  b1 <- coef(model)["fit_educ_below"]
  b2 <- coef(model)["fit_educ_above"]
  V <- vcov(model)
  se <- sqrt(V["fit_educ_below", "fit_educ_below"] +
               V["fit_educ_above", "fit_educ_above"] -
               2 * V["fit_educ_below", "fit_educ_above"])
  t <- (b2 - b1) / se
  list(diff = b2 - b1, se = se, t = t, p = 2 * pnorm(-abs(t)))
}

run_ch_candidate <- function(candidate) {
  q_var <- candidate$var
  sub <- main[!is.na(get(q_var))]
  if (!is.null(candidate$min_school_age_years)) {
    sub <- sub[ebs_school_age_years >= candidate$min_school_age_years]
  }
  if (nrow(sub) < 500) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "insufficient_N", N = nrow(sub),
                      theory_rank = candidate$theory_rank,
                      defensibility = candidate$defensibility,
                      note = candidate$note))
  }

  fs <- fit_reduced_form(sub)
  sub[, educ_hat := fitted(fs)]
  fs_stat <- fitstat(fs, "wald")$wald$stat
  fs_r2 <- fitstat(fs, "r2")[[1]]

  q <- sub[[q_var]]
  q_grid <- sort(unique(q))
  q_grid <- q_grid[vapply(q_grid, function(g) {
    mean(q <= g, na.rm = TRUE) >= TRIM &&
      mean(q > g, na.rm = TRUE) >= TRIM
  }, logical(1))]
  if (length(q_grid) > 80) {
    q_grid <- as.numeric(quantile(q, seq(TRIM, 1 - TRIM, length.out = 50),
                                  na.rm = TRUE))
    q_grid <- unique(round(q_grid, 6))
  }
  if (length(q_grid) < 2) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "degenerate_grid", N = nrow(sub),
                      theory_rank = candidate$theory_rank,
                      defensibility = candidate$defensibility,
                      note = candidate$note))
  }

  ssrs <- numeric(length(q_grid))
  for (i in seq_along(q_grid)) {
    g <- q_grid[i]
    m <- fit_ch_ls(sub, g, q_var)
    ssrs[i] <- weighted_ssr(m, sub)
  }
  best <- which.min(ssrs)
  gamma_star <- q_grid[best]
  ssr_star <- ssrs[best]
  null_ls <- feols(log_wage ~ educ_hat + experience + experience_sq +
                     sex + i(marital_f) + urban + hhsize |
                     wave,
                   data = sub, weights = ~hhweight, notes = FALSE)
  ssr_null <- weighted_ssr(null_ls, sub)
  sup_wald <- max(0, nrow(sub) * (ssr_null - ssr_star) / ssr_star)

  split <- fit_split_iv(sub, q_var, gamma_star)
  b_low <- if (!is.null(split$low)) coef(split$low)["fit_educ_years"] else NA_real_
  s_low <- if (!is.null(split$low)) se(split$low)["fit_educ_years"] else NA_real_
  b_high <- if (!is.null(split$high)) coef(split$high)["fit_educ_years"] else NA_real_
  s_high <- if (!is.null(split$high)) se(split$high)["fit_educ_years"] else NA_real_
  fs_low <- if (!is.null(split$low)) fitstat(split$low, "ivf")$ivf1$stat else NA_real_
  fs_high <- if (!is.null(split$high)) fitstat(split$high, "ivf")$ivf1$stat else NA_real_

  joint <- fit_joint_iv_at_gamma(sub, q_var, gamma_star)
  jd <- joint_diff_test(joint)
  # H6 fix: report joint-IV regime betas as the primary specification (full
  # instrument efficiency). Split-sample betas are kept in the table only as
  # an auxiliary footnote, so paper text and headline tables reference the
  # joint coefficients to avoid the split-vs-joint mismatch flagged in audit.
  if (!is.null(joint) &&
      all(c("fit_educ_below", "fit_educ_above") %in% names(coef(joint)))) {
    joint_b_low <- coef(joint)["fit_educ_below"]
    joint_s_low <- se(joint)["fit_educ_below"]
    joint_b_high <- coef(joint)["fit_educ_above"]
    joint_s_high <- se(joint)["fit_educ_above"]
  } else {
    joint_b_low <- joint_s_low <- joint_b_high <- joint_s_high <- NA_real_
  }

  data.table(
    proxy = candidate$label,
    q_var = q_var,
    status = "ok",
    N = nrow(sub),
    theory_rank = candidate$theory_rank,
    defensibility = candidate$defensibility,
    note = candidate$note,
    gamma_star = gamma_star,
    ch_first_stage_wald = fs_stat,
    ch_first_stage_r2 = fs_r2,
    ch_ssr_null = ssr_null,
    ch_ssr_threshold = ssr_star,
    ch_sup_wald = sup_wald,
    # Primary: joint-IV regime betas (full instrument efficiency)
    joint_beta_low_q = joint_b_low,
    joint_se_low_q = joint_s_low,
    joint_return_low_q_pct = 100 * (exp(joint_b_low) - 1),
    joint_beta_high_q = joint_b_high,
    joint_se_high_q = joint_s_high,
    joint_return_high_q_pct = 100 * (exp(joint_b_high) - 1),
    joint_diff_high_minus_low = jd$diff,
    joint_diff_se = jd$se,
    joint_diff_t = jd$t,
    joint_diff_p = jd$p,
    # Auxiliary: split-sample betas (separate first stages, weak in small regimes)
    split_beta_low_q = b_low,
    split_se_low_q = s_low,
    split_return_low_q_pct = 100 * (exp(b_low) - 1),
    split_beta_high_q = b_high,
    split_se_high_q = s_high,
    split_return_high_q_pct = 100 * (exp(b_high) - 1),
    n_low_q = split$n_low,
    n_high_q = split$n_high,
    fs_low_q_separate = fs_low,
    fs_high_q_separate = fs_high
  )
}

candidates <- list(
  list(var = "ebs_teachers_per_1000_school_age",
       label = "D1: EBS school-age teachers per 1,000 students",
       theory_rank = 1L, defensibility = "Best theory",
       note = "Own school-age regional teacher supply; predetermined.",
       min_school_age_years = 3L),
  list(var = "ebs_schools_per_1000_school_age",
       label = "D2: EBS school-age schools per 1,000 students",
       theory_rank = 2L, defensibility = "Strong theory",
       note = "Own school-age school access; predetermined.",
       min_school_age_years = 3L),
  list(var = "ebs_student_teacher_ratio_school_age",
       label = "D3: EBS school-age student-teacher ratio",
       theory_rank = 3L, defensibility = "Strong theory",
       note = "Class-size/school-quality proxy during school ages; predetermined.",
       min_school_age_years = 3L),
  list(var = "ebs_teachers_per_1000_age12",
       label = "D4: EBS age-12 teachers per 1,000 students",
       theory_rank = 4L, defensibility = "Strong but smaller N",
       note = "Exact age-12 regional teacher supply.",
       min_school_age_years = NULL),
  list(var = "ebs_student_teacher_ratio_age12",
       label = "D5: EBS age-12 student-teacher ratio",
       theory_rank = 5L, defensibility = "Strong but smaller N",
       note = "Exact age-12 class-size/school-quality proxy.",
       min_school_age_years = NULL),
  list(var = "ebs_teachers_per_1000_2000",
       label = "D6: EBS 2000 teachers per 1,000 students",
       theory_rank = 6L, defensibility = "Initial condition",
       note = "Predetermined regional initial condition; not own exposure for older cohorts.",
       min_school_age_years = NULL),
  list(var = "ebs_student_teacher_ratio_2000",
       label = "D7: EBS 2000 student-teacher ratio",
       theory_rank = 7L, defensibility = "Initial condition",
       note = "Predetermined regional initial class-size proxy.",
       min_school_age_years = NULL),
  list(var = "birth_year",
       label = "C1: birth-year cohort",
       theory_rank = 8L, defensibility = "Purely exogenous",
       note = "Tests cohort/reform-period heterogeneity, not supply directly.",
       min_school_age_years = NULL),
  # H4 fix: C2 (reform2005_exp) is another cohort/reform timing proxy;
  # it is not an independent threshold family, so we drop C2.
  # H5 fix: C3 (reform2008_exp) collapses to a binary cohort dummy under the
  # 15% trim, so we relabel it explicitly.
  list(var = "reform2008_exp",
       label = "C3: 2008 reform cohort dummy (effectively binary; born >= 1991)",
       theory_rank = 9L, defensibility = "Exogenous binary cohort indicator",
       note = "Trim leaves a single cut at gamma=0; report as cohort-difference test, not continuous CH threshold.",
       min_school_age_years = NULL),
  list(var = "age_at_2008",
       label = "C4: age at 2008 education reform",
       theory_rank = 10L, defensibility = "Purely exogenous",
       note = "Alternative cohort-state version of reform exposure.",
       min_school_age_years = NULL),
  list(var = "log_dist_ub",
       label = "G1: log distance to UB",
       theory_rank = 11L, defensibility = "Geographic diagnostic",
       note = "Predetermined remoteness; may also proxy labor-market access.",
       min_school_age_years = NULL),
  list(var = "aimag_prior_mean",
       label = "B1: birth-aimag prior-cohort mean education",
       theory_rank = 12L, defensibility = "Diagnostic only",
       note = "Predetermined relative to person but constructed from HSES outcomes.",
       min_school_age_years = NULL),
  list(var = "loo_mean_educ",
       label = "A1: leave-one-out local mean education",
       theory_rank = 14L, defensibility = "Diagnostic only",
       note = "Outcome-based environment proxy; not cleanly exogenous.",
       min_school_age_years = NULL),
  list(var = "educ_years",
       label = "INVALID: educ_years threshold",
       theory_rank = 99L, defensibility = "Invalid for CH",
       note = "Endogenous regressor and threshold variable are the same.",
       min_school_age_years = NULL)
)

cat("\n=== Classical Caner-Hansen threshold sweep ===\n")
results <- rbindlist(lapply(candidates, function(candidate) {
  cat(sprintf("  Running: %s\n", candidate$label))
  tryCatch(run_ch_candidate(candidate),
           error = function(e) data.table(proxy = candidate$label,
                                          q_var = candidate$var,
                                          status = paste("error:", e$message),
                                          N = NA_integer_,
                                          theory_rank = candidate$theory_rank,
                                          defensibility = candidate$defensibility,
                                          note = candidate$note))
}), fill = TRUE)

results[, recommended_candidate :=
          status == "ok" &
          theory_rank == min(theory_rank[status == "ok" & theory_rank < 99],
                             na.rm = TRUE)]

cat("\n=== Classical CH Results (joint-IV primary) ===\n")
print(results[order(theory_rank),
              .(proxy, status, N, gamma_star,
                joint_low = round(joint_return_low_q_pct, 1),
                joint_high = round(joint_return_high_q_pct, 1),
                diff = round(joint_diff_high_minus_low, 4),
                diff_p = round(joint_diff_p, 4),
                ch_sup_wald = round(ch_sup_wald, 2),
                recommended_candidate)])

cat("\n=== Auxiliary split-sample regime betas (footnote) ===\n")
print(results[order(theory_rank),
              .(proxy, status,
                split_low = round(split_return_low_q_pct, 1),
                split_high = round(split_return_high_q_pct, 1),
                fs_low = round(fs_low_q_separate, 2),
                fs_high = round(fs_high_q_separate, 2))])

fwrite(results, file.path(BASE, "clean", "ch_classical_threshold_comparison.csv"))
fwrite(results, file.path(OUT_TABS, "t8_ch_classical_threshold_comparison.csv"))
fwrite(results, file.path(IN_TABS, "t8_ch_classical_threshold_comparison.csv"))

best <- results[recommended_candidate == TRUE][1]
if (nrow(best) == 1) {
  cat(sprintf("\nRecommended classical CH proxy: %s\n", best$proxy))
  cat(sprintf("  gamma* = %.4f, N = %s, slope-diff p = %.4f\n",
              best$gamma_star, format(best$N, big.mark = ","),
              best$joint_diff_p))
}

cat("\nSaved: ch_classical_threshold_comparison.csv and t8_ch_classical_threshold_comparison.csv\n")
