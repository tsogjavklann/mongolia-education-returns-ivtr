# =============================================================================
# 11_threshold_comparison.R -- Compare exogenous threshold proxies for IVTR
# =============================================================================
# Goal: replace the endogenous educ_years threshold with a defensible,
# predetermined threshold variable. The ranking below is theory-first: we do not
# pick a threshold merely because it gives significance.
#
# Preferred logic for Mongolia:
#   1. Birth-aimag education supply during school ages (EBS teachers/schools per
#      1,000 students): closest to "initial condition" and predetermined.
#   2. Birth-aimag 2000 initial EBS supply: full-sample regional environment,
#      but not every older person's own school-age condition.
#   3. Cohort/birth-year: cleanly predetermined but changes interpretation.
#   4. HSES education means / LOO means: diagnostic only, outcome-based.
#   5. educ_years: invalid as Caner-Hansen threshold because it is endogenous.
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

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]
dt[, birth_aimag_f := factor(birth_aimag)]

required_ebs <- c("ebs_teachers_per_1000_school_age",
                  "ebs_schools_per_1000_school_age",
                  "ebs_student_teacher_ratio_school_age",
                  "ebs_student_teacher_ratio_age12",
                  "ebs_teachers_per_1000_2000",
                  "ebs_schools_per_1000_2000",
                  "ebs_student_teacher_ratio_2000",
                  "ebs_school_age_years")
if (!all(required_ebs %in% names(dt))) {
  stop("EBS threshold variables are missing. Run R/03b_iv_construction.R first.")
}

# -----------------------------------------------------------------------------
# Diagnostic candidate: prior-cohort mean education in birth aimag
# -----------------------------------------------------------------------------
# This is strictly older cohorts only, but it is still computed from HSES wage
# earners' schooling outcomes. We keep it as diagnostic, not a headline proxy.
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
cat(sprintf("Main IV sample: %d\n", nrow(main)))

# -----------------------------------------------------------------------------
# Joint 2SLS estimator at a given gamma, given threshold variable q
# -----------------------------------------------------------------------------
estimate_joint_iv <- function(q_var, gamma, dat, cluster_se = FALSE) {
  dat <- copy(dat)
  dat[, below := as.integer(get(q_var) <= gamma)]
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

compute_ssr <- function(q_var, gamma, dat) {
  m <- estimate_joint_iv(q_var, gamma, dat, cluster_se = FALSE)
  if (is.null(m)) return(Inf)
  sum(dat$hhweight * resid(m)^2, na.rm = TRUE)
}

null_iv <- function(dat, cluster_se = FALSE) {
  cluster_formula <- if (cluster_se) ~newaimag else NULL
  feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
          urban + hhsize |
          wave |
          educ_years ~ i(birth_aimag_f),
        data = dat, weights = ~hhweight, cluster = cluster_formula,
        notes = FALSE)
}

separate_regime_f <- function(q_var, gamma, dat) {
  out <- c(NA_real_, NA_real_)
  for (j in 0:1) {
    sub <- dat[as.integer(get(q_var) <= gamma) == j]
    if (nrow(sub) < 200 || uniqueN(sub$birth_aimag) < 3) next
    m <- tryCatch(
      feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
              urban + hhsize |
              wave | educ_years ~ i(birth_aimag_f),
            data = sub, weights = ~hhweight, cluster = ~newaimag,
            notes = FALSE),
      error = function(e) NULL
    )
    if (!is.null(m)) out[j + 1L] <- fitstat(m, "ivf")$ivf1$stat
  }
  c(fs_above = out[1], fs_below = out[2])
}

