#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Build a fresh source snapshot for the approved offline Mac 68+5 suite.

Never launches an app. Production code stays untouched. Exact-context overlays
add only the reviewed QA mock/ownership diagnostics and deny HTTP/Keychain.
"""
from pathlib import Path
from collections import Counter
import argparse, difflib, hashlib, json, re, shutil, subprocess, uuid
from nonbyok_scope import load_scope, MANIFEST

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--repo', type=Path, default=HERE.parents[1])
parser.add_argument('--scope', choices=['current73', 'nonbyok'], default='nonbyok')
args = parser.parse_args()
repo, out = args.repo.resolve(), args.output.resolve()
assert not out.exists(), 'Preserve previous QA evidence; use a fresh output directory.'
subprocess.run(['python3', '-B', str(repo/'qa/reader-professional/prepare.py'), '--output', str(out)], check=True)
record = json.loads((out/'PREPARATION.json').read_text())
source = out/'source'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
inventory = json.loads((HERE/'method-inventory.json').read_text())
approved = load_scope(repo)
aliases = approved.get('architecture_cleanup_review', {}).get('gui_replacements', {})
current_method = lambda method: aliases.get(method, method)
assert sorted(record['expected_methods']) == sorted(map(current_method, inventory['original68']))
assert len(inventory['new5']) == 5 and len(inventory['gate17']) == 17

seed = out/'FixtureSeed'
(seed/'Originals').mkdir(parents=True)
sample = repo/'apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.pdf'
digest = sha(sample)
assert digest == '0364d0ca9f7317a7bbcb546faafbdd19d4b3a4ebc31afbee38d7bb30d14f0847'
shutil.copy2(sample, seed/'Originals'/(digest+'.pdf'))
book_id, edition, note_id, answer_id = [str(uuid.uuid4()).upper() for _ in range(4)]
quote = 'Reading opens a small window onto a wider world.'
book = dict(id=book_id, editionID=edition, title='Original Saved AI Fixture', fileSHA256=digest,
            originalFilename='Original Saved AI Fixture.pdf', pageCount=2, importedAt=800000000, lastPageIndex=1)
anchor = dict(schemaVersion=1, editionID=edition, fileSHA256=digest, quote=quote,
              regions=[dict(pageIndex=0, x=72, y=656.7802734375, width=314.34200000000004, height=14, quote=quote)],
              extractionVersion='pdfkit-selection-1')
provider = dict(id=str(uuid.uuid4()).upper(), generation=1, mode='mock', label='Original offline fixture', endpoint='', model='')
result = dict(requestID=answer_id, kind='explain',
              source=dict(bookID=book_id, readerSessionID=str(uuid.uuid4()).upper(), documentVersion=0, anchor={'pdf':{'_0':anchor}}),
              provider=provider, promptVersion='selection-1', text='Original offline explanation. SavedSearchMarker.', fromCache=False)
note = dict(id=note_id, bookID=book_id, anchor={'pdf':{'_0':anchor}}, origin='explicitlySavedAI', sourceRecordID=answer_id,
            aiResult=result, kind='note', userText='Original committed comment', revision=1, createdAt=800000000, updatedAt=800000000)
for name, value in [('library-v1.json',dict(schemaVersion=1,books=[book],notes=[])),
                    ('annotations-v1.json',dict(schemaVersion=1,notes=[note])),
                    ('annotation-edit-drafts-v1.json',dict(schemaVersion=1,drafts=[dict(baseline={'annotation':note},text='OriginalDraftOnlyMarker')]))]:
    (seed/name).write_text(json.dumps(value, sort_keys=True, indent=2)+'\n')
seed_hashes = {str(p.relative_to(seed)):sha(p) for p in seed.rglob('*') if p.is_file()}

substitutions = {'__QA_BUNDLE__':record['bundle'], '__PREVIEW_UUID__':record['preview_uuid'],
                 '__DERIVED_DATA__':str(out/'DerivedData'), '__REGISTRY_ROOT__':record['registry'],
                 '__SOURCE_HEAD__':record['source_head'], '__SEED_ROOT__':str(seed),
                 '__DIAGNOSTICS_ROOT__':str(out/'Diagnostics'), '__NOTE_ID__':note_id,
                 '__SEED_LINES__':'\n'.join('                try seedFile('+json.dumps(name)+', expected: '+json.dumps(value)+')'
                                          for name,value in seed_hashes.items())}
def render(text):
    for old,new in substitutions.items(): text=text.replace(old,new)
    assert not re.search(r'__(?:QA_|PREVIEW_|DERIVED_|REGISTRY_|SOURCE_|SEED_|DIAGNOSTICS_|NOTE_)\w*__',text)
    return text
(source/'apple/Apps/Mac/PDFnoMacApp.swift').write_text(render((HERE/'GuardedMacApp.swift.template').read_text()))

# Apply only reviewed runtime additions. An upstream context change is an error,
# never a reason to silently replace a newer shipping implementation.
for rel, edits in json.loads((HERE/'runtime-overlays.json').read_text()).items():
    text = (source/rel).read_text()
    patches=[]
    for edit in edits:
        before=edit['left']+edit['old']+edit['right']
        assert text.count(before)==1, (rel, 'QA overlay context changed')
        begin=text.index(before)+len(edit['left'])
        patches.append((begin,begin+len(edit['old']),render(edit['replacement'])))
    for a,b in zip(patches,patches[1:]): assert a[1]<=b[0]
    for begin,end,replacement in reversed(patches): text=text[:begin]+replacement+text[end:]
    (source/rel).write_text(text)
    record['qa_only_deviations'].append(rel)

tests=source/'apple/Tests'
for cls in ['ReaderChromeUITests','ReaderConversationUITests','SavedAISearchUITests','QAOwnDesktopFence']:
    (tests/(cls+'.swift')).write_text(render((HERE/(cls+'.swift.template')).read_text()))
    record['qa_only_deviations'].append('apple/Tests/'+cls+'.swift')
install='\n        QAOwnDesktopFence.install(); continueAfterFailure = false\n'
for cls in ['NativeUITests','EbookFormatUITests','NextBatchUITests','ReadingIntegrationUITests','ProfessionalReaderUITests']:
    path=tests/(cls+'.swift'); text=path.read_text()
    guarded,count=re.subn(r'(func test\w+\([^)]*\)(?:\s+async)?(?:\s+throws)?\s*\{)',lambda m:m[0]+install,text)
    assert count>0 and guarded.replace(install,'')==text
    if cls == 'NativeUITests':
        # An existing live credential process must never be relaunched. Its
        # original first activation and ownDesktop() admit the exact window;
        # intercept subsequent inputs only after that authorized admission.
        name = 'func testFinalFourUIRealSelectionAndFullDocumentConsent() throws {'
        assert guarded.count(name) == 1
        start = guarded.index(name)
        prefix, live = guarded[:start], guarded[start:]
        assert live.count(install) == 1
        live = live.replace(install, '\n        continueAfterFailure = false\n', 1)
        activation = 'app.activate();try ownDesktop()'
        assert live.count(activation) == 1
        live = live.replace(activation, activation + '; QAOwnDesktopFence.install()', 1)
        guarded = prefix + live
    if cls=='ProfessionalReaderUITests':
        guarded=guarded.replace('FileManager.default.temporaryDirectory.appendingPathComponent(',
            'FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(')
    path.write_text(guarded); record['qa_only_deviations'].append('apple/Tests/'+cls+'.swift')

project=source/'apple/PDFno.xcodeproj/project.pbxproj'; text=project.read_text()
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
for cls in ['ReaderChromeUITests','ReaderConversationUITests','SavedAISearchUITests','QAOwnDesktopFence']:
    ref,build=ident('Full73'+cls+'ref'),ident('Full73'+cls+'build')
    text=text.replace('objects = {',f'objects = {{\n{ref} = {{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/{cls}.swift; sourceTree = "<group>"; }};\n{build} = {{ isa = PBXBuildFile; fileRef = {ref}; }};',1)
    for key,field,value in [(ident('PDFnoMacUITestssources'),'files',build),(ident('mainGroup'),'children',ref)]:
        i=text.index(key+' = '); i=text.index(field+' = (',i)+len(field+' = ('); text=text[:i]+value+','+text[i:]
project.write_text(text)

fixture_name='Original-only-long-document-title-for-local-reader-chrome-overflow-check-with-no-private-content.md'
assert sha(HERE/fixture_name)==inventory['fixture_long_title_sha256']
fixture=out/'ReaderPanelSimplification/2026-10-10/QA01/FixtureInput'/fixture_name
fixture.parent.mkdir(parents=True); shutil.copy2(HERE/fixture_name,fixture)
methods=list(map(current_method, inventory['original68']+inventory['new5']))
assert len(set(methods))==73
for method in methods:
    cls,name=method.split('/')
    assert re.search(r'func\s+'+re.escape(name)+r'\s*\(', (tests/(cls+'.swift')).read_text())
record.update(expected_methods=methods, all_compiled_methods=methods, gate17=inventory['gate17'],
              remaining56=[x for x in methods if x not in inventory['gate17']],
              representative8=inventory['representative8'],
              fixture_seed_hashes=seed_hashes, fixture_note_id=note_id, fixture_book_id=book_id,
              fixture_long_title_path=str(fixture), diagnostics=str(out/'Diagnostics'),
              scope='Approved Mac original68 plus new5; representative8 then gate17 then remaining56, distinct exact current candidate',
              GUI_started=False, network_refused=True, keychain_refused=True,
              original_generated_ui_plan_unfiltered=True, new_accounts_or_packages=False)
record['historical_gui_replacements'] = aliases
assert len(record['remaining56'])==56
assert len(set(record['representative8']))==8 and set(record['representative8']).issubset(inventory['original68'])
if args.scope == 'nonbyok':
    approved = load_scope(repo)
    record.update(execution_scope='user-approved-nonbyok', scope_manifest_sha256=sha(MANIFEST),
                  authorization=approved['authorization'], exclusions_are_accepted=False,
                  excluded_not_accepted=approved['gui']['excluded'], accepted_scope_methods=approved['gui']['retained'],
                  representative6=approved['gui']['representative6'], nonbyok_gate17=approved['gui']['nonbyok-gate17'],
                  remaining38=approved['gui']['remaining38'],
                  scope='Compile original73; execute non-BYOK representative6, gate17, remaining38; 55 distinct retained, 18 user-excluded not accepted')
(out/'PREPARATION.json').write_text(json.dumps(record,indent=2)+'\n')
(out/'DerivedData').mkdir()
print(json.dumps({'source_head':record['source_head'],'bundle':record['bundle'],'methods':73,'gate':17,'remaining':56,'GUI_started':False}))
