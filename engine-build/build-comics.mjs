// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(await readFile(path.join(root,'COMICS-SOURCE.json'),'utf8'));
const item=manifest.files[0], source=await readFile(path.join(root,'vendor/kookit',item.path));
const hash=createHash('sha1').update(`blob ${source.length}\0`).update(source).digest('hex');
if (hash!==item.gitBlobSHA1 || createHash('sha256').update(source).digest('hex')!==item.sha256) throw Error('Kookit comic source changed');
const original=source.toString('utf8');
if ((original.match(/export const makeComicBook/g)||[]).length!==1 || /^import\s/m.test(original)) throw Error('Unexpected dependency/export');
const output=path.resolve(root,'../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics');
await mkdir(output,{recursive:true});
const script='// Kookit '+manifest.commit+' comic model. Source: engine-build/. See Notices.txt.\n(()=>{\n'+original.replace('export const makeComicBook','const makeComicBook')+'\n'+await readFile(path.join(root,'comics-reader.js'),'utf8')+'\n})();\n';
await writeFile(path.join(output,'engine.js'),script);
await writeFile(path.join(output,'Notices.txt'),'PDFno CBZ adapter: AGPL-3.0-or-later. Kookit makeComicBook from '+manifest.commit+'.\nCorresponding source: engine-build/vendor/kookit/src/libs/comic-book.js and engine-build/comics-reader.js.\nNo ZIP/RAR/PDF engine, worker, WASM, npm dependency or executable is bundled in this comic profile.\n\n'+await readFile(path.join(root,'vendor/kookit/LICENSE'),'utf8'));
console.log('Built comics model and adapter from one verified upstream file; no package install.');
