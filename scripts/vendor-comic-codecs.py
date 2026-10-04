#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
from pathlib import Path
import hashlib,json,re,shutil,tarfile
import argparse
parser=argparse.ArgumentParser(description='Reproduce selected official decoder source, notices and digests; no network/install')
parser.add_argument('--source-root',type=Path,required=True,help='Directory containing the verified release tarballs and extracted trees')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
src=args.source_root
for name,digest in [('libarchive-3.8.9.tar.xz','888c934f9d95648ecb9163dc8e23ab80a476ecb81a8f1154704a227b5b676dde'),('xz-5.8.4.tar.xz','4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b')]:
    assert hashlib.sha256((src/name).read_bytes()).hexdigest()==digest,name
dest=root/'apple/Packages/PDFnoKit/Sources/PDFnoComicCodecs'
la=src/'libarchive-3.8.9'
xz=src/'xz-5.8.4'
lac=['archive_acl','archive_check_magic','archive_entry','archive_entry_copy_stat','archive_entry_sparse','archive_entry_stat','archive_entry_strmode','archive_entry_xattr','archive_options','archive_rb','archive_read','archive_read_open_memory','archive_read_add_passphrase','archive_read_set_options','archive_read_support_filter_none','archive_read_support_format_7zip','archive_read_support_format_rar','archive_read_support_format_rar5','archive_string','archive_string_sprintf','archive_util','archive_version_details','archive_virtual','archive_ppmd7','archive_blake2s_ref','archive_blake2sp_ref','archive_time','archive_random']
xzc=['common/common','common/filter_common','common/filter_decoder','common/vli_size','common/vli_decoder','lz/lz_decoder','lzma/lzma_decoder','lzma/lzma2_decoder','lzma/lzma_encoder_presets']
releases={'libarchive':tarfile.open(src/'libarchive-3.8.9.tar.xz'),'xz':tarfile.open(src/'xz-5.8.4.tar.xz')}
chosen={}
def gather(path,base,prefix):
    relative=path.relative_to(base)
    key=prefix+'/'+str(relative)
    if key in chosen:return
    chosen[key]=path
    text=path.read_text()
    for header in re.findall(r'^\s*#\s*include\s*"([^"\n]+)"',text,re.M):
        options=[path.parent/header,base/header]+[p/header for p in [xz/'src/common',xz/'src/liblzma/api']+list((xz/'src/liblzma').glob('*')) if p.is_dir()]
        target=next((p for p in options if p.is_file() and (base==la/'libarchive' or p.is_relative_to(xz/'src'))),None)
        if target:gather(target,base,prefix)
for name in lac:gather(la/'libarchive'/(name+'.c'),la/'libarchive','libarchive')
for name in xzc:gather(xz/'src/liblzma'/(name+'.c'),xz/'src','xz')
# Angle-bracket public liblzma API headers are included by lzma.h.
for p in (xz/'src/liblzma/api').rglob('*.h'):gather(p,xz/'src','xz')
dest.mkdir(parents=True,exist_ok=True)
inventory=[]
alltext=''
for relative,path in sorted(chosen.items()):
    data=path.read_bytes();text=data.decode('utf-8')
    kind='libarchive' if relative.startswith('libarchive/') else 'xz'
    release_name='libarchive-3.8.9' if kind=='libarchive' else 'xz-5.8.4'
    original_path=str(path.relative_to(la if kind=='libarchive' else xz))
    assert releases[kind].extractfile(release_name+'/'+original_path).read()==data,relative
    output=dest/relative;output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(data)
    if relative.startswith('xz/'):
        assert 'SPDX-License-Identifier: 0BSD' in text[:5000],relative
        license='0BSD'
    elif 'archive_blake2' in relative:license='CC0-1.0 (selected from upstream triple license)'
    elif 'archive_ppmd' in relative:license='Public domain'
    elif relative=='libarchive/archive_entry.c':license='BSD-2-Clause AND BSD-3-Clause (embedded UC Regents section)'
    else:
        assert 'Redistribution and use in source and binary forms' in text[:8000] or 'Copyright' in text[:8000],relative
        license='BSD-2-Clause (file header controls)'
    inventory.append({'path':relative,'upstreamPath':str(path.relative_to(la if relative.startswith('libarchive/') else xz)), 'upstreamSHA256':hashlib.sha256(data).hexdigest(),'license':license})
    alltext+=text+'\n'
for version,base,names in [('libarchive',la,['COPYING']),('xz',xz,['COPYING','COPYING.0BSD'])]:
    for name in names:
        output=dest/'Licenses'/version/name;output.parent.mkdir(parents=True,exist_ok=True)
        release_name='libarchive-3.8.9' if version=='libarchive' else 'xz-5.8.4'
        data=releases[version].extractfile(release_name+'/'+name).read()
        assert data==(base/name).read_bytes()
        output.write_bytes(data)
