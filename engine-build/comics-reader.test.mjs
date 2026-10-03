// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const script=await readFile(new URL('../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics/engine.js',import.meta.url),'utf8');
function host({imageFails=false}={}) {
  let serial=0, ready=0, highWater=0;
  const live=new Map(), revoked=[], element={dataset:{},children:[],replaceChildren(){this.children=[];},appendChild(frame){this.children.push(frame);queueMicrotask(()=>frame.onload());}};
  const document={getElementById:id=>{assert.equal(id,'pages');return element;},createElement:tag=>{
    assert.equal(tag,'iframe');return {setAttribute(k,v){assert.equal(k,'sandbox');assert.equal(v,'allow-same-origin');},
      contentDocument:{documentElement:{style:{}},body:{style:{}},querySelector:()=>({naturalWidth:imageFails?0:12})}};
  }};
  const window={webkit:{messageHandlers:{comic:{postMessage(value){assert.equal(value,'ready');ready++;}}}}};
  const context=vm.createContext({window,document,Blob,Uint8Array,atob,setTimeout,clearTimeout,URL:{
    createObjectURL(blob){const url='blob:test/'+serial++;live.set(url,blob);highWater=Math.max(highWater,live.size);return url;},
    revokeObjectURL(url){assert(live.has(url));live.delete(url);revoked.push(url);}
  }});
  vm.runInContext(script,context);
  const base={v:1,command:'render',requestID:'first',session:'session-a',bookID:'book-a',editionID:'edition-a',fileSHA256:'a'.repeat(64),names:['page-0.png','page-1.png','page-2.png']};
  return {reader:window.PDFnoComic,base,element,live,revoked,get highWater(){return highWater;},get ready(){return ready;}};
}
const page=index=>({index,data:Buffer.from([137,80,78,71]).toString('base64')});
test('fixed Kookit model honors native logical order and two-page visual order',async()=>{
  const h=host();assert.equal(h.ready,1);
  let state=JSON.parse(await h.reader.command({...h.base,pages:[page(0)]}));
  assert.deepEqual(state.indices,[0]);assert.equal(h.element.dataset.count,'1');assert.equal(h.live.size,2);
  state=JSON.parse(await h.reader.command({...h.base,requestID:'rtl',pages:[page(2),page(1)]}));
  assert.deepEqual(state.indices,[2,1]);assert.equal(state.requestID,'rtl');assert.equal(h.element.children.length,2);
  assert.equal(h.element.dataset.count,'2');assert.equal(h.revoked.length,2);assert.equal(h.live.size,4);
  assert.equal(h.element.children[0].contentDocument.body.style.cssText,'margin:0;width:100%;height:100%;background:#202124');
  await h.reader.command({...h.base,requestID:'last',pages:[page(2)]});
  assert.equal(h.revoked.length,6);assert.equal(h.live.size,2);assert.equal(h.highWater,4);
  h.reader.close();assert.equal(h.live.size,0);assert.equal(h.element.children.length,0);
});
test('stale identities, unknown commands, out-of-range pages and duplicate pages fail closed',async()=>{
  const h=host();await h.reader.command({...h.base,pages:[page(0)]});
  for(const bad of [{session:'old'},{bookID:'other'},{editionID:'other'},{fileSHA256:'b'.repeat(64)},{command:'fetch'},{v:2},
      {pages:[page(3)]},{pages:[page(-1)]},{pages:[page(1),page(1)]},{pages:[]}]) {
    await assert.rejects(h.reader.command({...h.base,pages:[page(1)],...bad}));
    assert.equal(h.live.size,2);
  }
  h.reader.close();assert.equal(h.live.size,0);
});
test('failed images release every Kookit blob and never report successful progress',async()=>{
  const h=host({imageFails:true});await assert.rejects(h.reader.command({...h.base,pages:[page(0)]}),/Page failed/);
  assert.equal(h.live.size,0);assert.equal(h.element.children.length,0);
});
test('concurrent render is rejected while current render completes',async()=>{
  const h=host(), first=h.reader.command({...h.base,pages:[page(0)]});
  await assert.rejects(h.reader.command({...h.base,requestID:'racing',pages:[page(1)]}),/Invalid comic request/);
  assert.deepEqual(JSON.parse(await first).indices,[0]);h.reader.close();assert.equal(h.live.size,0);
});
