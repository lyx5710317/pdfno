#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Small source/provenance guard; not a full security or license audit."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
sys.dont_write_bytecode = True
from requirement_ledger import SPEC_PATH, validate_requirement_ledger

ROOT=Path(__file__).resolve().parents[1]
raw=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT)
files={Path(x.decode()) for x in raw.split(b'\0') if x and (ROOT/x.decode()).is_file()}
failures=[]
private_patterns=[r'/Users/' + r'[^/\s]+/', r'libfile_' + r'[a-z0-9]{20,}', r'-----BEGIN ' + r'(?:RSA |EC |OPENSSH )?PRIVATE KEY-----', r'gh[pousr]_' + r'[A-Za-z0-9]{36,}', r'github_pat_' + r'[A-Za-z0-9_]{40,}', r'sk-' + r'[A-Za-z0-9_-]{32,}']
pdf_paths={Path('apple/Packages/PDFnoKit')/suffix for suffix in ['Sources/PDFnoUI/Resources/study-sample.pdf','Tests/PDFnoKitTests/Fixtures/study-sample.pdf']}
epub_hashes={Path('apple/Packages/PDFnoKit')/suffix: digest for suffix,digest in [
    ('Sources/PDFnoUI/Resources/study-sample.epub','d8db9c9b04dc3d6f55aa3706b552e2cbaecba41e6b0ae3a0f7536ee0d8bfe7fd'),
    ('Tests/PDFnoKitTests/Fixtures/study-sample.epub','d8db9c9b04dc3d6f55aa3706b552e2cbaecba41e6b0ae3a0f7536ee0d8bfe7fd'),
    ('Tests/PDFnoKitTests/Fixtures/security-sample.epub','da599fe9b7760d46dfc2c2b1c63e243af483d808d1355601a7eb31e4bd17c443')]}
docx_names=('altchunk bad-crc cycle deep descriptor-sample embedded encrypted entities '
            'expansion external hyperlink-sample local-mismatch macro mammoth-sample '
            'oversize paragraphbudget stored-sample study-sample textbudget traversal utf16').split()
docx_paths={Path('apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX')/(name+'.docx') for name in docx_names}
docx_paths.add(Path('apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.docx'))
extraction_path=Path('apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/mammoth-extraction.json')
inventory=json.loads((ROOT/'scripts/ORIGINAL-FIXTURES.json').read_text())
ebook_paths={Path('apple/Packages/PDFnoKit')/folder/('study-sample.'+ext) for folder in ['Sources/PDFnoUI/Resources/Ebooks','Tests/PDFnoKitTests/Fixtures/Ebooks'] for ext in ['mobi','azw','azw3','fb2']}
expected_paths=ebook_paths | pdf_paths | set(epub_hashes) | docx_paths | {extraction_path}
if len(inventory)!=len(expected_paths) or {Path(x['path']) for x in inventory}!=expected_paths:
    failures.append('Original fixture inventory differs from the explicitly approved corpus')
for record in inventory:
    relative=Path(record['path'])
    if (set(record)!={'path','bytes','sha256','generator'} or relative not in expected_paths or
            not isinstance(record['bytes'],int) or isinstance(record['bytes'],bool) or record['bytes']<=0 or
            re.fullmatch(r'[0-9a-f]{64}',record['sha256']) is None):
        failures.append('Invalid original fixture record'); continue
    if relative not in files:
        failures.append(f'Missing approved original fixture: {relative}'); continue
    data=(ROOT/relative).read_bytes()
    if len(data)!=record['bytes'] or hashlib.sha256(data).hexdigest()!=record['sha256']:
        failures.append(f'Original fixture bytes changed: {relative}')
for relative in sorted(files):
    path=ROOT/relative
    if any(part in {'.build','node_modules','xcuserdata','.private'} for part in relative.parts) or path.suffix in {'.key','.pem','.p12','.mobileprovision','.xcuserstate'}:
        failures.append(f'Private/build artifact: {relative}'); continue
    data=path.read_bytes()
    if relative in ebook_paths:
        if path.suffix != '.fb2' and data[60:68] != b'BOOKMOBI': failures.append(f'Invalid original ebook signature: {relative}')
        continue
    if relative in docx_paths:
        if not data.startswith(b'PK\x03\x04'): failures.append(f'Invalid original DOCX signature: {relative}')
        continue
    if relative in epub_hashes:
        if hashlib.sha256(data).hexdigest()!=epub_hashes[relative]: failures.append(f'Original EPUB fixture changed: {relative}')
        continue
    if data.startswith(b'%PDF-'):
        if relative not in pdf_paths: failures.append(f'Unapproved PDF: {relative}')
        continue
    try: text=data.decode('utf-8')
    except UnicodeDecodeError:
        failures.append(f'Unreviewed binary: {relative}'); continue
    for pattern in private_patterns:
        if re.search(pattern,text): failures.append(f'Private identifier/path/credential pattern: {relative}')
for relative in pdf_paths:
    if relative not in files: failures.append(f'Missing original fixture: {relative}')
for relative in epub_hashes:
    if relative not in files: failures.append(f'Missing original EPUB fixture: {relative}')
if len({hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in pdf_paths})!=1:
    failures.append('UI and test fixture bytes differ')
project=(ROOT/'apple/PDFno.xcodeproj/project.pbxproj').read_text()
if project.count('productType = "com.apple.product-type.application";')!=2: failures.append('Expected two real application targets')
if project.count('productType = "com.apple.product-type.bundle.ui-testing";')!=2: failures.append('Expected two native UI test targets')
if 'TARGETED_DEVICE_FAMILY = "1,2";' not in project: failures.append('Mobile target must support iPhone and iPad')
for path in (ROOT/'apple/Packages/PDFnoKit/Sources/PDFnoDomain').glob('*.swift'):
    if re.search(r'import (?:SwiftUI|AppKit|UIKit|PDFKit|WebKit)',path.read_text()): failures.append('Domain imports UI: '+path.name)
package=(ROOT/'apple/Packages/PDFnoKit/Package.swift').read_text()
if '.package(' in package: failures.append('External dependency needs explicit audit')
for workflow in (ROOT/'.github/workflows').glob('*.yml'):
    for use in re.findall(r'^\s*-\s*uses:\s*([^\s#]+)', workflow.read_text(), re.M):
        if not use.startswith('./') and not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}', use):
            failures.append(f'Workflow Action must use a full commit SHA: {workflow.name}: {use}')
ledger=json.loads((ROOT/'docs/REQUIREMENTS-LEDGER.json').read_text())
failures.extend(validate_requirement_ledger(ledger, (ROOT/SPEC_PATH).read_text()))
for name in ['package.json','package-lock.json','src','electron','shared','native','tests']:
    if (ROOT/name).exists(): failures.append('Retired runtime still present: '+name)
if failures:
    print('\n'.join(failures)); sys.exit(1)
print(f'Checked {len(files)} source files: two real app targets, shared domain boundary, original fixtures, no detected private/build material or retired runtime.')