# Fixed source-level guard changes remain separately inventoried, with original digests retained.
p=dest/'libarchive/archive_read_support_format_7zip.c';text=p.read_text()
text=text.replace('#define UMAX_ENTRY\tARCHIVE_LITERAL_LL(100000000)','#define UMAX_ENTRY\tARCHIVE_LITERAL_LL(2000) /* PDFno bounded profile */')
anchor='\t\t\tif (parse_7zip_size(a, &(f[i].numUnpackStreams)) < 0)\n\t\t\t\treturn (-1);'
assert text.count(anchor)==1
text=text.replace(anchor,anchor+'\n\t\t\tif (f[i].numUnpackStreams > 1) /* PDFno: refuse solid folders. */\n\t\t\t\treturn (-1);')
anchor='\tzip->entries = calloc(zip->numFiles, sizeof(*zip->entries));'
assert text.count(anchor)==1
text=text.replace(anchor,'\tif (zip->numFiles > UMAX_ENTRY) return (-1); /* PDFno admission count */\n'+anchor)
anchor='\tconst char *cname = (header)?"archive header":"file content";'
assert text.count(anchor)==1
text=text.replace(anchor,anchor+'\n\t/* PDFno: one COPY/LZMA/LZMA2 coder, no transform chains or encryption. */\n\tif (folder->numCoders != 1 || folder->numInStreams != 1 || folder->numOutStreams != 1 ||\n\t    (folder->coders[0].codec != _7Z_COPY && folder->coders[0].codec != _7Z_LZMA && folder->coders[0].codec != _7Z_LZMA2))\n\t\treturn (ARCHIVE_FATAL);')
p.write_text(text)
text=text.replace('\t\tcase kAnti:\n','\t\tcase kAnti:\n\t\t\treturn (-1); /* PDFno: anti-files are outside the profile. */\n')
p.write_text(text)
# Validate every folder, including any folder not selected as an image.
text=text.replace('if (f->numCoders > 4)','if (f->numCoders != 1) /* PDFno: single codec only. */')
text=text.replace('if (*p & 0x80)','if (*p & 0xc0) /* PDFno: reject reserved coder flags. */')
anchor='\t\tif (simple) {'
assert text.count(anchor)==1
text=text.replace(anchor,'\t\tif (!simple || (f->coders[i].codec != _7Z_COPY && f->coders[i].codec != _7Z_LZMA && f->coders[i].codec != _7Z_LZMA2)) return (-1); /* PDFno profile */\n'+anchor)
anchor='\t// These attributes are supported by the windows implementation of archive_write_disk.'
assert text.count(anchor)==1
text=text.replace(anchor,'\t/* PDFno: bound and classify before link/body expansion; require payload CRC. */\n\tif ((zip_entry->mode & AE_IFMT) != AE_IFREG && (zip_entry->mode & AE_IFMT) != AE_IFDIR) return (ARCHIVE_FATAL);\n\tif (zip->entry_bytes_remaining > 16 * 1024 * 1024 || (zip->entry_bytes_remaining > 0 && !(zip_entry->flg & CRC32_IS_SET))) return (ARCHIVE_FATAL);\n'+anchor)
p.write_text(text)
# Namespace all decoder-owned identifiers so linking cannot interpose system libraries.
symbols=set(re.findall(r'\b(?:(?:__)?archive_|lzma_|blake2(?:s|sp)?_)[A-Za-z0-9_]+',alltext))
macros=set(re.findall(r'^\s*#\s*define\s+(\w+)',alltext,re.M))
symbols=sorted(symbols-macros)
(dest/'private/PDFnoCodecNames.h').write_text('// Generated PDFno decoder namespace. SPDX-License-Identifier: AGPL-3.0-or-later\n'+''.join('#define '+s+' pdfno_vendor_'+s+'\n' for s in symbols))
for record in inventory:record['vendoredSHA256']=hashlib.sha256((dest/record['path']).read_bytes()).hexdigest()
(dest/'SOURCE.json').write_text(json.dumps({'profile':'Apple read-only 7z/RAR; no CLI, disk extraction, external filter or other archive modules','sources':[{'version':'libarchive-3.8.9','url':'https://github.com/libarchive/libarchive/releases/download/v3.8.9/libarchive-3.8.9.tar.xz','sha256':'888c934f9d95648ecb9163dc8e23ab80a476ecb81a8f1154704a227b5b676dde'},{'version':'xz-5.8.4','url':'https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.xz','sha256':'4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b'}],'files':inventory,'licenses':[{'path':str(q.relative_to(dest)),'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'source':('https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt' if q.name=='CC0-1.0.txt' else 'Verified fixed release tarball; see sources')} for q in sorted((dest/'Licenses').rglob('*')) if q.is_file()]},ensure_ascii=False,indent=2)+'\n')
print('Vendored',len(inventory),'source/header files')

# Bundle the complete selected per-file notices and license texts for source and binary distribution.
notices=['PDFno original wrapper/configuration/guards: AGPL-3.0-or-later.\nSelected upstream libarchive 3.8.9 + XZ 5.8.4 decoder sources.\nBSD file notices retained below; PPMd public domain; BLAKE2 selects CC0-1.0; liblzma 0BSD.\nNo UnRAR, full 7zz/WASM, CLI, external filter program, other codec library, or upstream test binary is bundled.\nSOURCE.json binds every selected file to its original and vendored hash.\n']
for record in inventory:
    content=(dest/record['path']).read_text()
    preface=content[:content.index('*/')+2] if content.startswith('/*') else '\n'.join(content.splitlines()[:15])
    for comment in re.findall(r'/\*.*?\*/',content,re.S):
        if comment != preface and re.search(r'copyright|redistribution|public domain|license',comment,re.I):preface+='\n'+comment
    notices.append('\nFILE: '+record['path']+'\nSELECTED LICENSE: '+record['license']+'\n'+preface+'\n')
for license_path in sorted((dest/'Licenses').rglob('*')):
    if license_path.is_file():notices.append('\nLICENSE FILE: '+str(license_path.relative_to(dest))+'\n'+license_path.read_text()+'\n')
resource=root/'apple/Packages/PDFnoKit/Sources/PDFnoServices/Resources/ComicCodecs'
resource.mkdir(parents=True,exist_ok=True)
(resource/'NOTICES.txt').write_text('\n'.join(notices))
shutil.copyfile(dest/'SOURCE.json',resource/'SOURCE.json')
