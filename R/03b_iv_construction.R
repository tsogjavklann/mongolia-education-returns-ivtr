# =============================================================================
# 03b_iv_construction.R — Construct IV variables
# Z1: birth_aimag dummies (already in data)
# Z2: Distance from aimag center to Ulaanbaatar (km) — hardcoded geographic data
# Z3: Aimag-cohort mean education of OTHER individuals (leave-one-out peer IV)
# =============================================================================

library(data.table)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("Loaded: %d rows\n", nrow(dt)))

# =============================================================================
# IV-Z2: Distance from aimag center to Ulaanbaatar (km, road distance)
# =============================================================================
# Source: Mongolian road network, well-known geographic facts
# Aimag codes follow NSO standard coding (1-22)

dist_ub <- data.table(
  newaimag = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
               11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22),
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

cat("\n=== Aimag-UB Distance (km) ===\n")
print(dist_ub[order(-dist_km)][1:10])

# Merge distance to main data
# Use birth_aimag for main waves (2020+), newaimag for all
dt <- merge(dt, dist_ub[, .(newaimag, dist_ub_current = dist_km)],
            by = "newaimag", all.x = TRUE)

# For birth_aimag (only 2020+2021+2024)
dt <- merge(dt, dist_ub[, .(birth_aimag = newaimag, dist_ub_birth = dist_km)],
            by = "birth_aimag", all.x = TRUE)

# Best available distance IV
dt[, dist_ub := fifelse(!is.na(dist_ub_birth), dist_ub_birth, dist_ub_current)]
dt[, log_dist_ub := log(pmax(dist_ub, 1))]

cat(sprintf("\ndist_ub available: %d/%d (%.1f%%)\n",
            sum(!is.na(dt$dist_ub)), nrow(dt), 100*mean(!is.na(dt$dist_ub))))

# =============================================================================
# IV-Z3: Leave-one-out aimag-cohort mean education
# =============================================================================
# For each individual: mean educ_years of OTHER people in same (iv_aimag × cohort_5yr)
# This captures "education supply / peer environment" at the aimag-cohort level

dt[, cohort_5yr_num := as.integer(factor(cohort_5yr))]
dt[, cell_sum := sum(educ_years, na.rm = TRUE), by = .(iv_aimag, cohort_5yr, wave)]
dt[, cell_n := sum(!is.na(educ_years)), by = .(iv_aimag, cohort_5yr, wave)]
dt[, loo_mean_educ := (cell_sum - educ_years) / pmax(cell_n - 1, 1)]
dt[, c("cell_sum", "cell_n") := NULL]

cat(sprintf("loo_mean_educ: mean = %.2f, sd = %.2f\n",
            mean(dt$loo_mean_educ, na.rm = TRUE), sd(dt$loo_mean_educ, na.rm = TRUE)))

# =============================================================================
# FIRST STAGE TESTS for all IVs
# =============================================================================
cat("\n=== FIRST STAGE TESTS ===\n")

library(fixest)

main <- dt[wave >= 2020 & !is.na(birth_aimag) & !is.na(educ_years)]

# Z1: birth_aimag dummies
fs1 <- feols(educ_years ~ i(birth_aimag) + experience + experience_sq +
               sex + marital + urban + hhsize | wave,
             data = main, weights = ~hhweight)
cat(sprintf("  Z1 (birth_aimag dummies): R² = %.4f\n", fitstat(fs1, "r2")[[1]]))

# Z2: distance to UB
fs2 <- feols(educ_years ~ dist_ub + experience + experience_sq +
               sex + marital + urban + hhsize | wave,
             data = main[!is.na(dist_ub)], weights = ~hhweight)
cat(sprintf("  Z2 (dist_UB):            β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs2)["dist_ub"], se(fs2)["dist_ub"],
            coef(fs2)["dist_ub"] / se(fs2)["dist_ub"]))

# Z2: log distance
fs2b <- feols(educ_years ~ log_dist_ub + experience + experience_sq +
                sex + marital + urban + hhsize | wave,
              data = main[!is.na(log_dist_ub) & is.finite(log_dist_ub)],
              weights = ~hhweight)
cat(sprintf("  Z2b (log dist_UB):       β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs2b)["log_dist_ub"], se(fs2b)["log_dist_ub"],
            coef(fs2b)["log_dist_ub"] / se(fs2b)["log_dist_ub"]))

# Z3: leave-one-out mean educ
fs3 <- feols(educ_years ~ loo_mean_educ + experience + experience_sq +
               sex + marital + urban + hhsize | wave,
             data = main[!is.na(loo_mean_educ)], weights = ~hhweight)
cat(sprintf("  Z3 (LOO mean educ):      β = %.4f (SE %.4f), t = %.2f\n",
            coef(fs3)["loo_mean_educ"], se(fs3)["loo_mean_educ"],
            coef(fs3)["loo_mean_educ"] / se(fs3)["loo_mean_educ"]))

# =============================================================================
# 2SLS with distance IV
# =============================================================================
cat("\n=== 2SLS with Distance IV ===\n")

iv_dist <- feols(log_wage ~ experience + experience_sq +
                   sex + marital + urban + hhsize | wave |
                   educ_years ~ log_dist_ub,
                 data = main[!is.na(log_dist_ub) & is.finite(log_dist_ub)],
                 weights = ~hhweight, cluster = ~newaimag)
cat(sprintf("  β_educ (IV, log_dist) = %.4f (SE %.4f)\n",
            coef(iv_dist)["fit_educ_years"], se(iv_dist)["fit_educ_years"]))
fs_dist <- fitstat(iv_dist, "ivf")$ivf1$stat
cat(sprintf("  First-stage F = %.2f\n", fs_dist))

# Overidentified model: birth_aimag + log_dist
iv_over <- feols(log_wage ~ experience + experience_sq +
                   sex + marital + urban + hhsize | wave |
                   educ_years ~ i(birth_aimag) + log_dist_ub,
                 data = main[!is.na(log_dist_ub) & is.finite(log_dist_ub)],
                 weights = ~hhweight, cluster = ~newaimag)
cat(sprintf("\n  Overidentified (birth_aimag + log_dist):\n"))
cat(sprintf("  β_educ = %.4f (SE %.4f)\n",
            coef(iv_over)["fit_educ_years"], se(iv_over)["fit_educ_years"]))

# =============================================================================
# SAVE updated dataset with IV variables
# =============================================================================
fwrite(dt, file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("\nUpdated analysis_sample.csv with IV variables (dist_ub, loo_mean_educ)\n"))

cat("\n=== DONE: 03b_iv_construction.R ===\n")
