#!/usr/bin/env python3
"""Extrae el índice Point & Click de un PDF generado por LilyPond."""
import pymupdf as fitz  # PyMuPDF
import json, os, sys
from collections import defaultdict
from urllib.parse import unquote

def parse_textedit(uri):
    """textedit:///abs/path/file.ly:line:col:endcol -> (path, line, col, end_col)"""
    if not uri.startswith("textedit://"):
        return None
    rest = uri[len("textedit://"):]
    # rsplit: la ruta puede tener ':' (poco común en Linux, pero por las dudas)
    parts = rest.rsplit(":", 3)
    if len(parts) != 4:
        return None
    path, line_s, col_s, endcol_s = parts
    try:
        return unquote(path), int(line_s), int(col_s), int(endcol_s)
    except ValueError:
        return None

def extract(pdf_path):
    doc = fitz.open(pdf_path)
    by_file = defaultdict(list)
    for page_num in range(len(doc)):
        for link in doc[page_num].get_links():
            if link.get("kind") != fitz.LINK_URI:
                continue
            parsed = parse_textedit(link.get("uri", ""))
            if parsed is None:
                continue
            path, line, col, end_col = parsed
            r = link["from"]
            by_file[path].append({
                "line": line, "col": col, "end_col": end_col,
                "page": page_num,
                "rect": [round(r.x0, 3), round(r.y0, 3),
                         round(r.x1, 3), round(r.y1, 3)],
#                "uri": link["uri"],  # para debug
            })
    doc.close()
    for entries in by_file.values():
        entries.sort(key=lambda e: (e["line"], e["col"]))
    return by_file

def main():
    pdf, out = sys.argv[1], sys.argv[2]
    by_file = extract(pdf)
    json.dump({
        "pdf": os.path.abspath(pdf),
        "pdf_mtime": int(os.path.getmtime(pdf)),
        "sources": {p: e for p, e in by_file.items()},
    }, open(out, "w"), indent=2)
    for p, e in by_file.items():
        print(f"{len(e):5d}  {p}", file=sys.stderr)

main()
