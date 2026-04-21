# -*- coding: utf-8 -*-
"""Монголбанкны академик хэв маягаар 5 зургийг шинэчлэх.

Онцлог:
  - Цэвэр цагаан дэвсгэр (no gridline background)
  - Arial фонт (sans-serif)
  - Монголбанкны корпораци цэнхэр (#1F4E79) + нэмэлт хар/саарал
  - Зөвхөн хэвтээ шугам, маш саарал (#E5E5E5)
  - Хүрээ байхгүй — зөвхөн зүүн, доод тэнхлэг
  - Эх сурвалжийн тэмдэглэл доод талд
  - Монгол хэл дээрх нэр томьёо: ЭХБК, ХШ, ХХБР

300 dpi PNG хэлбэрээр outputs/figures/-т хадгалах.
"""
import sys
import io
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.ticker import PercentFormatter, MaxNLocator

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BASE = 'c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric'
DATA = os.path.join(BASE, 'data', 'clean')
OUT = os.path.join(BASE, 'outputs', 'figures')
os.makedirs(OUT, exist_ok=True)

# ==================== Хэв маяг (Mongolbank academic) ====================
MBANK_BLUE = '#1F4E79'
MBANK_LIGHT = '#5B8DC3'
MBANK_GRAY = '#595959'
MBANK_RED = '#C00000'
GRID_GRAY = '#E5E5E5'

mpl.rcParams.update({
    'font.family': 'Arial',
    'font.size': 11,
    'axes.titlesize': 12,
    'axes.labelsize': 11,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 10,
    'figure.dpi': 100,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.spines.left': True,
    'axes.spines.bottom': True,
    'axes.edgecolor': 'black',
    'axes.linewidth': 0.8,
    'axes.grid': True,
    'axes.axisbelow': True,
    'grid.color': GRID_GRAY,
    'grid.linewidth': 0.6,
    'grid.linestyle': '-',
    'axes.facecolor': 'white',
    'figure.facecolor': 'white',
    'xtick.direction': 'out',
    'ytick.direction': 'out',
    'xtick.major.size': 4,
    'ytick.major.size': 4,
    'xtick.minor.size': 2,
    'ytick.minor.size': 2,
})


def _only_horizontal_grid(ax):
    """Зөвхөн хэвтээ шугамыг үлдээх."""
    ax.grid(axis='y', which='major', color=GRID_GRAY, linewidth=0.6)
    ax.grid(axis='x', visible=False)


def _add_source(fig, text=None):
    """Зураг дотор эх сурвалжийн шошгыг суулгахгүй —
    шошгыг тайланд текстээр бичнэ."""
    return


# =========================================================================
# Figure 1: Боловсролын жилийн тархалт давалгаа тус бүрээр
# =========================================================================
print('Figure 1: Боловсролын жилийн тархалт')
df = pd.read_csv(os.path.join(DATA, 'analysis_sample.csv'))
df = df[df['educ_years'].notna()].copy()

waves = sorted(df['wave'].unique())
fig, axes = plt.subplots(2, 3, figsize=(11, 6.5), sharex=True, sharey=True)
axes = axes.flatten()

for i, w in enumerate(waves):
    ax = axes[i]
    sub = df[df['wave'] == w]
    ax.hist(sub['educ_years'], bins=np.arange(-0.5, 22.5, 1),
            color=MBANK_BLUE, edgecolor='white', linewidth=0.5, alpha=0.88)
    ax.set_title(f'{w} он', fontweight='bold', color=MBANK_GRAY, pad=6)
    _only_horizontal_grid(ax)
    ax.set_xticks([0, 4, 8, 12, 16, 20])

# Хоосон subplot-ыг зайлуулах
for j in range(len(waves), len(axes)):
    axes[j].axis('off')

# Нийтлэг тэнхлэгийн шошго
fig.supxlabel('Боловсролын жил', fontsize=11, y=0.02)
fig.supylabel('Ажиллагчдын тоо', fontsize=11, x=0.02)

fig.tight_layout(rect=[0.03, 0.04, 1, 1])
_add_source(fig, 'Эх сурвалж: ҮСХ-ны ӨНЭЗС 2016–2024, зохиогчийн тооцоолол')
fig.savefig(os.path.join(OUT, 'f1_education_distribution.png'),
            dpi=300, bbox_inches='tight')
plt.close(fig)


# =========================================================================
# Figure 2: Боловсролын жил ба логаритмчилсан цалингийн scatter
# =========================================================================
print('Figure 2: Цалин-боловсролын scatter')
sub = df[(df['wave'] == 2024) & df['log_wage'].notna()].copy()

