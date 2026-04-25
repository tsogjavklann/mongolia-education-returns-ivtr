# Монгол Улс дахь боловсролын өгөөжийн IV-threshold шинжилгээ

Энэ repository нь ӨНЭЗС/HSES 2016, 2018, 2020, 2021, 2024 микро өгөгдөл дээр
боловсролын өгөөжийг OLS, IV, panel/pseudo-panel, Caner-Hansen (2004)
IV-threshold аргуудаар шалгасан reproducible шинжилгээний кодыг агуулна.

> Анхаар: `outputs/paper/*.docx` дотор хуучин тоо байж болно. Одоогийн зөв
> шинжилгээний үр дүнг `inputs/data_summary/research_results.md` болон
> `outputs/tables/*.csv`-ээс авна.

## Одоогийн гол үр дүн

- Үндсэн sample: 25-60 насны, эерэг сарын цалинтай 49,366 хүн.
- IV sample: 2020, 2021, 2024 оны стандарт төрсөн-аймгийн кодтой 11,924 хүн.
- OLS + аймаг/wave fixed effects: боловсролын өгөөж ойролцоогоор 6.5%.
- IV (`birth_aimag` instruments): `beta = 0.1213`, өгөөж ойролцоогоор 12.9%,
  first-stage F/Wald = 16.39.
- Өмнөх `educ_years` threshold specification нь Caner-Hansen-ийн exogenous
  threshold assumption зөрчсөн тул headline-д ашиглахгүй.
- Хамгийн хамгаалагдах exogenous threshold: төрсөн аймгийн school-age үеийн
  ЕБС-ийн багш / 1,000 сурагч (`ebs_teachers_per_1000_school_age`).
- Classical Caner-Hansen 3-step estimator дээр энэ EBS teacher-supply threshold
  formal SupWald bootstrap test-ээр significant: `gamma = 41.26`, `p = 0.001`
  (`B = 999`).
- Гэхдээ education-return slope difference D1 дээр significant биш
  (`p = 0.4286`). Иймээс зөв claim нь: formal threshold structure байна,
  харин teacher-supply regime бүрийн боловсролын өгөөж баттай ялгаатай гэж
  хэтрүүлж болохгүй.
- Хамгийн сайн supplementary returns-heterogeneity evidence:
  age-12 student-teacher ratio threshold, `gamma = 23.63`, formal CH
  bootstrap `p = 0.001`, slope-difference `p = 0.0546`.

## Pipeline

```powershell
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' 'R\00_main.R'
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' 'R\99_tests.R'
```

`R/00_main.R` нь 13 алхамтай:

1. HSES import
2. variable harmonization
3. pseudo-panel construction
4. IV болон EBS threshold variable construction
5. OLS + IV
6. strict interacted-IV threshold robustness
7. threshold proxy comparison
8. classical Caner-Hansen threshold sweep
9. classical Caner-Hansen bootstrap test
10. panel FE/RE
11. robustness checks
12. diagnostics
13. figures/tables

## Гол outputs

- `inputs/data_summary/research_results.md`: судалгааны одоогийн зөв хураангуй.
- `inputs/data_summary/ch_mongolia_literature_and_threshold_logic.md`: threshold
  variable сонголтын Монгол-specific онолын үндэслэл.
- `outputs/tables/t7_threshold_proxy_comparison.csv`: strict/joint IV threshold
  proxy comparison.
- `outputs/tables/t8_ch_classical_threshold_comparison.csv`: classical
  Caner-Hansen sweep and slope-difference results.
- `outputs/tables/t9_ch_classical_bootstrap.csv`: formal classical CH SupWald
  bootstrap p-values.

## Арга зүйн гол анхаарах зүйл

Caner and Hansen (2004) нь endogenous regressor-тэй боловч exogenous threshold
variable-тай model-ийг авч үздэг. Тиймээс `educ_years` нь endogenous regressor
хэвээр, харин threshold variable нь predetermined/exogenous байх ёстой.
Энэ repo-д headline threshold нь хувь хүний өөрийн боловсрол биш, харин төрсөн
аймгийн school-age үеийн ЕБС-ийн supply/quality proxy байна.
