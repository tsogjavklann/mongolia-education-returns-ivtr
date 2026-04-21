# Docx файл үүсгэх ур чадвар (SEZIS уралдаанд зориулсан)

## I. Үүсгэх арга — 2 хувилбар

### Арга 1 (САНАЛ): Pandoc + Markdown
**Давуу тал:** OMML math автомат, хүснэгт/зураг хялбар, hyperlink автомат

```bash
pandoc input.md -f markdown+tex_math_dollars+tex_math_single_backslash \
  -t docx \
  --reference-doc=reference_tnr.docx \
  --toc --toc-depth=2 \
  -o output.docx
```

### Арга 2 (нарийвчилсан контроль шаардсан үед): docx-js (Node.js)
**Давуу тал:** Formatting-ыг нарийн хянах, custom styles

## II. Уралдааны стандарт (заавал)

### Хуудас ба margins
```javascript
// docx-js-д:
{
  page: {
    size: { width: convertMillimetersToTwip(210), height: convertMillimetersToTwip(297) },  // A4
    margin: {
      top: convertMillimetersToTwip(20),
      bottom: convertMillimetersToTwip(20),
      left: convertMillimetersToTwip(30),    // ★ зүүн 30мм
      right: convertMillimetersToTwip(15)    // ★ баруун 15мм
    }
  }
}
```

### Fonts
```javascript
{
  font: { name: "Times New Roman" },
  size: 24,  // docx-ийн size нь half-points: 24 = 12pt
}
```

### Мөр зай
```javascript
{
  spacing: { line: 360 }  // 360 = 1.5 зай (240 = single, 480 = double)
}
```

### Pandoc reference doc (шаардлагатай)
Pandoc-д TNR 12 + 1.5 зай-г оруулахын тулд reference.docx бэлдэнэ:

```bash
pandoc -o reference_default.docx --print-default-data-file reference.docx
# Дараа нь Python/python-docx-оор Normal style-ыг засна
```

## III. Validation script (ажиллуулах ёстой)

`skills/docx/scripts/validate.py`-г ашиглан:

```bash
python skills/docx/scripts/validate.py outputs/paper/SEZIS_paper.docx
```

Шалгах зүйлс:
1. Font = Times New Roman
2. Body font size = 12pt
3. Line spacing = 1.5
4. Page size = A4
5. Margins = 20/20/30/15 mm
6. OMML math equations exist
7. Tables have borders
8. Figures have captions

## IV. Хүснэгтийн стандарт

### Бүх хүснэгтийн формат
- TNR 10pt
- Center alignment for numbers
- Left alignment for labels
- Borders бүх cell-д
- Column widths DXA-аар (pt × 20)

```javascript
// docx-js example:
new Table({
  columnWidths: [2000, 1500, 1500, 1500],  // DXA
  rows: [
    new TableRow({
      children: [
        new TableCell({
          width: { size: 2000, type: WidthType.DXA },
          children: [new Paragraph("Label")]
        }),
        // ...
      ]
    })
  ]
})
```

### Хүснэгтийн гарчиг
- Хүснэгтийн ДЭЭД талд: "Хүснэгт 1: [нэр]"
- TNR 10pt bold
- Left-aligned

### Эх сурвалжийн тайлбар
- Хүснэгтийн ДООД талд: "Эх сурвалж: ӨНЭЗС, зохиогчийн тооцоо"
- TNR 9pt italic
- Statistical significance notes: "* p<0.10, ** p<0.05, *** p<0.01"

## V. Зургийн стандарт

- Format: PNG, 300 dpi
- Orientation: хүснэгтийн доод талд "Зураг N: [нэр]"
- TNR 10pt
- Center-aligned
- Max width = page width - margins

```javascript
new Paragraph({
  children: [
    new ImageRun({
      data: fs.readFileSync("figures/f3_threshold.png"),
      transformation: { width: 500, height: 400 }
    })
  ],
  alignment: AlignmentType.CENTER
})
```

## VI. Математик томьёо (OMML)

### Pandoc-аар (хамгийн хялбар)
Markdown бичвэрт:
```markdown
Mincer equation:
$$\ln w_i = \alpha_0 + \alpha_1 \text{educ}_i + \alpha_2 \text{exp}_i + \alpha_3 \text{exp}_i^2 + \varepsilon_i$$

Inline: $\beta_{IV} = 0.113$
```

Pandoc автоматаар `<m:oMath>` элемент болгон хөрвүүлнэ.

### docx-js-ээр (сайхан харагдуулахад)
docx-js нь шууд OMML дэмждэггүй. Хэрэв Pandoc ашиглахгүй бол:
- Томьёог зураг болгож оруулах (LaTeX → PNG)
- Эсвэл LibreOffice macro ашиглах

**САНАЛ: Pandoc-оор хийх**

## VII. Агуулгын хүснэгт (TOC)

Pandoc-оор автоматаар:
```bash
pandoc ... --toc --toc-depth=2 ...
```

docx-дээ ороход F9 дарахад update хийдэг.

## VIII. Typical заруудын code

### Heading styles
```javascript
new Paragraph({
  heading: HeadingLevel.HEADING_1,
  children: [new TextRun({ text: "1. ОРШИЛ", bold: true, size: 28 })]
})
```

### Paragraph с indent
```javascript
new Paragraph({
  indent: { firstLine: convertMillimetersToTwip(12.5) },  // 1.25cm first-line indent
  spacing: { line: 360 },
  alignment: AlignmentType.JUSTIFIED
})
```

### Footnotes (хэрэгтэй бол)
```javascript
new Paragraph({
  children: [
    new TextRun("Текст"),
    new FootnoteReferenceRun(1)
  ]
})
```

## IX. Эцсийн validation

**Шаардлагатай:** `validate.py`-г ажиллуулах
**Алдаа гарвал:** засварлаад дахин ажиллуулах
**Амжилттай бол:** `.docx` → `.pdf` PDF хөрвүүлэх (Word дээр File → Export)

## X. Уралдааны шалгалтын жагсаалт (заавал бүгд)

- [ ] Font = Times New Roman (бүх хэсэгт)
- [ ] Size = 12pt (body), 10pt (captions, tables)
- [ ] Line spacing = 1.5
- [ ] Page size = A4
- [ ] Margins = top 20, bottom 20, left 30, right 15 mm
- [ ] Page numbers = bottom center
- [ ] Tables numbered & titled (Хүснэгт 1, 2, ...)
- [ ] Figures numbered & titled (Зураг 1, 2, ...)
- [ ] Math equations use OMML format (not images)
- [ ] References APA 7 format
- [ ] Total ≤ 30 pages (including appendix)
- [ ] PDF version exported
- [ ] File named: `bagiin_ner.docx` + `bagiin_ner.pdf`
