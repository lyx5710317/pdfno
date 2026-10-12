#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Compile all tests, execute only the explicit non-BYOK allowlist, verify XML."""
from pathlib import Path
import argparse, datetime, json, subprocess, sys, xml.etree.ElementTree as ET
from nonbyok_scope import load_scope, swift_filter, sha, MANIFEST

p = argparse.ArgumentParser()
p.add_argument('--scratch', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()
repo = Path(__file__).resolve().parents[2]
scope = load_scope(repo)
out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
expected = scope['swift']['retained']
command = ['swift', 'test', '--package-path', str(repo/'apple/Packages/PDFnoKit'),
           '--scratch-path', str(args.scratch.resolve()), '--jobs', '1', '--no-parallel',
           '--filter', swift_filter(expected), '--xunit-output', str(out/'swift-testing.xml')]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
with (out/'swift.log').open('x') as log:
    code = subprocess.call(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
cases = []
if (out/'swift-testing.xml').exists():
    for case in ET.parse(out/'swift-testing.xml').getroot().iter('testcase'):
        cases.append({'method': case.attrib['classname'].split('.')[-1] + '/' + case.attrib['name'].split('(')[0],
                      'failed': case.find('failure') is not None or case.find('error') is not None,
                      'skipped': case.find('skipped') is not None})
actual = [case['method'] for case in cases]
accepted = (code == 0 and len(actual) == len(set(actual)) == len(expected)
            and set(actual) == set(expected) and all(not case['failed'] and not case['skipped'] for case in cases))
load_scope(repo)  # No source drift during execution.
record = {'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
          'scope': 'user-approved-nonbyok', 'authorization': scope['authorization'],
          'manifest_sha256': sha(MANIFEST), 'started_at_utc': started,
          'ended_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'command': command, 'exit_code': code, 'expected_methods': expected, 'actual_methods': actual,
          'excluded_not_accepted': scope['swift']['excluded'], 'accepted': accepted,
          'passed': sum(not c['failed'] and not c['skipped'] for c in cases),
          'failed': sum(c['failed'] for c in cases), 'skipped': sum(c['skipped'] for c in cases),
          'xml_sha256': sha(out/'swift-testing.xml') if (out/'swift-testing.xml').exists() else None,
          'log_sha256': sha(out/'swift.log'), 'automatic_retries': 0}
(out/'VERIFICATION.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({key: record[key] for key in ['source_head', 'scope', 'passed', 'failed', 'skipped', 'accepted']}))
sys.exit(0 if accepted else 1)
