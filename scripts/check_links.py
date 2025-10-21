#!/usr/bin/env python3
"""Check relative markdown links in docs/ point to real files.

This is a small, conservative checker — it only validates links like
[text](some/path.md) or [text](./file.md) that point to local files.
"""
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'

md_link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")

def find_md_files():
    return list(DOCS.rglob('*.md'))

def check_file(path: Path):
    text = path.read_text(encoding='utf-8')
    bad = []
    for m in md_link_re.finditer(text):
        link = m.group(1).split('#', 1)[0]
        if link.startswith('http://') or link.startswith('https://') or link.startswith('mailto:'):
            continue
        if link.strip() == '':
            continue
        target = (path.parent / link).resolve()
        # If link is to a directory, accept it (index)
        if target.is_file():
            continue
        # allow links that omit .md and point to directory index
        if (path.parent / (link + '.md')).resolve().is_file():
            continue
        bad.append((m.group(1), target))
    return bad

def main():
    files = find_md_files()
    total_bad = 0
    for f in files:
        bad = check_file(f)
        if bad:
            print(f"{f} -> {len(bad)} broken links")
            for link, target in bad:
                print(f"  {link} -> {target}")
            total_bad += len(bad)
    if total_bad:
        print(f"Found {total_bad} broken links")
        return 2
    print("No broken relative links found in docs/")
    return 0

if __name__ == '__main__':
    sys.exit(main())
