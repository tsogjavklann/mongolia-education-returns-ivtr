"""Merge cover.docx with paper_body.docx into the final submission docx."""
import sys, io, shutil
from pathlib import Path
from docx import Document
from docx.oxml.ns import qn
from copy import deepcopy

sys.stdout.reconfigure(encoding='utf-8')

OUT_DIR = Path(__file__).parent
COVER = OUT_DIR / "cover.docx"
BODY = OUT_DIR / "paper_body.docx"
FINAL = OUT_DIR / "bagiin_ner.docx"

# Start with the cover as the base (it has correct page setup: margins 25/20/30/20)
shutil.copy(str(COVER), str(FINAL))

cover_doc = Document(str(FINAL))
body_doc = Document(str(BODY))

# Add page break at the end of cover
cover_doc.add_page_break()

# Get the body element of the cover doc
cover_body = cover_doc.element.body

# Insert a reference to sectPr location
# We want to insert body elements BEFORE the final sectPr of cover
cover_sectPr = None
for child in list(cover_body):
    if child.tag == qn('w:sectPr'):
        cover_sectPr = child
        break

# Copy every element from body doc into the cover doc, inserting before sectPr
body_elements = list(body_doc.element.body)
for element in body_elements:
    if element.tag == qn('w:sectPr'):
        continue  # skip body's own sectPr; keep cover's
    new_el = deepcopy(element)
    if cover_sectPr is not None:
        cover_sectPr.addprevious(new_el)
    else:
        cover_body.append(new_el)

# Copy all images from body to cover
body_part = body_doc.part
cover_part = cover_doc.part

# Find all relationship IDs in body and map to cover
body_rels = body_part.rels
for rel_id, rel in list(body_rels.items()):
    if "image" in rel.reltype.lower():
        # Get the image part
        image_part = rel.target_part
        # Add it to cover doc
        new_rel_id = cover_part.relate_to(image_part, rel.reltype)
        # Find all XML elements that reference the old rel_id and update them
        # (Actually when we copy the elements above, the rel_ids reference the body's rels)
        # Need to rewrite embed/rid attributes
        print(f"Body rel {rel_id} -> cover rel {new_rel_id}")

# After copying, re-scan all elements for r:embed and update
# We need to go through XML and update r:embed references
from docx.oxml.ns import nsmap
rel_map = {}

# Re-do this more carefully: we need to copy image parts AND map old rel_id -> new rel_id
rel_map = {}
for rel_id, rel in list(body_rels.items()):
    if rel.is_external:
        continue
    target = rel.target_part
    # Check if it's an image
    if "image" in rel.reltype.lower():
        new_rel_id = cover_part.relate_to(target, rel.reltype)
        rel_map[rel_id] = new_rel_id

# Now update all r:embed, r:link references in the copied elements
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
