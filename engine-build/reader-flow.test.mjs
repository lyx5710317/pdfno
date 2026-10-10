// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const source=(await readFile(new URL('./reader.js',import.meta.url),'utf8')).replace(/^import .*;$/gm,'');
function host(){
 const dom=new JSDOM('<!doctype html><main id="page-area"></main>',{runScripts:'outside-only'}),w=dom.window,d=w.document;
 w.messages=[];w.webkit={messageHandlers:{epub:{postMessage:m=>w.messages.push(JSON.parse(m))}}};
 const html=['<p>first same 😀 <ruby>本<rt>ほん</rt></ruby></p>','<h1>Second</h1><p>later same café</p>'];
 const area=d.getElementById('page-area');Object.defineProperties(area,{clientWidth:{value:600},clientHeight:{value:500}});
 area.scrollTo=(_x,y)=>{area.scrollTop=y};area.scrollBy=(_x,y)=>{area.scrollTop+=y};
 w.EpubRender=class {
  constructor(){this.book={sections:html.map((text,i)=>({id:'chapter'+i+'.xhtml',text}))};this.flattenChapters=[{label:'first',index:0},{label:'second',index:1}];this.readerMode='single';this.textOrientation='horizontal';}
  async renderTo(e){this.element=e;this.frame=d.createElement('iframe');e.appendChild(this.frame);const doc=this.frame.contentDocument;doc.defaultView.CSS={highlights:new Map()};doc.defaultView.Highlight=class {constructor(...r){this.ranges=r}};
   doc.defaultView.Range.prototype.getClientRects=function(){return [this.getBoundingClientRect()]};
   doc.defaultView.Range.prototype.getBoundingClientRect=function(){const i=Number(this.startContainer.parentElement.closest('[data-pdfno-spine]')?.dataset.pdfnoSpine??0);const top=i*900+(this.startContainer.parentElement.closest('p')&&i>0?30:0)+this.startOffset;return {left:10,right:250,top,bottom:top+20,width:240,height:20}};
  }
  getDocument(){return this.frame.contentDocument}getIframe(){return this.frame}isVertical(){return this.textOrientation==='vertical'}
  async goToChapterDocIndex(i){this.getDocument().body.innerHTML=html[i]}
 };
 w.handleOneChapterDoc=async item=>'<html><head><title>Metadata'+html.indexOf(item.text)+'</title></head><body>'+item.text+'</body></html>';w.handleLayout=()=>{};w.progressInfo=()=>({currentPage:1});
 w.eval(source+'\nwindow.flowTest={canonical,selectedAnchor,rangeFor,trackFlowViewport,getDoc:doc};');
 const identity={v:1,session:'session',bookID:'book',editionID:'edition',fileSHA256:'sha'};
 let id=0;const command=async(command,payload={})=>{const version=w.messages.filter(m=>m.documentVersion!==undefined).at(-1)?.documentVersion??0;
  const result=JSON.parse(await w.PDFno.command({...identity,requestID:String(++id),documentVersion:version,command,payload}));w.messages.push(result);return result.payload};
 return {w,area,command,close:()=>w.close()};
}
function positions(h){const roots=h.w.flowTest.getDoc().querySelectorAll('[data-pdfno-spine]');for(let i=0;i<roots.length;i++){Object.defineProperties(roots[i],{offsetTop:{value:i*900},offsetHeight:{value:900}});Object.defineProperties(roots[i].parentElement,{offsetTop:{value:i*900},offsetHeight:{value:900}})}}
test('horizontal EPUB keeps consecutive chapters mounted and canonical ruby/Unicode sources separate',async()=>{
 const h=host();try{await h.command('open',{data:'',names:[],notes:[]});positions(h);
 const doc=h.w.flowTest.getDoc();assert.equal(doc.querySelectorAll('[data-pdfno-spine]').length,2);
 assert.equal(h.w.flowTest.canonical().text,'Metadata0first same 😀 本');assert.equal(doc.querySelector('rt').textContent,'ほん');
 h.area.scrollTop=930;h.w.flowTest.trackFlowViewport();assert.equal(h.w.flowTest.canonical().text,'Metadata1Secondlater same café');
 assert.equal(h.w.messages.at(-1).payload.spineIndex,1);assert.equal(h.w.messages.at(-1).payload.kind,'viewport');
 }finally{h.close()}
});
test('a later chapter note returns to its exact quote despite repeated text in earlier chapters',async()=>{
 const h=host();try{await h.command('open',{data:'',names:[],notes:[]});positions(h);h.area.scrollTop=930;h.w.flowTest.trackFlowViewport();
 const text=h.w.flowTest.canonical().text,start=text.indexOf('same');const anchor={schemaVersion:1,extractionVersion:'epub-canonical-utf16-1',editionID:'edition',fileSHA256:'sha',spineIndex:1,resourceHref:'chapter1.xhtml',start,end:start+4,quote:'same',prefix:text.slice(0,start),suffix:text.slice(start+4),vertical:false};
 const reply=await h.command('navigate',{anchor});assert.equal(reply.navigationSelection.quote,'same');assert.equal(reply.navigationSelection.spineIndex,1);assert.equal(reply.navigationSelection.start,start);
 assert.throws(()=>h.w.flowTest.rangeFor({...anchor,quote:'other'}));
 }finally{h.close()}
});
test('a cross-chapter selection cannot produce a falsely attributed note source',async()=>{
 const h=host();try{await h.command('open',{data:'',names:[],notes:[]});positions(h);
 const d=h.w.flowTest.getDoc(),p=d.querySelectorAll('p'),r=d.createRange();r.setStart(p[0].firstChild,0);r.setEnd(p[1].firstChild,4);d.getSelection().addRange(r);
 assert.equal(h.w.flowTest.selectedAnchor(),null);
 }finally{h.close()}
});
test('an inspector resize preserves the actual selection and canonical source in continuous flow',async()=>{
 const h=host();try{await h.command('open',{data:'',names:[],notes:[]});positions(h);
 const d=h.w.flowTest.getDoc(),node=d.querySelector('p').firstChild,r=d.createRange();r.setStart(node,6);r.setEnd(node,10);d.getSelection().addRange(r);const selected=h.w.flowTest.selectedAnchor();
 const reply=await h.command('resize',{selectionAnchor:selected});assert.equal(reply.resizeSelection.quote,'same');assert.equal(reply.resizeSelection.start,15);assert.equal(d.querySelectorAll('[data-pdfno-spine]').length,2);
 }finally{h.close()}
});

test('vertical flow mounts the same original sources, preserves selection and keeps directory jumps vertical',async()=>{
 const h=host();try{await h.command('open',{data:'',names:[],notes:[]});positions(h);
 const d=h.w.flowTest.getDoc(),before=[...d.querySelectorAll('[data-pdfno-spine]')].map(r=>r.textContent),node=d.querySelector('p').firstChild,r=d.createRange();r.setStart(node,6);r.setEnd(node,10);d.getSelection().addRange(r);
 const reply=await h.command('vertical');assert.equal(reply.vertical,true);assert.equal(reply.orientationSelection.quote,'same');assert.equal(reply.orientationSelection.start,15);assert.equal(reply.orientationSelection.vertical,true);
 assert.deepEqual([...d.querySelectorAll('[data-pdfno-spine]')].map(r=>r.textContent),before);
 const chapter=await h.command('chapter',{index:1});assert.equal(chapter.vertical,true);assert.equal(chapter.spineIndex,1);
 const horizontal=await h.command('vertical');assert.equal(horizontal.vertical,false);assert.equal(horizontal.spineIndex,1);
 }finally{h.close()}
});
