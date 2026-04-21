
import pandas as pd
import numpy as np
from linearmodels.iv import IV2SLS
import statsmodels.api as sm

df = pd.read_csv("c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data/clean/analysis_sample.csv")
main = df[(df.wave >= 2020) & df.birth_aimag.notna() & df.educ_years.notna() & df.log_wage.notna()].copy()

# OLS
X_ols = sm.add_constant(main[["educ_years","experience","experience_sq","sex","marital","urban","hhsize"]])
ols = sm.WLS(main["log_wage"], X_ols, weights=main["hhweight"]).fit()
print(f"OLS beta_educ = {ols.params["educ_years"]:.4f} (SE {ols.bse["educ_years"]:.4f})")

print("\nPython replication complete.")

