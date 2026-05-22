with open(r'c:\Yrepo\rtfreporter\tests\feature_test.R', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix block 2: set_document_defaults with default_header/footer -> add_section header/footer
import re
pattern = r"  r <- rtfreport\[\['new'\]\]\(\)\n  r\[\['set_document_defaults'\]\]\("
# Use simple string replace - first find old block
old_marker = "r\(\n    default_header = list(\n      rows = list(\n        c(\n          l = \"Sponsor: Example Corp          Study: EX-2026-001\","
print('old_marker in content:', old_marker in content)
print('done')
