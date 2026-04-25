# Судалгааны үр дүнгийн шинэчилсэн хураангуй

> Энэ файл нь зөвхөн шинжилгээний шинэчилсэн үр дүнг нэгтгэнэ. Paper/docx доторх хуучин тоонуудыг эндээс автоматаар зөв гэж үзэж болохгүй.

## Өгөгдөл

- Эх үүсвэр: ҮСХ, ӨНЭЗС/HSES.
- Давалгаа: 2016, 2018, 2020, 2021, 2024.
- Үндсэн sample: 25-60 насны, эерэг сарын цалинтай 49,366 хүн.
- IV sample: 2020, 2021, 2024 оны Монголын стандарт төрсөн-аймгийн кодтой 11,924 хүн.
- Threshold sample: school-age EBS exposure дор хаяж 3 жил ажиглагдсан 5,170 хүн.

## Гол хувьсагч

| Хувьсагч | Тайлбар |
|---|---|
| `log_wage` | ln(сарын цалин) |
| `educ_years` | боловсролын жил, endogenous regressor |
| `birth_aimag` | төрсөн аймаг, ҮСХ-ийн 2 оронтой код |
| `log_dist_ub` | төрсөн аймгийн төвөөс Улаанбаатар хүртэлх зайны логарифм |
| `ebs_teachers_per_1000_school_age` | төрсөн аймгийн ЕБС-ийн багш / 1,000 сурагч, 6-17 насны school-age жилүүдийн дундаж |

## OLS

| Загвар | beta_educ | SE | N |
|---|---:|---:|---:|
| OLS simple | 0.0736 | 0.0011 | 49,357 |
| OLS + controls | 0.0784 | 0.0011 | 49,357 |
| OLS + aimag FE + wave FE | 0.0631 | 0.0020 | 49,357 |

Тайлбар: Үндсэн OLS+FE өгөөж `exp(0.0631)-1 = 6.5%` орчим.

## IV

| Загвар | beta_educ | SE | First-stage F/Wald | N |
|---|---:|---:|---:|---:|
| OLS, IV sample | 0.0553 | 0.0031 | - | 11,924 |
| 2SLS birth_aimag | 0.1213 | 0.0079 | 16.39 | 11,924 |
| 2SLS log_dist_UB | 0.1498 | 0.0145 | 227.98 | 11,924 |
| 2SLS birth_aimag + current aimag FE | 0.1113 | 0.0040 | 15.22 | 11,924 |

Хамгийн хамгаалагдах гол IV үр дүн нь `birth_aimag` instrument: `exp(0.1213)-1 = 12.9%`.

## Threshold Засвар

Өмнөх `educ_years` threshold нь Caner-Hansen-ийн exogenous-threshold assumption зөрчсөн. Зассан хувилбарт:

- Endogenous regressor: `educ_years`
- Instrument: `birth_aimag`
- Threshold variable: `ebs_teachers_per_1000_school_age`

Энэ threshold нь тухайн хүний боловсролын сонголт биш, харин төрсөн аймаг дахь school-age үеийн боловсролын supply учраас онолын хувьд хамгийн хамгаалагдах сонголт.

## IV Threshold Үр Дүн: strict interacted-IV robustness

| Item | Value |
|---|---:|
| Threshold variable | EBS teachers per 1,000 students during school ages 6-17 |
| gamma* | 41.10 teachers per 1,000 students |
| LR-profile 95% set | [41.10, 43.71] |
| Regime 1: low EBS supply | beta = 0.0588, SE = 0.0155, return = 6.1% |
| Regime 2: high EBS supply | beta = 0.0507, SE = 0.0393, return = 5.2% |
| Difference beta2 - beta1 | -0.0081 |
| Equality test | t = -0.17, p = 0.8688 |
| Separate-regime F/Wald, low supply | 11.55 |
| Separate-regime F/Wald, high supply | 19.59 |
| SupWald-style statistic | 657.52 |
| Wild bootstrap p-value | 0.9870, B = 1000 |
| N regime 1 / regime 2 | 2,820 / 2,350 |

Зөв тайлбар: strict interacted-IV robustness загвар дээр боловсролын өгөөж ЕБС-ийн teacher-supply regime-ээр статистикийн хувьд ялгаатай гэсэн нотолгоо гарахгүй байна. Энэ нь Caner-Hansen (2004)-ийн classical 3-step estimator биш, харин илүү хатуу interacted first-stage robustness шалгалт.

