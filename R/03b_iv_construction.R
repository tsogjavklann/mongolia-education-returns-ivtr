# =============================================================================
# 03b_iv_construction.R — Construct IV variables
# Z1: birth_aimag dummies (already in data)
# Z2: Distance from birthplace aimag center to Ulaanbaatar (km)
# Z3: Aimag-cohort mean education of OTHER individuals (diagnostic only)
# Z4: EBS education-supply exposure in birth aimag (threshold candidates)
# =============================================================================

library(data.table)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("Loaded: %d rows\n", nrow(dt)))

# Drop previously generated IV columns so the script is idempotent.
generated_cols <- c("dist_ub_current", "dist_ub_birth", "dist_ub",
                    "log_dist_ub", "birth_aimag_mn", "loo_mean_educ",
                    "cohort_5yr_num",
                    # Legacy EBS columns from earlier experimental merges.
                    "ebs_aimag", "ebs_year", "students_per_teacher", "schools",
                    # Rebuilt EBS exposure variables.
                    "ebs_year_age12", "ebs_aimag_name_age12",
                    "ebs_teachers_age12", "ebs_schools_age12",
                    "ebs_students_thousand_age12",
                    "ebs_schools_per_1000_age12",
                    "ebs_teachers_per_1000_age12",
                    "ebs_student_teacher_ratio_age12",
                    "ebs_aimag_name_2000",
                    "ebs_teachers_2000", "ebs_schools_2000",
                    "ebs_students_thousand_2000",
                    "ebs_schools_per_1000_2000",
                    "ebs_teachers_per_1000_2000",
                    "ebs_student_teacher_ratio_2000",
                    "ebs_school_age_years",
                    "ebs_teachers_school_age", "ebs_schools_school_age",
                    "ebs_students_thousand_school_age",
                    "ebs_schools_per_1000_school_age",
                    "ebs_teachers_per_1000_school_age",
                    "ebs_student_teacher_ratio_school_age")
dt[, (intersect(generated_cols, names(dt))) := NULL]

# =============================================================================
# IV-Z2: Distance from aimag center to Ulaanbaatar (km, road distance)
# =============================================================================
# Source: Mongolian road network, well-known geographic facts.
# Aimag codes follow the NSO two-digit coding used in HSES:
# 11=Ulaanbaatar, 21-23=East, 41-48=Central, 61-67=Khangai, 81-85=West.

dist_ub <- data.table(
  newaimag = c(65, 83, 64, 63, 82,
               44, 21, 48, 81, 62,
               46, 22, 43, 41, 85,
               84, 67, 23, 45, 11,
               61, 42),
  aimag_name = c(
    "Архангай", "Баян-Өлгий", "Баянхонгор", "Булган", "Говь-Алтай",
    "Дорноговь", "Дорнод", "Дундговь", "Завхан", "Өвөрхангай",
    "Өмнөговь", "Сүхбаатар", "Сэлэнгэ", "Төв", "Увс",
    "Ховд", "Хөвсгөл", "Хэнтий", "Дархан-Уул", "Улаанбаатар",
    "Орхон", "Говьсүмбэр"
  ),
  dist_km = c(
    468,  1636, 630,  318,  1028,  # Архангай-Говь-Алтай
    462,   664, 256,   932,  430,  # Дорноговь-Өвөрхангай
    553,   615, 310,   195, 1336,  # Өмнөговь-Увс
    1425,  671, 331,   220,    0,  # Ховд-Улаанбаатар
    371,   230                     # Орхон-Говьсүмбэр
  )
)

mn_aimag_codes <- dist_ub$newaimag

cat("\n=== Aimag-UB Distance (km) ===\n")
print(dist_ub[order(-dist_km)][1:10])

# Merge distance to main data
# Use birth_aimag for main waves (2020+), newaimag for all
dt <- merge(dt, dist_ub[, .(newaimag, dist_ub_current = dist_km)],
            by = "newaimag", all.x = TRUE)

# For birth_aimag (only 2020+2021+2024)
dt <- merge(dt, dist_ub[, .(birth_aimag = newaimag, dist_ub_birth = dist_km)],
            by = "birth_aimag", all.x = TRUE)

