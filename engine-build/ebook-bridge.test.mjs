// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import {JSDOM} from 'jsdom';import {boundedPalmDOC} from './ebook-index.js';
const native=await readFile(new URL('../apple/Packages/PDFnoKit/Sources/PDFnoReaders/EbookHTML.swift',import.meta.url),'utf8');
const bridge=native.slice(native.indexOf("        'use strict';"),native.indexOf('        </script></body>')).replaceAll('\\(nonce)','original-session').replaceAll('\\\\','\\');
function host(html){const dom=new JSDOM('<!doctype html><body><main>'+html+'</main></body>',{runScripts:'outside-only'}),w=dom.window;w.messages=[];w.webkit={messageHandlers:{ebook:{postMessage:m=>w.messages.push(m)}}};w.eval(bridge);return dom;}
test('native trusted bridge excludes author ruby and preserves Unicode selections/return',()=>{
 const dom=host('<p data-block="0" data-start="0"><ruby>本<rt>ほん</rt></ruby> 😀 é same</p><p data-block="1" data-start="13">same</p>'),w=dom.window,d=w.document;
 assert.equal(w.eval(bridge+'\ncanonical'),'本 😀 é same\nsame');assert.equal(w.messages[0].session,'original-session');
 const p=d.querySelectorAll('p'),text=p[0].childNodes[1],r=d.createRange();r.setStart(text,1);r.setEnd(text,3);w.getSelection().removeAllRanges();w.getSelection().addRange(r);
 const selected=w.pdfnoEbook.captureSelection();assert.deepEqual([selected.start,selected.end,selected.quote],[2,4,'😀']);
 p[0].scrollIntoView=()=>{};assert.equal(w.pdfnoEbook.navigate({start:2,end:4,quote:'😀'}),true);assert.equal(w.pdfnoEbook.navigate({start:2,end:4,quote:'other'}),false);
 d.hasFocus=()=>true; // A real pointer selection in the reader has document focus.
 const ruby=d.querySelector('rt').firstChild;r.setStart(ruby,0);r.setEnd(ruby,1);w.getSelection().removeAllRanges();w.getSelection().addRange(r);assert.equal(w.pdfnoEbook.captureSelection(),null);
 dom.window.close();
});
test('native bridge rejects mismatched install and resolves exact cross-paragraph quote',()=>{
 const dom=host('<p data-block="0" data-start="0">same</p><p data-block="1" data-start="5">same</p>'),w=dom.window,d=w.document;
 const ps=d.querySelectorAll('p'),r=d.createRange();r.setStart(ps[0].firstChild,2);r.setEnd(ps[1].firstChild,2);w.getSelection().addRange(r);
 const selected=w.pdfnoEbook.captureSelection();assert.deepEqual([selected.start,selected.end,selected.quote],[2,7,'me\nsa']);
 assert.throws(()=>w.pdfnoEbook.install('<p data-block="0" data-start="0">changed</p>','expected'));assert.equal(d.querySelector('main').textContent,'');w.close();
});
test('PalmDOC refuses bad backward pairs and stops actual expansion at record budget',()=>{
 assert.throws(()=>boundedPalmDOC(Uint8Array.from([128,0])));assert.throws(()=>boundedPalmDOC(Uint8Array.from([128])));assert.throws(()=>boundedPalmDOC(Uint8Array.from([8,65])));
 assert.throws(()=>boundedPalmDOC(Uint8Array.from(Array(4097).fill(65))));assert.equal(new TextDecoder().decode(boundedPalmDOC(Uint8Array.from([65,128,8]))),'AAAA');
});
