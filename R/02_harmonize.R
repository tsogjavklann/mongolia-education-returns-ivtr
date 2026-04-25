# =============================================================================
# 02_harmonize.R — Clean, filter, construct analysis sample
# SEZIS Econometrics VIII Olympiad — Returns to Education (IV-Threshold)
# =============================================================================

library(data.table)

# --- Load pooled data --------------------------------------------------------
BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "hses_pooled.csv"))
cat(sprintf("Loaded: %s rows x %s cols\n", nrow(dt), ncol(dt)))

# --- M3 fix: normalize 2-digit year coding (e.g., 24 -> 2024) ---------------
# 2024 wave HSES file stores survey_year as 24 (2-digit). Standardize to 4-digit
# so any future-trend or cohort code using survey_year does not silently break.
if ("survey_year" %in% names(dt)) {
  n_short <- sum(!is.na(dt$survey_year) & dt$survey_year < 100, na.rm = TRUE)
  if (n_short > 0) {
    dt[!is.na(survey_year) & survey_year < 100,
       survey_year := survey_year + 2000L]
    cat(sprintf("Normalized %d 2-digit survey_year values to 4-digit.\n", n_short))
  }
}

# =============================================================================
# 1. EDUCATION YEARS: 2008 reform correction (11-year → 12-year system)
# =============================================================================
# Before 2008: system was 4+4+3 = 11 years (primary + lower secondary + upper secondary)
# After 2008:  system is 5+4+3 = 12 years (primary extended by 1 year)
# Cohorts born ≤ 1995 were in the old system; born ≥ 1996 in the new system
# q0213 reports raw years — no adjustment needed if survey asked "total years attended"
# But educ_level (q0210) codes may differ. We use educ_years (q0213) directly.

# IMPUTE educ_years from educ_level for waves where q0213 is mostly NA (2016/2018)
# Mapping derived from 2020+2021+2024 cross-tabulation (median years per level)
educ_level_to_years <- c(
  `1` = 2,   # Боловсролгүй / бага эхлэл
  `2` = 4,   # Бага
  `3` = 8,   # Суурь (дунд)
  `4` = 10,  # Бүрэн дунд (хуучин 10 анги)
  `5` = 11,  # Бүрэн дунд (шинэ 11/12 анги)
  `6` = 12,  # МСҮТ / мэргэжлийн сургалт
  `7` = 14,  # Коллеж / диплом
  `8` = 14,  # Бакалавр
  `9` = 16,  # Магистр
  `10` = 18  # Доктор
)

n_missing_before <- sum(is.na(dt$educ_years))
dt[is.na(educ_years) & !is.na(educ_level),
   educ_years := educ_level_to_years[as.character(educ_level)]]
n_imputed <- n_missing_before - sum(is.na(dt$educ_years))
cat(sprintf("\nImputed educ_years from educ_level: %s values filled\n", n_imputed))

# Sanity check
cat("\n=== Education years distribution (after imputation) ===\n")
print(dt[, .N, by = educ_years][order(educ_years)])

# Cap at reasonable range
dt[educ_years < 0 | educ_years > 22, educ_years := NA]

# =============================================================================
# 2. AGE FILTER: working-age population (25-60)
# =============================================================================
# 25+: ensures most schooling is completed
# 60:  pre-retirement in Mongolia

n_before <- nrow(dt)
dt <- dt[age >= 25 & age <= 60]
cat(sprintf("\nAge filter (25-60): %s -> %s (dropped %s)\n",
            n_before, nrow(dt), n_before - nrow(dt)))

# =============================================================================
# 3. WAGE FILTER: positive wages only (main analysis sample)
# =============================================================================
# Keep only individuals with reported positive monthly wages
# This excludes: unemployed, herders, self-employed, students, homemakers

dt[, has_wage := !is.na(wage_monthly) & wage_monthly > 0]
cat(sprintf("\nWage availability: %s have wages (%.1f%%)\n",
            sum(dt$has_wage), 100 * mean(dt$has_wage)))

# Main analysis sample: wage earners
main <- dt[has_wage == TRUE]
cat(sprintf("Main analysis sample: %s individuals\n", nrow(main)))

# =============================================================================
# 4. WAGE CONSTRUCTION: log hourly wage
# =============================================================================
# For 2020/2021/2024: hours_per_day and days_per_month available
# For 2016/2018: only hours_week (7-day hours) available

# Method A: Use hours_per_day × days_per_month (preferred, 2020+)
main[, monthly_hours_A := hours_per_day * days_per_month * (months_worked / 12)]

# Method B: Use hours_week × 4.33 (fallback, all waves)
main[, monthly_hours_B := hours_week * 4.33]

# Pick best available
main[, monthly_hours := fifelse(!is.na(monthly_hours_A) & monthly_hours_A > 0,
                                monthly_hours_A, monthly_hours_B)]

