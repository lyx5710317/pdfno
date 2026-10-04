// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {build} from 'esbuild';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url)),output=path.resolve(root,'../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Ebooks');await mkdir(output,{recursive:true});
const manifest=JSON.parse(await readFile(path.join(root,'EBOOK-SOURCE.json')));
for(const record of manifest.files){const bytes=await readFile(record.localPath ? path.join(root,record.localPath) : path.join(root,'vendor/kookit',record.path));if(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex')!==record.gitBlobSHA1||createHash('sha256').update(bytes).digest('hex')!==record.sha256)throw Error('Upstream ebook source changed');}
const result=await build({absWorkingDir:root,entryPoints:['ebook-adapter.js'],outfile:path.join(output,'engine.js'),bundle:true,format:'iife',platform:'browser',target:['safari16'],minify:false,legalComments:'inline',metafile:true,
 banner:{js:'// Kookit 95f602e MOBI/KF8/FB2 restricted profile; corresponding source engine-build/. See Notices.txt.'},
 plugins:[{name:'ebook-bounds',setup(api){api.onLoad({filter:/vendor\/kookit\/src\/libs\/mobi\.js$/},async args=>{
 let s=await readFile(args.path,'utf8');
 function replace(a,b){if(!s.includes(a))throw Error('MOBI patch mismatch');s=s.replace(a,b);}
 const a=s.indexOf('const getIndexData = async'),b=s.indexOf('const getNCX = async',a);if(a<0||b<0)throw Error('INDX patch mismatch');
 s=s.slice(0,a)+'const getIndexData = boundedIndexData;\n'+s.slice(b);s="import {boundedIndexData,boundedPalmDOC} from '../../../../ebook-index.js';\n"+s;
 const palmStart=s.indexOf('const decompressPalmDOC ='),palmEnd=s.indexOf('const read32Bits =',palmStart);
 if(palmStart<0||palmEnd<0)throw Error('PalmDOC patch mismatch');s=s.slice(0,palmStart)+'const decompressPalmDOC = boundedPalmDOC;\n'+s.slice(palmEnd);
 const huffStart=s.indexOf('const huffcdic ='),huffEnd=s.indexOf('const getIndexData =',huffStart);
 if(huffStart<0||huffEnd<0)throw Error('HUFF patch mismatch');s=s.slice(0,huffStart)+'const huffcdic = () => { throw Error("HUFF/CDIC not supported"); };\n'+s.slice(huffEnd);
 const fontStart=s.indexOf('const getFont ='),fontEnd=s.indexOf('export const isMOBI =',fontStart);
 if(fontStart<0||fontEnd<0)throw Error('Font patch mismatch');s=s.slice(0,fontStart)+'const getFont = () => { throw Error("Font decoding disabled"); };\n'+s.slice(fontEnd);
 replace('new TextDecoder(MOBI_ENCODING[x]);', 'new TextDecoder(MOBI_ENCODING[x], {fatal: true});');
 replace('this.headers = this.#getHeaders(await super.loadRecord(0));','this.headers = this.#getHeaders(await super.loadRecord(0));\n    if (this.headers.palmdoc.encryption || ![1,2].includes(this.headers.palmdoc.compression)) throw Error("DRM/compression rejected");');
 replace('.then(this.#decompress);','.then(this.#decompress).then(data => { if (data.length > 4096) throw Error("Text record budget"); return data; });');
 replace('while (this.#rawHead.length < end) {','if (start < 0 || end < start || end > 4194304) throw Error("KF8 raw range");\n      while (this.#rawHead.length < end) {');
 replace('const index = ++this.#lastLoadedHead;','const index = ++this.#lastLoadedHead;\n        if (index >= this.mobi.headers.palmdoc.numTextRecords) throw Error("KF8 text range");');
 replace('const data = await this.mobi.loadText(index);\n      this.#rawTail','if (index < 0) throw Error("KF8 text range");\n      const data = await this.mobi.loadText(index);\n      this.#rawTail');
 replace('const frags = fragTable.slice(fragStart, fragEnd);','const frags = fragTable.slice(fragStart, fragEnd);\n      if (skel.numFrag < 1 || skel.numFrag > 1000 || frags.length !== skel.numFrag || skel.offset + skel.length > 4194304 || frags.some(f => f.length < 1 || f.length > 4194304 || f.offset > 4194304 || f.insertOffset < skel.offset || f.insertOffset > skel.offset + skel.length)) throw Error("KF8 fragment bounds");');
 replace('const str = rawBytesToString(array);', 'const str = rawBytesToString(array);\n    let sectionCount = 0; for (const match of str.matchAll(mbpPagebreakRegex)) { if (++sectionCount >= 1000) throw Error("MOBI section budget"); }');
 replace('const fdstTable = Array.from(','if (fdst.numEntries < 1 || fdst.numEntries > 1000 || 12 + fdst.numEntries * 8 > fdstBuffer.byteLength) throw Error("FDST budget");\n      const fdstTable = Array.from(');
 s=s.replaceAll('const str = await this.loadText(section);','const str = await this.loadText(section);\n    if (/<!DOCTYPE|<!ENTITY/i.test(str)) throw Error("Book declarations rejected");');
 return {contents:s,loader:'js'};});}}]});
const inputs=Object.keys(result.metafile.inputs).sort();if(inputs.some(x=>/node_modules|epub|pdf\.js|GeneralRender|MobiRender|Fb2Render|mammoth|fflate|rangy/.test(x)))throw Error('Unexpected ebook runtime dependency');
await writeFile(path.join(root,'EBOOK-BUNDLE-INPUTS.json'),JSON.stringify(inputs,null,2)+'\n');
let notices='PDFno ebook profile. Original Kookit 1.0.4: AGPL-3.0-or-later; embedded foliate reference: MIT, John Factotum. PDFno modifications: AGPL-3.0-or-later. Corresponding source: engine-build/. Upstream wrappers retained as references, not executed. No extra/fflate/font/DRM component.\n';
for(const file of ['vendor/kookit/LICENSE','licenses/foliate-MIT.txt']){try{notices+='\n===== '+file+' =====\n'+await readFile(path.join(root,file),'utf8');}catch(e){if(file.includes('foliate')){const fs=await import('node:fs/promises');const name=(await fs.readdir(path.join(root,'licenses'))).find(x=>x.startsWith('foliate'));notices+='\n===== foliate original MIT =====\n'+await readFile(path.join(root,'licenses',name),'utf8');}else throw e;}}
await writeFile(path.join(output,'Notices.txt'),notices);console.log('Built ebooks:',inputs.length,'source inputs; no runtime npm dependency.');
