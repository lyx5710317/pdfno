// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {convertDOCX,sanitiseDOCX} from './docx-adapter.js';
const fixtures=new URL('../apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/',import.meta.url);
const sample=async name=>{const b=await readFile(new URL(name+'.docx',fixtures));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength);};
const canonical=result=>result.document.blocks.map(b=>b.runs.map(r=>r.text).join('')).join('\n');
test('actual Kookit/Mammoth chain supplies headings, Unicode, ordered lists, tables and direct emphasis',async()=>{
  const r=await convertDOCX(await sample('mammoth-sample'));
  assert.equal(r.engine,'kookit-mammoth-1.13.0');
  assert.deepEqual(r.document.blocks.filter(x=>x.headingLevel).map(x=>x.headingLevel),[1,2]);
  assert.match(r.html,/<ol[ >]/);assert.match(r.html,/<strong>window<\/strong>/);assert.match(r.html,/<table/);
  assert.ok(canonical(r).includes('日本語🌸 café & <script>literal</script>'));
  assert.ok(r.document.blocks.find(x=>x.listLevel!==undefined));assert.equal(r.document.blocks.filter(x=>x.table===0).length,2);
  let start=0;for(const [id,b] of r.document.blocks.entries()){assert.equal(b.id,id);assert.equal(b.start,start);start+=b.runs.map(x=>x.text).join('').length+1;}
  // A deterministic actual-engine DTO is used by Swift source-contract tests, not a hand-authored mirror.
  assert.deepEqual(r.document,JSON.parse(await readFile(new URL('mammoth-extraction.json',fixtures))));
});
test('ordinary external hyperlinks preserve label text with no URL/event/resource attributes',async()=>{
  const r=await convertDOCX(await sample('hyperlink-sample'));
  assert.ok(canonical(r).includes('Ordinary hyperlink label'));
  assert.doesNotMatch(r.html,/href=|src=|example\.invalid|javascript:|onclick=/i);
  assert.ok(r.document.warnings.some(x=>x.includes('超链接')));
});
test('strict sanitizer strips active content, arbitrary attributes and image resources',()=>{
  const r=sanitiseDOCX('<p onclick="run()" style="background:url(https://example.invalid)">safe<a href="javascript:run()">label</a><img src="file:///private" alt="inert image"/><script>run()</script><svg><text>active</text></svg></p>');
  assert.equal(canonical(r),'safelabel[inert image]');
  assert.doesNotMatch(r.html,/onclick|style=|href=|src=|<script|<svg|file:|https:/i);
  assert.throws(()=>sanitiseDOCX('<!DOCTYPE p><p>DTD</p>'));
  assert.throws(()=>sanitiseDOCX('<p>'.repeat(70)+'deep'+'</p>'.repeat(70)));
  assert.throws(()=>sanitiseDOCX('<p>'+'A'.repeat(1000001)+'</p>'));
});
test('browser bundle invokes the same Mammoth chain without any fetch, filesystem or Rangy',async()=>{
  const input=await readFile(new URL('hyperlink-sample.docx',fixtures));
  const messages={v:1,session:'isolated-test',bookID:'book',editionID:'edition',fileSHA256:'a'.repeat(64),data:input.toString('base64')};
  const context=vm.createContext({window:{},TextDecoder,TextEncoder,atob,btoa,setTimeout,clearTimeout,console},{codeGeneration:{strings:false,wasm:false}});
  const script=await readFile(new URL('../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/DOCX/engine.js',import.meta.url),'utf8');
  vm.runInContext('globalThis.self=globalThis',context);
  vm.runInContext(script,context,{timeout:5000});context.message=messages;
  const browser=JSON.parse(await vm.runInContext('window.PDFnoDOCXEngine.convert(message)',context));
  const node=await convertDOCX(input.buffer.slice(input.byteOffset,input.byteOffset+input.byteLength));
  assert.equal(canonical(browser),canonical(node));assert.equal(browser.session,'isolated-test');
  assert.equal(browser.extractionVersion,'docx-mammoth-utf16-1');
  assert.doesNotMatch(browser.html,/href=|src=|example\.invalid/i);
  await assert.rejects(vm.runInContext('window.PDFnoDOCXEngine.convert(message)',context));
  const inputs=JSON.parse(await readFile(new URL('DOCX-BUNDLE-INPUTS.json',import.meta.url)));
  assert.ok(inputs.some(x=>x.includes('mammoth/browser/docx/files.js')));
  assert.ok(!inputs.some(x=>/rangy|\/fs\.js|7z|pdfUtil|zh-convert/.test(x)));
});
