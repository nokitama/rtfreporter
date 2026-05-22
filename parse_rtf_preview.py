"""
Simple RTF text extractor — strips RTF control words and shows readable content.
Not a full parser; sufficient for previewing rtfreporter-generated table text.
"""
import re, sys

def strip_rtf(text):
    # Remove RTF groups that contain binary data (\pict etc.)
    text = re.sub(r'\{\\pict[^}]*\}', '[IMAGE]', text, flags=re.DOTALL)
    # Replace explicit line/para breaks
    text = re.sub(r'\\(line|par|row)\b\*?', '\n', text)
    text = re.sub(r'\\cell\b', '\t', text)
    text = re.sub(r'\\sect\b', '\n' + '─'*70 + '\n', text)
    text = re.sub(r'\\page\b', '\n' + '═'*70 + '\n', text)
    # Unicode escapes  \uNNNN?
    def repl_u(m):
        cp = int(m.group(1))
        try: return chr(cp)
        except: return '?'
    text = re.sub(r'\\u(-?\d+)\?', repl_u, text)
    # Remove all remaining control words and symbols
    text = re.sub(r'\\[a-z*-]+[-]?\d*\s?', '', text)
    text = re.sub(r'\\[^a-z\s]', '', text)
    # Remove RTF group braces
    text = re.sub(r'[{}]', '', text)
    # Collapse multiple tabs/spaces per line
    lines = []
    for line in text.split('\n'):
        cells = [c.strip() for c in line.split('\t') if c.strip()]
        if cells:
            lines.append('  '.join(cells))
    return '\n'.join(l for l in lines if l)

path = r"C:\Yrepo\rtfreporter\tests\output\shift_table.rtf"
with open(path, 'r', encoding='latin-1', errors='replace') as f:
    raw = f.read()

print(strip_rtf(raw))
