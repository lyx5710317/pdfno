// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {MOBI,isMOBI} from './vendor/kookit/src/libs/mobi.js';
import {makeFB2} from './vendor/kookit/src/libs/fb2.js';
export const engine='kookit-foliate-95f602e';
export const extractionVersion='ebook-kookit-utf16-1';
export async function extractEbook(buffer,format) {
  if(!(buffer instanceof ArrayBuffer)||buffer.byteLength>8*1024*1024||!['mobi','azw','azw3','fb2'].includes(format))throw Error('Ebook input profile');
  let book,kind;
  if(format==='fb2'){
    const str=new TextDecoder('utf-8',{fatal:true}).decode(buffer);
    if(/<!DOCTYPE|<!ENTITY|\0/i.test(str)||/encoding\s*=\s*["'](?!utf-8["'])/i.test(str))throw Error('FB2 encoding/entities profile');
    const doc=new DOMParser().parseFromString(str,'application/xml');
    if(doc.querySelector('parsererror')||doc.documentElement.localName!=='FictionBook'||doc.documentElement.namespaceURI!=='http://www.gribuser.ru/xml/fictionbook/2.0')throw Error('Invalid FB2');
    let nodes=0;const check=(n,d)=>{if(++nodes>100000||d>48)throw Error('FB2 structure budget');for(const c of n.childNodes)check(c,d+1);};check(doc,0);
    if(doc.querySelector('binary')||doc.querySelectorAll('body > *').length>1000||Array.from(doc.querySelectorAll('body')).some(b=>b.parentElement!==doc.documentElement))throw Error('FB2 text-only/section profile');
    book=await makeFB2(new Blob([buffer]));kind='fb2';
  } else {
    const file=new Blob([buffer]);if(!await isMOBI(file))throw Error('Not MOBI');
    const bytes=new Uint8Array(buffer),view=new DataView(buffer),u32=p=>view.getUint32(p),u16=p=>view.getUint16(p);
    const count=u16(76);if(count<2||count>1000||78+count*8+2>buffer.byteLength)throw Error('PDB record budget');
    const r=u32(78);if(r<78+count*8+2||r+280>buffer.byteLength)throw Error('MOBI header range');
    const version=u32(r+36);kind=version===8?'kf8':'mobi6';
    if(![6,8].includes(version)||format==='azw3'&&version!==8||u16(r+12)!==0||![1,2].includes(u16(r))||u32(r+240)!==0||u32(r+244)!==0xffffffff||version===8&&u32(r+260)!==0xffffffff||u16(r+8)>=count)throw Error('MOBI restricted profile/DRM');
    const header=u32(r+20);if(header<248||header>512||r+16+header>buffer.byteLength)throw Error('MOBI length');
    if(u32(r+128)&64){let p=r+16+header;const len=u32(p+4),n=u32(p+8);if(n>1000||len<12||p+len>u32(86))throw Error('EXTH range');const end=p+len;p+=12;for(let i=0;i<n;i++){const type=u32(p),l=u32(p+4);if(l<8||p+l>end||[121,122,125,126,132].includes(type))throw Error('Combo/fixed layout profile');p+=l;}}
    book=await new MOBI({unzlib:()=>{throw Error('Embedded fonts/resources disabled');}}).open(file);
  }
  if(!book.sections?.length||book.sections.length>1000||book.rendition?.layout==='pre-paginated')throw Error('Ebook sections profile');
  const blocks=[],warnings=['正文重排；图片、字体、链接目标和原始分页不显示。'];let start=0,work=0;
  const active=new Set(['script','style','iframe','object','embed','svg','math','form','input','button','link','meta','base','audio','video','noscript']);
  const breaks=new Set(['p','h1','h2','h3','h4','h5','h6','li','pre','blockquote','div','section','header','td','th','tr']);
  const name=n=>(n.localName||'').toLowerCase();
  for(let section=0;section<book.sections.length;section++){
    if(book.sections[section].linear==='no')continue;
    const doc=await book.sections[section].createDocument();if(!doc||doc.querySelector('parsererror'))throw Error('Invalid ebook section XML');
    let runs=[],heading=null;
    function flush(){const text=runs.map(r=>r.text).join('');if(text.trim()){if(blocks.length>=10000||start+text.length>1000000)throw Error('Ebook canonical budget');blocks.push({id:blocks.length,start,section,runs,headingLevel:heading,listLevel:null,table:null,row:null,cell:null});start+=text.length+1;}runs=[];heading=null;}
    function walk(n,depth,bold=false,italic=false){
      if(++work>300000||depth>48)throw Error('Ebook DOM work budget');
      if(n.nodeType===3||n.nodeType===4){if(n.nodeValue)runs.push({text:n.nodeValue,bold,italic,ruby:null});return;}
      if(n.nodeType!==1)return;const tag=name(n);if(active.has(tag)||['rt','rp'].includes(tag))return;
      if(tag==='img')return; // No invented placeholder text in immutable source anchors.
      if(tag==='br'){runs.push({text:'\n',bold,italic,ruby:null});return;}
      const block=breaks.has(tag);if(block){flush();heading=/^h[1-6]$/.test(tag)?Number(tag[1]):(n.classList.contains('title')||n.parentElement?.closest('.title'))?1:null;}
      if(tag==='ruby'){
        const rubyBase=(node,d)=>{if(++work>300000||d>48)throw Error('Ruby structure budget');if(node.nodeType===3||node.nodeType===4)return node.nodeValue||'';if(node.nodeType!==1||active.has(name(node))||['rt','rp'].includes(name(node)))return '';return Array.from(node.childNodes).map(c=>rubyBase(c,d+1)).join('');};
        const base=rubyBase(n,depth);
        const ruby=Array.from(n.querySelectorAll('rt')).map(c=>c.textContent).join('');
        if(ruby.length>1024)throw Error('Ruby budget');runs.push({text:base,bold,italic,ruby});
      } else for(const c of n.childNodes)walk(c,depth+1,bold||['strong','b'].includes(tag),italic||['em','i'].includes(tag));
      if(block)flush();
    }
    for(const n of (doc.body||doc.documentElement).childNodes)walk(n,0);flush();
  }
  book.destroy?.();if(!blocks.length)throw Error('Empty ebook body');
  return {engine,extractionVersion,contentKind:kind,document:{blocks,warnings}};
}
window.PDFnoEbookEngine={async extract(message){
  const binary=atob(message.data),bytes=Uint8Array.from(binary,c=>c.charCodeAt(0));
  const result=await extractEbook(bytes.buffer,message.format);
  return JSON.stringify({...result,v:1,session:message.session,bookID:message.bookID,editionID:message.editionID,fileSHA256:message.fileSHA256,format:message.format});
}};
