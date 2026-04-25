# =============================================================================
# 14_audit_checks.R -- Evidence-based econometric audit (read-only checks)
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))
suppressMessages(library(AER))

ROOT <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric"
BASE <- file.path(ROOT, "data")
AUDIT_DIR <- file.path(ROOT, "outputs", "audit")
dir.create(AUDIT_DIR, recursive = TRUE, showWarnings = FALSE)

out_file <- file.path(AUDIT_DIR, "audit_console_output.txt")
sink(out_file, split = TRUE)
on.exit(sink(), add = TRUE)

cat("============================================================\n")
cat("ECONOMETRIC AUDIT CHECKS\n")
cat("Run time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("============================================================\n\n")

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
full <- fread(file.path(BASE, "clean", "full_sample.csv"))
pooled <- fread(file.path(BASE, "clean", "hses_pooled.csv"))
pp <- fread(file.path(BASE, "clean", "pseudopanel.csv"))
ebs_raw <- fread(file.path(BASE, "auxiliary", "ebs_aimag_year.csv"), encoding = "UTF-8")

MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

cat("DATA SIZES\n")
print(data.table(
  object = c("hses_pooled", "full_sample", "analysis_sample", "pseudopanel", "ebs_raw"),
  rows = c(nrow(pooled), nrow(full), nrow(dt), nrow(pp), nrow(ebs_raw)),
  cols = c(ncol(pooled), ncol(full), ncol(dt), ncol(pp), ncol(ebs_raw))
))

key_vars <- c("wave", "survey_year", "log_wage", "wage_monthly",
              "log_wage_hourly", "educ_years", "educ_level", "age", "sex",
              "marital", "experience", "experience_sq", "urban", "hhsize",
              "hhweight", "birth_aimag", "newaimag", "birth_year",
              "dist_ub", "log_dist_ub", "loo_mean_educ",
              "ebs_school_age_years",
              "ebs_teachers_per_1000_school_age",
              "ebs_schools_per_1000_school_age",
              "ebs_student_teacher_ratio_school_age",
              "ebs_teachers_per_1000_age12",
              "ebs_student_teacher_ratio_age12",
              "ebs_teachers_per_1000_2000",
              "ebs_student_teacher_ratio_2000")
key_vars <- intersect(key_vars, names(dt))

cat("\nKEY VARIABLE NA RATES\n")
na_table <- rbindlist(lapply(key_vars, function(v) {
  data.table(var = v,
             class = paste(class(dt[[v]]), collapse = "/"),
             N = nrow(dt),
             nonmissing = sum(!is.na(dt[[v]])),
             na = sum(is.na(dt[[v]])),
             na_pct = round(100 * mean(is.na(dt[[v]])), 2))
}))
print(na_table)
fwrite(na_table, file.path(AUDIT_DIR, "audit_na_rates.csv"))

num_vars <- key_vars[vapply(dt[, ..key_vars], is.numeric, logical(1))]
cat("\nNUMERIC SUMMARIES\n")
num_summary <- rbindlist(lapply(num_vars, function(v) {
  x <- dt[[v]]
  data.table(var = v,
             N = sum(!is.na(x)),
             mean = mean(x, na.rm = TRUE),
             sd = sd(x, na.rm = TRUE),
             min = min(x, na.rm = TRUE),
             p01 = as.numeric(quantile(x, 0.01, na.rm = TRUE)),
             p25 = as.numeric(quantile(x, 0.25, na.rm = TRUE)),
             median = median(x, na.rm = TRUE),
             p75 = as.numeric(quantile(x, 0.75, na.rm = TRUE)),
             p99 = as.numeric(quantile(x, 0.99, na.rm = TRUE)),
             max = max(x, na.rm = TRUE))
}))
print(num_summary)
fwrite(num_summary, file.path(AUDIT_DIR, "audit_numeric_summary.csv"))

cat("\nCATEGORICAL TABLES WITH NA\n")
cat("wave\n"); print(dt[, .N, by = wave][order(wave)])
cat("sex\n"); print(dt[, .N, by = sex][order(sex)])
cat("urban\n"); print(dt[, .N, by = urban][order(urban)])
cat("marital\n"); print(dt[, .N, by = marital][order(marital)])
cat("educ_level\n"); print(dt[, .N, by = educ_level][order(educ_level)])
cat("birth_aimag main waves\n")
print(dt[wave >= 2020, .N, by = birth_aimag][order(birth_aimag)])
cat("newaimag all waves\n")
print(dt[, .N, by = newaimag][order(newaimag)])

cat("\nTARGET VARIABLE OUTLIERS / FILTER CHECKS\n")
print(dt[, .(
  N = .N,
  wage_nonpositive = sum(wage_monthly <= 0, na.rm = TRUE),
  wage_exact_5m = sum(wage_monthly == 5000000, na.rm = TRUE),
  wage_above_5m = sum(wage_monthly > 5000000, na.rm = TRUE),
  educ_zero = sum(educ_years == 0, na.rm = TRUE),
  educ_below_6 = sum(educ_years < 6, na.rm = TRUE),
  educ_above_18 = sum(educ_years > 18, na.rm = TRUE),
  log_wage_min = min(log_wage, na.rm = TRUE),
  log_wage_max = max(log_wage, na.rm = TRUE)
)])
cat("educ_years by wave\n")
print(dcast(dt[, .N, by = .(wave, educ_years)], educ_years ~ wave,
            value.var = "N", fill = 0))
cat("educ_level x educ_years for tertiary levels\n")
print(dt[educ_level >= 7, .N, by = .(educ_level, educ_years)][order(educ_level, educ_years)])

cat("\nMERGE INTEGRITY CHECKS\n")
main_waves <- dt[wave >= 2020]
main_valid <- main_waves[birth_aimag %in% MN_AIMAG_CODES]
cat(sprintf("birth_aimag valid overlap: %d/%d = %.2f%%\n",
            nrow(main_valid), nrow(main_waves),
            100 * nrow(main_valid) / nrow(main_waves)))
cat("birth_aimag outside MN standard codes in main waves\n")
print(main_waves[!is.na(birth_aimag) & !(birth_aimag %in% MN_AIMAG_CODES),
                 .N, by = birth_aimag][order(birth_aimag)])

cat(sprintf("dist_ub_birth coverage among valid birth_aimag: %d/%d = %.2f%%\n",
            sum(!is.na(main_valid$dist_ub_birth)), nrow(main_valid),
            100 * mean(!is.na(main_valid$dist_ub_birth))))
cat(sprintf("EBS 2000 coverage among valid birth_aimag: %d/%d = %.2f%%\n",
            sum(!is.na(main_valid$ebs_teachers_per_1000_2000)), nrow(main_valid),
            100 * mean(!is.na(main_valid$ebs_teachers_per_1000_2000))))
cat(sprintf("EBS age-12 coverage among valid birth_aimag: %d/%d = %.2f%%\n",
            sum(!is.na(main_valid$ebs_teachers_per_1000_age12)), nrow(main_valid),
            100 * mean(!is.na(main_valid$ebs_teachers_per_1000_age12))))
cat(sprintf("EBS school-age >=3y coverage among valid birth_aimag: %d/%d = %.2f%%\n",
            sum(main_valid$ebs_school_age_years >= 3, na.rm = TRUE),
            nrow(main_valid),
            100 * mean(main_valid$ebs_school_age_years >= 3, na.rm = TRUE)))

cat("\nEBS RAW SEMANTIC CHECK\n")
setnames(ebs_raw, names(ebs_raw)[1:6],
         c("source_code", "year_index", "raw_teachers",
           "raw_schools", "raw_students_thousand", "legacy_ratio"))
ebs_raw[, ebs_year := 2025L - as.integer(year_index)]
print(ebs_raw[, .(
  rows = .N,
  source_codes = uniqueN(source_code),
  years = paste(range(ebs_year, na.rm = TRUE), collapse = "-"),
  raw_teachers_min = min(raw_teachers, na.rm = TRUE),
  raw_teachers_max = max(raw_teachers, na.rm = TRUE),
  raw_schools_min = min(raw_schools, na.rm = TRUE),
  raw_schools_max = max(raw_schools, na.rm = TRUE),
  raw_students_thousand_min = min(raw_students_thousand, na.rm = TRUE),
  raw_students_thousand_max = max(raw_students_thousand, na.rm = TRUE),
  implied_ptr_min = min(raw_students_thousand * 1000 / raw_teachers, na.rm = TRUE),
  implied_ptr_max = max(raw_students_thousand * 1000 / raw_teachers, na.rm = TRUE)
)])

cat("\nSEMANTIC RANGE CHECKS FOR DERIVED EBS VARIABLES\n")
ebs_vars <- grep("^ebs_.*(per_1000|ratio)", names(dt), value = TRUE)
print(rbindlist(lapply(ebs_vars, function(v) {
  x <- dt[[v]]
  data.table(var = v,
             N = sum(!is.na(x)),
             min = min(x, na.rm = TRUE),
             median = median(x, na.rm = TRUE),
             max = max(x, na.rm = TRUE))
})))

cat("\nECONOMETRIC DIAGNOSTICS\n")
dt[, marital_f := factor(marital)]
dt[, birth_aimag_f := factor(birth_aimag)]
main <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
             !is.na(educ_years) & !is.na(log_wage) & !is.na(experience)]
