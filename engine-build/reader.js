// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {EpubRender} from './kookit-adapter';
import {handleOneChapterDoc,handleLayout,progressInfo} from './vendor/kookit/src/utils/layoutUtil';
let identity, renderer, version=0, current=0, notes=[], initialising=false, lastSelection='', flow=false, lastViewport='';
const flowRoots=new Map(), flowFrames=new Map();
let flowWidth=0, flowHeight=0, annotationRecords=[], writingLanguageEvidence=null;
let readingLayout={fontSize:20,mode:'scroll',vertical:false};
const flowLayouts=new Map();
let pinnedProgress=null,pinnedScrollTop=0;
const post = value => window.webkit?.messageHandlers.epub.postMessage(JSON.stringify(value));
const envelope = (payload,requestID='event') => ({...identity,v:1,documentVersion:version,requestID,payload});
const doc = () => renderer.getDocument();
function canonical() {
  const root=flow ? flowRoots.get(current) : doc().body, nodes=[]; let text='';
  if (!root) throw Error('Chapter outside verified flow');
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
  const range=selected.getRangeAt(0);
  if (flow) {
    const first=range.startContainer.parentElement?.closest('[data-pdfno-spine]');
    const last=range.endContainer.parentElement?.closest('[data-pdfno-spine]');
    if (!first || first!==last) return null; // A stored source always belongs to one canonical spine resource.
    const index=Number(first.dataset.pdfnoSpine);
    if (index!==current) { current=index; version++; lastSelection=''; publishViewport(); }
  }
  const {nodes}=canonical();
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
  projectAnnotations();
  const ranges=[], original=current;
  for (const note of notes) if (flow || note.anchor.spineIndex===current) {
    try { current=note.anchor.spineIndex; ranges.push(rangeFor(note.anchor)); } catch {} finally { current=original; }
  }
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
function projectAnnotations() {
  const d=doc(),css=d.defaultView.CSS,groups={highlight:[],underline:[],note:[]},original=current;
  d.querySelectorAll('[data-pdfno-annotation-overlay]').forEach(n=>n.remove());
  for(const item of annotationRecords){
    try {
      current=item.anchor.spineIndex;const range=rangeFor(item.anchor);groups[item.kind]?.push(range);
      if(item.kind==='underline'||!css?.highlights){for(const r of range.getClientRects()){
        if(r.width<=0||r.height<=0)continue;const mark=d.createElement('div');mark.dataset.pdfnoAnnotationOverlay='';
        mark.style.cssText=`position:fixed;pointer-events:none;z-index:4;left:${r.left}px;top:${r.top}px;width:${r.width}px;height:${r.height}px;`+(item.kind==='underline'?(renderer.isVertical()?'border-left:2px solid #b67a00':'border-bottom:2px solid #b67a00'):'background:#ffe28588');d.body.appendChild(mark);
      }}
    }catch{}finally{current=original;}
  }
  if(css?.highlights&&d.defaultView.Highlight)css.highlights.set('pdfno-annotations',new d.defaultView.Highlight(...groups.highlight,...groups.note));
}
function decorate() {
  const d=doc();
  d.documentElement.lang = /[\u3040-\u30ff]/.test(d.body.textContent) ? 'ja' : 'en';
  const style=d.createElement('style'); style.textContent='body{font:20px/1.85 system-ui;padding:24px!important;color:#222;background:#fff} ruby{ruby-position:over} ::highlight(pdfno-notes){background:#ffdc73;color:#222} ::highlight(pdfno-annotations){background:#ffe285;color:#222}';
  d.head.appendChild(style);
  d.addEventListener('selectionchange',selection);
  d.addEventListener('mouseup',selection);
  d.addEventListener('keyup',selection);
  d.addEventListener('click',event => { if (event.target.closest?.('a')) event.preventDefault(); },true);
  project();
}
async function chapter(index,vertical=renderer.isVertical(),preserveVersion=false) {
  if (!Number.isSafeInteger(index) || index<0 || index>=renderer.book.sections.length) throw Error('Invalid chapter');
  initialising=true;
  try {
    if (!flow) await buildFlow();
    if (renderer.isVertical()!==vertical) layoutFlow(vertical);
    else sizeFlow();
    if (current!==index) { doc().getSelection()?.removeAllRanges(); if(!preserveVersion)version++; }
    current=index; pinnedProgress=null;lastSelection='';
    sizeFlow();
    if(readingLayout.mode!=='scroll')flowLayouts.get(current)?.show(0);
    renderer.element.scrollTo(0,readingLayout.mode==='scroll'?flowFrames.get(index).offsetTop:0);
  } finally { initialising=false; }
}
function visibleRects(range) {
  const width=renderer.element.clientWidth,height=renderer.element.clientHeight,top=renderer.element.scrollTop;
  return [...range.getClientRects()].some(r=>r.width>0 && r.height>0 && r.left<width && r.right>0 && r.top-top<height && r.bottom-top>0);
}
function progress() {
  if(pinnedProgress){rangeFor(pinnedProgress);return pinnedProgress;}
  const {nodes}=canonical();
  const range=doc().createRange();
  const visible=nodes.find(x=>{range.selectNodeContents(x.node);return visibleRects(range);});
  if (!visible) return null;
  // A vertical paragraph can wrap from bottom to top many times on a page.
  // Bisect ranges by *intersection*, rather than assuming glyph Y is monotonic.
  let low=0,high=visible.node.length;
  while(high-low>1) {
    const middle=Math.floor((low+high)/2);
    range.setStart(visible.node,low);range.setEnd(visible.node,middle);
    if(visibleRects(range))high=middle;else low=middle;
  }
  if(low>0 && /[\uDC00-\uDFFF]/.test(visible.node.data[low]))low--;
  const start=visible.start+low;
  return makeAnchor(start,Math.min(visible.end,start+128));
}
function state() {
  const page=flow&&readingLayout.mode!=='scroll'?flowLayouts.get(current)?.state().page??1:flow ? Math.max(1,Math.floor((renderer.element.scrollTop-flowFrames.get(current).offsetTop)/Math.max(1,renderer.element.clientHeight-(renderer.isVertical()?0:50)))+1) : (progressInfo(renderer.readerMode,doc(),renderer.element)?.currentPage ?? 1);
  return {kind:'state',readingLayout:{...readingLayout,vertical:renderer.isVertical()},
    hasPreviousPage:current>0||flowLayouts.get(current)?.state().hasPrevious===true,
    hasNextPage:current<renderer.book.sections.length-1||flowLayouts.get(current)?.state().hasNext===true,spineIndex:current,chapterCount:renderer.book.sections.length,page:String(page),
    vertical:renderer.isVertical(),progress:progress(),outline:renderer.flattenChapters.map(x=>({title:x.label,index:x.index})).slice(0,1000)};
}

async function buildFlow() {
  renderer.readerMode='scroll'; window.readerMode='scroll';
  renderer.textOrientation='horizontal'; window.textOrientation='horizontal';
  renderer.getIframe().style.removeProperty('height');
  await renderer.goToChapterDocIndex(0);
  const d=doc(); d.documentElement.removeAttribute('style'); d.body.removeAttribute('style'); d.body.replaceChildren();
  // Reuse the bounded, sanitised publication loader. Book scripts remain disabled in the original iframe.
  flowRoots.clear();flowFrames.clear();flowLayouts.clear();
  const stack=d.createElement('main');stack.id='pdfno-flow-stack';d.body.appendChild(stack);
  for(let index=0;index<renderer.book.sections.length;index++) {
    const html=await handleOneChapterDoc(renderer.book.sections[index],false);
    const section=d.createElement('section'); section.dataset.pdfnoSpine=String(index);
    // Match the original Kookit body-fragment insertion exactly. Invisible title
    // text remains part of the existing canonical offsets used by saved notes.
    section.innerHTML=html;
    const frame=d.createElement('div');frame.dataset.pdfnoChapter=String(index);
    frame.appendChild(section);stack.appendChild(frame);flowRoots.set(index,section);flowFrames.set(index,frame);
  }
  const languages=renderer.book.metadata?.language;
  const metadata=typeof languages==='string'?languages:(Array.isArray(languages)&&languages.length===1?(typeof languages[0]==='string'?languages[0]:languages[0]?.value):null);
  const texts=Array.from(flowRoots.values(),root=>{
    const walker=d.createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode:n=>n.parentElement?.closest('rt,rp,script,style,noscript,title')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});let text='';while(walker.nextNode())text+=walker.currentNode.data;return text;
  });
  const total=texts.reduce((n,t)=>n+t.length,0),stride=Math.max(1,Math.ceil(total/100000));let sample='',offset=0;
  // Deterministic whole-document sampling weights chapters by actual text length.
  for(const text of texts){for(let i=(stride-offset%stride)%stride;i<text.length;i+=stride){const code=text.charCodeAt(i);if(code>=0xd800&&code<=0xdbff&&i+1<text.length)sample+=text.slice(i,i+2);else if(code<0xdc00||code>0xdfff)sample+=text[i];}offset+=text.length;}
  writingLanguageEvidence={metadata:typeof metadata==='string'?metadata:null,sample:sample.slice(0,200000)};
  flow=true; current=0; version++; lastSelection=''; lastViewport=''; decorate(); layoutFlow(false);
  for(const [index,root] of flowRoots)flowLayouts.set(index,new window.PDFnoReflow.Layout(root));
}
function layoutFlow(vertical) {
  const d=doc(),frame=renderer.getIframe();
  // An old inline height overrides the vendor's iframe height attribute. Clear
  // both before measuring the new orientation, and replace one exact flow height.
  frame.style.removeProperty('height');frame.removeAttribute('height');
  readingLayout.vertical=vertical;
  renderer.textOrientation=vertical?'vertical':'horizontal';window.textOrientation=renderer.textOrientation;
  let style=d.getElementById('pdfno-continuous-layout');
  if(!style){style=d.createElement('style');style.id='pdfno-continuous-layout';d.head.appendChild(style);}
  style.textContent=`html{width:100%!important;height:auto!important;overflow:visible!important;writing-mode:${vertical?'vertical-rl':'horizontal-tb'}!important;column-count:auto!important;column-width:auto!important}
    body{width:100%!important;height:auto!important;overflow:visible!important;writing-mode:${vertical?'vertical-rl':'horizontal-tb'}!important;column-count:auto!important;column-width:auto!important;margin:0!important;padding:0!important}
    #pdfno-flow-stack{writing-mode:horizontal-tb!important;width:100%;height:auto}
    [data-pdfno-chapter]{display:block;box-sizing:border-box;width:100%;border-bottom:1px solid #e5e5e5}
    [data-pdfno-spine]{font-size:${readingLayout.fontSize}px!important;display:block;box-sizing:border-box;padding:24px;min-height:160px;overflow-wrap:anywhere;${vertical?'writing-mode:vertical-rl!important;text-orientation:mixed;column-fill:auto;column-gap:48px;':'writing-mode:horizontal-tb!important;height:auto!important;width:100%!important;column-width:auto!important;'}}`;
  flowWidth=0;flowHeight=0;sizeFlow();lastViewport='';
}
function sizeFlow() {
  if(!flow || !doc()?.body)return;
  const width=renderer.element.clientWidth||640,height=renderer.element.clientHeight||480;
  if(readingLayout.mode!=='scroll') {
    const anchor=progress();
    for(const [index,frame] of flowFrames){frame.style.display=index===current?'block':'none';frame.style.height=height+'px';}
    renderer.element.style.overflowY='hidden';
    const layout=flowLayouts.get(current),key=JSON.stringify([readingLayout,width,height]);
    if(layout&&layout.cacheKey!==key){
      const chosen=selectedAnchor();layout.configure(readingLayout,width,height);layout.cacheKey=key;
      if(anchor)scrollToSource(anchor);
      if(chosen){const selected=doc().getSelection();selected.removeAllRanges();selected.addRange(rangeFor(chosen));}
    }
    renderer.getIframe().style.height=height+'px';renderer.element.scrollTo(0,0);return;
  }
  renderer.element.style.overflowY='auto';
  for(const [index,frame] of flowFrames){
    frame.style.removeProperty('display');const layout=flowLayouts.get(index);
    if(layout?.paged){layout.restore();layout.settings={...readingLayout};layout.remap();layout.cacheKey=null;}
    flowRoots.get(index).style.fontSize=readingLayout.fontSize+'px';
  }
  if(width!==flowWidth || height!==flowHeight) {
    const anchor=flowWidth>0 ? progress() : null;
    flowWidth=width;flowHeight=height;
    for(const [index,root] of flowRoots) {
      if(renderer.isVertical()) {
        root.style.width=Math.max(100,width)+'px';root.style.height=Math.max(100,height)+'px';
        root.style.columnWidth=Math.max(52,height-48)+'px';
        flowFrames.get(index).style.height=Math.max(height,Math.ceil(root.scrollHeight))+'px';
      } else {
        root.style.removeProperty('height');root.style.removeProperty('width');root.style.removeProperty('column-width');
        flowFrames.get(index).style.removeProperty('height');
      }
    }
    if(anchor) scrollToSource(anchor);
  }
  const frame=renderer.getIframe(),heightValue=Math.ceil(doc().body.scrollHeight)+'px';
  if(frame.style.height!==heightValue)frame.style.height=heightValue;
}
function scrollToSource(anchor) {
  const range=rangeFor(anchor);
  if(readingLayout.mode!=='scroll'){
    flowLayouts.get(current).navigate(range.startContainer);renderer.element.scrollTo(0,0);
    pinnedProgress={...anchor};pinnedScrollTop=0;return;
  }
  const glyph=range.cloneRange();
  glyph.setEnd(range.startContainer,Math.min(range.startContainer.length,range.startOffset+(range.startContainer.data.codePointAt(range.startOffset)>65535?2:1)));
  const r=glyph.getBoundingClientRect(),chapterTop=flowFrames.get(current).offsetTop;
  const pageHeight=Math.max(1,renderer.element.clientHeight-(renderer.isVertical()?0:50));
  // The first visible glyph may straddle a page boundary. Use its exclusive
  // bottom edge to restore that page; subtracting a display margin from the
  // glyph top moves a saved second/third-page position into the previous page.
  const page=Math.max(0,Math.floor((r.bottom-chapterTop-0.01)/pageHeight));
  renderer.element.scrollTo(0,chapterTop+page*pageHeight);
  pinnedProgress={...anchor};pinnedScrollTop=renderer.element.scrollTop;
}
function publishViewport() {
  if(initialising || !renderer?.getDocument())return;
  const value=state(),anchor=value.progress;
  const key=anchor ? version+':'+anchor.spineIndex+':'+anchor.start+':'+anchor.vertical : '';
  if(key!==lastViewport){lastViewport=key;post(envelope({...value,kind:'viewport'}));}
}
function trackFlowViewport() {
  if(!flow || initialising)return;
  if(pinnedProgress&&renderer.element.scrollTop!==pinnedScrollTop)pinnedProgress=null;
  sizeFlow();projectAnnotations();
  if(readingLayout.mode!=='scroll'){publishViewport();return;}
  const top=renderer.element.scrollTop;
  const visible=[...flowFrames].find(([,root])=>root.offsetTop+root.offsetHeight>top+24);
  if(visible && visible[0]!==current){doc().getSelection()?.removeAllRanges();current=visible[0];version++;lastSelection='';}
  publishViewport();
}
async function navigate(anchor,preserveVersion=false) {
  await chapter(anchor.spineIndex,anchor.vertical,preserveVersion);
  const range=rangeFor(anchor);
  scrollToSource(anchor);
  const selection=doc().getSelection();selection.removeAllRanges();selection.addRange(range);
}
window.PDFno = {async command(message) {
  if (message.v!==1 || typeof message.requestID!=='string') throw Error('Invalid bridge version');
  if (message.command!=='open' && (!identity || ['session','bookID','editionID','fileSHA256'].some(k=>message[k]!==identity[k]) || message.documentVersion!==version)) throw Error('Stale reader request');
  if (message.command==='open') {
    if (identity) throw Error('A session can only open one book');
    identity={session:message.session,bookID:message.bookID,editionID:message.editionID,fileSHA256:message.fileSHA256};
    const raw=atob(message.payload.data); const buffer=Uint8Array.from(raw,c=>c.charCodeAt(0));
    renderer=new EpubRender(buffer.buffer,message.payload.names); notes=message.payload.notes;
    if(message.payload.readingLayout)readingLayout={...message.payload.readingLayout};
    await renderer.renderTo(document.getElementById('page-area'));
    await chapter(0,false);
    if (message.payload.progress) await navigate(message.payload.progress);
  } else if (message.command==='next' || message.command==='previous') {
    pinnedProgress=null;
    if(flow&&readingLayout.mode!=='scroll'){
      const delta=message.command==='next'?1:-1,layout=flowLayouts.get(current);
      if(!layout.turn(delta)){
        const target=current+delta;
        if(target>=0&&target<renderer.book.sections.length){
          await chapter(target,renderer.isVertical());
          if(delta<0)flowLayouts.get(current).show(flowLayouts.get(current).spreads.length-1);
        }
      }
    }else if(flow) {
      const delta=(message.command==='next'?1:-1)*Math.max(1,renderer.element.clientHeight-(renderer.isVertical()?0:50));
      renderer.element.scrollBy(0,delta);trackFlowViewport();
    } else {
    initialising=true;
    try {
      await renderer[message.command==='next'?'next':'prev']();
      const target=Number(renderer.getPosition().chapterDocIndex??current);
      if (target!==current) { current=target; version++; decorate(); }
    } finally { initialising=false; }
    }
  } else if(message.command==='layout'){
    const value=message.payload.readingLayout;
    if(!value||!Number.isSafeInteger(value.fontSize)||value.fontSize<12||value.fontSize>36||!['single','double','scroll'].includes(value.mode)||typeof value.vertical!=='boolean')throw Error('Invalid reflow settings');
    const chosen=selectedAnchor()??message.payload.selectionAnchor??null,anchor=message.payload.positionAnchor??progress();
    if(anchor)rangeFor(anchor);if(chosen)rangeFor(chosen);
    readingLayout={...value};pinnedProgress=null;flowWidth=0;flowHeight=0;
    for(const layout of flowLayouts.values())layout.cacheKey=null;
    layoutFlow(value.vertical);sizeFlow();
    if(anchor)await navigate({...anchor,vertical:value.vertical},true);
    const selected=doc().getSelection();selected.removeAllRanges();
    if(chosen)selected.addRange(rangeFor({...chosen,vertical:value.vertical}));
  } else if (message.command==='chapter') await chapter(message.payload.index,renderer.isVertical());
  else if (message.command==='vertical') {
    const selected=selectedAnchor() ?? message.payload.selectionAnchor ?? null, anchor=progress();
    if(!anchor)throw Error('No visible source position');
    if(selected)rangeFor(selected);
    anchor.vertical=!renderer.isVertical();await navigate(anchor);
    const selection=doc().getSelection();selection.removeAllRanges();
    if(selected)selection.addRange(rangeFor({...selected,vertical:anchor.vertical}));
  } else if (message.command==='navigate') await navigate(message.payload.anchor);
  else if (message.command==='notes') { notes=message.payload.notes; project(); }
  else if(message.command==='annotations'){annotationRecords=message.payload.annotations??[];if(annotationRecords.length>10000)throw Error('Annotation limit');}
  else if(message.command==='captureSelection'){const captured=selectedAnchor();return JSON.stringify(envelope({...state(),capturedSelection:captured},message.requestID));}
  else if (message.command==='resize') {
    // Rebind the actual DOM range after reflow, independently of the visible
    // reading-position anchor. Opening an inspector must not select that anchor.
    const selected=selectedAnchor() ?? message.payload.selectionAnchor ?? null, anchor=message.payload.anchor ?? progress();
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
  if(message.command==='open')response.writingLanguageEvidence=writingLanguageEvidence;
  // A selection event may arrive while the native command is busy and then be
  // deduplicated. Acknowledge the actual DOM range in this verified reply too.
  if(message.command==='navigate') response.navigationSelection=selectedAnchor();
  if(message.command==='notes') response.noteSelection=selectedAnchor();
  if(message.command==='annotations') response.annotationSelection=selectedAnchor();
  if(message.command==='resize') response.resizeSelection=selectedAnchor();
  if(message.command==='vertical') response.orientationSelection=selectedAnchor();
  if(message.command==='layout') response.layoutSelection=selectedAnchor();
  return JSON.stringify(envelope(response,message.requestID));
}};
post({v:1,payload:{kind:'ready'}});
// WebKit can suppress listeners in a script-disabled book frame. Poll from
// the trusted parent realm; keep the sandbox rather than enabling book scripts.
setInterval(()=>{trackFlowViewport();selection();},100);
