# =============================================================================
# 08_figures.R — 5 Publication-Quality Figures (300 dpi PNG)
# =============================================================================

library(data.table)
library(ggplot2)

BASE  <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data"
FIGS  <- "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/outputs/figures"
dir.create(FIGS, showWarnings = FALSE, recursive = TRUE)

dt <- fread(file.path(BASE, "clean", "analysis_sample.csv"))

theme_paper <- theme_minimal(base_size = 12, base_family = "serif") +
  theme(plot.title = element_text(face = "bold", size = 13),
        panel.grid.minor = element_blank())

# =============================================================================
# Figure 1: Education years distribution by wave
# =============================================================================
cat("Figure 1: Education distribution\n")
p1 <- ggplot(dt[!is.na(educ_years)], aes(x = educ_years)) +
  geom_histogram(binwidth = 1, fill = "#2166AC", color = "white", alpha = 0.8) +
  facet_wrap(~wave, ncol = 3) +
  labs(x = "Боловсролын жил", y = "Хүний тоо") +
  scale_x_continuous(breaks = seq(0, 20, 4)) +
  theme_paper
ggsave(file.path(FIGS, "f1_education_distribution.png"), p1,
       width = 10, height = 6, dpi = 300)

# =============================================================================
# Figure 2: Log wage vs education (scatter + OLS fit)
# =============================================================================
cat("Figure 2: Wage-education scatter\n")
p2 <- ggplot(dt[wave == 2024 & !is.na(educ_years)],
             aes(x = educ_years, y = log_wage)) +
  geom_jitter(alpha = 0.05, size = 0.5, color = "#4393C3") +
  geom_smooth(method = "lm", color = "#D6604D", linewidth = 1.2, se = TRUE) +
  labs(x = "Боловсролын жил", y = "log(сарын цалин)") +
  theme_paper
ggsave(file.path(FIGS, "f2_wage_education_scatter.png"), p2,
       width = 8, height = 6, dpi = 300)

# =============================================================================
# Figure 3: IVTR Grid Search — SSR vs gamma (HEADLINE FIGURE)
# =============================================================================
cat("Figure 3: IVTR threshold profile\n")
grid <- fread(file.path(BASE, "clean", "ivtr_grid_results.csv"))
gamma_star <- grid[which.min(ssr), gamma]

p3 <- ggplot(grid, aes(x = gamma, y = ssr)) +
  geom_line(color = "#2166AC", linewidth = 1.2) +
  geom_point(color = "#2166AC", size = 3) +
  geom_vline(xintercept = gamma_star, linetype = "dashed", color = "#D6604D",
             linewidth = 1) +
  annotate("text", x = gamma_star + 0.3, y = max(grid$ssr) * 0.98,
           label = paste0("γ* = ", gamma_star, " жил"),
           color = "#D6604D", fontface = "bold", size = 5, hjust = 0) +
  labs(x = "Босго γ (боловсролын жил)",
       y = "Төвлөрсөн алдааны квадратын нийлбэр (SSR)") +
  theme_paper
ggsave(file.path(FIGS, "f3_threshold_profile.png"), p3,
       width = 8, height = 6, dpi = 300)

# =============================================================================
# Figure 4: Regime-specific returns (coefficient plot)
# =============================================================================
cat("Figure 4: Regime slopes\n")
regime_dt <- data.table(
  regime = c(paste0("β₁: educ ≤ ", gamma_star), paste0("β₂: educ > ", gamma_star)),
  beta = c(0.0533, 0.1650),
  se = c(0.0272, 0.0307)
)
regime_dt[, `:=`(lo = beta - 1.96 * se, hi = beta + 1.96 * se)]
regime_dt[, regime := factor(regime, levels = regime)]

p4 <- ggplot(regime_dt, aes(x = regime, y = beta)) +
  geom_col(fill = c("#4393C3", "#D6604D"), width = 0.5) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.8) +
  geom_hline(yintercept = 0, linewidth = 0.5) +
  labs(x = NULL, y = "Боловсролын жилийн өгөөж (β)") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  annotate("text", x = 1, y = regime_dt$beta[1] + 0.03,
           label = "5.5%/жил", fontface = "bold", size = 4.5) +
  annotate("text", x = 2, y = regime_dt$beta[2] + 0.03,
           label = "17.9%/жил", fontface = "bold", size = 4.5) +
  theme_paper
ggsave(file.path(FIGS, "f4_regime_slopes.png"), p4,
       width = 7, height = 6, dpi = 300)

# =============================================================================
# Figure 5: OLS vs IV comparison across waves
# =============================================================================
cat("Figure 5: OLS vs IV comparison\n")
comp_dt <- data.table(
  wave = rep(c(2016, 2018, 2020, 2021, 2024), 2),
  method = rep(c("OLS", "IV (birth aimag)"), each = 5),
  beta = c(0.0894, 0.0822, 0.0621, 0.0646, 0.0494,   # OLS by wave
           NA, NA, 0.1133, 0.1133, 0.1133),            # IV (pooled main)
  se = c(0.0021, 0.0028, 0.0036, 0.0022, 0.0021,
         NA, NA, 0.0068, 0.0068, 0.0068)
)
comp_dt[, `:=`(lo = beta - 1.96 * se, hi = beta + 1.96 * se)]

p5 <- ggplot(comp_dt[!is.na(beta)], aes(x = wave, y = beta, color = method)) +
  geom_point(size = 3, position = position_dodge(width = 0.8)) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.4,
                position = position_dodge(width = 0.8)) +
  geom_line(position = position_dodge(width = 0.8), linewidth = 0.8) +
  scale_color_manual(values = c("OLS" = "#2166AC", "IV (birth aimag)" = "#D6604D"),
                     labels = c("OLS" = "OLS", "IV (birth aimag)" = "IV (төрсөн аймаг)")) +
  labs(x = "ӨНЭЗС-ийн жил", y = "Боловсролын жилийн өгөөж (β)",
       color = "Арга") +
  theme_paper +
  theme(legend.position = "bottom")
ggsave(file.path(FIGS, "f5_ols_vs_iv.png"), p5,
       width = 8, height = 6, dpi = 300)

cat(sprintf("\n=== ALL 5 FIGURES SAVED to %s ===\n", FIGS))
cat("  f1_education_distribution.png\n")
cat("  f2_wage_education_scatter.png\n")
cat("  f3_threshold_profile.png\n")
cat("  f4_regime_slopes.png\n")
cat("  f5_ols_vs_iv.png\n")
cat("\n=== DONE: 08_figures.R ===\n")