## Threshold Proxy Comparison

- Хамгийн зөв онолын сонголт: `D1: EBS school-age teachers per 1,000 students`.
- `educ_years` threshold нь invalid хэвээр: endogenous regressor болон threshold variable давхар ашиглагдсан.
- `EBS age-12 student-teacher ratio` нь school-quality сувгийг хамгийн сонирхолтойгоор барьж байна: formal CH threshold test significant, slope-difference нь 10%-ийн түвшинд marginal.
- `2008 reform exposure` нь цэвэр exogenous cohort threshold боловч slope inference сул, high-regime first-stage weak тул headline болгоход эрсдэлтэй.
- `log_dist_ub` болон prior-cohort mean нь significant diagnostic proxy; wage-д шууд нөлөөлөх эсвэл HSES outcome-based сувагтай тул causal headline-д ашиглахгүй.

## Нэмэлт diagnostic

- Distance-IV AR-style 95% CI: [0.1250, 0.1750].
- Distance-IV standard 2SLS CI: [0.1214, 0.1783].
- Distance mechanism check: `log_dist_ub` нь боловсролоос гадна regional labor-market access-ийг шууд proxy хийх эрсдэлтэй.
- Heckman correction: beta_educ = 0.0557, SE = 0.0072; IMR lambda = -0.1562, t = -1.86.

## Шүүгчдэд хэлэх хамгаалагдах байрлал

- Гол causal claim: боловсролын IV өгөөж ойролцоогоор 12.9%, OLS+FE-ээс өндөр.
- Threshold claim: өмнөх `educ_years` threshold-г causal Caner-Hansen гэж хамгаалж болохгүй.
- Classical Caner-Hansen (2004) 3-step estimator дээр exogenous EBS threshold-ууд formal SupWald bootstrap test-ээр significant гарч байна.
- Гэхдээ хамгийн хамгаалагдах D1 teacher-supply threshold дээр education-return slope difference significant биш. Иймээс “threshold structure exists” гэж хэлж болно, харин “teacher-supply regime бүрд боловсролын өгөөж баттай өөр” гэж хэтрүүлж болохгүй.
- Хамгийн сайн positive өгүүлэмж: `EBS age-12 student-teacher ratio` дээр formal CH threshold significant бөгөөд education-return slope difference marginal (`p = 0.0546`). Энэ нь Монголын school-quality/channel story-той нийцэх supplementary evidence.

## Аудитын дараах заавал бичих caveat

- `birth_aimag` IV нь relevance-ийн хувьд хангалттай хүчтэй (`first-stage F = 16.39`) боловч dummy instrument set overidentified тул Sargan diagnostic reject хийж байна (`Sargan = 83.30`, `p = 1.07e-09`; current-aimag FE нэмэхэд `p = 0.0111`). Иймээс paper дээр “exclusion restriction батлагдсан” гэж бичихгүй; “main IV estimate, but overidentification diagnostics raise exclusion-risk” гэж шударгаар тайлбарлана.
- `log_dist_ub` IV нь robustness-only. Mechanism/placebo check дээр distance нь бага боловсролтой бүлгийн боловсролтой ч статистикийн хамааралтай (`educ <= 8`: beta = -0.0898, t = -3.66), тиймээс regional labor-market access-ийг шууд proxy хийх эрсдэлтэй.
- `educ_years` хэмжилт нь HSES wave/coding limitation-тай. 2016/2018 дээр `13`, `15`, `17` жилийн утга огт байхгүй; bachelor (`educ_level = 8`) ихэвчлэн `14` жилээр кодлогдсон. Иймээс `educ_years`-ийн linear return-г тайлбарлахдаа education-system/coding transition limitation-г ил тод бичнэ.
- IVTR headline specification нь `educ_years`-ийг threshold болгож ашиглахгүй. Зөв specification: endogenous regressor = `educ_years`, instruments = `birth_aimag` dummies, exogenous threshold = `ebs_teachers_per_1000_school_age`.

## Classical Caner-Hansen sweep

Caner-Hansen (2004)-ийн 3-step логикт нийцүүлэн `R/12_ch_classical_mongolia.R` болон formal bootstrap p-value гаргах `R/13_ch_classical_bootstrap.R` ажиллуулсан:

1. `educ_years`-ийн pooled reduced-form first stage.
2. `educ_hat`-аар threshold grid search.
3. Сонгогдсон gamma дээр split-sample IV / joint-IV slope-difference test.
4. Null model-оос wild bootstrap хийж SupWald threshold test-ийн p-value тооцсон (`B = 999`).

