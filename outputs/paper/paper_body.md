# Deprecated paper body

This generated paper body is intentionally disabled.

The previous version contained stale IV-threshold claims based on an endogenous
`educ_years` threshold. Those claims are no longer econometrically defensible
after the audit.

Use the current analysis outputs instead:

- `inputs/data_summary/research_results.md`
- `inputs/tables/t3_iv_results.csv`
- `inputs/tables/t4_ivtr_headline.csv`
- `inputs/tables/t7_threshold_proxy_comparison.csv`

Before rebuilding the paper, rewrite the manuscript around the current
evidence:

- Main IV return: `birth_aimag` instrument, with overidentification caveat.
- Distance IV: robustness only, because the mechanism check is not clean.
- IV-threshold: exogenous EBS school-age teacher supply threshold; no
  statistically significant slope difference in the headline specification.
- Education-years coding: report the HSES coding limitation explicitly.
