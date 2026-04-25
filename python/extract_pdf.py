# -*- coding: utf-8 -*-
"""Extract PDF text to inputs/sezis_format_extracted.md."""
import sys
import io
import pypdf

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

reader = pypdf.PdfReader('ОЮУТНЫ-БИЕ-ДААН-ГҮЙЦЭТГЭХ-АЖИЛ.pdf')
out_path = 'inputs/sezis_format_extracted.md'

with open(out_path, 'w', encoding='utf-8') as f:
    f.write('# СЭЗИС-ын "Оюутны бие даан гүйцэтгэх ажил" PDF-аас задалсан\n\n')
    for i, page in enumerate(reader.pages, start=1):
        f.write(f'\n## PAGE {i}\n\n')
        f.write(page.extract_text())
        f.write('\n')

print(f'Saved {len(reader.pages)} pages to {out_path}')