cat(sprintf("main IV N: %d\n", nrow(main)))

ols_main <- feols(log_wage ~ educ_years + experience + experience_sq +
                    sex + i(marital_f) + urban + hhsize | wave,
                  data = main, weights = ~hhweight, cluster = ~newaimag,
                  notes = FALSE)
iv_birth <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                    urban + hhsize |
                    wave |
                    educ_years ~ i(birth_aimag_f),
                  data = main, weights = ~hhweight, cluster = ~newaimag,
                  notes = FALSE)
iv_birth_fe <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                       urban + hhsize |
                       wave + newaimag |
                       educ_years ~ i(birth_aimag_f),
                     data = main, weights = ~hhweight, cluster = ~newaimag,
                     notes = FALSE)
cat(sprintf("OLS main beta educ = %.6f, SE = %.6f\n",
            coef(ols_main)["educ_years"], se(ols_main)["educ_years"]))
cat(sprintf("IV birth_aimag beta educ = %.6f, SE = %.6f, first-stage F/Wald = %.4f\n",
            coef(iv_birth)["fit_educ_years"], se(iv_birth)["fit_educ_years"],
            fitstat(iv_birth, "ivf")$ivf1$stat))
cat(sprintf("IV birth_aimag + current FE beta educ = %.6f, SE = %.6f, first-stage F/Wald = %.4f\n",
            coef(iv_birth_fe)["fit_educ_years"], se(iv_birth_fe)["fit_educ_years"],
            fitstat(iv_birth_fe, "ivf")$ivf1$stat))

