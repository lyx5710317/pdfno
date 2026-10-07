#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Exercise acceptance rejection paths using self-authored temporary packages."""
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release_check', Path(__file__).with_name('check-mac-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class AcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pdfno-release-check-')
        self.root = Path(self.temp.name)
        self.app = self.root/'PDFnoMac.app'
        self.resources = self.app/'Contents/Resources'
        self.resources.mkdir(parents=True)
        (self.app/'Contents/MacOS').mkdir()
        (self.app/'Contents/MacOS/PDFnoMac').write_bytes(b'self-authored-placeholder')
        info = {'CFBundleIdentifier': 'org.pdfno.PDFnoMac', 'CFBundleShortVersionString': '0.3.0',
                'CFBundleVersion': '1', 'LSMinimumSystemVersion': '14.0', 'CFBundleExecutable': 'PDFnoMac'}
        (self.app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        self.entitlements = self.root/'apple/Configs/PDFnoMacRelease.entitlements'
        self.entitlements.parent.mkdir(parents=True)
        self.entitlements.write_bytes(plistlib.dumps({}))
        self.settings = dict(release.EXPECTED_SETTINGS, ARCHS='arm64 x86_64', CODE_SIGN_ENTITLEMENTS='Configs/PDFnoMacRelease.entitlements')
        self.settings_file = self.root/'settings.json'
        for name in release.NOTICES:
            (self.root/name).write_text('Self-authored fixture notice '+name)
            (self.resources/name).write_bytes((self.root/name).read_bytes())
        for target in ('PDFnoReaders', 'PDFnoServices', 'PDFnoUI'):
            source = self.root/'apple/Packages/PDFnoKit/Sources'/target/'Resources/fixture.txt'
            source.parent.mkdir(parents=True)
            source.write_text('Self-authored fixture resource')
            dest = self.resources/('PDFnoKit_'+target+'.bundle/fixture.txt')
            dest.parent.mkdir(parents=True)
            dest.write_bytes(source.read_bytes())
        self.signing = 'Signature=adhoc\nTeamIdentifier=not set\nflags=0x20002(adhoc,linker-signed)\n'
        self.symbols = 'application symbol'

    def tearDown(self):
        self.temp.cleanup()

    def inspect(self):
        self.settings_file.write_text(json.dumps([{'target': 'PDFnoMac', 'buildSettings': self.settings}]))
        def command(argv):
            outputs = {'lipo': 'arm64 x86_64\n', 'codesign': self.signing,
                       'otool': 'binary:\n\t/System/Library/Frameworks/WebKit.framework/Versions/A/WebKit (compatibility version 1.0)\n',
                       'nm': self.symbols}
            return subprocess.CompletedProcess(argv, 0, outputs[Path(argv[0]).name], '')
        with patch.object(release, 'command', command):
            return release.inspect(self.app, self.settings_file, self.root)

    def test_unsigned_package_does_not_claim_effective_runtime_or_distribution(self):
        result = self.inspect()
        self.assertEqual(result['status'], 'PASS')
        self.assertTrue(result['effectiveHardenedRuntime'].startswith('UNVERIFIED'))
        self.assertTrue(result['formalDistribution'].startswith('NOT-ACCEPTED'))

    def test_runtime_exception_or_sandbox_is_rejected(self):
        for entitlement in ('com.apple.security.cs.allow-jit', 'com.apple.security.cs.disable-library-validation',
                            'com.apple.security.app-sandbox', 'com.apple.security.get-task-allow'):
            with self.subTest(entitlement=entitlement):
                self.entitlements.write_bytes(plistlib.dumps({entitlement: True}))
                self.assertIn('zero-requested-entitlements', self.inspect()['errors'])

    def test_missing_or_changed_reader_asset_is_rejected(self):
        asset = self.resources/'PDFnoKit_PDFnoReaders.bundle/fixture.txt'
        asset.write_text('changed')
        self.assertIn('resource:PDFnoReaders/fixture.txt', self.inspect()['errors'])
        asset.unlink()
        self.assertIn('resource:PDFnoReaders/fixture.txt', self.inspect()['errors'])

    def test_debug_or_nonuniversal_build_is_rejected(self):
        self.settings['ARCHS'] = 'arm64'
        self.settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        self.settings['ENABLE_TESTABILITY'] = 'YES'
        self.symbols = 'OfflineSelectionUITestTransport'
        errors = self.inspect()['errors']
        self.assertTrue({'architectures', 'no-debug-condition', 'setting:ENABLE_TESTABILITY', 'debug-fixtures-absent'}.issubset(errors))

    def test_distribution_signature_and_private_signing_assets_are_rejected(self):
        self.signing = 'Authority=Developer ID Application: synthetic test text\nTeamIdentifier=synthetic\n'
        (self.resources/'fixture.key').write_text('self-authored placeholder; never a real key')
        errors = self.inspect()['errors']
        self.assertIn('no-distribution-signature', errors)
        self.assertIn('no-test-runner-or-private-signing-assets', errors)


if __name__ == '__main__':
    unittest.main()
