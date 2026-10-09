#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Guarded fixture preparation, retaining the production manual appearance path."""
from pathlib import Path
import argparse, json, subprocess, sys

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve()
subprocess.run([sys.executable, str(root/'qa/tabs-sidebar/prepare.py'), '--output', str(out)], check=True)
app = out/'source/apple/Apps/Mac/PDFnoMacApp.swift'
text = app.read_text()
anchor = '.preferredColorScheme(appearance)'
assert text.count(anchor) == 1
text = text.replace(anchor, '')
start = text.index('    private var appearance: ColorScheme? {')
end = text.index('    var body: some Scene {', start)
text = text[:start] + text[end:]
assert 'preferredColorScheme(PDFnoAppearanceMode(rawValue: appearancePreference)?.colorScheme)' in text
assert 'PDFNO_A_QA_APPEARANCE' not in text
app.write_text(text)
receipt = json.loads((out/'PREPARATION.json').read_text())
receipt['scope'] = 'Bounded appearance/sidebar UI validation; production manual appearance and app-only persistence; no forced QA theme; live HTTP and Keychain disabled; original assertions unchanged.'
receipt['forced_qa_appearance'] = False
(out/'PREPARATION.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({'source_head':receipt['source_head'], 'bundle':receipt['bundle'], 'forced_qa_appearance':False}))
