// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import JSZip from 'jszip';
const ENTRY = 4 * 1024 * 1024, TOTAL = 50 * 1024 * 1024;
export const safePath = name => typeof name === 'string' && name.length > 0 && name.length <= 1024 &&
  !/^[\/]|[\\:%\x00-\x1f\x7f]/.test(name) && name.split('/').every((p,i,a) => p !== '.' && p !== '..' && (p || i === a.length-1));
const safeReference = value => !/^[\/]|[\\:\x00-\x1f]/.test(value) && !/%(?:2e|2f|5c|00)/i.test(value);
function css(text) {
  // Fail closed for escaped CSS and import rules; author layout/ruby CSS remains.
  return text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/@import[^;]*(?:;|$)/gi, '')
    .replace(/url\([^)]*\)/gi, 'none').replace(/[^{};]*[\\][^{};]*(?:;|$)/g, '')
    .replace(/(?:behavior|-moz-binding)\s*:[^;}]*/gi, '');
}
export function sanitise(text, name) {
  if (/<!DOCTYPE|<!ENTITY/i.test(text)) throw Error('XML declarations are not accepted');
  if (/\.css$/i.test(name)) return css(text);
  if (!/\.(?:xhtml|html|xml|opf|ncx)$/i.test(name)) return text;
  const isHTML = /\.(?:xhtml|html)$/i.test(name);
  const doc = new DOMParser().parseFromString(text, isHTML ? 'application/xhtml+xml' : 'application/xml');
  if (doc.querySelector('parsererror')) throw Error('Invalid publication XML');
  for (const node of [...doc.querySelectorAll('*')]) {
    const tag = node.localName.toLowerCase();
    if (['script','iframe','object','embed','form','input','button','base','svg','math','audio','video'].includes(tag) ||
        (tag === 'meta' && node.hasAttribute('http-equiv'))) { node.remove(); continue; }
    for (const attr of [...node.attributes]) {
      const key = attr.localName.toLowerCase();
      if (key.startsWith('on') || ['srcdoc','action','formaction','srcset'].includes(key)) node.removeAttributeNode(attr);
      else if (key === 'style') attr.value = css(attr.value);
      else if (['href','src','poster','data','full-path'].includes(key) && !safeReference(attr.value)) node.removeAttributeNode(attr);
    }
    if (tag === 'style') node.textContent = css(node.textContent);
  }
  return new XMLSerializer().serializeToString(doc);
}
export async function makeLoader(buffer, allowedNames) {
  const zip = await JSZip.loadAsync(buffer);
  const actual = Object.keys(zip.files).sort();
  if (actual.length > 1000 || JSON.stringify(actual) !== JSON.stringify([...allowedNames].sort()) ||
      actual.some(name => !safePath(name) || (zip.files[name].unsafeOriginalName && zip.files[name].unsafeOriginalName !== name))) throw Error('Archive path mismatch');
  const cache = new Map(), checkedImages = new Set(); let total = 0, totalPixels = 0;
  const bytes = name => {
    if (!safePath(name)) throw Error('Resource outside publication');
    if (!zip.files[name]) return Promise.resolve(null);
    if (cache.has(name)) return cache.get(name);
    const pending = new Promise((resolve,reject) => {
      const chunks = []; let size = 0;
      const stream = zip.files[name].internalStream('uint8array');
      stream.on('data', chunk => {
        size += chunk.byteLength; total += chunk.byteLength;
        if (size > ENTRY || total > TOTAL) { stream.pause(); reject(Error('Decompression budget exceeded')); return; }
        chunks.push(chunk);
      }).on('error',reject).on('end',() => {
        const result = new Uint8Array(size); let offset=0;
        for (const chunk of chunks) { result.set(chunk,offset); offset += chunk.length; }
        resolve(result);
      }).resume();
    });
    cache.set(name,pending); return pending;
  };
  const loadText = async name => {
    const data = await bytes(name);
    return data ? sanitise(new TextDecoder('utf-8',{fatal:true}).decode(data),name) : '';
  };
  const loadBlob = async name => {
    if (/\.(?:xhtml|html|xml|opf|ncx|css)$/i.test(name)) return new Blob([await loadText(name)]);
    if (!/\.(?:png|jpe?g)$/i.test(name)) throw Error('Only bounded static PNG/JPEG image resources are currently accepted');
    const data = await bytes(name);
    if (data && !checkedImages.has(name)) {
      let width=0,height=0;
      if (data.length>=24 && data[0]===137 && data[1]===80 && data[2]===78 && data[3]===71) {
        const view=new DataView(data.buffer,data.byteOffset,data.byteLength); width=view.getUint32(16); height=view.getUint32(20);
        for (let p=8;p+12<=data.length;) {
          const length=view.getUint32(p), type=String.fromCharCode(...data.slice(p+4,p+8));
          if (type==='acTL') throw Error('Animated PNG is not accepted');
          if (p+12+length>data.length) throw Error('Invalid PNG'); p+=12+length;
        }
      } else if (data[0]===255 && data[1]===216) {
        for (let p=2;p+8<data.length;) {
          if (data[p]!==255) break;
          const marker=data[p+1], length=(data[p+2]<<8)|data[p+3];
          if ([0xc0,0xc1,0xc2].includes(marker)) { height=(data[p+5]<<8)|data[p+6]; width=(data[p+7]<<8)|data[p+8]; break; }
          if (length<2 || p+2+length>data.length) break; p+=2+length;
        }
      }
      if (!width || !height || width*height>4000000 || totalPixels+width*height>16000000) throw Error('Image pixel budget exceeded');
      totalPixels+=width*height; checkedImages.add(name);
    }
    return new Blob(data ? [data] : []);
  };
  return {entries:actual.map(filename => ({filename})), loadText, loadBlob,
    getSize:name => zip.files[name]?._data?.uncompressedSize ?? 0};
}
