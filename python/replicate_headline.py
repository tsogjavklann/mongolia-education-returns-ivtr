"""Independent headline OLS/2SLS coefficient replication.

This script intentionally avoids statsmodels/linearmodels so it can run in a
minimal Python environment. It checks coefficients only; R remains the source of
clustered standard errors and publication tables.
"""

import numpy as np
import pandas as pd

DATA = "c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/data/clean/analysis_sample.csv"
MN_AIMAG_CODES = [
    11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48,
    61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85,
]


def weighted_lstsq(y, x, weights):
    sw = np.sqrt(weights).reshape(-1, 1)
    xw = x * sw
    yw = y.reshape(-1, 1) * sw
    beta = np.linalg.lstsq(xw, yw, rcond=None)[0].ravel()
    return beta


def weighted_2sls(y, x, z, weights):
    sw = np.sqrt(weights).reshape(-1, 1)
    xw = x * sw
    zw = z * sw
    yw = y.reshape(-1, 1) * sw
    ztz_inv = np.linalg.pinv(zw.T @ zw)
    pz_x = zw @ (ztz_inv @ (zw.T @ xw))
    beta = np.linalg.lstsq(pz_x, yw, rcond=None)[0].ravel()
    return beta


df = pd.read_csv(DATA)
main = df[
    (df["wave"] >= 2020)
    & (df["birth_aimag"].isin(MN_AIMAG_CODES))
    & df["educ_years"].notna()
    & df["log_wage"].notna()
].copy()

marital = pd.get_dummies(main["marital"].astype("category"), prefix="marital", drop_first=True)
wave = pd.get_dummies(main["wave"].astype("category"), prefix="wave", drop_first=True)
birth = pd.get_dummies(main["birth_aimag"].astype("category"), prefix="birth", drop_first=True)

controls = pd.concat(
    [main[["experience", "experience_sq", "sex", "urban", "hhsize"]], marital, wave],
    axis=1,
).astype(float)
controls.insert(0, "const", 1.0)

y = main["log_wage"].to_numpy(float)
w = main["hhweight"].to_numpy(float)

ols_x_df = pd.concat([controls, main[["educ_years"]].astype(float)], axis=1)
ols_beta = weighted_lstsq(y, ols_x_df.to_numpy(float), w)
ols_educ = ols_beta[list(ols_x_df.columns).index("educ_years")]

iv_x_df = ols_x_df
iv_z_df = pd.concat([controls, birth.astype(float)], axis=1)
iv_beta = weighted_2sls(y, iv_x_df.to_numpy(float), iv_z_df.to_numpy(float), w)
iv_educ = iv_beta[list(iv_x_df.columns).index("educ_years")]

print(f"N = {len(main)}")
print(f"OLS beta_educ = {ols_educ:.6f}")
print(f"2SLS beta_educ = {iv_educ:.6f}")
print("Expected R coefficients: OLS about 0.0553; 2SLS about 0.1213")
