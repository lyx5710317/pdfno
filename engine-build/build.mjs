// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {build} from 'esbuild';
import {readFile, writeFile, mkdir, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.resolve(root, '../apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/EPUB');
await mkdir(output, {recursive: true});
const sourceManifest = JSON.parse(await readFile(path.join(root, 'vendor/manifest.json'), 'utf8'));
for (const file of sourceManifest.files) {
  const data = await readFile(path.join(root, 'vendor/kookit', file.path));
  const hash = createHash('sha1').update(`blob ${data.length}\0`).update(data).digest('hex');
  if (hash !== file.sha) throw Error('Upstream blob changed: ' + file.path);
}
const replacements = {
  'zh-convert': 'export default {s2t: x => x, t2s: x => x};',
  'pdfUtil': 'export function getPDFSearchResult() { throw Error("PDF uses native PDFKit"); }'
};
const result = await build({
  absWorkingDir: root, entryPoints: ['reader.js'], outfile: path.join(output, 'engine.js'),
  bundle: true, format: 'iife', platform: 'browser', target: ['safari16'], minify: false,
  legalComments: 'inline', metafile: true, sourcemap: false,
  banner: {js: '// Kookit 95f602e EPUB profile. Corresponding source: engine-build/. See Notices.txt.'},
  plugins: [{name: 'pdfno-epub-boundary', setup(api) {
    api.onResolve({filter: /(?:zh-convert|pdfUtil)$/}, args => ({path: path.basename(args.path), namespace: 'disabled-feature'}));
    api.onLoad({filter: /.*/, namespace: 'disabled-feature'}, args => ({contents: replacements[args.path], loader: 'js'}));
    api.onLoad({filter: /GeneralRender\.ts$/}, async args => {
      let contents = await readFile(args.path, 'utf8');
      const original = 'this.isAllowScript =\n      this.format === "PDF" || this.isMobile === "yes"\n        ? "yes"\n        : config.isAllowScript || "no";';
      if (!contents.includes(original)) throw Error('Script-disable patch no longer matches');
      contents = contents.replace(original, 'this.isAllowScript = "no"; // PDFno: book scripts always disabled');
      return {contents, loader: 'ts'};
    });
  }}]
});
const inputs = Object.keys(result.metafile.inputs).sort();
if (inputs.some(x => /(?:libs\/pdf\.js|PdfRender|EpubRender|mobi\.js|zh-convert\.ts|pdfUtil\.ts|7z|mammoth)/.test(x))) throw Error('Non-EPUB input entered bundle');
await writeFile(path.join(root, 'BUNDLE-INPUTS.json'), JSON.stringify(inputs, null, 2) + '\n');
let notices = 'PDFno EPUB resource — corresponding source: engine-build/; AGPL-3.0-or-later for PDFno and Kookit.\nCFI upstream declaration: AGPL-3.0; foliate-js: MIT. No relicensing claim.\nJSZip uses its MIT alternative.\n\n';
for (const name of (await readdir(path.join(root, 'licenses'))).sort()) {
  notices += `\n===== ${name} =====\n` + await readFile(path.join(root, 'licenses', name), 'utf8') + '\n';
}
notices += '\n===== Kookit LICENSE =====\n' + await readFile(path.join(root, 'vendor/kookit/LICENSE'), 'utf8');
await writeFile(path.join(output, 'Notices.txt'), notices);
console.log('Built bounded EPUB profile:', inputs.length, 'inputs; no PDF engine.');
