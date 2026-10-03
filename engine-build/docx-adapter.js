// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Kookit DocxRender 95f602e's original Mammoth convertToHtml chain, with explicit
// safe options, failure propagation and a strict semantic allowlist before display.
import mammoth from 'mammoth';
import {DOMParser, XMLSerializer} from '@xmldom/xmldom';
const NS='http://www.w3.org/1999/xhtml';
const allowed=new Set(['div','p','h1','h2','h3','h4','h5','h6','strong','em','u','s','sup','sub','br','hr','table','thead','tbody','tfoot','tr','td','th','ul','ol','li','blockquote','pre','code','span','a']);
const active=new Set(['script','style','iframe','object','embed','svg','math','form','input','button','link','meta','base','audio','video','noscript']);
const blockTags=new Set(['p','h1','h2','h3','h4','h5','h6','pre']);
const children=node=>Array.from(node.childNodes||[]);
const elements=node=>children(node).filter(x=>x.nodeType===1);
const tag=node=>(node.localName||node.nodeName||'').toLowerCase();
const ancestor=(node,predicate)=>{for(let p=node.parentNode;p&&p.nodeType===1;p=p.parentNode)if(predicate(p))return p;return null;};
const visit=(node,fn)=>{fn(node);for(const child of children(node))visit(child,fn);};
export function sanitiseDOCX(html,messages=[]) {
  if(typeof html!=='string'||html.length>4*1024*1024||/<!DOCTYPE|<!ENTITY/i.test(html))throw Error('DOCX converted HTML exceeds profile');
  let parseError=false;
  const parser=new DOMParser({errorHandler:{warning:()=>{parseError=true;},error:()=>{parseError=true;},fatalError:()=>{parseError=true;}}});
  const document=parser.parseFromString('<div xmlns="'+NS+'">'+html+'</div>','application/xhtml+xml');
  if(parseError||!document.documentElement)throw Error('Invalid converted DOCX HTML');
  const root=document.documentElement,warnings=new Set(messages.slice(0,100).map(x=>String(x.message||x).slice(0,512)));
  let count=0;
  function clean(node,depth=0){
    if(++count>100000||depth>64)throw Error('DOCX output structure budget');
    for(const child of children(node)){
      if(child.nodeType===3)continue;
      if(child.nodeType!==1){node.removeChild(child);continue;}
      const name=tag(child);
      if(active.has(name)){node.removeChild(child);warnings.add('主动内容已移除。');continue;}
      if(name==='img'){
        const label=child.getAttribute('alt')||'图片未显示';node.replaceChild(document.createTextNode('['+label+']'),child);warnings.add('图片与图形未显示；不读取图片或外部资源。');continue;
      }
      if(!allowed.has(name)){node.removeChild(child);warnings.add('不支持的扩展内容未显示。');continue;}
      if(child.namespaceURI!==NS)throw Error('Unexpected DOCX output namespace');
      // All source attributes are removed, including every URL, event, style and ID.
      const span=child.getAttribute('colspan'),rowspan=child.getAttribute('rowspan');
      for(const attribute of Array.from(child.attributes||[]))child.removeAttributeNode(attribute);
      if(['td','th'].includes(name))for(const [key,value] of [['colspan',span],['rowspan',rowspan]])if(/^[1-9][0-9]?$/.test(value||''))child.setAttribute(key,value);
      if(name==='a')warnings.add('超链接以普通文字显示；不访问链接目标。');
      if(name==='br'){node.replaceChild(document.createTextNode('\n'),child);continue;}
      clean(child,depth+1);
    }
  }
  clean(root);
  // Flatten only paragraph wrappers for canonical partitioning; list/table structure stays displayed.
  function wrapInline(node){
    const groups=[];let group=[];
    for(const child of children(node)){
      if(child.nodeType===1&&(blockTags.has(tag(child))||['ul','ol','table','blockquote','div'].includes(tag(child)))){if(group.length)groups.push(group);group=[];}
      else group.push(child);
    }
    if(group.length)groups.push(group);
    for(const values of groups){if(!values.some(x=>x.nodeType===1||(x.nodeValue||'').trim()))continue;
      const p=document.createElementNS(NS,'p');node.insertBefore(p,values[0]);for(const child of values)p.appendChild(child);
    }
  }
  const containers=[];visit(root,n=>{if(n.nodeType===1&&['li','td','th','div','blockquote'].includes(tag(n)))containers.push(n);});
  for(const container of containers.reverse())wrapInline(container);
  const blocks=[],tables=[];let start=0;
  visit(root,node=>{
    if(node.nodeType!==1)return;
    if(tag(node)==='table')tables.push(node);
    if(!blockTags.has(tag(node)))return;
    if(blocks.length>=10000)throw Error('DOCX paragraph budget');
    const runs=[];
    visit(node,n=>{if(n.nodeType===3&&n.nodeValue){runs.push({text:n.nodeValue,bold:!!ancestor(n,p=>tag(p)==='strong'),italic:!!ancestor(n,p=>tag(p)==='em')});}});
    const text=runs.map(x=>x.text).join('');if(start+text.length>1000000)throw Error('DOCX text budget');
    const li=ancestor(node,n=>tag(n)==='li'),table=ancestor(node,n=>tag(n)==='table'),tr=ancestor(node,n=>tag(n)==='tr'),cell=ancestor(node,n=>['td','th'].includes(tag(n)));
    const block={id:blocks.length,runs,start};
    if(/^h[1-6]$/.test(tag(node)))block.headingLevel=Number(tag(node).slice(1));
    if(li){let level=0;for(let p=li.parentNode;p;p=p.parentNode)if(tag(p)==='li')level++;block.listLevel=Math.min(8,level);}
    if(table&&tr&&cell){block.table=tables.indexOf(table);const rows=[];visit(table,n=>{if(tag(n)==='tr'&&ancestor(n,p=>tag(p)==='table')===table)rows.push(n);});block.row=rows.indexOf(tr);block.cell=elements(tr).filter(n=>['td','th'].includes(tag(n))).indexOf(cell);}
    node.setAttribute('id','b'+block.id);node.setAttribute('data-block',String(block.id));node.setAttribute('data-start',String(start));
    blocks.push(block);start+=text.length+1;
  });
  if(!blocks.some(b=>b.runs.some(r=>r.text.trim())))throw Error('No readable DOCX text');
  warnings.add('DOCX 为语义重排阅读；分页、字体、页眉页脚等与 Word 原版式不同。');
  const serializer=new XMLSerializer();
  return {html:children(root).map(n=>serializer.serializeToString(n)).join(''),document:{blocks,warnings:[...warnings].slice(0,100)},engine:'kookit-mammoth-1.13.0',extractionVersion:'docx-mammoth-utf16-1'};
}
export async function convertDOCX(buffer){
  if(!(buffer instanceof ArrayBuffer)||buffer.byteLength>20*1024*1024)throw Error('DOCX input budget');
  const result=await mammoth.convertToHtml({arrayBuffer:buffer,buffer:new Uint8Array(buffer)}, {
    externalFileAccess:false,includeEmbeddedStyleMap:false,includeDefaultStyleMap:true,ignoreEmptyParagraphs:false,
    convertImage:mammoth.images.imgElement(image=>({alt:image.altText||'图片未显示'}))
  });
  return sanitiseDOCX(result.value,result.messages);
}
