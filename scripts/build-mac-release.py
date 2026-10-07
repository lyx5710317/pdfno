#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Build/check/package a clean revision for local unsigned QA. No app launch or upload."""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='New evidence directory; never overwritten')
    parser.add_argument('--heavy-lock', required=True, type=Path, help='Existing shared native-check lock file')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This script requires macOS and Xcode')
    if git('status', '--porcelain'):
        parser.error('Commit the candidate first; source archive and binary must describe one clean revision')
    if args.output.exists() or not args.heavy_lock.is_file():
        parser.error('Output must be new and the shared heavy-check lock must already exist')
    output = args.output.resolve()
    output.mkdir(parents=True)
    revision = git('rev-parse', 'HEAD')
    receipt = {'schemaVersion': 1, 'sourceRevision': revision, 'branch': git('branch', '--show-current'),
               'startedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'driverPID': os.getpid(),
               'output': str(output), 'commands': [], 'status': 'RUNNING',
               'scope': 'LOCAL UNSIGNED QA ONLY; no Developer ID, certificate/Keychain lookup, app launch, notarization or publication'}
    receipt_path = output/'receipt.json'

    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')

    def run(argv, log_name, binary=False):
        entry = {'argv': argv, 'startedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'log': log_name}
        receipt['commands'].append(entry)
        save()
        with (output/log_name).open('wb' if binary else 'w') as log:
            proc = subprocess.Popen(argv, cwd=ROOT, stdout=log, stderr=subprocess.PIPE if binary else subprocess.STDOUT)
            entry['pid'] = proc.pid
            save()
            _, error = proc.communicate()
        entry['exitCode'] = proc.returncode
        if error:
            (output/(log_name+'.stderr')).write_bytes(error)
        save()
        if proc.returncode:
            raise RuntimeError(log_name+' exited '+str(proc.returncode))

    save()
    try:
        with args.heavy_lock.open('r+') as lock:
            print('Waiting for shared native-check lock', flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
            receipt['lockAdmittedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            save()
            run(['xcodebuild', '-version'], 'xcode-version.log')
            run(['sw_vers'], 'macos-version.log')
            base = ['xcodebuild', '-workspace', 'apple/PDFno.xcworkspace', '-scheme', 'PDFnoMac',
                    '-configuration', 'Release', '-destination', 'generic/platform=macOS',
                    '-derivedDataPath', str(output/'DerivedData'), '-jobs', '2',
                    'ARCHS=arm64 x86_64', 'ONLY_ACTIVE_ARCH=NO', 'CODE_SIGNING_ALLOWED=NO',
                    'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=', 'DEVELOPMENT_TEAM=']
            run(base+['-showBuildSettings', '-json'], 'build-settings.json')
            run(base+['-archivePath', str(output/'PDFno-UNSIGNED-QA.xcarchive'), 'archive'], 'archive.log')
            if git('rev-parse', 'HEAD') != revision or git('status', '--porcelain'):
                raise RuntimeError('Source changed during build; refusing to package mixed revisions')
            app = output/'PDFno-UNSIGNED-QA.xcarchive/Products/Applications/PDFnoMac.app'
            run([sys.executable, 'scripts/check-mac-release.py', '--app', str(app), '--build-settings',
                 str(output/'build-settings.json'), '--report', str(output/'package-check.json')], 'package-check.log')
            run(['git', 'archive', '--format=tar.gz', '--prefix=PDFno-source/', revision], 'PDFno-source-'+revision[:12]+'.tar.gz', binary=True)
            run(['/usr/bin/ditto', '-c', '-k', '--keepParent', str(app), str(output/'PDFno-UNSIGNED-QA.zip')], 'zip.log')
            artifacts = [output/'PDFno-UNSIGNED-QA.zip', output/('PDFno-source-'+revision[:12]+'.tar.gz')]
            receipt['artifactsSHA256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in artifacts}
            receipt['status'] = 'PASS'
            receipt['formalDistribution'] = 'NOT-ACCEPTED; unsigned QA artifacts must not be published as an official download'
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        receipt['status'] = 'FAIL'
        receipt['error'] = str(error)
    finally:
        receipt['endedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
    print(receipt['status'], 'Local unsigned Release preparation; receipt:', receipt_path, flush=True)
    return 0 if receipt['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
