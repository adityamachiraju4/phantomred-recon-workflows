#!/usr/bin/env python3
"""
embed_pipeline_image.py
Embeds recon-pipeline.png into README.md just before the ASCII pipeline block.
Run from: ~/Projects/phantomred-recon-workflows/
"""

import sys

TARGET = "README.md"
ANCHOR = "## Pipeline Architecture"

IMAGE_BLOCK = """## Pipeline Architecture

![PhantomRed Autonomous Recon Pipeline](screenshots/recon-pipeline.png)

"""

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

if ANCHOR not in content:
    print(f"ERROR: anchor not found — '{ANCHOR}'")
    sys.exit(1)

# Replace the heading + keep everything after it, but insert image right after heading
OLD = "## Pipeline Architecture\n"
NEW = IMAGE_BLOCK

if OLD not in content:
    print("ERROR: exact anchor line not found")
    sys.exit(1)

updated = content.replace(OLD, NEW, 1)

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(updated)

print("OK — image embedded in README.md")
