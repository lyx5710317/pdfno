// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';import {JSDOM} from 'jsdom';import {boundedIndexData} from './ebook-index.js';
const fixtureRoot=new URL('../apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Ebooks/',import.meta.url);
const source=await readFile(new URL('../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Ebooks/engine.js',import.meta.url),'utf8');
async function extract(data,format){
 const dom=new JSDOM('<!doctype html><html><body></body></html>',{runScripts:'outside-only',url:'https://example.invalid'}),w=dom.window;
 w.Blob=Blob;w.TextDecoder=TextDecoder;w.TextEncoder=TextEncoder;w.URL.createObjectURL=URL.createObjectURL;w.URL.revokeObjectURL=URL.revokeObjectURL;
 w.eval(source);try{return JSON.parse(await w.PDFnoEbookEngine.extract({v:1,session:'original-session',bookID:'original-book',editionID:'original-edition',fileSHA256:'a'.repeat(64),format,data:data.toString('base64')}));}finally{w.close();}
}
for(const format of ['mobi','azw','azw3','fb2'])test(`actual fixed bundle extracts genuine ${format.toUpperCase()} container`,async()=>{
 const data=await readFile(new URL('study-sample.'+format,fixtureRoot)),result=await extract(data,format);
 assert.equal(result.contentKind,format==='fb2'?'fb2':format==='azw3'?'kf8':'mobi6');assert.equal(result.format,format);assert.equal(result.engine,'kookit-foliate-95f602e');
 const blocks=result.document.blocks,text=blocks.map(b=>b.runs.map(r=>r.text).join('')).join('\n');
 assert.ok(text.includes('😀')&&text.includes('e\u0301')&&text.includes('original'));assert.ok(blocks.filter(b=>b.headingLevel).length>=2);
 let start=0;for(const b of blocks){assert.equal(b.start,start);start+=b.runs.map(r=>r.text).join('').length+1;}
 if(format==='mobi'||format==='azw'){assert.ok(text.includes('本')&&!text.includes('ほん'));assert.equal(blocks.flatMap(b=>b.runs).find(r=>r.ruby)?.ruby,'ほん');}
 if(format==='azw3')assert.ok(text.includes('Pure KF8 skeleton and fragment records'));
});
test('extension, DRM and unsupported compression refuse before body parsing',async()=>{
 const original=await readFile(new URL('study-sample.mobi',fixtureRoot)),r=original.readUInt32BE(78);
 for(const [format,mutate] of [['azw3',()=>{}],['mobi',b=>b.writeUInt16BE(1,r+12)],['mobi',b=>b.writeUInt16BE(17480,r)]]){
  const b=Buffer.from(original);mutate(b);await assert.rejects(extract(b,format));
 }
 await assert.rejects(extract(Buffer.from('ordinary text renamed'),'mobi'));
});
test('FB2 root, entity, encoding and depth admission fails closed',async()=>{
 const text=(await readFile(new URL('study-sample.fb2',fixtureRoot))).toString();
 for(const invalid of [text.replace('<FictionBook','<!DOCTYPE FictionBook [<!ENTITY x SYSTEM "https://example.invalid/unused">]><FictionBook'),text.replaceAll('FictionBook','NotFB2'),text.replace('utf-8','utf-16'),text.replace('</body>','<section>'.repeat(60)+'text'+'</section>'.repeat(60)+'</body>')])await assert.rejects(extract(Buffer.from(invalid),'fb2'));
});
test('bounded INDX refuses malformed integers, zero masks and ranges',async()=>{
 const data=await readFile(new URL('study-sample.azw3',fixtureRoot)),count=data.readUInt16BE(76),offsets=Array.from({length:count},(_,i)=>data.readUInt32BE(78+8*i));offsets.push(data.length);
 const records=offsets.slice(0,-1).map((p,i)=>Buffer.from(data.subarray(p,offsets[i+1])));
 const load=i=>{if(!records[i])throw Error('record range');const b=records[i];return Promise.resolve(b.buffer.slice(b.byteOffset,b.byteOffset+b.length));};
 assert.equal((await boundedIndexData(2,load)).table.length,1);
 records[2][206]=0;await assert.rejects(boundedIndexData(2,load));
});

test('NCX recursion and embedded FB2 binary resources are outside admission',async()=>{
 const mobi=await readFile(new URL('study-sample.mobi',fixtureRoot)),r=mobi.readUInt32BE(78);mobi.writeUInt32BE(1,r+244);await assert.rejects(extract(mobi,'mobi'));
 const fb2=(await readFile(new URL('study-sample.fb2',fixtureRoot))).toString().replace('</FictionBook>','<binary id="original-image" content-type="image/png">AAAA</binary></FictionBook>');await assert.rejects(extract(Buffer.from(fb2),'fb2'));
});
