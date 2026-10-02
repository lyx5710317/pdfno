#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Reproducible Xcode app targets and original, redistributable PDF fixtures.
No dependency download, signing account, private asset, or cloud setup.
"""
from pathlib import Path
import hashlib
import html
import json

ROOT = Path(__file__).resolve().parents[1]
APPLE = ROOT / 'apple'

def sample_pdf():
    def stream(lines):
        ops = ['BT']
        for text, size, y in lines:
            escaped = text.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')
            ops += [f'/F1 {size} Tf', f'1 0 0 1 72 {y} Tm', f'({escaped}) Tj']
        ops += ['ET']
        raw = '\n'.join(ops).encode('ascii')
        return b'<< /Length %d >>\nstream\n' % len(raw) + raw + b'\nendstream'
    objects = [
        b'<< /Type /Catalog /Pages 2 0 R /Outlines 8 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        stream([('PDFno - A moment to read', 24, 708), ('Reading opens a small window onto a wider world.', 14, 660), ('Choose a sentence. Save a thought. Return to its source.', 14, 630), ('This original sample contains no private or third-party book.', 12, 570), ('1 / 2', 12, 60)]),
        stream([('A second page', 24, 708), ('A useful note stays connected to the words that inspired it.', 14, 660), ('Local reading comes first; new capabilities follow evidence.', 14, 630), ('PDFno contributors - original test fixture - AGPL-3.0-or-later', 11, 570), ('2 / 2', 12, 60)]),
        b'<< /Type /Outlines /First 9 0 R /Last 10 0 R /Count 2 >>',
        b'<< /Title (A moment to read) /Parent 8 0 R /Next 10 0 R /Dest [3 0 R /Fit] >>',
        b'<< /Title (A second page) /Parent 8 0 R /Prev 9 0 R /Dest [4 0 R /Fit] >>'
    ]
    result = b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n'
    offsets = [0]
    for number, obj in enumerate(objects, 1):
        offsets.append(len(result))
        result += f'{number} 0 obj\n'.encode() + obj + b'\nendobj\n'
    start = len(result)
    result += f'xref\n0 {len(objects)+1}\n0000000000 65535 f \n'.encode()
    for offset in offsets[1:]:
        result += f'{offset:010d} 00000 n \n'.encode()
    result += f'trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n'.encode()
    return result

objects = {}
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def quote(s): return json.dumps(str(s), ensure_ascii=False)
def add(name, isa, body):
    oid = ident(name)
    objects[oid] = f'isa = {isa}; {body}'
    return oid

def config_list(name, settings):
    ids = []
    for mode in ['Debug', 'Release']:
        settings_for_mode = dict(settings)
        settings_for_mode['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if mode == 'Debug' else '-O'
        settings_for_mode['DEBUG_INFORMATION_FORMAT'] = 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym'
        settings_for_mode['ONLY_ACTIVE_ARCH'] = 'YES' if mode == 'Debug' else 'NO'
        if mode == 'Debug': settings_for_mode['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        body = 'buildSettings = { ' + ' '.join(f'{k} = {quote(v)};' for k,v in sorted(settings_for_mode.items())) + ' }; name = '+quote(mode)+';'
        ids.append(add(name+mode, 'XCBuildConfiguration', body))
    return add(name+'configs', 'XCConfigurationList', 'buildConfigurations = ('+','.join(ids)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

project_settings = {'CLANG_ENABLE_MODULES':'YES', 'SWIFT_VERSION':'6.0', 'MACOSX_DEPLOYMENT_TARGET':'14.0', 'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'ENABLE_TESTABILITY':'YES', 'CLANG_WARN_DOCUMENTATION_COMMENTS':'YES'}
project_configs = config_list('project', project_settings)
package = add('localPackage','XCLocalSwiftPackageReference','relativePath = Packages/PDFnoKit;')
product_refs = []
source_refs = []
targets = []
app_targets = {}

def file_ref(name, path, kind):
    ref = add(name, 'PBXFileReference', f'lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = "<group>";')
    source_refs.append(ref)
    return ref

mac_source = file_ref('MacSource','Apps/Mac/PDFnoMacApp.swift','sourcecode.swift')
mobile_source = file_ref('MobileSource','Apps/Mobile/PDFnoMobileApp.swift','sourcecode.swift')
test_source = file_ref('TestSource','Tests/NativeUITests.swift','sourcecode.swift')

def phase(name, isa, file_ids):
    return add(name, isa, 'buildActionMask = 2147483647; files = ('+','.join(file_ids)+'); runOnlyForDeploymentPostprocessing = 0;')

for name, source, platform in [('PDFnoMac', mac_source, 'mac'), ('PDFnoMobile', mobile_source, 'mobile')]:
    product = add(name+'product', 'PBXFileReference', f'explicitFileType = wrapper.application; includeInIndex = 0; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR;')
    product_refs.append(product)
    source_build = add(name+'sourceBuild','PBXBuildFile',f'fileRef = {source};')
    dependency = add(name+'packageProduct','XCSwiftPackageProductDependency',f'package = {package}; productName = PDFnoUI;')
    package_build = add(name+'packageBuild','PBXBuildFile',f'productRef = {dependency};')
    phases = [phase(name+'sources','PBXSourcesBuildPhase',[source_build]),phase(name+'frameworks','PBXFrameworksBuildPhase',[package_build]),phase(name+'resources','PBXResourcesBuildPhase',[])]
    settings = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'org.pdfno.'+name,'GENERATE_INFOPLIST_FILE':'YES', 'INFOPLIST_KEY_CFBundleDisplayName':'PDFno','MARKETING_VERSION':'0.3.0','CURRENT_PROJECT_VERSION':'1', 'CODE_SIGN_STYLE':'Manual','CODE_SIGN_IDENTITY':'-','DEVELOPMENT_TEAM':'','SWIFT_VERSION':'6.0','ENABLE_PREVIEWS':'YES'}
    if platform == 'mac':
        settings.update({'SDKROOT':'macosx', 'SUPPORTED_PLATFORMS':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','INFOPLIST_KEY_NSPrincipalClass':'NSApplication','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.education'})
    else:
        settings.update({'SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'})
    configs = config_list(name,settings)
    target = add(name+'target','PBXNativeTarget',f'buildConfigurationList = {configs}; buildPhases = ({",".join(phases)}); buildRules = (); dependencies = (); name = {name}; packageProductDependencies = ({dependency}); productName = {name}; productReference = {product}; productType = "com.apple.product-type.application";')
    targets.append(target); app_targets[name] = (target,product,platform)

for name, (app_target, app_product, platform) in app_targets.items():
    test_name = name+'UITests'
    product = add(test_name+'product','PBXFileReference',f'explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {test_name}.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    product_refs.append(product)
    build = add(test_name+'build','PBXBuildFile',f'fileRef = {test_source};')
    phases = [phase(test_name+'sources','PBXSourcesBuildPhase',[build]),phase(test_name+'frameworks','PBXFrameworksBuildPhase',[]),phase(test_name+'resources','PBXResourcesBuildPhase',[])]
    proxy = add(test_name+'proxy','PBXContainerItemProxy',f'containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = {name};')
    dependency = add(test_name+'dependency','PBXTargetDependency',f'target = {app_target}; targetProxy = {proxy};')
    settings = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'org.pdfno.'+test_name,'GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Manual','CODE_SIGN_IDENTITY':'-','DEVELOPMENT_TEAM':'','TEST_TARGET_NAME':name, 'SWIFT_VERSION':'6.0'}
    if platform == 'mac': settings.update({'SDKROOT':'macosx','SUPPORTED_PLATFORMS':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0'})
    else: settings.update({'SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1,2'})
    configs = config_list(test_name,settings)
    test_target = add(test_name+'target','PBXNativeTarget',f'buildConfigurationList = {configs}; buildPhases = ({",".join(phases)}); buildRules = (); dependencies = ({dependency}); name = {test_name}; productName = {test_name}; productReference = {product}; productType = "com.apple.product-type.bundle.ui-testing";')
    targets.append(test_target)

products = add('products','PBXGroup','children = ('+','.join(product_refs)+'); name = Products; sourceTree = "<group>";')
main_group = add('mainGroup','PBXGroup','children = ('+','.join(source_refs+[products])+'); sourceTree = "<group>";')
attrs = ' '.join(f'{target} = {{ CreatedOnToolsVersion = 16.4; }};' for target in targets)
project = add('project','PBXProject',f'attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1640; TargetAttributes = {{ {attrs} }}; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, "zh-Hans"); mainGroup = {main_group}; packageReferences = ({package}); productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(targets)});')
project_dir = APPLE / 'PDFno.xcodeproj'
project_dir.mkdir(parents=True,exist_ok=True)
content = '// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
content += '\n'.join(f' {oid} = {{ {body} }};' for oid,body in sorted(objects.items()))
content += f'\n }}; rootObject = {project};\n}}\n'
(project_dir/'project.pbxproj').write_text(content)
scheme_dir = project_dir/'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True,exist_ok=True)
for name,(app_target,_,_) in app_targets.items():
    def ref(target, product, target_name):
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{target_name}" ReferencedContainer="container:PDFno.xcodeproj"/>'
    app_ref = ref(app_target,name+'.app',name)
    test_ref = ref(ident(name+'UITeststarget'),name+'UITests.xctest',name+'UITests')
    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_dir/(name+'.xcscheme')).write_text(xml)
workspace = APPLE/'PDFno.xcworkspace'
workspace.mkdir(parents=True,exist_ok=True)
(workspace/'contents.xcworkspacedata').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="group:PDFno.xcodeproj"/></Workspace>\n')
fixture = sample_pdf()
for path in [APPLE/'Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.pdf', APPLE/'Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/study-sample.pdf']:
    path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(fixture)
print('Generated app/UITest targets, shared schemes, workspace and original two-page PDF ('+str(len(fixture))+' bytes).')