# Hourly wage
main[, hourly_wage := wage_monthly / pmax(monthly_hours, 1)]

# Log wages
main[, log_wage_monthly := log(wage_monthly)]
main[, log_wage_hourly  := log(hourly_wage)]

# Use log monthly wage as primary outcome (more stable, fewer missing)
main[, log_wage := log_wage_monthly]

# =============================================================================
# 5. EXPERIENCE
# =============================================================================
main[, experience := pmax(age - educ_years - 6L, 0L, na.rm = TRUE)]
main[, experience_sq := experience^2]

# =============================================================================
# 6. BIRTH YEAR & COHORT
# =============================================================================
main[, birth_year := wave - age]
main[, cohort_5yr := cut(birth_year,
                         breaks = seq(1960, 2005, by = 5),
                         labels = paste0(seq(1960, 2000, by = 5), "-",
                                        seq(1964, 2004, by = 5)),
                         right = FALSE)]

# =============================================================================
# 7. LOCATION: aimag for IV
# =============================================================================
# For IV: use birth_aimag if available (2020/2021/2024), else current aimag
main[, iv_aimag := fifelse(!is.na(birth_aimag), birth_aimag, newaimag)]

# Aimag × cohort cell identifier (for pseudo-panel)
main[, cell_id := paste(newaimag, cohort_5yr, wave, sep = "_")]

# =============================================================================
# 8. TRIM OUTLIERS
# =============================================================================
# Drop top and bottom 0.5% of log_wage distribution (within each wave)
main[, `:=`(
  wage_p005 = quantile(log_wage, 0.005, na.rm = TRUE),
  wage_p995 = quantile(log_wage, 0.995, na.rm = TRUE)
), by = wave]

n_before <- nrow(main)
main <- main[log_wage >= wage_p005 & log_wage <= wage_p995]
cat(sprintf("\nOutlier trim (0.5%%): %s -> %s (dropped %s)\n",
            n_before, nrow(main), n_before - nrow(main)))
main[, c("wage_p005", "wage_p995") := NULL]

# =============================================================================
# 9. FINAL VARIABLE SELECTION
# =============================================================================
keep_vars <- c(
  # IDs
  "identif", "ind_id", "wave", "survey_year",
  # Outcome
  "log_wage", "wage_monthly", "log_wage_hourly",
  # Endogenous regressor
  "educ_years", "educ_level",
  # Controls
  "age", "sex", "marital", "experience", "experience_sq",
  "sector", "occupation", "employer_type",
  # Location
  "newaimag", "urban", "hhsize", "hhweight", "strata",
  # IV variables
  "birth_aimag", "birth_soum", "born_here", "iv_aimag",
  "has_birth_aimag",
  # Pseudo-panel
  "birth_year", "cohort_5yr", "cell_id",
  # Extra
  "hours_week", "days_per_month", "hours_per_day",
  "months_worked", "rel_to_head"
)

# Keep only vars that exist
keep_vars <- intersect(keep_vars, names(main))
main <- main[, ..keep_vars]

# =============================================================================
# 10. SAVE
# =============================================================================
fwrite(main, file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("\n=== SAVED: analysis_sample.csv ===\n"))
cat(sprintf("Final sample: %s individuals across %s waves\n",
            nrow(main), uniqueN(main$wave)))

# --- Summary statistics ------------------------------------------------------
cat("\n=== SUMMARY BY WAVE ===\n")
summ <- main[, .(
  N          = .N,
  mean_educ  = round(mean(educ_years, na.rm = TRUE), 1),
  mean_age   = round(mean(age, na.rm = TRUE), 1),
  med_wage   = round(median(wage_monthly, na.rm = TRUE), 0),
  mean_logw  = round(mean(log_wage, na.rm = TRUE), 3),
  pct_female = round(100 * mean(sex == 2, na.rm = TRUE), 1),
  pct_urban  = round(100 * mean(urban == 1, na.rm = TRUE), 1),
  n_birth_aim = sum(!is.na(birth_aimag))
), by = wave]
print(summ)

cat("\n=== SUMMARY: MAIN vs ROBUSTNESS WAVES ===\n")
cat(sprintf("Main (2020+2021+2024): %s individuals, birth_aimag available\n",
            nrow(main[wave >= 2020])))
cat(sprintf("Robustness (2016+2018): %s individuals, current aimag only\n",
            nrow(main[wave < 2020])))

# Full sample for Heckman selection (includes non-wage earners)
fwrite(dt, file.path(BASE, "clean", "full_sample.csv"))
cat(sprintf("\nAlso saved: full_sample.csv (%s rows, for Heckman selection)\n", nrow(dt)))

cat("\n=== DONE: 02_harmonize.R ===\n")
