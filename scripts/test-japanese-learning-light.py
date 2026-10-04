#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Compile real dependencies + this slice; no app launch/network/keychain.

Excludes readers, other UI and unrelated tests; not full package/Xcode/UI/mobile acceptance.
SwiftPM's normal sandbox stays enabled; compilation uses one job.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
package = root / 'apple/Packages/PDFnoKit'
services = ['AICredentials.swift', 'AIHTTPProvider.swift', 'AIJobCoordinator.swift',
            'DeepSeekSelectionProvider.swift', 'DeepSeekSelfTest.swift', 'AppAISession.swift',
            'LibraryRepository.swift', 'BoundedFileReader.swift',
            'JapaneseLearningProvider.swift', 'JapaneseLearningCoordinator.swift', 'JapaneseLearningRepository.swift', 'JapaneseLearningMockComponents.swift']
ui = ['JapaneseLearningModel.swift', 'JapaneseLearningWorkspace.swift', 'JapaneseSentenceComponentsView.swift']
tests = ['JapaneseLearningDomainTests.swift', 'JapaneseLearningFlowTests.swift', 'JapaneseLearningRepositoryTests.swift', 'JapaneseLearningComponentTests.swift']
with tempfile.TemporaryDirectory(prefix='pdfno-japanese-light-', dir='/tmp') as temporary:
    target = Path(temporary)
    groups = {'PDFnoDomain': list((package / 'Sources/PDFnoDomain').glob('*.swift')),
              'PDFnoServices': [package / 'Sources/PDFnoServices' / name for name in services],
              'PDFnoUI': [package / 'Sources/PDFnoUI' / name for name in ui],
              'PDFnoKitTests': [package / 'Tests/PDFnoKitTests' / name for name in tests]}
    for module, sources in groups.items():
        destination = target / ('Tests' if module == 'PDFnoKitTests' else 'Sources') / module
        destination.mkdir(parents=True)
        for source in sources:
            shutil.copy2(source, destination / source.name)
    (target / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "JapaneseLearningLight", platforms: [.macOS(.v14)], targets: [
    .target(name: "PDFnoDomain"),
    .target(name: "PDFnoServices", dependencies: ["PDFnoDomain"]),
    .target(name: "PDFnoUI", dependencies: ["PDFnoDomain", "PDFnoServices"]),
    .testTarget(name: "PDFnoKitTests", dependencies: ["PDFnoDomain", "PDFnoServices", "PDFnoUI"])
])
''')
    print('Light slice: ' + ', '.join(f'{module}={len(sources)} real source files' for module, sources in groups.items()), flush=True)
    result = subprocess.run(['swift', 'test', '--package-path', str(target), '-j', '1', '--filter', 'JapaneseLearning'])
    raise SystemExit(result.returncode)