# Main distance IV: birthplace distance when birthplace is observed.
# If birth_aimag is non-Mongolian/nonstandard, keep distance missing rather than
# incorrectly falling back to current residence. For early waves without
# birth_aimag, retain current-residence distance only for descriptive use.
dt[, birth_aimag_mn := !is.na(birth_aimag) & birth_aimag %in% mn_aimag_codes]
dt[, dist_ub := fcase(
  !is.na(birth_aimag), dist_ub_birth,
  is.na(birth_aimag), dist_ub_current
)]
dt[, log_dist_ub := log(pmax(dist_ub, 1))]

cat(sprintf("\ndist_ub available: %d/%d (%.1f%%)\n",
            sum(!is.na(dt$dist_ub)), nrow(dt), 100*mean(!is.na(dt$dist_ub))))
cat(sprintf("Valid Mongolian birth_aimag: %d/%d in main waves\n",
            sum(dt$birth_aimag_mn, na.rm = TRUE),
            nrow(dt[wave >= 2020 & !is.na(birth_aimag)])))

# =============================================================================
# IV-Z3: Leave-one-out aimag-cohort mean education
# =============================================================================
# For each individual: mean educ_years of OTHER people in same (iv_aimag × cohort_5yr)
# This captures aimag-cohort education environment at the descriptive level.
# It is not used as a headline IV because peer education can violate exclusion.

dt[, cohort_5yr_num := as.integer(factor(cohort_5yr))]
dt[, cell_sum := sum(educ_years, na.rm = TRUE), by = .(iv_aimag, cohort_5yr, wave)]
dt[, cell_n := sum(!is.na(educ_years)), by = .(iv_aimag, cohort_5yr, wave)]
dt[, loo_mean_educ := (cell_sum - educ_years) / pmax(cell_n - 1, 1)]
dt[, c("cell_sum", "cell_n") := NULL]

cat(sprintf("loo_mean_educ: mean = %.2f, sd = %.2f\n",
            mean(dt$loo_mean_educ, na.rm = TRUE), sd(dt$loo_mean_educ, na.rm = TRUE)))

# =============================================================================
# IVTR threshold candidates: EBS education-supply exposure
# =============================================================================
# The raw 1212.mn extract uses 3-digit aimag codes (e.g., 181=Zavkhan,
# 511=Ulaanbaatar), while HSES uses two-digit NSO codes. Earlier experimental
# merges matched 1..22/three-digit codes to birth_aimag and were not valid.
#
# The raw column labels in data/auxiliary/ebs_aimag_year.csv are also misleading:
#   n_schools  = teachers count
#   n_students = schools count
#   n_teachers = students, thousand persons
# Therefore we rebuild transparent supply measures:
#   schools per 1,000 students  = schools / students_thousand
#   teachers per 1,000 students = teachers / students_thousand
#   student-teacher ratio       = students_thousand * 1000 / teachers

