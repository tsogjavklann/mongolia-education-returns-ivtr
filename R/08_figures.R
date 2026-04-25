# =============================================================================
# 08_figures.R -- Generate analysis figures
# =============================================================================

suppressMessages(library(data.table))
suppressMessages(library(fixest))
suppressMessages(library(ggplot2))

BASE <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
ROOT <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric"
FIGS <- file.path(ROOT, "outputs", "figures")
dir.create(FIGS, recursive = TRUE, showWarnings = FALSE)

MN_AIMAG_CODES <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
                    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))
dt[, marital_f := factor(marital)]

theme_paper <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0),
    legend.position = "bottom"
  )

# =============================================================================
# Figure 1: Education distribution by wave
# =============================================================================
cat("Figure 1: Education distribution\n")
p1 <- ggplot(dt[!is.na(educ_years)], aes(x = educ_years)) +
  geom_histogram(binwidth = 1, boundary = 0, fill = "#2166AC",
                 color = "white", alpha = 0.9) +
  facet_wrap(~wave, ncol = 3, scales = "free_y") +
  labs(title = "Education years by survey wave",
       x = "Years of schooling", y = "Number of wage earners") +
  theme_paper
ggsave(file.path(FIGS, "f1_education_distribution.png"), p1,
       width = 9, height = 6, dpi = 300)

# =============================================================================
# Figure 2: Wage-education scatter
# =============================================================================
cat("Figure 2: Wage-education scatter\n")
set.seed(2026)
p2 <- ggplot(dt[wave == 2024 & !is.na(educ_years) & !is.na(log_wage)],
             aes(x = educ_years, y = log_wage)) +
  geom_jitter(alpha = 0.05, size = 0.5, color = "#4393C3", width = 0.15) +
  geom_smooth(method = "lm", color = "#D6604D", linewidth = 1.2, se = TRUE) +
  labs(title = "Wages and schooling, 2024",
       x = "Years of schooling", y = "Log monthly wage") +
  theme_paper
ggsave(file.path(FIGS, "f2_wage_education_scatter.png"), p2,
       width = 8, height = 6, dpi = 300)

# =============================================================================
# Figure 3: IVTR threshold profile
# =============================================================================
cat("Figure 3: IVTR threshold profile\n")
grid <- fread(file.path(BASE, "clean", "ivtr_grid_results.csv"))
ivtr_summary <- fread(file.path(BASE, "clean", "ivtr_headline_results.csv"))
get_ivtr_chr <- function(name) ivtr_summary[item == name, value][1]
threshold_label <- get_ivtr_chr("threshold_label")
threshold_unit <- get_ivtr_chr("threshold_unit")
gamma_star <- grid[which.min(ssr), gamma]

p3 <- ggplot(grid, aes(x = gamma, y = ssr)) +
  geom_line(color = "#2166AC", linewidth = 1.2) +
  geom_point(color = "#2166AC", size = 2.5) +
  geom_vline(xintercept = gamma_star, linetype = "dashed",
             color = "#D6604D", linewidth = 1) +
  annotate("text", x = gamma_star, y = max(grid$ssr, na.rm = TRUE),
           label = paste0("gamma* = ", sprintf("%.2f", gamma_star)),
           color = "#D6604D", fontface = "bold", size = 4, vjust = 1.2) +
  labs(title = "IV threshold profile",
       subtitle = threshold_label,
       x = paste0("Threshold gamma (", threshold_unit, ")"),
       y = "Weighted structural SSR") +
  theme_paper
ggsave(file.path(FIGS, "f3_threshold_profile.png"), p3,
       width = 8, height = 6, dpi = 300)

# =============================================================================
# Figure 4: Regime-specific returns
# =============================================================================
cat("Figure 4: Regime slopes\n")
get_ivtr_num <- function(name) as.numeric(ivtr_summary[item == name, value][1])
gamma_star <- get_ivtr_num("gamma_star")
b1 <- get_ivtr_num("beta_1")
b2 <- get_ivtr_num("beta_2")
s1 <- get_ivtr_num("se_1")
s2 <- get_ivtr_num("se_2")

