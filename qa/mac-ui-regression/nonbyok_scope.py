#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Explicit user-excluded scope; exclusions are never passes or acceptance."""
from pathlib import Path
import hashlib, json, re

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / 'nonbyok-scope.json'
SCOPES = ['representative6', 'nonbyok-gate17', 'remaining38', 'completion49']
AUTHORITY = 'Sentinel_16e90e990010819186595583a4bde414'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_scope(repo=None):
    scope = json.loads(MANIFEST.read_text())
    assert scope['authorization']['message_id'] == AUTHORITY
    assert scope['exclusions_are_accepted'] is False
    inventory = json.loads((HERE / 'method-inventory.json').read_text())
    original = inventory['original68'] + inventory['new5']
    gui = scope['gui']
    excluded = [item['method'] for item in gui['excluded']]
    retained = gui['retained']
    assert len(original) == len(set(original)) == 73
    assert len(excluded) == len(set(excluded)) == 18
    assert len(retained) == len(set(retained)) == 55
    assert not set(retained) & set(excluded)
    assert set(retained) | set(excluded) == set(original)
    assert all(item['reason'] and item['status'] == 'user-excluded-not-accepted' for item in gui['excluded'])
    assert gui['nonbyok-gate17'] == inventory['gate17']
    assert len(gui['nonbyok-gate17']) == 17 and len(gui['remaining38']) == 38
    assert not set(gui['nonbyok-gate17']) & set(gui['remaining38'])
    assert set(gui['nonbyok-gate17']) | set(gui['remaining38']) == set(retained)
    assert len(gui['representative6']) == len(set(gui['representative6'])) == 6
    assert set(gui['representative6']).issubset(retained)
    completion = scope['completion_authorization']
    assert completion['message_id'] == 'Sentinel_ae30196ad1dc8191b5e6f2d5ee0055fa'
    assert completion['deferred_failed_method'] == 'NativeUITests/testMacEPUBSelectionRubyNotesAndRestart'
    assert len(gui['completion49']) == len(set(gui['completion49'])) == 49
    assert set(gui['completion49']) == set(retained) - set(gui['representative6'])
    swift = scope['swift']
    cleanup = scope.get('architecture_cleanup_review')
    if cleanup is not None:
        assert cleanup['authorization_message_id'] == 'Sentinel_961aedf64a208191afc1cb734f2de5bd'
        assert cleanup['validation_authorization_message_id'] == 'Sentinel_e0cf63b4333c8191a85b9fc2f8ae5b4b'
        assert cleanup['original_700_591_109_and_GUI73_55_18_sets_unchanged'] is True
        retired = {item['method'] for item in cleanup['retired_original_swift_methods']}
        assert retired.issubset({item['method'] for item in swift['excluded']})
        assert not retired.intersection(swift['retained'])
        assert set(cleanup['gui_replacements']).issubset(excluded)
        assert not set(cleanup['gui_replacements']).intersection(retained)
        assert len(set(cleanup['gui_replacements'].values())) == len(cleanup['gui_replacements'])
        assert all(item['original'] in swift['all_methods'] for item in cleanup['replacement_swift_methods'])
        assert all(item['source'] in swift['source_sha256'] and
                   swift['source_sha256'][item['source']] == item['reviewed_sha256']
                   for item in cleanup['reviewed_source_digests'])
    all_methods = swift['all_methods']
    excluded_swift = [item['method'] for item in swift['excluded']]
    assert len(all_methods) == len(set(all_methods)) == 700
    assert len(excluded_swift) == len(set(excluded_swift)) == 109
    assert len(swift['retained']) == len(set(swift['retained'])) == 591
    assert not set(swift['retained']) & set(excluded_swift)
    assert set(swift['retained']) | set(excluded_swift) == set(all_methods)
    if repo is not None:
        test_root=Path(repo)/'apple/Packages/PDFnoKit/Tests/PDFnoKitTests'
        actual_files={str(path.relative_to(repo)) for path in test_root.glob('*.swift')}
        classified_files={rel for rel in swift['source_sha256'] if rel.startswith('apple/Packages/PDFnoKit/Tests/')}
        assert actual_files==classified_files, 'Swift source inventory changed; classify before executing'
        for rel, digest in swift['source_sha256'].items():
            assert sha(Path(repo) / rel) == digest, ('Swift classification source changed', rel)
    return scope

def swift_filter(methods):
    # Match complete identities, including Swift Testing's parameter suffix.
    # Allowlisting avoids accidentally executing newly added BYOK tests.
    return r'(^|[./])(?:' + '|'.join(re.escape(m).replace('/', r'[./]') for m in methods) + r')(\(|$)'

if __name__ == '__main__':
    scope = load_scope(HERE.parents[1])
    pattern = re.compile(swift_filter(scope['swift']['retained']))
    for method in scope['swift']['all_methods']:
        for identity in ['PDFnoKitTests.' + method + '()', 'PDFnoKitTests/' + method + '(argument:)']:
            assert bool(pattern.search(identity)) == (method in scope['swift']['retained']), identity
    for method in scope['swift']['retained']:
        assert not pattern.search('PDFnoKitTests.' + method + 'Extra()')
    print(json.dumps({'scope': 'user-approved-nonbyok', 'gui_retained': 55, 'gui_excluded_not_accepted': 18,
                      'swift_retained': 591, 'swift_excluded_not_accepted': 109, 'test_bodies_executed': False}))
