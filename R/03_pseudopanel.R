# =============================================================================
# 03_pseudopanel.R — Pseudo-panel: cohort × aimag × wave cell construction
# =============================================================================

library(data.table)

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
cat(sprintf("Loaded: %s rows\n", nrow(dt)))

# --- Build cohort groups (5-year birth cohorts) ------------------------------
dt[, cohort := cut(birth_year,
                   breaks = seq(1960, 2005, by = 5),
                   labels = paste0("c", seq(1960, 2000, by = 5)),
                   right = FALSE)]

# Drop individuals with missing cohort or aimag
dt <- dt[!is.na(cohort) & !is.na(newaimag)]

# --- Aggregate to cell means -------------------------------------------------
# Cell = cohort × aimag × wave
panel <- dt[, .(
  log_wage     = weighted.mean(log_wage, hhweight, na.rm = TRUE),
  educ_years   = weighted.mean(educ_years, hhweight, na.rm = TRUE),
  experience   = weighted.mean(experience, hhweight, na.rm = TRUE),
  experience_sq = weighted.mean(experience_sq, hhweight, na.rm = TRUE),
  age          = weighted.mean(age, hhweight, na.rm = TRUE),
  pct_female   = weighted.mean(sex == 2, hhweight, na.rm = TRUE),
  pct_urban    = weighted.mean(urban == 1, hhweight, na.rm = TRUE),
  pct_married  = weighted.mean(marital %in% c(1, 2), hhweight, na.rm = TRUE),
  mean_hhsize  = weighted.mean(hhsize, hhweight, na.rm = TRUE),
  cell_n       = .N,
  sum_weight   = sum(hhweight, na.rm = TRUE)
), by = .(cohort, newaimag, wave)]

# --- Filter: minimum cell size -----------------------------------------------
min_cell <- 20
n_before <- nrow(panel)
panel <- panel[cell_n >= min_cell]
cat(sprintf("\nPseudo-panel cells: %d -> %d (dropped %d with < %d obs)\n",
            n_before, nrow(panel), n_before - nrow(panel), min_cell))

# --- Panel identifiers -------------------------------------------------------
panel[, panel_id := paste(cohort, newaimag, sep = "_")]
panel[, n_waves := .N, by = panel_id]

cat(sprintf("Unique panel units (cohort×aimag): %d\n", uniqueN(panel$panel_id)))
cat(sprintf("Total cells: %d\n", nrow(panel)))
cat(sprintf("Waves per unit: min=%d, median=%d, max=%d\n",
            min(panel$n_waves), median(panel$n_waves), max(panel$n_waves)))

# --- Save --------------------------------------------------------------------
fwrite(panel, file.path(BASE, "clean", "pseudopanel.csv"))
cat(sprintf("\nSaved: pseudopanel.csv (%d cells)\n", nrow(panel)))

cat("\n=== Cell size distribution ===\n")
print(panel[, .(cells = .N, mean_n = round(mean(cell_n), 1),
                min_n = min(cell_n), max_n = max(cell_n)), by = wave])

cat("\n=== DONE: 03_pseudopanel.R ===\n")
