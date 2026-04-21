# =============================================================================
# 01_import.R — HSES 5 wave (2016, 2018, 2020, 2021, 2024) import & merge
# SEZIS Econometrics VIII Olympiad — Returns to Education (IV-Threshold)
# =============================================================================

library(haven)
library(data.table)

# --- Paths -------------------------------------------------------------------
BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
OUT  <- file.path(BASE, "clean")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# --- Wave config -------------------------------------------------------------
# File names differ by wave (Windows download appends numbers)
waves <- list(
  "2016" = list(
    indiv    = file.path(BASE, "hses_2016", "02_indiv (8).dta"),
    basic    = file.path(BASE, "hses_2016", "basicvars (7).dta"),
    hhold    = file.path(BASE, "hses_2016", "01_hhold (7).dta")
  ),
  "2018" = list(
    indiv    = file.path(BASE, "hses_2018", "02_indiv (10).dta"),
    basic    = file.path(BASE, "hses_2018", "basicvars (9).dta"),
    hhold    = file.path(BASE, "hses_2018", "01_hhold (9).dta")
  ),
  "2020" = list(
    indiv    = file.path(BASE, "hses_2020", "02_indiv (12).dta"),
    basic    = file.path(BASE, "hses_2020", "basicvars (11).dta"),
    hhold    = file.path(BASE, "hses_2020", "01_hhold (11).dta")
  ),
  "2021" = list(
    indiv    = file.path(BASE, "hses_2021", "02_indiv (13).dta"),
    basic    = file.path(BASE, "hses_2021", "basicvars (12).dta"),
    hhold    = file.path(BASE, "hses_2021", "01_hhold (12).dta")
  ),
  "2024" = list(
    indiv    = file.path(BASE, "hses_2024", "02_indiv.dta"),
    basic    = file.path(BASE, "hses_2024", "basicvars.dta"),
    hhold    = file.path(BASE, "hses_2024", "01_hhold.dta")
  )
)

# --- Variable selection per wave group ---------------------------------------
# 2016/2018: short employment section (q04xx ends at q0419)
# 2020/2021/2024: full employment section (q04xx goes to q0450+)

vars_common <- c("identif", "ind_id", "q0102", "q0103", "q0105y", "q0106",
                 "q0210", "q0213", "q0404")

vars_early  <- c(vars_common,
                 "q0412", "q0413", "q0414",       # occupation, sector, hours (7d)
                 "q0417a", "q0417b")               # wage month, wage 12m

vars_full   <- c(vars_common,
                 "q0117", "q0118a", "q0118b",      # born_here, birth_aimag, birth_soum
                 "q0424", "q0425", "q0426", "q0427", # sector, occup, employer, hours(7d)
                 "q0435", "q0436a", "q0436b",       # received_wage, wage_month, wage_12m
                 "q0437", "q0438", "q0439")          # months, days/month, hours/day

vars_basic  <- c("identif", "newaimag", "urban", "region", "strata",
                 "aimagsoum", "hhsize", "hhweight")

