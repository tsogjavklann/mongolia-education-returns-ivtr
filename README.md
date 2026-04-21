# Монгол Улс дахь боловсролын бодит өгөөжийн босготой үнэлгээ

**IV-Threshold регрессийн шинжилгээ ӨНЭЗС микро өгөгдөлд суурилсан**

СЭЗИС-ийн Эконометрикийн VIII Олимпиадын II шатанд оруулж буй эрдэм шинжилгээний бүтээл.

## Судалгааны агуулга

Монгол Улсын хөдөлмөрийн зах зээлд боловсролын бодит өгөөжийг Caner, Hansen
(2004) нарын хэрэгсэл хувьсагчтай босго утгат регрессийн (ХХБР) аргачлалаар
анх удаа үнэлэв. Үндэсний Статистикийн Хорооны Өрхийн нийгэм, эдийн засгийн
судалгаа (ӨНЭЗС)-ны 2016, 2018, 2020, 2021, 2024 оны таван давалгааны
нэгтгэсэн өгөгдлөөс 25–60 насны цалин хөлстэй ажиллагч 49,366 хүний
ажиглалтыг ашиглав.

### Гол үр дүн

- **ЭХБК үнэлгээ:** 6.8 хувь / жил
- **ХШХБК үнэлгээ:** 11.3 хувь / жил (эхний шатны F = 10.46)
- **ХХБР босго γ\*:** 13 жил
  - Регим 1 (educ ≤ 13): **5.5 хувь / жил**
  - Регим 2 (educ > 13): **17.9 хувь / жил** (3.3 дахин их)
- **Вайлд бүүтстрап p-утга:** p < 0.001

## Төслийн бүтэц

```
ecnometric/
├── R/                         # 13 R скрипт (00_main.R-ээс 99_tests.R)
├── python/                    # Python replication болон docx боловсруулалт
├── data/
│   ├── hses_2016/ … hses_2024/    # ҮСХ-ны ӨНЭЗС өгөгдөл
│   ├── aux/                        # ЕБС-ийн статистик (ҮСХ нээлттэй)
│   └── clean/                      # Нэгтгэсэн, цэвэрлэсэн CSV
├── outputs/
│   ├── tables/                # T1–T6 хүснэгт
│   ├── figures/               # F1–F5 зураг (300 dpi PNG)
│   └── paper/                 # Эцсийн docx/pdf
├── inputs/                    # Бичвэрт ашигласан материал
├── mb_refs/                   # Монголбанкны 15 эх сурвалжийн судалгаа
├── examples/                  # 5 олон улсын академик өгүүллийн жишээ
└── skills/                    # Mongolian academic + docx skill-үүд
```

## Аргачлал

Шинжилгээг дөрвөн шатлалтайгаар явуулсан:

1. **ЭХБК** — Минсерийн цалингийн тэгшитгэл, суурь үнэлгээ
2. **Псевдо-панел** — Deaton (1985) арга, төрсөн когорт × аймаг × давалгааны
   692 нүдтэй хиймэл панел
3. **ХШХБК** — 3 хэрэгсэл хувьсагчтайгаар эндоген хазайлтыг засах:
   - Төрсөн аймгийн ангилал хувьсагч
   - Улаанбаатар хүртэлх зайн логарифм
   - Сумын ЕБС-ийн багш / сурагчийн харьцаа
4. **ХХБР** — Caner, Hansen (2004) нарын аргаар 13 жилийн бүтцийн хугарлыг
   тогтоосон

## Техникийн орчин

- **R:** 4.4.3 (fixest, plm, AER, data.table, ggplot2)
- **Python:** 3.10 (pandas, numpy, matplotlib, statsmodels, linearmodels)
- **Pandoc:** docx + markdown үүсгэх
- **Node.js:** docx@9.6.1 (ахиу форматлал)

## Давтах заавар

```bash
# 1) R багцуудыг суулгах
Rscript R/00_main.R

# 2) Өгөгдөл цэвэрлэх, нэгтгэх
Rscript R/01_import.R
Rscript R/02_harmonize.R
Rscript R/03_pseudopanel.R

# 3) Үнэлгээг явуулах
Rscript R/04_ols_iv.R
Rscript R/05_ivtr_caner_hansen.R

# 4) Зураг, хүснэгт гаргах
Rscript R/08_figures.R
Rscript R/09_tables.R
python python/regenerate_figures_v2.py
```

## Ашигласан гол эх сурвалж

- Caner, M., & Hansen, B. E. (2004). *Instrumental Variable Estimation of a
  Threshold Model*. Econometric Theory, 20(5).
- Mincer, J. (1974). *Schooling, Experience, and Earnings*. NBER.
- Card, D. (1993). *Using Geographic Variation in College Proximity to
  Estimate the Return to Schooling*. NBER WP 4483.
- Duflo, E. (2001). *Schooling and Labor Market Consequences of School
  Construction in Indonesia*. American Economic Review, 91(4).
- Psacharopoulos, G., & Patrinos, H. A. (2018). *Returns to investment in
  education: a decennial review of the global literature*. Education
  Economics, 26(5).

## Удирдагч багш

С.Өнөр — [unur@thinkers.mn](mailto:unur@thinkers.mn)

## Зохиогчийн эрх

Энэ хэвлэл нь СЭЗИС-ийн Эконометрикийн VIII Олимпиадын уралдаанд оруулж буй
оюутны судалгааны ажил юм. ӨНЭЗС-ийн микро өгөгдөл нь ҮСХ-ны өмч.
