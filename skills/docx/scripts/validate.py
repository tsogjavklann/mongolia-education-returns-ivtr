"""
SEZIS Econometrics VIII Olympiad — Docx validation script
Validates that the paper conforms to competition requirements.

Usage:
    python validate.py <path_to_docx>
"""
import sys, io
from pathlib import Path
from docx import Document
from docx.shared import Mm, Pt, Twips

# Force UTF-8 output on Windows
if sys.stdout.encoding != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


# SEZIS official requirements (per "Оюутны бие даан гүйцэтгэх ажил, тайлан бичих
# ерөнхий шаардлага, формат" standard)
REQ_FONT = "Times New Roman"
REQ_BODY_SIZE_PT = 12
REQ_LINE_SPACING = 1.5
REQ_PAGE_WIDTH_MM = 210   # A4 width
REQ_PAGE_HEIGHT_MM = 297  # A4 height
REQ_MARGIN_TOP_MM = 25    # SEZIS: 2.5 cm
REQ_MARGIN_BOTTOM_MM = 20 # SEZIS: 2 cm
REQ_MARGIN_LEFT_MM = 30   # SEZIS: 3 cm (includes binding space)
REQ_MARGIN_RIGHT_MM = 20  # SEZIS: 2 cm
# No max page count in SEZIS Econometrics Olympiad guideline

# Tolerance for float comparisons
TOL_MM = 1.0  # 1mm tolerance
TOL_PT = 0.5


def validate(docx_path):
    path = Path(docx_path)
    if not path.exists():
        print(f"FAIL: File not found: {docx_path}")
        return 1

    doc = Document(str(path))

    passed = 0
    failed = 0
    warnings = 0

    def check(name, condition, details=""):
        nonlocal passed, failed
        if condition:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name}  {details}")
            failed += 1

    def warn(name, condition, details=""):
        nonlocal warnings
        if not condition:
            print(f"  WARN: {name}  {details}")
            warnings += 1

    print(f"\n=== Validating: {path.name} ===\n")

    # --- Page setup ---
    print("[Page setup]")
    section = doc.sections[0]
    page_w = section.page_width.mm if section.page_width else 0
    page_h = section.page_height.mm if section.page_height else 0
    check(f"Page width = A4 ({REQ_PAGE_WIDTH_MM}mm), got {page_w:.1f}mm",
          abs(page_w - REQ_PAGE_WIDTH_MM) <= TOL_MM)
    check(f"Page height = A4 ({REQ_PAGE_HEIGHT_MM}mm), got {page_h:.1f}mm",
          abs(page_h - REQ_PAGE_HEIGHT_MM) <= TOL_MM)

    # Margins
    m_top = section.top_margin.mm
    m_bottom = section.bottom_margin.mm
    m_left = section.left_margin.mm
    m_right = section.right_margin.mm
    check(f"Top margin = {REQ_MARGIN_TOP_MM}mm, got {m_top:.1f}mm",
          abs(m_top - REQ_MARGIN_TOP_MM) <= TOL_MM)
    check(f"Bottom margin = {REQ_MARGIN_BOTTOM_MM}mm, got {m_bottom:.1f}mm",
          abs(m_bottom - REQ_MARGIN_BOTTOM_MM) <= TOL_MM)
    check(f"Left margin = {REQ_MARGIN_LEFT_MM}mm, got {m_left:.1f}mm",
          abs(m_left - REQ_MARGIN_LEFT_MM) <= TOL_MM)
    check(f"Right margin = {REQ_MARGIN_RIGHT_MM}mm, got {m_right:.1f}mm",
          abs(m_right - REQ_MARGIN_RIGHT_MM) <= TOL_MM)

    # --- Font (Normal style) ---
    print("\n[Font & Style]")
    try:
        normal = doc.styles["Normal"]
        font_name = normal.font.name or "(inherited)"
        check(f"Normal style font = {REQ_FONT}, got {font_name}",
              font_name == REQ_FONT)

        font_size = normal.font.size
        size_pt = font_size.pt if font_size else None
        check(f"Normal style size = {REQ_BODY_SIZE_PT}pt, got {size_pt}pt",
              size_pt is not None and abs(size_pt - REQ_BODY_SIZE_PT) <= TOL_PT)

        # Line spacing
        pf = normal.paragraph_format
        line_sp = pf.line_spacing
        check(f"Normal style line spacing = {REQ_LINE_SPACING}, got {line_sp}",
              line_sp is not None and abs(float(line_sp) - REQ_LINE_SPACING) <= 0.05)
    except KeyError:
        print("  FAIL: Normal style not found")
        failed += 1

    # --- Paragraph count & approximate page count ---
    print("\n[Content]")
    n_paragraphs = len(doc.paragraphs)
    n_tables = len(doc.tables)
    print(f"  INFO: {n_paragraphs} paragraphs, {n_tables} tables")

    # Approximate page count (informational only — no hard limit in SEZIS guideline)
    total_chars = sum(len(p.text) for p in doc.paragraphs)
    approx_pages = max(1, total_chars // 2500)
    print(f"  INFO: Estimated ~{approx_pages} pages (char-based estimate)")
    print(f"  INFO: SEZIS Olympiad has no hard page limit")

    # --- OMML math check ---
    print("\n[Math equations]")
    import zipfile
    with zipfile.ZipFile(str(path)) as z:
        try:
            doc_xml = z.read("word/document.xml").decode("utf-8")
            omath_count = doc_xml.count("<m:oMath")
            print(f"  INFO: {omath_count} OMML equations found")
            warn("Has math equations (OMML)", omath_count > 0,
                 "Use Pandoc markdown -> docx or Word Equation Editor")
        except KeyError:
            print("  WARN: Could not read document.xml")

    # --- Tables ---
    print("\n[Tables]")
    if n_tables > 0:
        # Check first table has borders
        warn("Tables present", n_tables >= 1)
    else:
        warn("Tables present (at least 1)", False, "Competition recommends ≥5 tables")

    # --- Images ---
    print("\n[Images]")
    with zipfile.ZipFile(str(path)) as z:
        media = [n for n in z.namelist() if n.startswith("word/media/")]
        print(f"  INFO: {len(media)} embedded images")
        warn("Figures present (at least 1)", len(media) >= 1,
             "Competition recommends ≥5 figures")

    # --- Summary ---
    print(f"\n{'='*50}")
    print(f"  RESULTS: {passed} passed, {failed} failed, {warnings} warnings")
    if failed == 0:
        print("  STATUS: PASSED (ready for submission)")
    else:
        print("  STATUS: FAILED (fix errors before submission)")
    print(f"{'='*50}\n")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python validate.py <docx_file>")
        sys.exit(1)
    sys.exit(validate(sys.argv[1]))
