#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline selected-source/hash/license and original fixture consistency check; not a security audit."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
base=root/'apple/Packages/PDFnoKit/Sources/PDFnoComicCodecs'
manifest=json.loads((base/'SOURCE.json').read_text())
expected={x['path'] for x in manifest['files']}
actual={str(p.relative_to(base)) for name in ['libarchive','xz'] for p in (base/name).rglob('*') if p.is_file()}
assert expected==actual,'Source inventory differs'
for record in manifest['files']:
    data=(base/record['path']).read_bytes()
    assert hashlib.sha256(data).hexdigest()==record['vendoredSHA256'],record['path']
    assert record['license'] and len(record['upstreamSHA256'])==64
for record in manifest['licenses']:
    assert hashlib.sha256((base/record['path']).read_bytes()).hexdigest()==record['sha256'],record['path']
for path in base.rglob('*.c'):
    text=path.read_text()
    assert '#include "archive_platform.h"' in text or '#include "common.h"' in text or '#include "PDFnoBudget.h"' in text or 'archive_blake2' in path.name or 'archive_ppmd' in path.name or '#include "filter_' in text or '#include "lzma_' in text or '#include "lz_' in text or '#include "vli_' in text,path
for source in ['archive_read_support_filter_program.c','archive_read_open_filename.c','archive_read_extract.c','archive_read_support_format_zip.c']:
    assert not (base/'libarchive'/source).exists(),source
directory=root/'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Comics'
fixtures=json.loads((directory/'NATIVE-SOURCE.json').read_text())
for record in fixtures:
    text=(directory/(record['name']+'.hex')).read_bytes()
    data=bytes.fromhex(text.decode())
    assert hashlib.sha256(text).hexdigest()==record['hexSHA256'],record['name']
    assert hashlib.sha256(data).hexdigest()==record['sha256'] and len(data)==record['bytes'],record['name']
notice=root/'apple/Packages/PDFnoKit/Sources/PDFnoServices/Resources/ComicCodecs/NOTICES.txt'
assert 'Neither the name of the University' in notice.read_text()
assert notice.is_file() and all(x['path'] in notice.read_text() for x in manifest['files'])
print(f'Verified {len(expected)} selected codec source/header hashes/licenses and {len(fixtures)} original real-format fixtures; offline only.')