ivreg_birth <- ivreg(log_wage ~ educ_years + experience + experience_sq + sex +
                       marital_f + urban + hhsize + factor(wave) |
                       experience + experience_sq + sex + marital_f + urban +
                       hhsize + factor(wave) + factor(birth_aimag),
                     data = main, weights = hhweight)
ivreg_birth_fe <- ivreg(log_wage ~ educ_years + experience + experience_sq + sex +
                          marital_f + urban + hhsize + factor(wave) +
                          factor(newaimag) |
                          experience + experience_sq + sex + marital_f + urban +
                          hhsize + factor(wave) + factor(newaimag) +
                          factor(birth_aimag),
                        data = main, weights = hhweight)
cat("AER ivreg diagnostics: birth_aimag\n")
print(summary(ivreg_birth, diagnostics = TRUE)$diagnostics)
cat("AER ivreg diagnostics: birth_aimag + current aimag FE\n")
print(summary(ivreg_birth_fe, diagnostics = TRUE)$diagnostics)

cat("\nPLACEBO / MECHANISM CHECK FOR log_dist_ub\n")
placebo <- rbindlist(lapply(list(primary_or_less = main[educ_years <= 8],
                                 above_primary = main[educ_years > 8]), function(x) {
  m <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | wave,
             data = x, weights = ~hhweight, cluster = ~newaimag,
             notes = FALSE)
  data.table(N = nobs(m), beta_dist = coef(m)["log_dist_ub"],
             se = se(m)["log_dist_ub"],
             t = coef(m)["log_dist_ub"] / se(m)["log_dist_ub"])
}), idcol = "group")
print(placebo)