cat("\n=== EBS education-supply exposure ===\n")
ebs_path <- file.path(BASE, "auxiliary", "ebs_aimag_year.csv")
if (file.exists(ebs_path)) {
  ebs_raw <- fread(ebs_path, encoding = "UTF-8")
  setnames(ebs_raw, names(ebs_raw)[1:6],
           c("source_code", "year_index", "raw_teachers",
             "raw_schools", "raw_students_thousand", "legacy_ratio"))

  ebs_code_map <- data.table(
    source_code = c(181L, 182L, 183L, 184L, 185L,
                    261L, 262L, 263L, 264L, 265L, 267L,
                    341L, 342L, 343L, 344L, 345L, 346L, 348L,
                    421L, 422L, 423L, 511L),
    birth_aimag = c(81L, 82L, 83L, 84L, 85L,
                    61L, 62L, 63L, 64L, 65L, 67L,
                    41L, 42L, 43L, 44L, 45L, 46L, 48L,
                    21L, 22L, 23L, 11L),
    ebs_aimag_name = c("Zavkhan", "Govi-Altai", "Bayan-Ulgii", "Khovd", "Uvs",
                       "Orkhon", "Uvurkhangai", "Bulgan", "Bayankhongor",
                       "Arkhangai", "Khuvsgul", "Tuv", "Govisumber",
                       "Selenge", "Dornogovi", "Darkhan-Uul", "Umnugovi",
                       "Dundgovi", "Dornod", "Sukhbaatar", "Khentii",
                       "Ulaanbaatar")
  )

  ebs <- merge(ebs_raw, ebs_code_map, by = "source_code", all = FALSE)
  ebs[, `:=`(
    ebs_year = 2025L - as.integer(year_index),
    ebs_teachers = as.numeric(raw_teachers),
    ebs_schools = as.numeric(raw_schools),
    ebs_students_thousand = as.numeric(raw_students_thousand)
  )]
  ebs[, `:=`(
    ebs_schools_per_1000 = ebs_schools / ebs_students_thousand,
    ebs_teachers_per_1000 = ebs_teachers / ebs_students_thousand,
    ebs_student_teacher_ratio = (ebs_students_thousand * 1000) / ebs_teachers
  )]

  # Exact exposure around lower-secondary completion age.
  dt[, ebs_year_age12 := as.integer(birth_year + 12L)]
  ebs_age12 <- ebs[, .(
    birth_aimag,
    ebs_year_age12 = ebs_year,
    ebs_aimag_name_age12 = ebs_aimag_name,
    ebs_teachers_age12 = ebs_teachers,
    ebs_schools_age12 = ebs_schools,
    ebs_students_thousand_age12 = ebs_students_thousand,
    ebs_schools_per_1000_age12 = ebs_schools_per_1000,
    ebs_teachers_per_1000_age12 = ebs_teachers_per_1000,
    ebs_student_teacher_ratio_age12 = ebs_student_teacher_ratio
  )]
  dt <- merge(dt, ebs_age12,
              by = c("birth_aimag", "ebs_year_age12"), all.x = TRUE)

  # Baseline "initial value" proxy. This follows the initial-condition logic in
  # threshold applications, but it is a regional environment proxy rather than
  # every person's own school-age exposure.
  ebs_2000 <- ebs[ebs_year == 2000L, .(
    birth_aimag,
    ebs_aimag_name_2000 = ebs_aimag_name,
    ebs_teachers_2000 = ebs_teachers,
    ebs_schools_2000 = ebs_schools,
    ebs_students_thousand_2000 = ebs_students_thousand,
    ebs_schools_per_1000_2000 = ebs_schools_per_1000,
    ebs_teachers_per_1000_2000 = ebs_teachers_per_1000,
    ebs_student_teacher_ratio_2000 = ebs_student_teacher_ratio
  )]
  dt <- merge(dt, ebs_2000, by = "birth_aimag", all.x = TRUE)

  # Mean observed EBS supply during school ages 6-17. Coverage starts for cohorts
  # whose school-age years overlap the 2000-2025 auxiliary data.
  dt[, obs_id_ebs := .I]
  dt_school <- dt[!is.na(birth_aimag) & !is.na(birth_year),
                  .(obs_id_ebs, birth_aimag, birth_year)]
  ebs_exposure <- rbindlist(lapply(6:17, function(age_at_school) {
    tmp <- copy(dt_school)
    tmp[, `:=`(school_age = age_at_school,
               ebs_year = as.integer(birth_year + age_at_school))]
    merge(tmp,
          ebs[, .(birth_aimag, ebs_year, ebs_teachers, ebs_schools,
                  ebs_students_thousand, ebs_schools_per_1000,
                  ebs_teachers_per_1000, ebs_student_teacher_ratio)],
          by = c("birth_aimag", "ebs_year"), all = FALSE)
  }), use.names = TRUE)

  ebs_school_age <- ebs_exposure[, .(
    ebs_school_age_years = uniqueN(ebs_year),
    ebs_teachers_school_age = mean(ebs_teachers, na.rm = TRUE),
    ebs_schools_school_age = mean(ebs_schools, na.rm = TRUE),
    ebs_students_thousand_school_age = mean(ebs_students_thousand, na.rm = TRUE),
    ebs_schools_per_1000_school_age = mean(ebs_schools_per_1000, na.rm = TRUE),
    ebs_teachers_per_1000_school_age = mean(ebs_teachers_per_1000, na.rm = TRUE),
    ebs_student_teacher_ratio_school_age = mean(ebs_student_teacher_ratio, na.rm = TRUE)
  ), by = obs_id_ebs]

  ebs_cols <- setdiff(names(ebs_school_age), "obs_id_ebs")
  for (col in ebs_cols) {
    dt[ebs_school_age, on = .(obs_id_ebs), (col) := get(paste0("i.", col))]
  }
  dt[, obs_id_ebs := NULL]

  main_ebs <- dt[wave >= 2020 & birth_aimag_mn == TRUE]
  cat(sprintf("  EBS exact age-12 exposure: %d/%d main IV obs\n",
              sum(!is.na(main_ebs$ebs_teachers_per_1000_age12)),
              nrow(main_ebs)))
  cat(sprintf("  EBS school-age exposure (>=3 observed school years): %d/%d main IV obs\n",
              sum(main_ebs$ebs_school_age_years >= 3, na.rm = TRUE),
              nrow(main_ebs)))
  cat(sprintf("  EBS 2000 initial supply: %d/%d main IV obs\n",
              sum(!is.na(main_ebs$ebs_teachers_per_1000_2000)),
              nrow(main_ebs)))
} else {
  warning("EBS auxiliary file not found; EBS threshold candidates not constructed.")
}

