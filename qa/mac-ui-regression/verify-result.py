#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Keep official per-method evidence; never turn partial/skipped runs green."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, sys

p=argparse.ArgumentParser()
p.add_argument('--qa',type=Path,required=True)
p.add_argument('--scope',choices=['diagnostic6','gate17','remaining56'],required=True)
p.add_argument('--result',type=Path,required=True)
p.add_argument('--log',type=Path,required=True)
p.add_argument('--exit-code',type=int,required=True)
args=p.parse_args(); q=args.qa.resolve()
plan=json.loads((q/('PLAN-'+args.scope+'.json')).read_text())
evidence=q/'Evidence'; evidence.mkdir(exist_ok=True)
data={}
for name in ['summary','tests']:
    result=subprocess.run(['xcrun','xcresulttool','get','test-results',name,'--path',str(args.result.resolve())],capture_output=True,text=True)
    if result.returncode:
        print('Official result extraction failed:',name,result.returncode); sys.exit(1)
    data[name]=json.loads(result.stdout)
    (evidence/(args.scope+'-official-'+name+'.json')).write_text(result.stdout)
cases=[]
def visit(node):
    if isinstance(node,list):
        for n in node: visit(n)
    elif isinstance(node,dict):
        if node.get('nodeType')=='Test Case': cases.append(node)
        for n in node.get('children',[]): visit(n)
visit(data['tests']['testNodes'])
actual=[n['nodeIdentifier'].removesuffix('()') for n in cases]
expected=plan['expected_methods']
summary=data['summary']
passed=(args.exit_code==0 and len(actual)==len(set(actual))==len(expected) and set(actual)==set(expected)
        and all(n['result']=='Passed' for n in cases)
        and summary['passedTests']==len(expected) and summary['totalTestCount']==len(expected)
        and summary['failedTests']==summary['skippedTests']==summary['expectedFailures']==0)

# Collect only recorded paths to screenshots of this self-authored QA window.
shots=[]; sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
lines=args.log.read_text(errors='replace').splitlines()
roots=[]
for line in lines:
    marker='PDFNO_QA_OWN_DOCUMENTS_ROOT '
    if marker not in line: continue
    entry=json.loads(line.split(marker,1)[1])
    assert entry['bundle']==plan['compiled_products']['runner']['bundle']
    assert entry['root'] in plan['allowed_own_documents_roots']
    roots.append(Path(entry['root']))
assert not roots or len(set(roots))==1
own_root=roots[0] if roots else None
shot_root=evidence/(args.scope+'-OwnWindowShots'); shot_root.mkdir(exist_ok=True)
for line in lines:
    marker='PDFNO_A_WINDOW_SHOT '
    if marker not in line: continue
    entry=json.loads(line.split(marker,1)[1])
    path=Path(entry['path'])
    assert own_root is not None and path.is_absolute() and path.parent==own_root
    assert path==path.resolve(strict=True)
    assert not any(part.is_symlink() for part in [path,*path.parents])
    assert path.name==entry['name']+'.png' and path.is_file() and not path.is_symlink()
    destination=shot_root/path.name
    if not destination.exists(): shutil.copy2(path,destination)
    assert sha(path)==sha(destination)
    shots.append({'name':entry['name'],'original_path':str(path),'retained_path':str(destination),'sha256':sha(destination)})
record={'diagnostic_only':args.scope=='diagnostic6','source_head':plan['source_head'],'scope':args.scope,'expected_methods':expected,
        'actual_methods':actual,'all_expected_distinct_methods_executed':set(actual)==set(expected),
        'passed':summary['passedTests'],'failed':summary['failedTests'],'skipped':summary['skippedTests'],
        'expected_failures':summary['expectedFailures'],'xcodebuild_exit_code':args.exit_code,'accepted':passed,
        'own_screenshot_root':str(own_root) if own_root else None,'own_window_screenshots':shots,
        'compiled_products':plan['compiled_products'],'automatic_retries':0}
if args.scope=='remaining56':
    gate=json.loads((evidence/'gate17-verification.json').read_text())
    assert gate['accepted'] and gate['compiled_products']==plan['compiled_products']
    assert not set(actual)&set(gate['actual_methods'])
    assert set(actual)|set(gate['actual_methods'])==set(plan['all_compiled_methods'])
    record['accepted_distinct_total']=73 if passed else None
(evidence/(args.scope+'-verification.json')).write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k in ['source_head','scope','passed','failed','skipped','accepted','accepted_distinct_total']}))
sys.exit(0 if passed else 1)
