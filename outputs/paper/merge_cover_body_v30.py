"""Merge cover.docx with paper_body_v30.docx into bagiin_ner_v30.docx."""
import sys, shutil
from pathlib import Path
from docx import Document
from docx.oxml.ns import qn
from copy import deepcopy

sys.stdout.reconfigure(encoding='utf-8')

OUT_DIR = Path(__file__).parent
COVER = OUT_DIR / "cover.docx"
BODY = OUT_DIR / "paper_body_v30.docx"
FINAL = OUT_DIR / "bagiin_ner_v30.docx"

shutil.copy(str(COVER), str(FINAL))

cover_doc = Document(str(FINAL))
body_doc = Document(str(BODY))

cover_doc.add_page_break()

cover_body = cover_doc.element.body
cover_sectPr = None
for child in list(cover_body):
    if child.tag == qn('w:sectPr'):
        cover_sectPr = child
        break

body_elements = list(body_doc.element.body)
for element in body_elements:
    if element.tag == qn('w:sectPr'):
        continue
    new_el = deepcopy(element)
    if cover_sectPr is not None:
        cover_sectPr.addprevious(new_el)
    else:
        cover_body.append(new_el)

body_part = body_doc.part
cover_part = cover_doc.part
body_rels = body_part.rels

rel_map = {}
for rel_id, rel in list(body_rels.items()):
    if rel.is_external:
        continue
    target = rel.target_part
    if "image" in rel.reltype.lower():
        new_rel_id = cover_part.relate_to(target, rel.reltype)
        rel_map[rel_id] = new_rel_id
        print(f"Body rel {rel_id} -> cover rel {new_rel_id}")

R_EMBED = qn('r:embed')
R_LINK = qn('r:link')
for element in cover_body.iter():
    for attr_name in (R_EMBED, R_LINK):
        val = element.get(attr_name)
        if val and val in rel_map:
            element.set(attr_name, rel_map[val])

cover_doc.save(str(FINAL))
print(f"\nSaved final docx: {FINAL}")
print(f"Size: {FINAL.stat().st_size:,} bytes")
