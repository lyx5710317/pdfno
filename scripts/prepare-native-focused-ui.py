#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Configure an explicit ten-method diagnostic run without changing original tests."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib

parser = argparse.ArgumentParser()
parser.add_argument('--products', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
products = args.products.resolve()
output = args.output.resolve()
assert not output.exists(), 'Keep every prior diagnostic plan.'
generated = list(products.glob('PDFnoMac_*.xctestrun'))
assert len(generated) == 1, 'Require the actual compiled Mac test plan.'
original = generated[0].read_bytes()
raw = plistlib.loads(original)
conf = raw['PDFnoMacUITests']
assert not conf.get('OnlyTestIdentifiers') and not conf.get('SkipTestIdentifiers')
methods = [
    'NativeUITests/testMacLibraryLayoutSelectionAndOriginalSampleEntrypoints',
    'NativeUITests/testMacBooknoExplicitOfflinePreviewSavedBodyMockReplayAndClose',
    'NativeUITests/testMacCB7ImportSpreadsDirectionPageJumpAndRestart',
    'NativeUITests/testMacCBRImportSpreadsDirectionPageJumpAndRestart',
    'NativeUITests/testMacCBTImportSpreadsDirectionPageJumpAndRestart',
    'NativeUITests/testMacCBZImportSpreadsDirectionPageJumpAndRestart',
    'ReadingIntegrationUITests/testMacParagraphTypedEvidenceConsentManualSaveAndSource',
    'ReadingIntegrationUITests/testMacPDFSearchTOCReturnAndTextInputProtection',
    'ReadingIntegrationUITests/testMacSettingsCategoriesPreserveUnappliedConfiguration',
    'ReadingIntegrationUITests/testMacToolsRouteRequiresConsentAndManualSave',
]
assert len(set(methods)) == 10
repo = Path(__file__).resolve().parent.parent
for method in methods:
    suite, name = method.split('/')
    assert 'func ' + name + '(' in (repo / 'apple/Tests' / (suite + '.swift')).read_text()
conf['OnlyTestIdentifiers'] = methods
conf['SkipTestIdentifiers'] = []
conf['TestTimeoutsEnabled'] = True
conf['DefaultTestExecutionTimeAllowance'] = 180
conf['MaximumTestExecutionTimeAllowance'] = 240
conf['SystemAttachmentLifetime'] = 'keepNever'
conf['UserAttachmentLifetime'] = 'keepAlways'
conf.setdefault('EnvironmentVariables', {})['PDFNO_UI_TEST_PANEL_DIAGNOSTICS'] = '1'
output.write_bytes(plistlib.dumps(raw))
receipt = {
    'scope': 'Focused diagnostic10; never claim original60 passed from this run.',
    'original_plan': str(generated[0]), 'original_plan_sha256': hashlib.sha256(original).hexdigest(),
    'configured_plan': str(output), 'configured_plan_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'expected_methods': methods, 'original_assertions_changed': False,
    'skips': [], 'automatic_retries': 0, 'original_time_allowances': [180, 240],
    'diagnostics': 'Actual fixture panel timing and exact own completion/control AX and screenshots only; no unrelated directory listing or desktop.',
}
output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
