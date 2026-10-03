// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {readFile,writeFile} from 'node:fs/promises';
import {convertDOCX} from './docx-adapter.js';
const root=new URL('../apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/',import.meta.url);
const data=await readFile(new URL('mammoth-sample.docx',root));
const result=await convertDOCX(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
await writeFile(new URL('mammoth-extraction.json',root),JSON.stringify(result.document,null,2)+'\n');
console.log('Generated actual pinned-Mammoth source DTO from original fixture.');
