#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Validate compiled guarded products and prepare the complete 64-method run; no GUI."""
from pathlib import Path
import argparse, hashlib, json, plistlib, subprocess, uuid

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve()
receipt = json.loads((out / 'PREPARATION.json').read_text())
products = out / 'DerivedData/Build/Products'
generated = list(products.glob('PDFnoMac_*.xctestrun'))
assert len(generated) == 1
raw = plistlib.loads(generated[0].read_bytes())
configuration = raw['PDFnoMacUITests']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
compiled = {}
for name, path in [
    ('app', products / 'Debug/PDFnoMac.app'),
    ('runner', products / 'Debug/PDFnoMacUITests-Runner.app'),
    ('tests', products / 'Debug/PDFnoMacUITests-Runner.app/Contents/PlugIns/PDFnoMacUITests.xctest'),
]:
    info = plistlib.loads((path / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'].startswith('org.pdfno.integration.professionala20261007.')
    binary = path / 'Contents/MacOS' / info['CFBundleExecutable']
    subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(path)], check=True, capture_output=True)
    architectures = subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).strip()
    assert architectures == 'arm64'
    compiled[name] = {'path': str(path), 'bundle': info['CFBundleIdentifier'], 'binary_sha256': sha(binary), 'architectures': architectures, 'signature_verified': True}
    if name == 'app':
        # App must not gain test/debug entitlements merely because tests were compiled.
        result = subprocess.run(['/usr/bin/codesign', '-d', '--entitlements', ':-', str(path)], capture_output=True)
        assert result.returncode == 0
        data = result.stdout
        entitlements = plistlib.loads(data) if data.strip() else {}
        assert not entitlements, 'QA app unexpectedly gained entitlements; do not launch it.'
        compiled[name]['entitlements'] = entitlements
        dylib = path / 'Contents/MacOS/PDFnoMac.debug.dylib'
        if dylib.exists(): compiled[name]['debug_dylib_sha256'] = sha(dylib)
assert compiled['app']['bundle'] == receipt['bundle']
assert configuration['TestHostBundleIdentifier'] == compiled['runner']['bundle']
snapshot = Path(receipt['source'])
for relative, expected in receipt['production_inputs'].items():
    if relative not in receipt['qa_only_deviations'] and relative != 'apple/PDFno.xcodeproj/project.pbxproj':
        assert sha(snapshot / relative) == expected, relative
for name, expected in receipt['production_original_four_ui_sha256'].items():
    assert sha(snapshot / 'apple/Tests' / name) == expected
assert len(receipt['expected_methods']) == 64 and len(set(receipt['expected_methods'])) == 64
token = str(uuid.uuid4()).upper()
bootstrap = Path('/tmp') / ('PDFno-UITests-' + token)
assert not bootstrap.exists()
configuration['UITargetAppPath'] = compiled['app']['path']
configuration['TestHostPath'] = compiled['runner']['path']
configuration['UITargetAppBundleIdentifier'] = receipt['bundle']
configuration.pop('OnlyTestIdentifiers', None)
configuration['SkipTestIdentifiers'] = []
configuration['TestTimeoutsEnabled'] = True
configuration['DefaultTestExecutionTimeAllowance'] = 180
configuration['MaximumTestExecutionTimeAllowance'] = 240
configuration['SystemAttachmentLifetime'] = 'keepNever'
configuration['UserAttachmentLifetime'] = 'keepNever'
environment = {
    'PDFNO_UI_TEST_SESSION': token,
    'PDFNO_UI_TEST_DEEPSEEK': 'offline',
    'PDFNO_A_QA_SCOPE': 'full64',
    'PDFNO_ISOLATED_UI_APPLICATION_ID': receipt['bundle'],
    'PDFNO_A_QA_SHOT_TOKEN': token,
}
configuration.setdefault('EnvironmentVariables', {}).update(environment)
configuration.setdefault('UITargetAppEnvironmentVariables', {}).update(environment)
configured = products / 'ProfessionalAComplete64.xctestrun'
assert not configured.exists()
configured.write_bytes(plistlib.dumps(raw))
result_bundle = out / 'ProfessionalAComplete64.xcresult'
assert not result_bundle.exists()
command = ['xcodebuild', '-xctestrun', str(configured), '-destination', 'platform=macOS', '-resultBundlePath', str(result_bundle), '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '180', '-maximum-test-execution-time-allowance', '240', 'test-without-building']
plan = {'source_head': receipt['source_head'], 'branch': receipt['branch'], 'bundle': receipt['bundle'], 'compiled_products': compiled, 'xctestrun': str(configured), 'xctestrun_sha256': sha(configured), 'bootstrap_uuid': token, 'bootstrap_root': str(bootstrap), 'expected_methods': receipt['expected_methods'], 'filters': [], 'skips': [], 'automatic_retries': 0, 'command': command, 'gui_started': False, 'desktop_exclusive_handoff_required_before_run': True}
(out / 'RUN-PLAN.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'bundle': receipt['bundle'], 'compiled_products_verified': True, 'expected_methods': 64, 'gui_started': False}))
