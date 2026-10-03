#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Inventory only the explicitly approved, deterministically generated corpus."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
KIT = 'apple/Packages/PDFnoKit/'
DOCX_NAMES = (
    'altchunk bad-crc cycle deep descriptor-sample embedded encrypted entities '
    'expansion external hyperlink-sample local-mismatch macro mammoth-sample '
    'oversize paragraphbudget stored-sample study-sample textbudget traversal utf16'
).split()
paths = {}
for name in ['Sources/PDFnoUI/Resources/study-sample.pdf', 'Tests/PDFnoKitTests/Fixtures/study-sample.pdf']:
    paths[KIT + name] = 'scripts/generate-apple-project.py'
for name in ['Sources/PDFnoUI/Resources/study-sample.epub', 'Tests/PDFnoKitTests/Fixtures/study-sample.epub', 'Tests/PDFnoKitTests/Fixtures/security-sample.epub']:
    paths[KIT + name] = 'scripts/generate-epub-fixture.py'
for name in DOCX_NAMES:
    paths[KIT + 'Tests/PDFnoKitTests/Fixtures/DOCX/' + name + '.docx'] = 'scripts/generate-docx-fixture.py'
paths[KIT + 'Sources/PDFnoUI/Resources/study-sample.docx'] = 'scripts/generate-docx-fixture.py'
paths[KIT + 'Tests/PDFnoKitTests/Fixtures/DOCX/mammoth-extraction.json'] = 'engine-build/generate-docx-extraction.mjs'
records = []
for name, generator in sorted(paths.items()):
    data = (ROOT / name).read_bytes()
    records.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), generator=generator))
(ROOT / 'scripts/ORIGINAL-FIXTURES.json').write_text(json.dumps(records, indent=2) + '\n')
print('Inventoried', len(records), 'approved original fixture copies; no user or arbitrary binary paths.')
