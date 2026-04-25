# Caner-Hansen threshold logic for this Mongolia study

This note records the post-audit logic for choosing threshold variables. The
aim is not to search mechanically for significance, but to use Mongolia-specific
institutional facts and official/research evidence to define defensible,
predetermined threshold candidates.

## Method constraint

Caner and Hansen (2004) study an IV threshold model with endogenous regressors
but an exogenous threshold variable. They explicitly state that treating the
threshold variable as endogenous would be a different model. Therefore:

- `educ_years` remains the endogenous regressor.
- `birth_aimag` dummies are the instruments.
- The threshold variable must be predetermined/exogenous.
- `educ_years` cannot be the Caner-Hansen threshold variable in the defensible
  headline specification.

Source: Caner & Hansen (2004), *Econometric Theory*:
https://www.ssc.wisc.edu/~bhansen/papers/et_04.pdf

## Mongolia-specific motivation

### Education-system transition

Mongolia extended general secondary schooling from 10 to 11 years in 2005 and
then to 12 years in 2008, with entry age lowered. This supports testing cohort
and school-supply thresholds, but it also means `educ_years` has coding/system
transition limitations across waves.

More recent UNESCO/GEM evidence also stresses rural boarding needs, uneven
quality, urban school-capacity pressure, and multi-shift schools. That makes
teacher supply and student-teacher ratio defensible Mongolia-specific threshold
variables, not arbitrary data-mined proxies.

Sources:

- UNESCO country report:
  https://www.unesco.org/education/edurights/media/resources/file/Mongolia.pdf
- UNESCO GEM Mongolia case study:
  https://www.unesco.org/gem-report/en/2026-gem-report-country-case-studies/mongolia
- APNNIC Mongolia basic education system:
  https://apnnic.net/mongolia/basic-education-system-3/
- World Bank rural education quality project:
  https://www.worldbank.org/en/results/2014/04/11/mongolia-improved-education-quality-in-rural-primary-schools

### Returns to education and non-linearity

Mongolian and international evidence supports positive returns to education and
non-linear qualification effects. RAND summarizes Pastore (2008, 2010), Darii
and Suruga (2006), and Batchuluun and Dalkhjav (2014): annual returns are
positive, tertiary education has a large premium, and postgraduate education
has a pronounced wage effect.

Sources:

- RAND, *Improving the Mongolian Labor Market and Enhancing Opportunities for
  Youth*:
  https://www.rand.org/content/dam/rand/pubs/research_reports/RR1000/RR1092/RAND_RR1092.pdf
- Pastore (2010), *Returns to education of young people in Mongolia*:
  https://www.researchgate.net/publication/227349366_Returns_to_education_of_young_people_in_Mongolia

### Regional labor-market and education mismatch

Official labor-market reports emphasize regional differences, education/labor
market mismatch, and skill-demand issues. This motivates distance/remoteness and
regional education-environment thresholds, but these are weaker as causal
thresholds because they can directly affect wages outside schooling.

Sources:

- Ministry of Labor and Social Protection research reports:
  https://mlsp.gov.mn/content/detail/3660
- MLSP labor-market overview PDF:
  https://projects.mlsp.gov.mn/api/uploads/project_attachments/20230209/8849d30e-5c19-4280-96ac-9fa7e62375ec.pdf
- MLSP Barometer Survey 2019:
  https://www.mlsp.gov.mn/uploads/files/Final_Report_Barometr_2019_MON.pdf
- NSO / 1212.mn Education and Employment PDF:
  https://www2.1212.mn/BookLibraryDownload.ashx?ln=Mn&url=Education_and_Employment.pdf

## Candidate ranking

1. Best headline threshold: `ebs_teachers_per_1000_school_age`.
   This is birth-aimag school supply during the person's school ages. It is
   predetermined and closest to the CH exogeneity requirement.

2. Strong supplementary thresholds:
   `ebs_schools_per_1000_school_age` and
   `ebs_student_teacher_ratio_school_age`.
   These represent access and classroom/school-quality environment during
   school ages.

3. Strong but smaller-N supplementary thresholds:
   `ebs_teachers_per_1000_age12` and
   `ebs_student_teacher_ratio_age12`.
   Exact age-12 exposure is conceptually clean but only available for a smaller
   younger-cohort sample.

4. Initial-condition diagnostics:
   `ebs_teachers_per_1000_2000`,
   `ebs_schools_per_1000_2000`, and
   `ebs_student_teacher_ratio_2000`.
   These are predetermined and full-sample, but they are not each person's own
   school-age exposure, especially for older cohorts.

5. Other diagnostics:
   `birth_year`, `reform2005_exp`, `reform2008_exp`, `age_at_2008`,
   `log_dist_ub`, `aimag_prior_mean`, `loo_mean_educ`.
   These are useful for mechanism checks but weaker as causal headline
   thresholds because they either change the story or may directly affect wages.

## Current empirical interpretation

The most defensible headline CH threshold remains the school-age EBS teacher
supply threshold. Under the classical Caner-Hansen three-step estimator, the
formal SupWald bootstrap test is statistically significant (`p = 0.001`,
`B = 999`) with `gamma = 41.26` teachers per 1,000 students. This supports a
threshold structure in the wage equation using an exogenous Mongolia-specific
school-supply proxy.

The conservative caveat is that the education-return slope difference at this
headline threshold is not statistically significant (`p = 0.4286`). Thus the
cleanest claim is "formal CH threshold structure exists," not "the return to
education is conclusively different across teacher-supply regimes."

The best supplementary returns-heterogeneity evidence is the age-12
student-teacher ratio threshold: formal CH bootstrap `p = 0.001`, gamma about
`23.63` pupils per teacher, low-regime return `3.4%`, high-regime return
`13.8%`, slope-difference `p = 0.0546`. This is a defensible school-quality
mechanism for Mongolia, but should be reported as marginal because the high
regime first stage is weak-ish.

Distance and prior regional education environment remain significant diagnostic
patterns. They should not be overclaimed as causal headline evidence because
their exclusion/exogeneity story is weaker: distance can directly affect wages
through labor-market access, and prior mean education is constructed from HSES
schooling outcomes.
