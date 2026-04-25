"""
Deprecated paper builder.

The previous builder generated a manuscript with stale IV-threshold claims
from the invalid endogenous `educ_years` threshold specification. It is
disabled so the outdated endogenous-threshold narrative cannot be accidentally
regenerated.
"""

raise SystemExit(
    "outputs/paper/build_paper.py is deprecated. "
    "Rewrite the paper from current inputs/data_summary/research_results.md "
    "and current inputs/tables/*.csv before building a DOCX."
)
