#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
from pathlib import Path
import argparse,json,subprocess,sys
root=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--output',type=Path,required=True);args=a.parse_args();out=args.output.resolve()
subprocess.run([sys.executable,str(root/'qa/reader-professional/prepare.py'),'--output',str(out)],check=True)
snapshot=out/'source';receipt=json.loads((out/'PREPARATION.json').read_text())
production=(root/'apple/Apps/Mac/PDFnoMacApp.swift').read_text();guarded=(snapshot/'apple/Apps/Mac/PDFnoMacApp.swift').read_text()
init=guarded[guarded.index('    init() {'):guarded.index('    var body: some Scene {')]
s=production.replace('import PDFnoUI','import PDFnoUI\nimport Darwin\nimport CryptoKit').replace('    var body: some Scene {',init+'    var body: some Scene {',1)
anchor='LibraryWorkspace(settingsRequest: settingsRequest).frame(minWidth: 720, minHeight: 468)';assert s.count(anchor)==1
s=s.replace(anchor,anchor+'.preferredColorScheme(appearance).background(QAWindowSize(width: width, height: height))')
x=s.index('            .defaultSize(');y=s.index('            .defaultPosition',x);s=s[:x]+'            .defaultSize(width: width, height: height)\n'+s[y:]
s+=guarded[guarded.index('// SwiftUI defaultSize'):];(snapshot/'apple/Apps/Mac/PDFnoMacApp.swift').write_text(s)
# The production tabbed workspace starts with its library. The guarded preview seeds only the original fixture.
p=snapshot/'apple/Packages/PDFnoKit/Sources/PDFnoUI/MacTabbedWorkspace.swift';s=p.read_text()
anchor='.task { await model.load(); if model.displayedDocumentID != nil { documents.adopt(model) } }';assert s.count(anchor)==1
s=s.replace(anchor,'.task { await model.load(); if ProcessInfo.processInfo.environment["PDFNO_A_QA_AUTOSAMPLE"] == "1" { await model.openSample() }; if model.displayedDocumentID != nil { documents.adopt(model) } }');p.write_text(s)
receipt['qa_only_deviations'].append(str(p.relative_to(snapshot)))
receipt['source_worktree_dirty']=bool(subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).strip())
receipt['scope']='Tabbed document workspace; snapshot source hashes authoritative; live HTTP and Keychain disabled; exact original builtin fixtures; no original assertions altered.'
(out/'PREPARATION.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'source_head':receipt['source_head'],'source_worktree_dirty':receipt['source_worktree_dirty'],'bundle':receipt['bundle'],'root':receipt['preview_root']}))