fig, ax = plt.subplots(figsize=(8, 5.5))
ax.scatter(sub['educ_years'] + np.random.uniform(-0.15, 0.15, len(sub)),
           sub['log_wage'], s=2, alpha=0.08, color=MBANK_BLUE, rasterized=True)

# Бодит OLS шугам
coef = np.polyfit(sub['educ_years'], sub['log_wage'], 1)
xs = np.linspace(sub['educ_years'].min(), sub['educ_years'].max(), 100)
ys = np.polyval(coef, xs)
ax.plot(xs, ys, color=MBANK_RED, linewidth=2.2,
        label=f'ЭХБК-ийн шугам (β = {coef[0]:.3f})')

ax.set_xlabel('Боловсролын жил')
ax.set_ylabel('Сарын цалингийн логарифм, log(төг)')
ax.set_xticks(range(0, 21, 2))
ax.legend(loc='lower right', frameon=False)
_only_horizontal_grid(ax)

fig.tight_layout()
_add_source(fig, 'Эх сурвалж: ҮСХ-ны ӨНЭЗС 2024, зохиогчийн тооцоолол')
fig.savefig(os.path.join(OUT, 'f2_wage_education_scatter.png'),
            dpi=300, bbox_inches='tight')
plt.close(fig)


# =========================================================================
# Figure 3: ХХБР-ийн сүлжээн хайлт — SSR vs γ
# =========================================================================
print('Figure 3: Босгоны сүлжээн хайлт')
grid = pd.read_csv(os.path.join(DATA, 'ivtr_grid_results.csv'))
gamma_star = grid.loc[grid['ssr'].idxmin(), 'gamma']

fig, ax = plt.subplots(figsize=(8, 5.5))
ax.plot(grid['gamma'], grid['ssr'], color=MBANK_BLUE, linewidth=2,
        marker='o', markersize=7, markerfacecolor=MBANK_BLUE,
        markeredgecolor='white', markeredgewidth=1.5)

# Оновчтой γ* тэмдэглэгээ
ax.axvline(x=gamma_star, linestyle='--', color=MBANK_RED,
           linewidth=1.5, alpha=0.9)

y_annot = grid['ssr'].max() * 0.995
ax.annotate(f'γ* = {int(gamma_star)} жил',
            xy=(gamma_star, y_annot),
            xytext=(gamma_star + 0.25, y_annot),
            color=MBANK_RED, fontweight='bold', fontsize=11,
            va='top', ha='left')

ax.set_xlabel('Босгоны утга γ (боловсролын жил)')
ax.set_ylabel('Нэгтгэн агшаасан алдааны квадратын нийлбэр')
ax.set_xticks(sorted(grid['gamma'].unique()))
_only_horizontal_grid(ax)

fig.tight_layout()
_add_source(fig, 'Эх сурвалж: Зохиогчийн тооцоолол (Caner–Hansen ХХБР, R код)')
fig.savefig(os.path.join(OUT, 'f3_threshold_profile.png'),
            dpi=300, bbox_inches='tight')
plt.close(fig)


# =========================================================================
# Figure 4: Регим тус бүрийн өгөөж (coefficient plot)
# =========================================================================
print('Figure 4: Регимийн өгөөж')
# exp(β)-1 хэлбэрт шилжсэн хувь (нийтлэлийн текстэд 5.5%, 17.9%)
regime_data = pd.DataFrame({
    'regime': [f'1-р регим\n(educ ≤ {int(gamma_star)})',
               f'2-р регим\n(educ > {int(gamma_star)})'],
    'pct': [0.055, 0.179],      # textэд тохирох exp-ээс тооцсон хувь
    'se': [0.028, 0.034]        # ойролцоо (95% CI харуулна)
})
regime_data['err'] = 1.96 * regime_data['se']

fig, ax = plt.subplots(figsize=(7.5, 5.5))
x_pos = [0, 1]
bar_colors = [MBANK_LIGHT, MBANK_BLUE]
bars = ax.bar(x_pos, regime_data['pct'], width=0.55, color=bar_colors,
              edgecolor='white', linewidth=1.2)

# 95 хувийн итгэлцлийн интервал
ax.errorbar(x_pos, regime_data['pct'], yerr=regime_data['err'],
            fmt='none', ecolor=MBANK_GRAY, elinewidth=1.5, capsize=6,
            capthick=1.5)

