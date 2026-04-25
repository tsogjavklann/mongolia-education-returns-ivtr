# -*- coding: utf-8 -*-
"""Regenerate the five main figures from the current analysis outputs.

This script mirrors R/08_figures.R and intentionally reads the current
ivtr_headline_results.csv so the threshold plots do not fall back to the old
educ_years threshold.
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

BASE = "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric"
DATA = os.path.join(BASE, "data", "clean")
OUT = os.path.join(BASE, "outputs", "figures")
os.makedirs(OUT, exist_ok=True)

BLUE = "#2166AC"
LIGHT_BLUE = "#4393C3"
RED = "#D6604D"
GRAY = "#595959"


def style_axis(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(axis="y", color="#E5E5E5", linewidth=0.7)
    ax.grid(axis="x", visible=False)
    ax.set_axisbelow(True)


def save(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, name), dpi=300, bbox_inches="tight")
    plt.close(fig)


df = pd.read_csv(os.path.join(DATA, "analysis_sample.csv"))

# Figure 1: education distribution by wave
print("Figure 1: education distribution")
waves = sorted(df["wave"].dropna().unique())
fig, axes = plt.subplots(2, 3, figsize=(11, 6.5), sharex=True)
axes = axes.ravel()
for ax, wave in zip(axes, waves):
    sub = df[(df["wave"] == wave) & df["educ_years"].notna()]
    ax.hist(sub["educ_years"], bins=np.arange(-0.5, 22.5, 1),
            color=BLUE, edgecolor="white", linewidth=0.5)
    ax.set_title(str(int(wave)), fontweight="bold", color=GRAY)
    ax.set_xlabel("Years of schooling")
    ax.set_ylabel("Count")
    style_axis(ax)
for ax in axes[len(waves):]:
    ax.axis("off")
save(fig, "f1_education_distribution.png")

# Figure 2: wage-education scatter
print("Figure 2: wage-education scatter")
sub = df[(df["wave"] == 2024) & df["educ_years"].notna() & df["log_wage"].notna()].copy()
rng = np.random.default_rng(2026)
fig, ax = plt.subplots(figsize=(8, 5.5))
ax.scatter(sub["educ_years"] + rng.uniform(-0.15, 0.15, len(sub)),
           sub["log_wage"], s=3, alpha=0.08, color=LIGHT_BLUE)
coef = np.polyfit(sub["educ_years"], sub["log_wage"], 1)
xs = np.linspace(sub["educ_years"].min(), sub["educ_years"].max(), 100)
ax.plot(xs, np.polyval(coef, xs), color=RED, linewidth=2)
ax.set_title("Wages and schooling, 2024", fontweight="bold")
ax.set_xlabel("Years of schooling")
ax.set_ylabel("Log monthly wage")
style_axis(ax)
save(fig, "f2_wage_education_scatter.png")

# Figure 3: IVTR threshold profile
print("Figure 3: IVTR threshold profile")
grid = pd.read_csv(os.path.join(DATA, "ivtr_grid_results.csv"))
summary = pd.read_csv(os.path.join(DATA, "ivtr_headline_results.csv"))
ivtr = dict(zip(summary["item"], summary["value"]))
gamma_star = float(grid.loc[grid["ssr"].idxmin(), "gamma"])
threshold_label = ivtr.get("threshold_label", "Threshold variable")
threshold_unit = ivtr.get("threshold_unit", "units")

fig, ax = plt.subplots(figsize=(8, 5.5))
ax.plot(grid["gamma"], grid["ssr"], color=BLUE, linewidth=2,
        marker="o", markersize=4)
ax.axvline(gamma_star, linestyle="--", color=RED, linewidth=1.5)
ax.annotate(f"gamma* = {gamma_star:.2f}",
            xy=(gamma_star, grid["ssr"].max()),
            xytext=(gamma_star + 0.25, grid["ssr"].max()),
            color=RED, fontweight="bold", va="top")
ax.set_title("IV threshold profile", fontweight="bold")
ax.text(0.0, 1.02, threshold_label, transform=ax.transAxes, color=GRAY)
ax.set_xlabel(f"Threshold gamma ({threshold_unit})")
ax.set_ylabel("Weighted structural SSR")
style_axis(ax)
save(fig, "f3_threshold_profile.png")

# Figure 4: regime-specific IV returns
print("Figure 4: regime returns")
b1 = float(ivtr["beta_1"])
b2 = float(ivtr["beta_2"])
s1 = float(ivtr["se_1"])
s2 = float(ivtr["se_2"])
regimes = [f"Low EBS supply\nq <= {gamma_star:.2f}",
           f"High EBS supply\nq > {gamma_star:.2f}"]
betas = np.array([b1, b2])
ses = np.array([s1, s2])
returns = 100 * (np.exp(betas) - 1)

fig, ax = plt.subplots(figsize=(7, 5.5))
x = np.arange(2)
bars = ax.bar(x, betas, width=0.55, color=[LIGHT_BLUE, RED], edgecolor="white")
ax.errorbar(x, betas, yerr=1.96 * ses, fmt="none", ecolor=GRAY,
            capsize=5, linewidth=1.3)
for i, bar in enumerate(bars):
    ax.text(bar.get_x() + bar.get_width() / 2,
            betas[i] + 1.96 * ses[i] + 0.006,
            f"{returns[i]:.1f}%/year",
            ha="center", va="bottom", fontweight="bold")
ax.axhline(0, color="black", linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels(regimes)
ax.set_title("IV return to education by exogenous EBS regime", fontweight="bold")
ax.set_ylabel("Return coefficient on schooling (beta)")
style_axis(ax)
save(fig, "f4_regime_slopes.png")

# Figure 5: OLS vs IV comparison
print("Figure 5: OLS vs IV comparison")
ols = []
for wave in waves:
    sub = df[(df["wave"] == wave) & df["educ_years"].notna() & df["log_wage"].notna()]
    coef = np.polyfit(sub["educ_years"], sub["log_wage"], 1)[0]
    ols.append({"wave": wave, "method": "OLS", "beta": coef})

t3 = pd.read_csv(os.path.join(BASE, "outputs", "tables", "t3_iv_results.csv"))
iv_beta = float(t3.loc[t3["Statistic"] == "beta_educ", "(2) 2SLS birth_aimag"].iloc[0])
for wave in [2020, 2021, 2024]:
    ols.append({"wave": wave, "method": "IV (birth aimag)", "beta": iv_beta})
comp = pd.DataFrame(ols)

fig, ax = plt.subplots(figsize=(8, 5.5))
for method, color in [("OLS", BLUE), ("IV (birth aimag)", RED)]:
    sub = comp[comp["method"] == method]
    ax.plot(sub["wave"], sub["beta"], marker="o", color=color,
            linewidth=1.5, label=method)
ax.set_title("OLS and IV returns to schooling", fontweight="bold")
ax.set_xlabel("Survey wave")
ax.set_ylabel("Return coefficient on schooling (beta)")
ax.legend(frameon=False, loc="best")
style_axis(ax)
save(fig, "f5_ols_vs_iv.png")

print(f"Saved figures to {OUT}")
