// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {build} from 'esbuild';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const output=path.resolve(root,'../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/TextFormats');
const profile=JSON.parse(await readFile(path.join(root,'TEXT-KOOKIT-SOURCE.json'),'utf8'));
const manifest=JSON.parse(await readFile(path.join(root,'vendor/manifest.json'),'utf8'));
for(const item of [...profile.files,manifest.files.find(x=>x.path==='src/libs/textProcessor.ts')]){
 const bytes=await readFile(path.join(root,item.localPath||'vendor/kookit/'+item.path));
 if(bytes.length!==item.size||createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex')!==item.sha)throw Error('Kookit text source changed: '+item.path);
}
const lock=JSON.parse(await readFile(path.join(root,'package-lock.json'),'utf8'));
if(lock.packages['node_modules/marked'].version!=='15.0.12')throw Error('Marked not pinned');
const checks=JSON.parse(await readFile(path.join(root,'TEXT-MARKED-SOURCE-CHECKS.json'),'utf8'));
for(const item of checks.files){const bytes=await readFile(path.join(root,'node_modules/marked',item.path));if(createHash('sha256').update(bytes).digest('hex')!==item.sha256)throw Error('Marked source changed');}
for(const item of checks.sources){const bytes=await readFile(path.join(root,'vendor/marked',item.path));if(createHash('sha256').update(bytes).digest('hex')!==item.sha256)throw Error('Marked corresponding source changed');}
if(checks.dist.integrity!==lock.packages['node_modules/marked'].integrity)throw Error('Marked integrity changed');
await mkdir(output,{recursive:true});
const result=await build({absWorkingDir:root,entryPoints:['text-reader.js'],outfile:path.join(output,'engine.js'),bundle:true,format:'iife',platform:'browser',target:['safari16'],minify:false,legalComments:'inline',metafile:true,banner:{js:'// PDFno fixed Kookit Txt/Md/Html + Marked 15.0.12 limited reader. Corresponding source: engine-build/. See Notices.txt.'}});
const inputs=Object.keys(result.metafile.inputs).sort();
const expected=['text-reader.js','text-adapter.js','vendor/kookit/src/libs/html.ts','vendor/kookit/src/libs/textProcessor.ts','node_modules/marked/lib/marked.esm.js'].sort();
if(JSON.stringify(inputs)!==JSON.stringify(expected))throw Error('Unexpected text bundle dependency');
await writeFile(path.join(root,'TEXT-BUNDLE-INPUTS.json'),JSON.stringify(inputs,null,2)+'\n');
const licenses=[['Kookit AGPL-3.0-or-later','vendor/kookit/LICENSE'],['Marked 15.0.12 MIT and Markdown notice','node_modules/marked/LICENSE.md']];
let notices='PDFno text modifications: AGPL-3.0-or-later. Actual runtime: fixed Kookit html/textProcessor sources and Marked 15.0.12. No chardet/mhtml2html/GeneralRender/cache/Rangy/fonts. Corresponding source: engine-build/.\n';
for(const [label,file] of licenses)notices+='\n===== '+label+' =====\n'+await readFile(path.join(root,file),'utf8');
await writeFile(path.join(output,'Notices.txt'),notices);
console.log('Text bundle verified:',inputs.length,'inputs; Kookit + Marked only.');