# -----------------------------------------------------------------------------
# Grid search over q with 15% trim per regime
# -----------------------------------------------------------------------------
run_threshold <- function(candidate, dat) {
  q_var <- candidate$var
  sub <- dat[!is.na(get(q_var))]
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

  q <- sub[[q_var]]
  q_uniq <- sort(unique(q))
  keep <- vapply(q_uniq, function(g) {
    mean(q <= g, na.rm = TRUE) >= 0.15 &&
      mean(q > g, na.rm = TRUE) >= 0.15
  }, logical(1))
  grid <- q_uniq[keep]

  if (length(grid) > 60) {
    grid <- as.numeric(quantile(q, seq(0.15, 0.85, length.out = 40),
                                na.rm = TRUE))
    grid <- unique(round(grid, 6))
  }
  if (length(grid) < 2) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "degenerate_grid", N = nrow(sub),
                      theory_rank = candidate$theory_rank,
                      defensibility = candidate$defensibility,
                      note = candidate$note))
  }

  ssrs <- vapply(grid, compute_ssr, numeric(1), q_var = q_var, dat = sub)
  best_i <- which.min(ssrs)
  gamma_star <- grid[best_i]
  ssr_star <- ssrs[best_i]

  m_star <- estimate_joint_iv(q_var, gamma_star, sub, cluster_se = TRUE)
  if (is.null(m_star)) {
    return(data.table(proxy = candidate$label, q_var = q_var,
                      status = "estimation_failed", N = nrow(sub),
                      theory_rank = candidate$theory_rank,
                      defensibility = candidate$defensibility,
                      note = candidate$note))
  }

  b1 <- coef(m_star)["fit_educ_below"]
  b2 <- coef(m_star)["fit_educ_above"]
  s1 <- se(m_star)["fit_educ_below"]
  s2 <- se(m_star)["fit_educ_above"]
  V <- vcov(m_star)
  diff_est <- b2 - b1
  diff_se <- sqrt(V["fit_educ_below", "fit_educ_below"] +
                    V["fit_educ_above", "fit_educ_above"] -
                    2 * V["fit_educ_below", "fit_educ_above"])
  t_eq <- diff_est / diff_se
  p_eq <- 2 * pnorm(-abs(t_eq))

  null_m <- null_iv(sub, cluster_se = FALSE)
  ssr_null <- sum(sub$hhweight * resid(null_m)^2, na.rm = TRUE)
  sup_wald_raw <- nrow(sub) * (ssr_null - ssr_star) / ssr_star
  sup_wald <- max(0, sup_wald_raw)

  n_below <- sum(sub[[q_var]] <= gamma_star, na.rm = TRUE)
  n_above <- nrow(sub) - n_below
  fs <- separate_regime_f(q_var, gamma_star, sub)

  data.table(
    proxy = candidate$label,
    q_var = q_var,
    status = "ok",
    N = nrow(sub),
    theory_rank = candidate$theory_rank,
    defensibility = candidate$defensibility,
    note = candidate$note,
    gamma_star = gamma_star,
    beta_low_q = b1,
    se_low_q = s1,
    return_low_q_pct = 100 * (exp(b1) - 1),
    beta_high_q = b2,
    se_high_q = s2,
    return_high_q_pct = 100 * (exp(b2) - 1),
    diff_high_minus_low = diff_est,
    diff_se = diff_se,
    diff_t = t_eq,
    diff_p = p_eq,
    ssr_null = ssr_null,
    ssr_threshold = ssr_star,
    sup_wald_raw = sup_wald_raw,
    sup_wald = sup_wald,
    ssr_improved = ssr_star < ssr_null,
    n_low_q = n_below,
    n_high_q = n_above,
    min_regime_n = min(n_below, n_above),
    fs_low_q_separate = fs[["fs_below"]],
    fs_high_q_separate = fs[["fs_above"]]
  )
}

cat("\n=== Comparing threshold proxies ===\n")

