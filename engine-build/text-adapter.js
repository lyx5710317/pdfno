// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Fixed Kookit Txt/Md/Html conversion route; GeneralRender/cache/network are excluded.
import {marked} from 'marked';
import {txtToHtml} from './vendor/kookit/src/libs/textProcessor.ts';
import {makeHtmlBook} from './vendor/kookit/src/libs/html.ts';
export const extractionVersion='kookit-text-marked15-utf16-1';
export const engine='kookit-text-marked-15.0.12';
const escape=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
const active=new Set(['script','style','iframe','frame','frameset','object','embed','svg','math','form','input','button','link','meta','base','audio','video','noscript','template','canvas','applet']);
const allowed=new Set(['div','section','article','main','header','footer','nav','aside','p','h1','h2','h3','h4','h5','h6','strong','b','em','i','u','s','sup','sub','br','hr','table','thead','tbody','tfoot','tr','td','th','ul','ol','li','blockquote','pre','code','span','a','ruby','rt','rp','dl','dt','dd','figure','figcaption','img','address','details','summary']);
const boundaries=new Set(['p','h1','h2','h3','h4','h5','h6','pre','li','td','th','blockquote','div','section','article','main','header','footer','nav','aside','tr','dt','dd','figure','figcaption','address','summary']);
export function extractTextHTML(html,format) {
  if(typeof html!=='string'||html.length>4*1024*1024||/<!ENTITY|<!DOCTYPE[^>]*\[|<\?xml/i.test(html))throw Error('Unsupported text profile');
  let markup=0;
  for(let i=html.indexOf('<');i!==-1;i=html.indexOf('<',i+1))if(++markup>100000)throw Error('Text markup budget');
  // Inert document; native CSP/content rules already prohibit all resource loads.
  // Only semantic text DTOs leave this document; no source attributes are installed.
  const doc=new DOMParser().parseFromString(html,'text/html');
  const blocks=[],warnings=new Set(['引文锚点使用规范化显示正文的 UTF-16 位置；不表示原文件的字节或 Markdown 标记位置。','链接仅显示普通文字，不访问目标；图片、字体、CSS 与嵌入内容不加载。']);
  let runs=[],headingLevel,listLevel,start=0,count=0,runCount=0,bufferedLength=0;
  function flush(force=false){
    if(!runs.length&&!force)return;
    const text=runs.map(r=>r.text).join('');
    if(!force&&!text.trim()){runs=[];bufferedLength=0;return;}
    if(blocks.length>=10000||start+text.length>1000000)throw Error('Text output budget');
    const block={id:blocks.length,start,runs};
    if(headingLevel)block.headingLevel=headingLevel;
    if(listLevel!==undefined)block.listLevel=Math.min(listLevel,8);
    blocks.push(block);start+=text.length+1;runs=[];bufferedLength=0;
  }
  function append(text,bold,italic){
    if(!text)return;
    if(++runCount>100000)throw Error('Text run budget');
    // Avoid retaining oversized output until the end of an enormous paragraph.
    bufferedLength+=text.length;
    if(start+bufferedLength>1000000)throw Error('Text output budget');
    const last=runs.at(-1);
    if(last&&last.bold===bold&&last.italic===italic)last.text+=text;
    else runs.push({text,bold,italic});
  }
  function walk(node,depth=0,bold=false,italic=false,list=undefined){
    if(++count>100000||depth>64)throw Error('Text structure budget');
    if(node.nodeType===3){append(node.nodeValue,bold,italic);return;}
    if(node.nodeType!==1)return;
    const name=node.localName.toLowerCase();
    if(active.has(name)||['rt','rp'].includes(name)){warnings.add('主动内容／ruby 读音未显示；仅保留可读正文。');return;}
    if(!allowed.has(name)){warnings.add('不支持的扩展内容未显示。');return;}
    if(name==='img'){append('['+(node.getAttribute('alt')||'图片未显示')+']',bold,italic);return;}
    if(name==='br'){append('\n',bold,italic);return;}
    if(name==='hr'){flush();return;}
    if(name==='a')warnings.add('超链接目标已移除，文字保留。');
    if(name==='table')warnings.add('表格按阅读顺序显示文字；原布局未保留。');
    const boundary=boundaries.has(name),oldHeading=headingLevel,oldList=listLevel;
    if(boundary){flush();headingLevel=/^h[1-6]$/.test(name)?Number(name[1]):undefined;listLevel=name==='li'?(list??0):list;}
    const childList=name==='li'?(list??0)+1:list;
    for(const child of Array.from(node.childNodes))walk(child,depth+1,bold||['b','strong'].includes(name),italic||['i','em'].includes(name),childList);
    if(boundary){flush(name==='p'||name==='pre');headingLevel=oldHeading;listLevel=oldList;}
  }
  for(const child of Array.from(doc.body.childNodes))walk(child);flush();
  if(!blocks.some(b=>b.runs.some(r=>r.text.trim())))throw Error('No readable text');
  // Execute the fixed original HTML-book chapter adapter only on our escaped DTO.
  // It cannot see active attributes or resources. Sections are never loaded as blob URLs.
  // A blank heading prevents Kookit's text-title fallback rewriting literal contents.
  const safe='<h1></h1>'+blocks.map(b=>{const tag=b.headingLevel?'h1':'p';return '<'+tag+'>'+escape(b.runs.map(r=>r.text).join(''))+'</'+tag+'>';}).join('');
  const book=makeHtmlBook(safe,false);
  if(book.sections.length>10001)throw Error('Text chapter budget');
  if(format==='txt')warnings.add('TXT 章节标题由固定 Kookit 规则识别；不是作者提供的目录。');
  if(format==='markdown')warnings.add('Markdown 由 Marked 15.0.12 渲染；原始 Markdown 文件完整保留。');
  return {document:{blocks,warnings:[...warnings]},engine,extractionVersion};
}
export function convertText(source,format){
  if(typeof source!=='string'||!['txt','markdown','html'].includes(format)||source.length>1000000)throw Error('Invalid text input');
  let html;
  if(format==='txt'){
    const normal=source.replace(/\r\n?/g,'\n');
    if(normal.split('\n').length>10000)throw Error('Text line budget');
    html=txtToHtml(escape(normal),'',{refresh:true});
    // Kookit inserts hidden synthetic headings for unchaptered text. They are
    // navigation scaffolding, not authored text; exclude them from quotation DTOs.
    html=html.replace(/<h1 class="hide">Chapter \d+<\/h1>/g,'');
  }else if(format==='markdown')html=marked.parse(source,{async:false,gfm:true});
  else html=source;
  return extractTextHTML(html,format);
}
