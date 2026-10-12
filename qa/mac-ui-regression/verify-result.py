#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Keep official per-method evidence; never turn partial/skipped runs green."""
from pathlib import Path
import argparse, hashlib, json, plistlib, re, shutil, subprocess, sys
from nonbyok_scope import load_scope, MANIFEST, SCOPES

p=argparse.ArgumentParser()
p.add_argument('--qa',type=Path,required=True)
p.add_argument('--scope',choices=['shared8','diagnostic6','gate17','remaining56']+SCOPES,required=True)
p.add_argument('--result',type=Path,required=True)
p.add_argument('--log',type=Path,required=True)
p.add_argument('--exit-code',type=int,required=True)
args=p.parse_args(); q=args.qa.resolve()
plan=json.loads((q/('PLAN-'+args.scope+'.json')).read_text())
if plan.get('execution_scope')=='user-approved-nonbyok':
    assert args.scope in SCOPES, 'Non-BYOK evidence cannot be reclassified as legacy full acceptance'
if args.scope in SCOPES:
    approved=load_scope()
    assert plan['scope']==args.scope
    assert plan['source_head']==subprocess.check_output(['git','rev-parse','HEAD'],cwd=MANIFEST.parents[2],text=True).strip()
    assert hashlib.sha256(Path(plan['xctestrun']).read_bytes()).hexdigest()==plan['xctestrun_sha256']
    assert plan['execution_scope']=='user-approved-nonbyok' and plan['scope_manifest_sha256']==hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
    assert plan['authorization']==approved['authorization'] and plan['exclusions_are_accepted'] is False
    assert plan['accepted_scope_methods']==approved['gui']['retained']
    assert plan['excluded_not_accepted']==approved['gui']['excluded']
    assert plan['expected_methods']==approved['gui'][args.scope]
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
record={'diagnostic_only':args.scope in ['diagnostic6','shared8','representative6'],'source_head':plan['source_head'],'scope':args.scope,'expected_methods':expected,
        'actual_methods':actual,'all_expected_distinct_methods_executed':set(actual)==set(expected),
        'passed':summary['passedTests'],'failed':summary['failedTests'],'skipped':summary['skippedTests'],
        'expected_failures':summary['expectedFailures'],'xcodebuild_exit_code':args.exit_code,'accepted':passed,
        'own_screenshot_root':str(own_root) if own_root else None,'own_window_screenshots':shots,
        'compiled_products':plan['compiled_products'],'automatic_retries':0}
bundle_files={str(path.relative_to(args.result)):sha(path) for path in sorted(args.result.rglob('*')) if path.is_file()}
assert bundle_files
record.update(result_bundle_files_sha256=bundle_files,
              result_bundle_manifest_sha256=hashlib.sha256(json.dumps(bundle_files,sort_keys=True).encode()).hexdigest(),
              official_summary_sha256=sha(evidence/(args.scope+'-official-summary.json')),
              official_tests_sha256=sha(evidence/(args.scope+'-official-tests.json')),
              log_sha256=sha(args.log))
if args.scope in SCOPES:
    for product in plan['compiled_products'].values():
        info=plistlib.loads((Path(product['path'])/'Contents/Info.plist').read_bytes())
        binary=Path(product['path'])/'Contents/MacOS'/info['CFBundleExecutable']
        assert sha(binary)==product['binary_sha256'], 'Compiled product changed during GUI execution'
        if 'debug_dylib_sha256' in product:
            assert sha(Path(product['path'])/'Contents/MacOS/PDFnoMac.debug.dylib')==product['debug_dylib_sha256']
    record.update(execution_scope=plan['execution_scope'], authorization=plan['authorization'],
                  scope_manifest_sha256=plan['scope_manifest_sha256'],
                  excluded_not_accepted=plan['excluded_not_accepted'], exclusions_are_accepted=False)
if args.scope=='completion49':
    record.update(completion_authorization=approved['completion_authorization'],
                  acceptance_of_all55=False, prior_results_reused_by_source_identity_only=True)

def require_previous(scope, count):
    previous=json.loads((evidence/(scope+'-verification.json')).read_text())
    previous_plan=json.loads((q/('PLAN-'+scope+'.json')).read_text())
    assert previous['accepted'] and previous['scope']==scope
    assert previous_plan['scope']==scope
    assert previous['execution_scope']==previous_plan['execution_scope']==plan['execution_scope']=='user-approved-nonbyok'
    assert previous['source_head']==previous_plan['source_head']==plan['source_head']
    assert previous['compiled_products']==previous_plan['compiled_products']==plan['compiled_products']
    assert previous['scope_manifest_sha256']==previous_plan['scope_manifest_sha256']==plan['scope_manifest_sha256']
    assert previous['authorization']==previous_plan['authorization']==plan['authorization']==approved['authorization']
    assert previous['exclusions_are_accepted'] is previous_plan['exclusions_are_accepted'] is False
    assert previous['excluded_not_accepted']==previous_plan['excluded_not_accepted']==approved['gui']['excluded']
    assert len(previous['actual_methods'])==len(set(previous['actual_methods']))==count
    assert set(previous['actual_methods'])==set(previous['expected_methods'])==set(previous_plan['expected_methods'])==set(approved['gui'][scope])
    return previous

if args.scope=='nonbyok-gate17':
    require_previous('representative6',6)
    record['representative6_accepted']=True
if args.scope=='remaining38':
    gate=require_previous('nonbyok-gate17',17)
    assert gate['representative6_accepted'] is True
    assert not set(actual)&set(gate['actual_methods'])
    assert set(actual)|set(gate['actual_methods'])==set(plan['accepted_scope_methods'])
    assert not (set(actual)|set(gate['actual_methods'])) & {x['method'] for x in plan['excluded_not_accepted']}
    record['accepted_distinct_total']=55 if passed else None
    record['accepted_original_methods']=50 if passed else None
    record['accepted_additional_methods']=5 if passed else None
    record['original73_all_accepted']=False
if args.scope=='gate17':
    representative=json.loads((evidence/'shared8-verification.json').read_text())
    representative_plan=json.loads((q/'PLAN-shared8.json').read_text())
    assert representative['accepted'] and representative['scope']=='shared8'
    assert representative['source_head']==representative_plan['source_head']==plan['source_head']
    assert representative['compiled_products']==representative_plan['compiled_products']==plan['compiled_products']
    assert len(representative['actual_methods'])==len(set(representative['actual_methods']))==8
    assert set(representative['actual_methods'])==set(representative['expected_methods'])==set(representative_plan['expected_methods'])
    record['representative8_accepted']=True
if args.scope=='remaining56':
    gate=json.loads((evidence/'gate17-verification.json').read_text())
    gate_plan=json.loads((q/'PLAN-gate17.json').read_text())
    assert gate['accepted'] and gate['scope']=='gate17' and gate['representative8_accepted'] is True
    assert gate['source_head']==gate_plan['source_head']==plan['source_head']
    assert gate['compiled_products']==gate_plan['compiled_products']==plan['compiled_products']
    assert len(gate['actual_methods'])==len(set(gate['actual_methods']))==17
    assert set(gate['actual_methods'])==set(gate['expected_methods'])==set(gate_plan['expected_methods'])
    assert not set(actual)&set(gate['actual_methods'])
    assert set(actual)|set(gate['actual_methods'])==set(plan['all_compiled_methods'])
    record['accepted_distinct_total']=73 if passed else None
(evidence/(args.scope+'-verification.json')).write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k in ['source_head','scope','passed','failed','skipped','accepted','accepted_distinct_total']}))
sys.exit(0 if passed else 1)