candidates <- list(
  list(var = "ebs_teachers_per_1000_school_age",
       label = "D1: EBS school-age teachers per 1,000 students",
       theory_rank = 1L,
       defensibility = "Best theory",
       note = "Predetermined birth-aimag school supply during ages 6-17; uses obs with >=3 EBS years.",
       min_school_age_years = 3L),
  list(var = "ebs_schools_per_1000_school_age",
       label = "D2: EBS school-age schools per 1,000 students",
       theory_rank = 2L,
       defensibility = "Strong theory",
       note = "Predetermined school access during ages 6-17; uses obs with >=3 EBS years.",
       min_school_age_years = 3L),
  list(var = "ebs_student_teacher_ratio_school_age",
       label = "D3: EBS school-age student-teacher ratio",
       theory_rank = 3L,
       defensibility = "Strong theory",
       note = "Predetermined class-size/school-quality proxy during ages 6-17; uses obs with >=3 EBS years.",
       min_school_age_years = 3L),
  list(var = "ebs_teachers_per_1000_age12",
       label = "D4: EBS age-12 teachers per 1,000 students",
       theory_rank = 4L,
       defensibility = "Strong but smaller N",
       note = "Exact birth-aimag supply at age 12; smaller young-cohort sample.",
       min_school_age_years = NULL),
  list(var = "ebs_schools_per_1000_age12",
       label = "D5: EBS age-12 schools per 1,000 students",
       theory_rank = 5L,
       defensibility = "Strong but smaller N",
       note = "Exact birth-aimag school access at age 12; smaller young-cohort sample.",
       min_school_age_years = NULL),
  list(var = "ebs_student_teacher_ratio_age12",
       label = "D6: EBS age-12 student-teacher ratio",
       theory_rank = 6L,
       defensibility = "Strong but smaller N",
       note = "Exact birth-aimag class-size/school-quality proxy at age 12; smaller young-cohort sample.",
       min_school_age_years = NULL),
  list(var = "ebs_teachers_per_1000_2000",
       label = "D7: EBS 2000 teachers per 1,000 students",
       theory_rank = 7L,
       defensibility = "Full-sample initial condition",
       note = "Predetermined regional supply in 2000; full sample but not older cohorts' own school-age exposure.",
       min_school_age_years = NULL),
  list(var = "ebs_schools_per_1000_2000",
       label = "D8: EBS 2000 schools per 1,000 students",
       theory_rank = 8L,
       defensibility = "Full-sample initial condition",
       note = "Predetermined regional school access in 2000; full sample but looser cohort interpretation.",
       min_school_age_years = NULL),
  list(var = "ebs_student_teacher_ratio_2000",
       label = "D9: EBS 2000 student-teacher ratio",
       theory_rank = 9L,
       defensibility = "Full-sample initial condition",
       note = "Predetermined regional class-size/school-quality proxy in 2000; full sample but looser cohort interpretation.",
       min_school_age_years = NULL),
  list(var = "birth_year",
       label = "C: birth_year cohort",
       theory_rank = 10L,
       defensibility = "Exogenous but different story",
       note = "Fully predetermined; tests cohort heterogeneity rather than education-access threshold.",
       min_school_age_years = NULL),
  # H4 fix: C2 (reform2005_exp) is another cohort/reform timing proxy,
  # not an independent threshold family, so we removed it from the list.
  # H5 fix: C3 (reform2008_exp) under the 15% trim collapses to a single
  # threshold cut at gamma=0 (born <=1990 vs >=1991); the result is effectively
  # a binary post-1991 cohort dummy, not a continuous CH threshold.
  list(var = "reform2008_exp",
       label = "C3: 2008 reform cohort dummy (effectively binary; born >= 1991)",
       theory_rank = 11L,
       defensibility = "Exogenous binary cohort indicator",
       note = "Cohort exposure to 2008 12-year system. The grid trim leaves only one cut, so this is reported as a cohort-difference test, not a continuous CH threshold.",
       min_school_age_years = NULL),
  list(var = "age_at_2008",
       label = "C4: age at 2008 education reform",
       theory_rank = 12L,
       defensibility = "Exogenous but different story",
       note = "Alternative cohort-state version of reform exposure.",
       min_school_age_years = NULL),
  list(var = "aimag_prior_mean",
       label = "B: birth-aimag prior-cohort mean education",
       theory_rank = 13L,
       defensibility = "Diagnostic only",
       note = "Predetermined relative to person but constructed from HSES schooling outcomes.",
       min_school_age_years = NULL),
  list(var = "loo_mean_educ",
       label = "A: leave-one-out local mean education",
       theory_rank = 14L,
       defensibility = "Diagnostic only",
       note = "Outcome-based peer/regional education proxy; not cleanly exogenous.",
       min_school_age_years = NULL),
  list(var = "log_dist_ub",
       label = "F: log distance to UB",
       theory_rank = 15L,
       defensibility = "Geographic diagnostic",
       note = "Predetermined geography but may directly proxy labor-market access.",
       min_school_age_years = NULL),
  list(var = "educ_years",
       label = "INVALID: educ_years threshold",
       theory_rank = 99L,
       defensibility = "Invalid for CH",
       note = "Same variable is endogenous regressor and threshold; violates CH exogenous-threshold assumption.",
       min_school_age_years = NULL)
)

results <- rbindlist(lapply(candidates, function(candidate) {
  cat(sprintf("  Running: %s ...\n", candidate$label))
  tryCatch(run_threshold(candidate, main),
           error = function(e) data.table(proxy = candidate$label,
                                          q_var = candidate$var,
                                          status = paste("error:", e$message),
                                          N = NA_integer_,
                                          theory_rank = candidate$theory_rank,
                                          defensibility = candidate$defensibility,
                                          note = candidate$note))
}), fill = TRUE)

results[, recommended_candidate :=
          status == "ok" & theory_rank == min(theory_rank[status == "ok" &
                                                            theory_rank < 99],
                                               na.rm = TRUE)]

cat("\n\n=== RESULTS ===\n")
print(results[order(theory_rank),
              .(proxy, status, N, gamma_star,
                beta_low_q = round(beta_low_q, 4),
                ret_low = round(return_low_q_pct, 1),
                beta_high_q = round(beta_high_q, 4),
                ret_high = round(return_high_q_pct, 1),
                diff = round(diff_high_minus_low, 4),
                diff_p = round(diff_p, 4),
                sup_wald = round(sup_wald, 2),
                fs_low = round(fs_low_q_separate, 2),
                fs_high = round(fs_high_q_separate, 2),
                recommended_candidate)])

fwrite(results, file.path(BASE, "clean", "threshold_proxy_comparison.csv"))
fwrite(results, file.path(OUT_TABS, "t7_threshold_proxy_comparison.csv"))
fwrite(results, file.path(IN_TABS, "t7_threshold_proxy_comparison.csv"))

best <- results[recommended_candidate == TRUE][1]
if (nrow(best) == 1) {
  cat(sprintf("\nRecommended threshold proxy: %s\n", best$proxy))
  cat(sprintf("  gamma* = %.4f, N = %s, diff p = %.4f, SupWald-style = %.2f\n",
              best$gamma_star, format(best$N, big.mark = ","),
              best$diff_p, best$sup_wald))
}

cat("\nSaved: threshold_proxy_comparison.csv and t7_threshold_proxy_comparison.csv\n")
