// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import JSZip from 'jszip';
import {makeLoader,safePath} from './loader.js';
test('raw path whitelist precedes JSZip normalisation',async()=>{
  for (const path of ['../x','/x','C:x','a\\x','a/%2e%2e/x','a//x']) assert.equal(safePath(path),false);
  const zip=new JSZip(); zip.file('../image.jpg','abc');
  const bytes=await zip.generateAsync({type:'uint8array'});
  await assert.rejects(makeLoader(bytes,['../image.jpg']),/path mismatch/);
});
test('actual decompression output is bounded even when ZIP sizes lie',async()=>{
  const zip=new JSZip(); zip.file('image.jpg',new Uint8Array(4*1024*1024+1));
  const bytes=await zip.generateAsync({type:'uint8array',compression:'DEFLATE'});
  const view=new DataView(bytes.buffer);
  // Deliberately lie in both header declarations. The stream must still cap actual output.
  view.setUint32(22,1,true);
  for(let p=0;p<bytes.length-46;p++) if(view.getUint32(p,true)===0x02014b50) { view.setUint32(p+24,1,true); break; }
  const loader=await makeLoader(bytes,['image.jpg']);
  await assert.rejects(loader.loadBlob('image.jpg'),/Decompression budget/);
});