# --- Import function ---------------------------------------------------------
import_wave <- function(year, paths) {
  cat(sprintf("\n=== Importing HSES %s ===\n", year))

  # Determine variable set
  is_early <- year %in% c("2016", "2018")
  sel_vars <- if (is_early) vars_early else vars_full

  # Read 02_indiv
  indiv <- as.data.table(read_dta(paths$indiv, col_select = any_of(sel_vars)))
  cat(sprintf("  indiv: %s rows x %s cols\n", nrow(indiv), ncol(indiv)))

  # Read basicvars (keep only vars that exist)
  basic_raw <- as.data.table(read_dta(paths$basic))
  basic_keep <- intersect(vars_basic, names(basic_raw))
  basic <- basic_raw[, ..basic_keep]
  cat(sprintf("  basic: %s rows x %s cols\n", nrow(basic), ncol(basic)))

  # Read 01_hhold for wave year
  hhold_raw <- as.data.table(read_dta(paths$hhold))
  # Extract year variable (may be 'years' or derivable)
  if ("years" %in% names(hhold_raw)) {
    hhold <- hhold_raw[, .(identif, survey_year = years)]
  } else {
    hhold <- data.table(identif = hhold_raw$identif, survey_year = as.integer(year))
  }
  cat(sprintf("  hhold: %s rows\n", nrow(hhold)))

  # Merge: indiv <- basic (by identif) <- hhold (by identif)
  dt <- merge(indiv, basic, by = "identif", all.x = TRUE)
  dt <- merge(dt, hhold, by = "identif", all.x = TRUE)

  # If survey_year still missing, fill with wave year
  if (!"survey_year" %in% names(dt) || all(is.na(dt$survey_year))) {
    dt[, survey_year := as.integer(year)]
  }

  # --- Harmonize variable names to common schema ---
  # Always available
  setnames(dt, old = "q0102", new = "rel_to_head", skip_absent = TRUE)
  setnames(dt, old = "q0103", new = "sex",         skip_absent = TRUE)
  setnames(dt, old = "q0105y", new = "age",        skip_absent = TRUE)
  setnames(dt, old = "q0106", new = "marital",     skip_absent = TRUE)
  setnames(dt, old = "q0210", new = "educ_level",  skip_absent = TRUE)
  setnames(dt, old = "q0213", new = "educ_years",  skip_absent = TRUE)
  setnames(dt, old = "q0404", new = "worked_7d",   skip_absent = TRUE)

  if (is_early) {
    # 2016/2018 mapping
    setnames(dt, old = "q0417a", new = "wage_monthly",  skip_absent = TRUE)
    setnames(dt, old = "q0417b", new = "wage_12m",      skip_absent = TRUE)
    setnames(dt, old = "q0413",  new = "sector",        skip_absent = TRUE)
    setnames(dt, old = "q0412",  new = "occupation",    skip_absent = TRUE)
    setnames(dt, old = "q0414",  new = "hours_week",    skip_absent = TRUE)
    # Not available in early waves
    dt[, `:=`(birth_aimag = NA_real_, birth_soum = NA_real_,
              born_here = NA_real_, employer_type = NA_real_,
              received_wage = NA_real_, months_worked = NA_real_,
              days_per_month = NA_real_, hours_per_day = NA_real_)]
  } else {
    # 2020/2021/2024 mapping
    setnames(dt, old = "q0436a", new = "wage_monthly",   skip_absent = TRUE)
    setnames(dt, old = "q0436b", new = "wage_12m",       skip_absent = TRUE)
    setnames(dt, old = "q0424",  new = "sector",         skip_absent = TRUE)
    setnames(dt, old = "q0425",  new = "occupation",     skip_absent = TRUE)
    setnames(dt, old = "q0427",  new = "hours_week",     skip_absent = TRUE)
    setnames(dt, old = "q0117",  new = "born_here",      skip_absent = TRUE)
    setnames(dt, old = "q0118a", new = "birth_aimag",    skip_absent = TRUE)
    setnames(dt, old = "q0118b", new = "birth_soum",     skip_absent = TRUE)
    setnames(dt, old = "q0426",  new = "employer_type",  skip_absent = TRUE)
    setnames(dt, old = "q0435",  new = "received_wage",  skip_absent = TRUE)
    setnames(dt, old = "q0437",  new = "months_worked",  skip_absent = TRUE)
    setnames(dt, old = "q0438",  new = "days_per_month", skip_absent = TRUE)
    setnames(dt, old = "q0439",  new = "hours_per_day",  skip_absent = TRUE)
  }

  # Add wave identifier
  dt[, wave := as.integer(year)]

  # Strip haven labels to avoid rbindlist class conflicts
  for (col in names(dt)) {
    if (inherits(dt[[col]], "haven_labelled")) {
      dt[[col]] <- as.numeric(dt[[col]])
    }
  }

  cat(sprintf("  merged: %s rows x %s cols\n", nrow(dt), ncol(dt)))
  return(dt)
}

# --- Import all waves --------------------------------------------------------
all_waves <- rbindlist(
  lapply(names(waves), function(y) import_wave(y, waves[[y]])),
  use.names = TRUE, fill = TRUE
)

cat(sprintf("\n=== POOLED: %s rows x %s cols ===\n", nrow(all_waves), ncol(all_waves)))
cat(sprintf("Waves: %s\n", paste(sort(unique(all_waves$wave)), collapse = ", ")))

# --- Basic derived variables -------------------------------------------------
all_waves[, `:=`(
  # Birth year
  birth_year = wave - age,
  # Experience (Mincer): age - educ_years - 6, floored at 0
  experience = pmax(age - educ_years - 6L, 0L, na.rm = TRUE),
  # Log wage (monthly)
  log_wage = log(wage_monthly)
)]

# Flag: has birth_aimag (for IV analysis)
all_waves[, has_birth_aimag := !is.na(birth_aimag)]

# --- Save --------------------------------------------------------------------
fwrite(all_waves, file.path(OUT, "hses_pooled.csv"))
cat(sprintf("\nSaved: %s\n", file.path(OUT, "hses_pooled.csv")))

# --- Summary -----------------------------------------------------------------
cat("\n=== SUMMARY BY WAVE ===\n")
summary_dt <- all_waves[, .(
  n_total     = .N,
  n_wage      = sum(!is.na(wage_monthly) & wage_monthly > 0, na.rm = TRUE),
  n_educ      = sum(!is.na(educ_years), na.rm = TRUE),
  n_birth_aim = sum(!is.na(birth_aimag), na.rm = TRUE),
  mean_age    = round(mean(age, na.rm = TRUE), 1),
  mean_educ   = round(mean(educ_years, na.rm = TRUE), 1),
  median_wage = round(median(wage_monthly[wage_monthly > 0], na.rm = TRUE), 0)
), by = wave]
print(summary_dt)

cat("\n=== DONE: 01_import.R ===\n")