cat("\nTHRESHOLD OUTPUTS\n")
strict <- fread(file.path(BASE, "clean", "threshold_proxy_comparison.csv"))
classic <- fread(file.path(BASE, "clean", "ch_classical_threshold_comparison.csv"))
boot <- fread(file.path(BASE, "clean", "ch_classical_bootstrap.csv"))
print(strict[order(theory_rank),
             .(proxy, N, gamma_star, diff_p,
               fs_low = fs_low_q_separate, fs_high = fs_high_q_separate)])
print(classic[order(theory_rank),
              .(proxy, N, gamma_star, diff_p = joint_diff_p,
                fs_low = fs_low_q_separate, fs_high = fs_high_q_separate)])
print(boot[, .(proxy, N, B, gamma_star, observed_sup_wald, bootstrap_p,
               bootstrap_p95, defensibility)])

cat("\nPSEUDOPANEL CHECKS\n")
print(pp[, .(
  cells = .N,
  waves = uniqueN(wave),
  min_cell_n = min(cell_n, na.rm = TRUE),
  median_cell_n = median(cell_n, na.rm = TRUE),
  max_cell_n = max(cell_n, na.rm = TRUE),
  mean_educ_min = min(educ_years, na.rm = TRUE),
  mean_educ_max = max(educ_years, na.rm = TRUE)
)])
cat("Pseudo-panel cells by wave\n")
print(pp[, .N, by = wave][order(wave)])

cat("\nOUTPUT RECONCILIATION\n")
table_files <- c("t1_descriptives.csv", "t1b_descriptives_by_wave.csv",
                 "t2_ols_panel.csv", "t3_iv_results.csv",
                 "t4_ivtr_headline.csv", "t5_robustness.csv",
                 "t6_full_summary.csv", "t7_threshold_proxy_comparison.csv",
                 "t8_ch_classical_threshold_comparison.csv",
                 "t9_ch_classical_bootstrap.csv")
sync <- rbindlist(lapply(table_files, function(f) {
  in_path <- file.path(ROOT, "inputs", "tables", f)
  out_path <- file.path(ROOT, "outputs", "tables", f)
  data.table(file = f,
             input_exists = file.exists(in_path),
             output_exists = file.exists(out_path),
             same_size = if (file.exists(in_path) && file.exists(out_path)) {
               file.info(in_path)$size == file.info(out_path)$size
             } else FALSE)
}))
print(sync)
fwrite(sync, file.path(AUDIT_DIR, "audit_table_sync.csv"))

cat("\nRESEARCH_RESULTS KEY NUMBER CHECK\n")
rr <- paste(readLines(file.path(ROOT, "inputs", "data_summary",
                                "research_results.md"), warn = FALSE),
            collapse = "\n")
numbers <- c("0.1213", "12.9%", "41.26", "0.001", "0.4286", "0.0546",
             "0.9870", "0.8688")
print(data.table(token = numbers,
                 present_in_research_results = vapply(numbers, grepl, logical(1),
                                                      x = rr, fixed = TRUE)))

cat("\nPYTHON REPLICATION OUTPUT\n")
old_wd <- getwd()
setwd(ROOT)
py_out <- system2("python", c("python/replicate_headline.py"),
                  stdout = TRUE, stderr = TRUE)
setwd(old_wd)
cat(paste(py_out, collapse = "\n"), "\n")

cat("\nDONE\n")