regime_dt <- data.table(
  regime = c(paste0("Low EBS supply\nq <= ", sprintf("%.2f", gamma_star)),
             paste0("High EBS supply\nq > ", sprintf("%.2f", gamma_star))),
  beta = c(b1, b2),
  se = c(s1, s2)
)
regime_dt[, `:=`(lo = beta - 1.96 * se, hi = beta + 1.96 * se,
                 ret_pct = 100 * (exp(beta) - 1))]
regime_dt[, regime := factor(regime, levels = regime)]

p4 <- ggplot(regime_dt, aes(x = regime, y = beta)) +
  geom_col(fill = c("#4393C3", "#D6604D"), width = 0.5) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.8) +
  geom_hline(yintercept = 0, linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%/year", ret_pct)),
            vjust = -0.6, fontface = "bold") +
  labs(title = "IV return to education by exogenous EBS regime",
       x = NULL, y = "Return coefficient on schooling (beta)") +
  theme_paper
ggsave(file.path(FIGS, "f4_regime_slopes.png"), p4,
       width = 7, height = 6, dpi = 300)

# =============================================================================
# Figure 5: OLS vs IV comparison across waves
# =============================================================================
cat("Figure 5: OLS vs IV comparison\n")
ols_wave <- rbindlist(lapply(sort(unique(dt$wave)), function(w) {
  m <- feols(log_wage ~ educ_years + experience + experience_sq +
               sex + i(marital_f) + urban + hhsize | newaimag,
             data = dt[wave == w], weights = ~hhweight, cluster = ~newaimag,
             notes = FALSE)
  data.table(wave = w, beta = coef(m)["educ_years"], se = se(m)["educ_years"])
}))
main_iv <- dt[wave >= 2020 & birth_aimag %in% MN_AIMAG_CODES &
                !is.na(educ_years) & !is.na(log_wage)]
iv_birth <- feols(log_wage ~ experience + experience_sq + sex + i(marital_f) +
                    urban + hhsize |
                    wave |
                    educ_years ~ i(birth_aimag),
                  data = main_iv, weights = ~hhweight, cluster = ~newaimag,
                  notes = FALSE)
iv_beta <- coef(iv_birth)["fit_educ_years"]
iv_se <- se(iv_birth)["fit_educ_years"]
comp_dt <- data.table(
  wave = rep(c(2016, 2018, 2020, 2021, 2024), 2),
  method = rep(c("OLS", "IV (birth aimag)"), each = 5),
  beta = c(ols_wave$beta, NA, NA, iv_beta, iv_beta, iv_beta),
  se = c(ols_wave$se, NA, NA, iv_se, iv_se, iv_se)
)
comp_dt[, `:=`(lo = beta - 1.96 * se, hi = beta + 1.96 * se)]

p5 <- ggplot(comp_dt[!is.na(beta)], aes(x = wave, y = beta, color = method)) +
  geom_point(size = 3, position = position_dodge(width = 0.8)) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.4,
                position = position_dodge(width = 0.8)) +
  geom_line(position = position_dodge(width = 0.8), linewidth = 0.8) +
  scale_color_manual(values = c("OLS" = "#2166AC",
                                "IV (birth aimag)" = "#D6604D")) +
  labs(title = "OLS and IV returns to schooling",
       x = "Survey wave", y = "Return coefficient on schooling (beta)",
       color = "Method") +
  theme_paper
ggsave(file.path(FIGS, "f5_ols_vs_iv.png"), p5,
       width = 8, height = 6, dpi = 300)

cat(sprintf("\n=== ALL 5 FIGURES SAVED to %s ===\n", FIGS))
cat("\n=== DONE: 08_figures.R ===\n")
