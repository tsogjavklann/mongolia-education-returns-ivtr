# =============================================================================
# 00_main.R — Master Runner
# SEZIS Econometrics VIII Olympiad — Returns to Education (IV-Threshold)
# Run this script to reproduce all results from scratch.
# =============================================================================

cat("============================================================\n")
cat("  SEZIS Econometrics VIII — Full Pipeline\n")
cat("  Returns to Education: IV-Threshold Regression\n")
cat("============================================================\n\n")

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/R"

t0 <- Sys.time()

cat(">>> Step 1/7: Importing HSES data...\n")
source(file.path(BASE, "01_import.R"))

cat("\n>>> Step 2/7: Harmonizing variables...\n")
source(file.path(BASE, "02_harmonize.R"))

cat("\n>>> Step 3/7: Building pseudo-panel...\n")
source(file.path(BASE, "03_pseudopanel.R"))

cat("\n>>> Step 4/7: OLS + IV estimation...\n")
source(file.path(BASE, "04_ols_iv.R"))

cat("\n>>> Step 5/7: Caner-Hansen IVTR (headline)...\n")
source(file.path(BASE, "05_ivtr_caner_hansen.R"))

cat("\n>>> Step 6/7: Panel FE/RE + Hausman...\n")
source(file.path(BASE, "06_panel_fe_re.R"))

cat("\n>>> Step 7/7: Robustness checks...\n")
source(file.path(BASE, "07_robustness.R"))

cat("\n>>> Generating figures...\n")
source(file.path(BASE, "08_figures.R"))

elapsed <- round(difftime(Sys.time(), t0, units = "mins"), 1)
cat(sprintf("\n============================================================\n"))
cat(sprintf("  ALL DONE in %.1f minutes\n", elapsed))
cat(sprintf("============================================================\n"))