# =============================================================================
# FIRST STAGE TESTS for all IVs
# =============================================================================
cat("\n=== FIRST STAGE TESTS ===\n")

library(fixest)

dt[, marital_f := factor(marital)]
main <- dt[wave >= 2020 & birth_aimag_mn == TRUE & !is.na(educ_years)]

# Z1: birth_aimag dummies
fs1 <- feols(educ_years ~ i(birth_aimag) + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | wave,
             data = main, weights = ~hhweight)
cat(sprintf("  Z1 (birth_aimag dummies): R² = %.4f\n", fitstat(fs1, "r2")[[1]]))

# Z2: distance to UB
fs2 <- feols(educ_years ~ dist_ub + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | wave,
             data = main[!is.na(dist_ub)], weights = ~hhweight)
cat(sprintf("  Z2 (dist_UB):            β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs2)["dist_ub"], se(fs2)["dist_ub"],
            coef(fs2)["dist_ub"] / se(fs2)["dist_ub"]))

# Z2: log distance
fs2b <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                sex + i(marital_f) + urban + hhsize | wave,
              data = main[!is.na(log_dist_ub) & is.finite(log_dist_ub)],
              weights = ~hhweight)
cat(sprintf("  Z2b (log dist_UB):       β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs2b)["log_dist_ub"], se(fs2b)["log_dist_ub"],
            coef(fs2b)["log_dist_ub"] / se(fs2b)["log_dist_ub"]))

# Z3: leave-one-out mean educ
fs3 <- feols(educ_years ~ loo_mean_educ + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | wave,
             data = main[!is.na(loo_mean_educ)], weights = ~hhweight)
cat(sprintf("  Z3 (LOO mean educ):      β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs3)["loo_mean_educ"], se(fs3)["loo_mean_educ"],
            coef(fs3)["loo_mean_educ"] / se(fs3)["loo_mean_educ"]))

# =============================================================================
# 2SLS with distance IV
# =============================================================================
cat("\n=== 2SLS with Distance IV ===\n")

iv_dist <- feols(log_wage ~ experience + experience_sq +
                   sex + i(marital_f) + urban + hhsize | wave |
                   educ_years ~ log_dist_ub,
                 data = main[!is.na(log_dist_ub) & is.finite(log_dist_ub)],
                 weights = ~hhweight, cluster = ~newaimag)
cat(sprintf("  β_educ (IV, log_dist) = %.4f (SE %.4f)\n",
            coef(iv_dist)["fit_educ_years"], se(iv_dist)["fit_educ_years"]))
fs_dist <- fitstat(iv_dist, "ivf")$ivf1$stat
cat(sprintf("  First-stage F = %.2f\n", fs_dist))

cat("\n  Note: birth_aimag dummies and log_dist_ub are not combined in one\n")
cat("  overidentified model because log_dist_ub is a deterministic function of\n")
cat("  birth_aimag after the NSO-code correction.\n")

# =============================================================================
# SAVE updated dataset with IV variables
# =============================================================================
fwrite(dt, file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("\nUpdated analysis_sample.csv with IV variables (dist_ub, loo_mean_educ)\n"))

cat("\n=== DONE: 03b_iv_construction.R ===\n")