Гол үр дүн:

| Threshold proxy | N | gamma* | CH SupWald bootstrap p | Low return | High return | Slope-diff p | Тайлбар |
|---|---:|---:|---:|---:|---:|---:|---|
| EBS school-age teachers per 1,000 | 5,170 | 41.26 | 0.001 | 11.6% | 3.3% | 0.4286 | Хамгийн хамгаалагдах headline threshold; formal CH significant, slope difference not significant |
| EBS school-age student-teacher ratio | 5,170 | 24.11 | 0.001 | 3.9% | 11.6% | 0.4370 | Formal CH significant, slope difference not significant |
| EBS age-12 student-teacher ratio | 3,701 | 23.63 | 0.001 | 3.4% | 13.8% | 0.0546 | Хамгийн сайн supplementary positive evidence: school-quality channel, 10%-ийн marginal slope difference |
| 2008 reform exposure | 11,924 | 0 years | 0.001 | 12.3% | 13.8% | 0.0712 | Цэвэр exogenous cohort threshold; high-regime first-stage weak тул болгоомжтой |
| log distance to UB | 11,924 | 6.51 | 0.001 | 12.2% | 8.7% | 0.0001 | Significant diagnostic боловч exclusion/direct labor-market risk өндөр |
| prior-cohort mean education | 11,881 | 11.24 | 0.029 | 6.6% | 12.6% | <0.001 | Significant diagnostic боловч HSES outcome-based |
| educ_years threshold | 11,924 | 12.00 | not used | 12.6% | 32.7% | 0.0004 | Caner-Hansen-д invalid, headline-д ашиглахгүй |

Зөв framing:

- Headline CH result: хамгийн хамгаалагдах EBS teacher-supply threshold дээр formal Caner-Hansen SupWald test significant (`p = 0.001`), босго `41.26` багш / 1,000 сурагч.
- Conservative slope interpretation: D1 дээр боловсролын өгөөжийн slope difference significant биш (`p = 0.4286`). Тиймээс threshold нь wage level / school environment structure-ийг илүү барьж байж магадгүй.
- Best positive returns-heterogeneity evidence: age-12 student-teacher ratio threshold дээр formal CH significant ба slope difference marginal (`p = 0.0546`); үүнийг “supplementary evidence” гэж хамгаална.
- Diagnostic evidence: distance болон prior regional education орчноор threshold pattern хүчтэй боловч эдгээрийг causal CH headline болгохгүй, учир нь wage-д шууд нөлөөлөх сувагтай.

## Phase A/B/C audit follow-up (засагдсан)

### Phase A — Code fixes (зассан)

- M3: `survey_year=24` (2024 wave) → 2024 болгож normalize хийсэн.
- H4: C2 `reform2005_exp` нь C1/C3-тэй адил cohort/reform-timing family-ийн proxy тул independent threshold family гэж тооцохгүй; threshold proxy жагсаалтаас хассан. Дахин тооцсон correlation: `birth_year`-`reform2005_exp` = 0.713, `reform2005_exp`-`reform2008_exp` = 0.941.
- H5: C3 `reform2008_exp` нь grid trim-ийн дор зөвхөн нэг cut-тэй болж binary cohort dummy болж хувирсан тул label-ыг "C3: 2008 reform cohort dummy (effectively binary; born >= 1991)" болгож, paper дээр continuous CH threshold гэж нэрлэхгүй.
- H6: T8 хүснэгтэд joint-IV regime betas-ийг үндсэн (joint_beta_low_q, joint_beta_high_q) болгож, split-sample-ийг auxiliary footnote болгосон.

### Phase B — Sensitivity / robustness (T10-T13)

