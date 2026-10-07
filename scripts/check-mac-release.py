#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Read-only checks for a local, unsigned Mac Release app. Never signs or launches."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NOTICES = ('LICENSE', 'SOURCE-NOTICES.md', 'THIRD_PARTY_NOTICES.md')
EXPECTED_SETTINGS = {
    'CONFIGURATION': 'Release', 'PRODUCT_BUNDLE_IDENTIFIER': 'org.pdfno.PDFnoMac',
    'SWIFT_OPTIMIZATION_LEVEL': '-O', 'ENABLE_TESTABILITY': 'NO', 'ENABLE_PREVIEWS': 'NO',
    'ENABLE_HARDENED_RUNTIME': 'YES', 'CODE_SIGN_INJECT_BASE_ENTITLEMENTS': 'NO',
    'CODE_SIGNING_ALLOWED': 'NO', 'CODE_SIGN_IDENTITY': '', 'DEVELOPMENT_TEAM': '',
    'ONLY_ACTIVE_ARCH': 'NO', 'MACOSX_DEPLOYMENT_TARGET': '14.0',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def inspect(app, settings_file, root=ROOT):
    errors = []
    checks = {}

    def check(name, ok, detail):
        checks[name] = {'pass': bool(ok), 'detail': detail}
        if not ok:
            errors.append(name)

    rows = json.loads(settings_file.read_text())
    candidates = [row['buildSettings'] for row in rows if row.get('target') == 'PDFnoMac']
    if len(candidates) != 1:
        raise ValueError('Expected exactly one PDFnoMac build-settings record')
    settings = candidates[0]
    for key, expected in EXPECTED_SETTINGS.items():
        actual = settings.get(key, '')
        check('setting:'+key, actual == expected, {'expected': expected, 'actual': actual})
    check('architectures', set(settings.get('ARCHS', '').split()) == {'arm64', 'x86_64'}, settings.get('ARCHS'))
    check('no-debug-condition', 'DEBUG' not in settings.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '').split(),
          settings.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', ''))
    check('no-app-sandbox-setting', settings.get('ENABLE_APP_SANDBOX', 'NO') == 'NO', settings.get('ENABLE_APP_SANDBOX', 'NO'))
    entitlement_path = root/'apple'/settings.get('CODE_SIGN_ENTITLEMENTS', '')
    entitlements = plistlib.loads(entitlement_path.read_bytes())
    check('zero-requested-entitlements', entitlements == {}, entitlements)

    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    for key, expected in [('CFBundleIdentifier', 'org.pdfno.PDFnoMac'), ('CFBundleShortVersionString', '0.3.0'),
                          ('CFBundleVersion', '1'), ('LSMinimumSystemVersion', '14.0')]:
        check('info:'+key, info.get(key) == expected, {'expected': expected, 'actual': info.get(key)})
    binary = app/'Contents/MacOS'/info['CFBundleExecutable']
    slices = command(['/usr/bin/lipo', '-archs', str(binary)])
    check('binary-universal', slices.returncode == 0 and set(slices.stdout.split()) == {'arm64', 'x86_64'}, slices.stdout.strip()+slices.stderr.strip())
    signing = command(['/usr/bin/codesign', '-d', '--verbose=4', str(app)])
    signing_text = signing.stdout+signing.stderr
    local_only = ('code object is not signed at all' in signing_text or 'Signature=adhoc' in signing_text)
    local_team = 'Signature=adhoc' not in signing_text or 'TeamIdentifier=not set' in signing_text
    check('no-distribution-signature', local_only and local_team and 'Authority=' not in signing_text, signing_text)
    links = command(['/usr/bin/otool', '-L', str(binary)])
    libraries = [line.strip().split(' (', 1)[0] for line in links.stdout.splitlines() if line.startswith('\t')]
    check('system-or-bundle-linkage', links.returncode == 0 and all(
        name.startswith(('/System/Library/', '/usr/lib/', '@rpath/', '@loader_path/', '@executable_path/')) for name in libraries), libraries)
    symbols = command(['/usr/bin/nm', '-a', str(binary)])
    forbidden_symbols = [name for name in ('OfflineSelectionUITestTransport', 'NoteEditingFilesystemUITestFixture') if name in symbols.stdout]
    check('debug-fixtures-absent', symbols.returncode == 0 and not forbidden_symbols, forbidden_symbols)

    resources = app/'Contents/Resources'
    matches = {}
    for name in NOTICES:
        source, dest = root/name, resources/name
        good = dest.is_file() and sha(source) == sha(dest)
        check('notice:'+name, good, {'sourceSHA256': sha(source), 'bundledSHA256': sha(dest) if dest.is_file() else None})
    for target in ('PDFnoReaders', 'PDFnoServices', 'PDFnoUI'):
        source_root = root/'apple/Packages/PDFnoKit/Sources'/target/'Resources'
        bundle = resources/('PDFnoKit_'+target+'.bundle')
        # Xcode embeds macOS resource bundles with Contents/Resources.
        dest_root = bundle/'Contents/Resources' if (bundle/'Contents/Resources').is_dir() else bundle
        for source in sorted(source_root.rglob('*')):
            if not source.is_file():
                continue
            rel = source.relative_to(source_root)
            dest = dest_root/rel
            key = target+'/'+rel.as_posix()
            good = dest.is_file() and sha(source) == sha(dest)
            matches[key] = {'sourceSHA256': sha(source), 'bundledSHA256': sha(dest) if dest.is_file() else None}
            check('resource:'+key, good, matches[key])

    app_files = {}
    forbidden_files = []
    for path in sorted(app.rglob('*')):
        rel = path.relative_to(app).as_posix()
        if path.is_symlink():
            forbidden_files.append(rel+' (symlink; needs explicit review)')
        elif path.is_file():
            app_files[rel] = sha(path)
        if any(part.endswith('.xctest') or part.endswith('.xcresult') for part in path.parts) or path.suffix.lower() in ('.p12', '.pfx', '.key', '.mobileprovision', '.provisionprofile') or path.name in ('embedded.provisionprofile', 'PDFnoMac.debug.dylib'):
            forbidden_files.append(rel)
    check('no-test-runner-or-private-signing-assets', not forbidden_files, forbidden_files)
    check('source-resources-present', bool(matches), len(matches))
    return {'schemaVersion': 1, 'status': 'PASS' if not errors else 'FAIL', 'errors': errors,
            'checks': checks, 'resourceFiles': len(matches), 'appFilesSHA256': app_files,
            'scope': 'unsigned universal Release package; no app launch, certificate lookup or security assessment',
            'effectiveHardenedRuntime': 'UNVERIFIED: configured YES; unsigned build cannot prove runtime signing flags',
            'formalDistribution': 'NOT-ACCEPTED: Developer ID, notarization, staple and quarantined download launch outstanding'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--build-settings', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    if args.report.exists():
        parser.error('Refusing to replace an existing report')
    try:
        result = inspect(args.app, args.build_settings)
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException) as error:
        result = {'status': 'FAIL', 'error': str(error)}
    args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n')
    print(result['status'], 'Mac Release package check; report:', args.report)
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
