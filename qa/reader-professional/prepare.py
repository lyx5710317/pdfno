#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Prepare a guarded snapshot and four extra UI regressions. Never launches GUI."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, uuid

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve()
if out.exists(): raise SystemExit('Use a fresh QA output directory; existing evidence is preserved.')
out.mkdir(parents=True)
snapshot = out / 'source'
snapshot.mkdir()
shutil.copytree(ROOT / 'apple', snapshot / 'apple', ignore=shutil.ignore_patterns('.build', 'DerivedData', 'xcuserdata', 'project.xcworkspace'))
for name in ['LICENSE', 'SOURCE-NOTICES.md', 'THIRD_PARTY_NOTICES.md']:
    shutil.copy2(ROOT / name, snapshot / name)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
inputs = {str(p.relative_to(ROOT)): sha(p) for p in (ROOT / 'apple').rglob('*') if p.is_file() and not any(x in p.relative_to(ROOT).parts for x in ['.build','xcuserdata','project.xcworkspace'])}
assert len(inputs) > 300, 'The full Apple source input manifest must never be empty.'
preview = str(uuid.uuid4()).upper()
registry = out / 'Registry'
app = (ROOT / 'qa/reader-professional/GuardedMacApp.swift.template').read_text().replace('__PREVIEW_UUID__', preview).replace('__REGISTRY_ROOT__', str(registry))
(snapshot / 'apple/Apps/Mac/PDFnoMacApp.swift').write_text(app)
changes = ['apple/Apps/Mac/PDFnoMacApp.swift']
# Reject all live network and Keychain operations in this snapshot only.
p = snapshot / 'apple/Packages/PDFnoKit/Sources/PDFnoServices/AIHTTPProvider.swift'
s = p.read_text(); a = s.index('    public func send(_ request: URLRequest) async throws -> AIHTTPResponse {'); b = s.index('\n}\npublic struct OpenAICompatibleSelectionProvider',a)
s = s[:a] + '    public func send(_ request: URLRequest) async throws -> AIHTTPResponse { throw AIFailure.network }\n' + s[b:]; p.write_text(s)
changes.append(str(p.relative_to(snapshot)))
p = snapshot / 'apple/Packages/PDFnoKit/Sources/PDFnoServices/AICredentials.swift'
s = p.read_text(); a = s.index('public struct SecurityKeychainClient: ExactKeychainClient {'); b = s.index('\npublic actor KeychainCredentialStore',a)
s = s[:a] + '''public struct SecurityKeychainClient: ExactKeychainClient {
    public init() {}
    public func read(service: String, account: String) throws -> Data? { throw AIFailure.credentials }
    public func put(_ bytes: Data, service: String, account: String) throws { throw AIFailure.credentials }
    public func remove(service: String, account: String) throws { throw AIFailure.credentials }
}
''' + s[b:]; p.write_text(s); changes.append(str(p.relative_to(snapshot)))
p = snapshot / 'apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryWorkspace.swift'
s = p.read_text(); before = '.task { await model.load() }'; assert s.count(before) == 1
s = s.replace(before, '.task { await model.load(); if ProcessInfo.processInfo.environment["PDFNO_A_QA_AUTOSAMPLE"] == "1" { await model.openSample(); compactColumn = .detail } }')
p.write_text(s); changes.append(str(p.relative_to(snapshot)))
extra = snapshot / 'apple/Tests/ProfessionalReaderUITests.swift'
shutil.copy2(ROOT / 'qa/reader-professional/ProfessionalReaderUITests.swift', extra)
# Add only the extra test file to the QA project; production project/Release config remain exact.
p = snapshot / 'apple/PDFno.xcodeproj/project.pbxproj'; s = p.read_text().replace('org.pdfno.', 'org.pdfno.integration.professionala20261007.')
reference, build = 'A7A7A7A7A7A7A7A7A7A7A701', 'A7A7A7A7A7A7A7A7A7A7A702'
s = s.replace('objects = {', f'''objects = {{
{reference} = {{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/ProfessionalReaderUITests.swift; sourceTree = "<group>"; }};
{build} = {{ isa = PBXBuildFile; fileRef = {reference}; }};''',1)
# Match the exact generated Mac UI sources phase and main group, not arbitrary phases.
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
source_phase = ident('PDFnoMacUITestssources')
idx = s.index(source_phase + ' = '); start = s.index('files = (',idx)+len('files = ('); s=s[:start]+build+','+s[start:]
group = ident('mainGroup'); idx = s.index(group + ' = '); start = s.index('children = (',idx)+len('children = ('); s=s[:start]+reference+','+s[start:]
p.write_text(s)
import re
legacy = re.findall(r'^\| `(\w+UITests/test\w+)` \| Passed \|', (ROOT/'docs/MAC-UI-FINAL-ACCEPTANCE-2026-10-06.md').read_text(), re.M)
extra_methods = ['ProfessionalReaderUITests/'+name for name in re.findall(r'func (test\w+)\(',extra.read_text())]
assert len(legacy)==60 and len(set(legacy))==60 and len(extra_methods)==4
receipt = {'source_head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'branch': subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(), 'bundle':'org.pdfno.integration.professionala20261007.PDFnoMac','source':str(snapshot),'preview_uuid':preview,'preview_root':'/tmp/PDFno-UITests-'+preview,'registry':str(registry),'production_inputs':inputs,'qa_only_deviations':changes,'extra_ui_file_sha256':sha(extra),'production_original_four_ui_sha256':{p.name:sha(p) for p in (ROOT/'apple/Tests').glob('*.swift')},'gui_started':False,'new_ui_methods':4,'expected_methods':sorted(legacy+extra_methods),'new_accounts_or_packages':False}
(out/'PREPARATION.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2))
print(json.dumps({'bundle':receipt['bundle'],'source':str(snapshot),'gui_started':False,'extra_ui_methods':4}))
