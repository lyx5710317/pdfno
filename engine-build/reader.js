// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {EpubRender} from './kookit-adapter';
import {handleLayout,progressInfo} from './vendor/kookit/src/utils/layoutUtil';
let identity, renderer, version=0, current=0, notes=[], initialising=false, lastSelection='';
const post = value => window.webkit?.messageHandlers.epub.postMessage(JSON.stringify(value));
const envelope = (payload,requestID='event') => ({...identity,v:1,documentVersion:version,requestID,payload});
const doc = () => renderer.getDocument();
function canonical() {
  const root=doc().body, nodes=[]; let text='';
  const walker=doc().createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode(node) {
    return node.parentElement?.closest('rt,rp,script,style,noscript') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
  }});
  while (walker.nextNode()) { const node=walker.currentNode; nodes.push({node,start:text.length,end:text.length+node.length}); text+=node.data; }
  return {text,nodes};
}
function makeAnchor(start,end) {
  const {text}=canonical();
  const low = value => value>=0xdc00 && value<=0xdfff;
  if (low(text.charCodeAt(start))) start--;
  if (low(text.charCodeAt(end))) end++;
  if (start<0 || end>text.length || end<=start || end-start>16000) return null;
  let before=Math.max(0,start-64), after=Math.min(text.length,end+64);
  if (low(text.charCodeAt(before))) before++;
  if (low(text.charCodeAt(after))) after--;
  return {schemaVersion:1,extractionVersion:'epub-canonical-utf16-1',editionID:identity.editionID,fileSHA256:identity.fileSHA256,
    spineIndex:current,resourceHref:renderer.book.sections[current].id,start,end,quote:text.slice(start,end),
    prefix:text.slice(before,start),suffix:text.slice(end,after),vertical:renderer.isVertical()};
}
function rangeFor(anchor) {
  if (anchor.editionID!==identity.editionID || anchor.fileSHA256!==identity.fileSHA256 ||
      anchor.extractionVersion!=='epub-canonical-utf16-1' || anchor.schemaVersion!==1 ||
      anchor.spineIndex!==current || anchor.resourceHref!==renderer.book.sections[current].id) throw Error('Source identity mismatch');
  const {text,nodes}=canonical();
  if (!Number.isSafeInteger(anchor.start) || !Number.isSafeInteger(anchor.end) || anchor.start<0 || anchor.end<=anchor.start ||
      text.slice(anchor.start,anchor.end)!==anchor.quote ||
      !text.slice(0,anchor.start).endsWith(anchor.prefix) || !text.slice(anchor.end).startsWith(anchor.suffix)) throw Error('Source quote needs rebinding');
  const first=nodes.find(x=>x.end>anchor.start), last=nodes.find(x=>x.end>=anchor.end);
  if (!first || !last) throw Error('Source range missing');
  const range=doc().createRange(); range.setStart(first.node,anchor.start-first.start); range.setEnd(last.node,anchor.end-last.start); return range;
}
function selectedAnchor() {
  if (initialising || !renderer?.getDocument()) return null;
  const selected=doc().getSelection();
  if (!selected?.rangeCount || selected.isCollapsed) return null;
  const range=selected.getRangeAt(0), {nodes}=canonical();
  const included=nodes.filter(x=>range.intersectsNode(x.node));
  if (!included.length) return null;
  const first=included[0], last=included[included.length-1];
  const start=first.start+(range.startContainer===first.node ? range.startOffset : 0);
  const end=last.start+(range.endContainer===last.node ? range.endOffset : last.node.length);
  return makeAnchor(start,end);
}
function selection() {
  const anchor=selectedAnchor(), key=anchor && version+':'+anchor.start+':'+anchor.end;
  if (anchor && key!==lastSelection) { lastSelection=key; post(envelope({kind:'selection',anchor})); }
}
function project() {
  const css=doc().defaultView.CSS;
  const ranges=[];
  for (const note of notes) if (note.anchor.spineIndex===current) { try { ranges.push(rangeFor(note.anchor)); } catch {} }
  for (const old of doc().querySelectorAll('[data-pdfno-overlay]')) old.remove();
  if (css?.highlights) {
    const Highlight=doc().defaultView.Highlight;
    css.highlights.set('pdfno-notes',new Highlight(...ranges));
  } else {
    // Older baseline WebKit: empty, fixed overlays do not change source offsets.
    for (const range of ranges) for (const r of range.getClientRects()) {
      const mark=doc().createElement('div'); mark.dataset.pdfnoOverlay='';
      mark.style.cssText=`position:fixed;pointer-events:none;left:${r.left}px;top:${r.top}px;width:${r.width}px;height:${r.height}px;background:#ffdc73;mix-blend-mode:multiply;z-index:5`;
      doc().body.appendChild(mark);
    }
  }
}
function decorate() {
  const d=doc();
  d.documentElement.lang = /[\u3040-\u30ff]/.test(d.body.textContent) ? 'ja' : 'en';
  const style=d.createElement('style'); style.textContent='body{font:20px/1.85 system-ui;padding:24px!important;color:#222;background:#fff} ruby{ruby-position:over} ::highlight(pdfno-notes){background:#ffdc73;color:#222}';
  d.head.appendChild(style);
  d.addEventListener('selectionchange',selection);
  d.addEventListener('mouseup',selection);
  d.addEventListener('keyup',selection);
  d.addEventListener('click',event => { if (event.target.closest?.('a')) event.preventDefault(); },true);
  project();
}
async function chapter(index,vertical=false,preserveVersion=false) {
  if (!Number.isSafeInteger(index) || index<0 || index>=renderer.book.sections.length) throw Error('Invalid chapter');
  initialising=true;
  try {
    current=index; renderer.textOrientation=vertical?'vertical':'horizontal'; window.textOrientation=renderer.textOrientation;
    handleLayout(renderer.element,renderer.readerMode,doc());
    await renderer.goToChapterDocIndex(index); if (!preserveVersion) version++; lastSelection=''; decorate();
  } finally { initialising=false; }
}
function progress() {
  const {nodes}=canonical(), width=renderer.element.clientWidth, height=renderer.element.clientHeight;
  const visible=nodes.find(x => {
    const range=doc().createRange(); range.selectNodeContents(x.node);
    return [...range.getClientRects()].some(r=>r.width>0 && r.height>0 && r.left<width && r.right>0 && r.top<height && r.bottom>0);
  });
  if (!visible) return null;
  // Pagination translates preceding columns outside the viewport. Find the
  // first visible scalar inside this text node, including a long single paragraph.
  let low=0,high=visible.node.length;
  const range=doc().createRange(),vertical=renderer.isVertical();
  const rectAt=offset=>{
    if(offset>0&&/[\uDC00-\uDFFF]/.test(visible.node.data[offset]))offset--;
    range.setStart(visible.node,offset);range.setEnd(visible.node,Math.min(visible.node.length,offset+(visible.node.data.codePointAt(offset)>65535?2:1)));
    return range.getBoundingClientRect();
  };
  while(low<high){const middle=Math.floor((low+high)/2),r=rectAt(middle);
    if(vertical?r.bottom<=0:r.right<=0)low=middle+1;else high=middle;
  }
  const start=visible.start+low;
  return makeAnchor(start,Math.min(visible.end,start+128));
}
function state() {
  const page=progressInfo(renderer.readerMode,doc(),renderer.element)?.currentPage ?? 1;
  return {kind:'state',spineIndex:current,chapterCount:renderer.book.sections.length,page:String(page),
    vertical:renderer.isVertical(),progress:progress(),outline:renderer.flattenChapters.map(x=>({title:x.label,index:x.index})).slice(0,1000)};
}
async function navigate(anchor,preserveVersion=false) {
  await chapter(anchor.spineIndex,anchor.vertical,preserveVersion);
  const range=rangeFor(anchor),glyph=range.cloneRange();
  glyph.setEnd(range.startContainer,Math.min(range.startContainer.length,range.startOffset+(range.startContainer.data.codePointAt(range.startOffset)>65535?2:1)));
  const r=glyph.getBoundingClientRect(),d=doc(),vertical=renderer.isVertical();
  const section=Math.floor((vertical?renderer.element.clientHeight:renderer.element.clientWidth)/12),gap=section%2===0?section:section-1;
  const stride=(vertical?d.body.clientHeight:d.body.clientWidth)+gap;
  if(!Number.isFinite(stride)||stride<=0)throw Error('Reader viewport unavailable');
  const absolute=vertical?r.top+d.body.scrollTop:r.left+d.body.scrollLeft;
  const offset=Math.max(0,Math.floor((absolute+0.5)/stride)*stride);
  d.body.scrollTo(vertical?0:offset,vertical?offset:0);
  await renderer.record();renderer.trigger('rendered');
  const selection=d.getSelection(); selection.removeAllRanges(); selection.addRange(range);
}
window.PDFno = {async command(message) {
  if (message.v!==1 || typeof message.requestID!=='string') throw Error('Invalid bridge version');
  if (message.command!=='open' && (!identity || ['session','bookID','editionID','fileSHA256'].some(k=>message[k]!==identity[k]) || message.documentVersion!==version)) throw Error('Stale reader request');
  if (message.command==='open') {
    if (identity) throw Error('A session can only open one book');
    identity={session:message.session,bookID:message.bookID,editionID:message.editionID,fileSHA256:message.fileSHA256};
    const raw=atob(message.payload.data); const buffer=Uint8Array.from(raw,c=>c.charCodeAt(0));
    renderer=new EpubRender(buffer.buffer,message.payload.names); notes=message.payload.notes;
    await renderer.renderTo(document.getElementById('page-area'));
    await chapter(0,false);
    if (message.payload.progress) await navigate(message.payload.progress);
  } else if (message.command==='next' || message.command==='previous') {
    initialising=true;
    try {
      await renderer[message.command==='next'?'next':'prev']();
      const target=Number(renderer.getPosition().chapterDocIndex??current);
      if (target!==current) { current=target; version++; decorate(); }
    } finally { initialising=false; }
  } else if (message.command==='chapter') await chapter(message.payload.index,false);
  else if (message.command==='vertical') {
    const anchor=progress(); if(!anchor)throw Error('No visible source position');anchor.vertical=!renderer.isVertical(); await navigate(anchor);
  } else if (message.command==='navigate') await navigate(message.payload.anchor);
  else if (message.command==='notes') { notes=message.payload.notes; project(); }
  else if (message.command==='resize') {
    // Rebind the actual DOM range after reflow, independently of the visible
    // reading-position anchor. Opening an inspector must not select that anchor.
    const selected=selectedAnchor() ?? message.payload.selectionAnchor ?? null, anchor=progress();
    if (selected) rangeFor(selected); // Verify the source before reflow too.
    if (anchor) {
      // This is the same canonical chapter, not a source or history change.
      await navigate(anchor,true);
      const selection=doc().getSelection(); selection.removeAllRanges();
      if (selected) selection.addRange(rangeFor(selected));
    }
  }
  else if (message.command==='chapterText') {
    const selected=selectedAnchor() ?? message.payload.selectionAnchor ?? null;
    if (selected) {
      const range=rangeFor(selected),selection=doc().getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    }
    // Bounds checked before bridging any body text. Oversize returns a true count and null, never an excerpt.
    const {text}=canonical();
    const chapterText={resourceHref:renderer.book.sections[current].id,spineIndex:current,
      chapterCount:renderer.book.sections.length,utf16Count:text.length,text:text.length<=3000?text:null,vertical:renderer.isVertical()};
    return JSON.stringify(envelope({...state(),chapterText,chapterSelection:selectedAnchor()},message.requestID));
  } else if (message.command==='validateAnchor') rangeFor(message.payload.anchor);
  else throw Error('Command is not allowed');
  project();
  const response=state();
  // A selection event may arrive while the native command is busy and then be
  // deduplicated. Acknowledge the actual DOM range in this verified reply too.
  if(message.command==='navigate') response.navigationSelection=selectedAnchor();
  if(message.command==='notes') response.noteSelection=selectedAnchor();
  if(message.command==='resize') response.resizeSelection=selectedAnchor();
  return JSON.stringify(envelope(response,message.requestID));
}};
post({v:1,payload:{kind:'ready'}});
// WebKit can suppress listeners in a script-disabled book frame. Poll from
// the trusted parent realm; keep the sandbox rather than enabling book scripts.
setInterval(selection,100);