- H3 EBS extreme-value robustness (`t10_h3_ebs_outlier_sensitivity.csv`): D1 EBS supply нь raw-д max=168 байсан. p1-p99 trim хийхэд γ\*=41.10 → 41.97; slope diff p = 0.87 → 0.78. Headline тогтвортой, threshold extreme outliers-аас үл хамаарна.
- M7 educ_years==0 sensitivity (`t11_m7_educ_zero_sensitivity.csv`): IV sample-д educ=0 = 48 obs. Тэдгээрийг хасахад β = 0.1213 → 0.1199 (-1.1%). Headline IV маш тогтвортой.
- M5 D6 EBS_2000 full-sample sensitivity (`t12_m5_ebs2000_full_sensitivity.csv`): EBS_2000 baseline нь full sample-д (N=11,924, олон cohort coverage) ажилласан. Joint-IV дээр γ\*=39, β_low=9.4%, β_high=3.2%, slope diff p = 4.25e-06. Гэхдээ энэ нь хувь хүний school-age exposure биш, regional initial-condition proxy тул D1-ийн slope-null-ийг "шийдсэн" гэж хэлэхгүй; зөвхөн full-sample sensitivity / supplementary evidence гэж тайлбарлана.
- Bonferroni reporting (`t13_bonferroni_reporting.csv`):
  - 6 nominal tests: Bonferroni α = 0.0083 → 5/6 SupWald pass.
  - 3 effective proxy families (Supply / Cohort / Geography) + diagnostic family: Bonferroni α = 0.0167 → 5/6 pass; B1 diagnostic proxy p=0.029 тул pass хийхгүй.
  - Conclusion: Formal SupWald threshold evidence нь олон proxy дээр хадгалагдаж байна, гэхдээ proxy-уудыг fully independent causal identification sources гэж тайлбарлахгүй.

### Phase C — Methodological extensions (T14-T15)

- M8 Wild cluster bootstrap SE (`t14_m8_wild_cluster_bootstrap.csv`): Cameron-Gelbach-Miller (2008) recommendation (clusters < 30) дагуу. Headline IV β=0.1213, standard cluster SE = 0.0079, WCB SE = 0.0080. Inference хадгалагдах.
- AR CI for birth_aimag IV (`t15_ar_robust_ci.csv`): Anderson-Rubin (1949) weak-IV-robust CI нь tested grid дээр EMPTY гарсан. Энэ нь Sargan rejection-тэй нийцэх анхааруулах diagnostic боловч дангаараа эцсийн нотолгоо биш; paper дээр birth_aimag dummy set-ийн joint exogeneity caveat болгон ашиглана.

### Phase D — Зөвхөн paper-т ил тэмдэглэх caveats

- H1: Sargan (`χ²=83.30, p<1e-08`) → "main IV estimate, but instruments are not jointly exogenous; results should be interpreted with the overidentification caveat in mind".
- H2: educ_years 2016/2018 wave-д `13/15/17` жилийн утга байхгүй, bachelor `educ_level=8` нь mostly `14` жилээр coded. Linear return нь pure continuous years биш — system/coding transition limitation бичих.
- M1: IV sample = 11,924 нь wave≥2020 wage-earner sample-ийн 42.6%. Үлдсэн 57.4% (foreign/non-MN birth_aimag, missing) drop хийсэн. Generalization caveat ил бичих.
- M2: log_dist_ub IV-ын placebo fail (educ≤8: t=-3.66) — зөвхөн robustness, headline биш.
- M4: Slope-difference тестүүд proxy-аар mixed (D1: p=0.43, D5: p=0.05, G1: p=0.0001, B1: p<0.001). "Threshold structure-ийг бат бөх илрүүлэв, slope-heterogeneity нь proxy-аас хамаарч өөр өөр" гэж framing.
- M6: ebs_2000 ↔ log_dist_ub correlation = 0.73 → joint regional pre-determined characteristics. Paper-т "fully independent identification sources" гэж хэлэхгүй.

### Audit-аас гарсан "3 effective family" framework

| Family | Proxies | SupWald (B=999) bootstrap p | Slope-diff p |
|---|---|---|---|
| Supply (school-environment) | D1, D3, D5 | 0.001, 0.001, 0.001 | 0.43, 0.44, 0.05 (D5 marginal) |
| Cohort (reform / birth-year) | C1, C3 | (CH classical) 0.001 | mostly null |
| Geography | G1 (log dist UB) | 0.001 | <0.001 |
| Diagnostic only | B1, A1 | 0.029, B1 | <0.001, B1 |

Headline framing: "Caner-Hansen IV-Threshold framework-ийн дагуу exogenous/predetermined threshold proxy-ууд дээр formal SupWald evidence хүчтэй гарсан (5/6 tested proxies Bonferroni-corrected threshold test-д pass; B1 diagnostic pass хийхгүй). Гэхдээ эдгээр нь fully independent causal identification sources биш. Хамгийн хамгаалагдах D1 school-supply threshold дээр slope-difference significant биш тул 'threshold structure exists, but return-slope heterogeneity is mixed and proxy-dependent' гэж тайлбарлана."
