// Kookit 95f602ed62d204af0de9278cf53212c309b34bfc comic model. Source: engine-build/. See Notices.txt.
(()=>{
const getExt = (name) => {
  const idx = name.lastIndexOf(".");
  return idx > -1 ? name.slice(idx).toLowerCase() : "";
};

const makeComicBook = ({ entries, loadBlob, getSize }, file) => {
  const cache = new Map();
  const urls = new Map();
  const load = async (name) => {
    if (cache.has(name)) return cache.get(name);
    const src = URL.createObjectURL(await loadBlob(name));
    const page = URL.createObjectURL(
      new Blob(
        [
          `<div style="width:100%; height:100%; display:flex; align-items:center; justify-content:center; overflow:hidden;"><img src="${src}" style="max-width:100%; max-height:100%; object-fit:contain;"></div>`,
        ],
        { type: "text/html" }
      )
    );
    urls.set(name, [src, page]);
    cache.set(name, page);
    return page;
  };
  const unload = (name) => {
    urls.get(name)?.forEach?.((url) => URL.revokeObjectURL(url));
    urls.delete(name);
    cache.delete(name);
  };

  const exts = [
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".webp",
    ".svg",
    ".bmp",
    ".tif",
    ".tiff",
    ".jfif",
    ".jpe",
    ".heic",
  ];
  const files = entries
    .map((entry) => entry.filename)
    .filter((name) => exts.some((ext) => name.endsWith(ext)))
    .sort((a, b) =>
      a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" })
    );

  const book = {};
  book.getCover = () => loadBlob(files[0]);
  book.metadata = { title: file.name };
  // 每张图片始终是一个独立 section，double 模式的两页合并由渲染层的
  // CSS 双列布局完成，与 PdfRender 的分页模型保持一致
  book.sections = files.map((name, index) => ({
    id: name,
    load: () => load(name),
    unload: () => unload(name),
    size: getSize(name),
  }));
  book.toc = files.map((name, index) => ({
    label: name.split("/").pop() || name,
    href: name,
  }));
  book.rendition = { layout: "pre-paginated" };
  book.resolveHref = (href) => ({
    index: book.sections.findIndex((s) => s.id === href),
  });
  book.resolveHrefIndex = (href) => ({
    index: book.sections.findIndex((s) => s.id === href),
  });
  book.splitTOCHref = (href) => [href, null];
  book.getTOCFragment = (doc) => doc.documentElement;
  return book;
};

// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Uses fixed Kookit makeComicBook, with native ordering and only the current bounded PNG thumbnails.
let identity, book, names=[], bytes=new Map(), visible=[], rendering=false;
const sameIdentity = message => ['session','bookID','editionID','fileSHA256'].every(k=>message[k]===identity?.[k]);
const dispose = () => { if (book) for (const index of visible) book.sections[index].unload(); visible=[]; bytes.clear(); };
const blob = name => {
  const value=bytes.get(name);
  if (!value) throw Error('Page outside current spread');
  const raw=atob(value); return new Blob([Uint8Array.from(raw,c=>c.charCodeAt(0))],{type:'image/png'});
};
async function frameFor(index) {
  const frame=document.createElement('iframe');
  frame.setAttribute('sandbox','allow-same-origin'); frame.title=`第 ${index+1} 页`;
  const loaded=new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>reject(Error('Page timed out')),10000);
    frame.onload=()=> { clearTimeout(timer); const doc=frame.contentDocument, image=doc?.querySelector('img');
      if (doc?.body) { doc.documentElement.style.height='100%'; doc.body.style.cssText='margin:0;width:100%;height:100%;background:#202124'; }
      if (image?.naturalWidth>0) resolve(); else reject(Error('Page failed')); };
    frame.onerror=()=>{clearTimeout(timer);reject(Error('Page failed'));};
  });
  frame.src=await book.sections[index].load(); document.getElementById('pages').appendChild(frame); await loaded;
}
window.PDFnoComic={async command(message) {
  if (message.v!==1 || message.command!=='render' || typeof message.requestID!=='string' || rendering) throw Error('Invalid comic request');
  if (identity && !sameIdentity(message)) throw Error('Stale comic request');
  if (!identity) {
    identity=Object.fromEntries(['session','bookID','editionID','fileSHA256'].map(k=>[k,message[k]]));
    names=message.names;
    if (!Array.isArray(names) || !names.length || names.length>2000 || new Set(names).size!==names.length) throw Error('Invalid page manifest');
    book=makeComicBook({entries:names.map(filename=>({filename})),loadBlob:blob,getSize:()=>1},{name:'CBZ'});
    // Upstream uses localeCompare and lowercase suffixes. Feed controlled aliases, then explicitly use native manifest order.
    const sections=new Map(book.sections.map(section=>[section.id,section]));
    if (names.some(name=>!sections.has(name))) throw Error('Page manifest mismatch');
    book.sections=names.map(name=>sections.get(name));
  }
  if (!Array.isArray(message.pages) || message.pages.length<1 || message.pages.length>2 ||
      message.pages.some(p=>!Number.isSafeInteger(p.index) || p.index<0 || p.index>=names.length || typeof p.data!=='string' || p.data.length>24*1024*1024) ||
      new Set(message.pages.map(p=>p.index)).size!==message.pages.length) throw Error('Invalid spread');
  rendering=true;
  try {
    document.getElementById('pages').replaceChildren(); dispose();
    visible=message.pages.map(p=>p.index);
    for (const p of message.pages) bytes.set(names[p.index],p.data);
    for (const index of visible) await frameFor(index);
    document.getElementById('pages').dataset.count=String(visible.length);
    return JSON.stringify({...identity,v:1,requestID:message.requestID,indices:visible});
  } catch(error) { document.getElementById('pages').replaceChildren(); dispose(); throw error; }
  finally { rendering=false; }
},close(){document.getElementById('pages').replaceChildren();dispose();book=null;identity=null;}};
window.webkit?.messageHandlers.comic.postMessage('ready');

})();
