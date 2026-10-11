#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Configure diagnosis or gate17/remaining56 on the same compiled QA bundle."""
from pathlib import Path
import argparse, hashlib, json, platform, plistlib, subprocess, uuid

parser=argparse.ArgumentParser()
parser.add_argument('--qa', type=Path, required=True)
parser.add_argument('--scope', choices=['diagnostic6','gate17','remaining56'], required=True)
args=parser.parse_args(); q=args.qa.resolve()
record=json.loads((q/'PREPARATION.json').read_text()); products=q/'DerivedData/Build/Products'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
generated=list(products.glob('PDFnoMac_*.xctestrun')); assert len(generated)==1
raw=plistlib.loads(generated[0].read_bytes()); conf=raw['PDFnoMacUITests']
assert not conf.get('OnlyTestIdentifiers') and not conf.get('SkipTestIdentifiers')
compiled={}
for name,path in [('app',products/'Debug/PDFnoMac.app'),('runner',products/'Debug/PDFnoMacUITests-Runner.app'),('tests',products/'Debug/PDFnoMacUITests-Runner.app/Contents/PlugIns/PDFnoMacUITests.xctest')]:
    info=plistlib.loads((path/'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'].startswith(record['bundle_prefix']+'.')
    binary=path/'Contents/MacOS'/info['CFBundleExecutable']
    subprocess.run(['codesign','--verify','--strict',str(path)],check=True,capture_output=True)
    architectures=subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip().split()
    assert platform.machine() in architectures
    compiled[name]={'path':str(path),'bundle':info['CFBundleIdentifier'],'binary_sha256':sha(binary),
                    'architectures':architectures,'signature_verified':True}
    if name=='app':
        ent=subprocess.run(['codesign','-d','--entitlements',':-',str(path)],capture_output=True,check=True)
        assert not (plistlib.loads(ent.stdout) if ent.stdout.strip() else {})
        compiled[name]['debug_dylib_sha256']=sha(path/'Contents/MacOS/PDFnoMac.debug.dylib')
    if name=='tests':
        symbols=subprocess.check_output(['nm','-gj',str(binary)])
        names=subprocess.run(['xcrun','swift-demangle'],input=symbols,stdout=subprocess.PIPE,check=True).stdout.decode()
        assert all(cls+'.'+method+'(' in names for cls,method in [m.split('/') for m in record['all_compiled_methods']])
assert compiled['app']['bundle']==record['bundle']
for rel,digest in record['production_inputs'].items():
    if rel not in record['qa_only_deviations'] and rel!='apple/PDFno.xcodeproj/project.pbxproj':
        assert sha(q/'source'/rel)==digest,rel
all73=set(record['all_compiled_methods']); gate=set(record['gate17']); remaining=set(record['remaining56'])
assert len(all73)==73 and len(gate)==17 and len(remaining)==56 and not gate&remaining and gate|remaining==all73
if args.scope == 'diagnostic6':
    names = {
        'testANarrowEPUBPanelsKeepCanonicalSourceAndDraft',
        'testShellNarrowDarkEPUBCanonicalSelectionDraftAndLibrary',
        'testNarrowOverflowBooknoAndOtherFormatPanels',
        'testNarrowIndependentSettingsDefaultOffAndRetainedDisabledConversation',
        'testWideConnectionFiveTasksDialogueStopRetryFollowupAndExplicitNotes',
        'testSavedAIQuoteAndResultSearchExactSourceAndDraftExclusion'
    }
    methods=[m for m in record['gate17'] if m.split('/')[1] in names]
    assert len(methods)==6 and set(methods).issubset(record['gate17'])
else:
    methods=record['gate17'] if args.scope=='gate17' else record['remaining56']
token=str(uuid.uuid4()).upper()
conf.update(TestHostBundleIdentifier=compiled['runner']['bundle'],UITargetAppPath=compiled['app']['path'],
            TestHostPath=compiled['runner']['path'],UITargetAppBundleIdentifier=record['bundle'],
            OnlyTestIdentifiers=methods,SkipTestIdentifiers=[],TestTimeoutsEnabled=True,
            DefaultTestExecutionTimeAllowance=180,MaximumTestExecutionTimeAllowance=240,
            SystemAttachmentLifetime='keepAlways',UserAttachmentLifetime='keepAlways')
env={'PDFNO_UI_TEST_SESSION':token,'PDFNO_UI_TEST_DEEPSEEK':'offline','PDFNO_A_QA_SCOPE':'current73',
     'PDFNO_ISOLATED_UI_APPLICATION_ID':record['bundle'],'PDFNO_A_QA_EXPECTED_BUNDLE':record['bundle'],
     'PDFNO_A_QA_SHOT_TOKEN':token,'PDFNO_CHROME_ORIGINAL_FILE':record['fixture_long_title_path'],
     'PDFNO_UI_TEST_PANEL_DIAGNOSTICS':'1'}
if args.scope=='diagnostic6': env['PDFNO_UI_TEST_SOURCE_DIAGNOSTICS']='1'
conf.setdefault('EnvironmentVariables',{}).update(env);conf.setdefault('UITargetAppEnvironmentVariables',{}).update(env)
output=products/('QA-'+args.scope+'.xctestrun'); assert not output.exists()
output.write_bytes(plistlib.dumps(raw))
plan={'source_head':record['source_head'],'scope':args.scope,'compiled_products':compiled,
      'all_compiled_methods':record['all_compiled_methods'],'expected_methods':methods,
      'xctestrun':str(output),'xctestrun_sha256':sha(output),'original_plan_sha256':sha(generated[0]),
      'automatic_retries_requested':0,'skips':[],'time_allowances':[180,240],
      'GUI_started':False,'own_screenshot_token':token,'runner_architecture':platform.machine(),
      'allowed_own_documents_roots':[
          str(Path.home()/'Documents'/('PDFno-A-WindowShots-'+token)),
          str(Path.home()/'Library/Containers'/compiled['runner']['bundle']/'Data/Documents'/('PDFno-A-WindowShots-'+token))]}
previous=q/'PLAN-gate17.json'
if args.scope=='remaining56':
    first=json.loads(previous.read_text()); assert first['compiled_products']==compiled
(q/('PLAN-'+args.scope+'.json')).write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'source_head':record['source_head'],'scope':args.scope,'expected_methods':len(methods),'all73_compiled_symbols_verified':True,'GUI_started':False}))
