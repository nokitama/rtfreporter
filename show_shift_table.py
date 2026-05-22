"""
Show shift table RTF content: headers per section + table body.
"""
import re, sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

path = r"C:\Yrepo\rtfreporter\tests\output\shift_table.rtf"
with open(path, 'r', encoding='latin-1', errors='replace') as f:
    raw = f.read()

def strip_ctrl(text):
    """Strip RTF control words, keep text content."""
    text = re.sub(r'\{\\fldinst[^}]*\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\{\\[a-z*]+[^{}]*\}', '', text)
    text = re.sub(r'\\[a-z*]+\-?\d*\s?', ' ', text)
    text = re.sub(r'\\[^a-z\s]', '', text)
    text = re.sub(r'[{}]', '', text)
    return ' '.join(text.split()).strip()

def extract_group(text, start):
    """Extract RTF group starting at position start."""
    depth = 0
    content = []
    i = start
    while i < len(text):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                content.append(c)
                break
        content.append(c)
        i += 1
    return ''.join(content)

# Split into sections on \sect
sect_positions = [0] + [m.start() for m in re.finditer(r'\\sect\b', raw)]

print("=" * 72)
print("  SHIFT TABLE REPORT  -  shift_table.rtf")
print("  File size: %d bytes,  Sections: %d" % (len(raw), len(sect_positions)))
print("=" * 72)

for sec_idx, sec_start in enumerate(sect_positions):
    sec_end = sect_positions[sec_idx + 1] if sec_idx + 1 < len(sect_positions) else len(raw)
    sec_text = raw[sec_start:sec_end]

    print("\n" + "-" * 72)
    print("  SECTION %d  (chars %d..%d)" % (sec_idx + 1, sec_start, sec_end))
    print("-" * 72)

    # --- Header ---
    hdr_match = re.search(r'\{\\header\b', sec_text)
    if hdr_match:
        hdr_text = extract_group(sec_text, hdr_match.start())
        rows = re.split(r'\\row\b', hdr_text)
        print("  [HEADER]")
        for r_idx, row in enumerate(rows):
            cells = [strip_ctrl(c) for c in re.split(r'\\cell\b', row)]
            cells = [c for c in cells if c and not c.startswith('{')]
            if cells:
                print("    Row %d: %s" % (r_idx + 1, "  |  ".join("%-30s" % c for c in cells)))

    # --- Table body rows ---
    data_rows = []
    for row_m in re.finditer(r'\\trowd\b.*?\\row\b', sec_text, re.DOTALL):
        row_text = row_m.group()
        cells = [strip_ctrl(c) for c in re.split(r'\\cell\b', row_text)]
        cells = [c for c in cells if c]
        if cells:
            data_rows.append(cells)

    if data_rows:
        print("  [TABLE ROWS]")
        for row in data_rows:
            print("    " + "  |  ".join("%-10s" % c for c in row))

    # --- Footer ---
    ftr_match = re.search(r'\{\\footer\b', sec_text)
    if ftr_match:
        ftr_text = extract_group(sec_text, ftr_match.start())
        rows = re.split(r'\\row\b', ftr_text)
        print("  [FOOTER]")
        for r_idx, row in enumerate(rows):
            cells = [strip_ctrl(c) for c in re.split(r'\\cell\b', row)]
            cells = [c for c in cells if c and not c.startswith('{')]
            if cells:
                print("    Row %d: %s" % (r_idx + 1, "  |  ".join("%-40s" % c for c in cells)))

print("\n" + "=" * 72)
print("  End of report")
print("=" * 72)
