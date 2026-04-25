# =============================================================================
# 00_main.R — Master Runner
# SEZIS Econometrics VIII Olympiad — Returns to Education (IV-Threshold)
# Run this script to reproduce all results from scratch.
# =============================================================================

cat("============================================================\n")
cat("  SEZIS Econometrics VIII — Full Pipeline\n")
cat("  Returns to Education: IV-Threshold Regression\n")
cat("============================================================\n\n")

R_DIR <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/R"

t0 <- Sys.time()

cat(">>> Step 1/15: Importing HSES data...\n")
source(file.path(R_DIR, "01_import.R"))

cat("\n>>> Step 2/15: Harmonizing variables...\n")
source(file.path(R_DIR, "02_harmonize.R"))

cat("\n>>> Step 3/15: Building pseudo-panel...\n")
source(file.path(R_DIR, "03_pseudopanel.R"))

cat("\n>>> Step 4/15: Constructing IV and threshold variables...\n")
source(file.path(R_DIR, "03b_iv_construction.R"))

cat("\n>>> Step 5/15: OLS + IV estimation...\n")
source(file.path(R_DIR, "04_ols_iv.R"))

cat("\n>>> Step 6/15: IV threshold estimates...\n")
source(file.path(R_DIR, "05_ivtr_caner_hansen.R"))

cat("\n>>> Step 7/15: Comparing threshold proxy candidates...\n")
source(file.path(R_DIR, "11_threshold_comparison.R"))

cat("\n>>> Step 8/15: Classical Caner-Hansen threshold sweep...\n")
source(file.path(R_DIR, "12_ch_classical_mongolia.R"))

cat("\n>>> Step 9/15: Classical Caner-Hansen bootstrap test...\n")
source(file.path(R_DIR, "13_ch_classical_bootstrap.R"))

cat("\n>>> Step 10/15: Panel FE/RE + Hausman...\n")
source(file.path(R_DIR, "06_panel_fe_re.R"))

cat("\n>>> Step 11/15: Robustness checks...\n")
source(file.path(R_DIR, "07_robustness.R"))

cat("\n>>> Step 12/15: Additional diagnostics and summary table...\n")
source(file.path(R_DIR, "10_improvements.R"))

cat("\n>>> Step 13/15: Phase B sensitivity checks (H3/M5/M7/Bonferroni)...\n")
source(file.path(R_DIR, "15_sensitivity_checks.R"))

cat("\n>>> Step 14/15: Phase C extensions (WCB SE, AR CI)...\n")
source(file.path(R_DIR, "16_phase_c_extensions.R"))

cat("\n>>> Step 15/15: Generating figures and tables...\n")
source(file.path(R_DIR, "08_figures.R"))
source(file.path(R_DIR, "09_tables.R"))

elapsed <- round(difftime(Sys.time(), t0, units = "mins"), 1)
cat(sprintf("\n============================================================\n"))
cat(sprintf("  ALL DONE in %.1f minutes\n", elapsed))
cat(sprintf("============================================================\n"))