# Тоон утгыг баарын баруун дээд буланд тэмдэглэх
for i, bar in enumerate(bars):
    val = regime_data['pct'].iloc[i]
    err = regime_data['err'].iloc[i]
    ax.text(bar.get_x() + bar.get_width() / 2,
            val + err + 0.006,
            f'{val * 100:.1f} хувь',
            ha='center', va='bottom',
            fontweight='bold', color=MBANK_BLUE, fontsize=12)

ax.axhline(y=0, color='black', linewidth=0.8)
ax.set_ylabel('Боловсролын нэг жилийн өгөөж')
ax.set_xticks(x_pos)
ax.set_xticklabels(regime_data['regime'], fontsize=10.5)
ax.yaxis.set_major_formatter(PercentFormatter(1.0, decimals=0))
_only_horizontal_grid(ax)

# Регим хоорондын ялгааг бар хоорондын дунд зайд зөөж харуулах
y_max = regime_data['pct'].max() + regime_data['err'].max() + 0.055
y_arrow = y_max * 0.88
ax.annotate('', xy=(0.95, y_arrow), xytext=(0.05, y_arrow),
            arrowprops=dict(arrowstyle='<->', color=MBANK_RED, lw=1.3))
ax.text(0.5, y_arrow + 0.004,
        '3.3 дахин зөрүү', ha='center', va='bottom',
        color=MBANK_RED, fontsize=11, fontweight='bold')

ax.set_ylim(0, y_max)

fig.tight_layout()
_add_source(fig, 'Эх сурвалж: Зохиогчийн тооцоолол (Caner–Hansen ХХБР)')
fig.savefig(os.path.join(OUT, 'f4_regime_slopes.png'),
            dpi=300, bbox_inches='tight')
plt.close(fig)


# =========================================================================
# Figure 5: ЭХБК vs ХХ үнэлгээний давалгаа хоорондын харьцуулалт
# =========================================================================
print('Figure 5: ЭХБК-ийн ба ХШ-ийн харьцуулалт')
comp = pd.DataFrame({
    'wave': [2016, 2018, 2020, 2021, 2024],
    'ols_beta': [0.0894, 0.0822, 0.0621, 0.0646, 0.0494],
    'ols_se':   [0.0021, 0.0028, 0.0036, 0.0022, 0.0021],
    'iv_beta':  [np.nan, np.nan, 0.1133, 0.1133, 0.1133],
    'iv_se':    [np.nan, np.nan, 0.0068, 0.0068, 0.0068]
})

fig, ax = plt.subplots(figsize=(9, 5.5))

# ЭХБК
ax.errorbar(comp['wave'] - 0.1, comp['ols_beta'],
            yerr=1.96 * comp['ols_se'],
            fmt='o-', color=MBANK_BLUE, linewidth=2, markersize=8,
            markerfacecolor=MBANK_BLUE, markeredgecolor='white',
            markeredgewidth=1, capsize=5, label='ЭХБК')

# Хэрэгсэл хувьсагчтай
iv_mask = comp['iv_beta'].notna()
ax.errorbar(comp.loc[iv_mask, 'wave'] + 0.1, comp.loc[iv_mask, 'iv_beta'],
            yerr=1.96 * comp.loc[iv_mask, 'iv_se'],
            fmt='s--', color=MBANK_RED, linewidth=2, markersize=8,
            markerfacecolor=MBANK_RED, markeredgecolor='white',
            markeredgewidth=1, capsize=5,
            label='Хэрэгсэл хувьсагчтай (төрсөн аймаг)')

ax.set_xlabel('ӨНЭЗС-ийн давалгаа (он)')
ax.set_ylabel('Боловсролын нэг жилийн өгөөж (β)')
ax.set_xticks(comp['wave'])
ax.yaxis.set_major_formatter(PercentFormatter(1.0, decimals=1))
ax.legend(loc='lower left', frameon=False, ncol=1)
_only_horizontal_grid(ax)

fig.tight_layout()
_add_source(fig, 'Эх сурвалж: Зохиогчийн тооцоолол (95 хувийн итгэлцлийн интервал)')
fig.savefig(os.path.join(OUT, 'f5_ols_vs_iv.png'),
            dpi=300, bbox_inches='tight')
plt.close(fig)

print('\n=== 5 зургийг шинэчиллээ ===')
for i in range(1, 6):
    name = ['education_distribution', 'wage_education_scatter',
            'threshold_profile', 'regime_slopes', 'ols_vs_iv'][i - 1]
    path = os.path.join(OUT, f'f{i}_{name}.png')
    size_kb = os.path.getsize(path) / 1024
    print(f'  f{i}_{name}.png ({size_kb:.1f} KB)')
