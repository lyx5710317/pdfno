// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

test('actual pinned Rangy utility rejects prototype keys and processes ordinary options',async()=>{
  const metadata=JSON.parse(await readFile(new URL('node_modules/rangy/package.json',import.meta.url),'utf8'));
  assert.equal(metadata.version,'1.3.2');
  const source=await readFile(new URL('node_modules/rangy/lib/rangy-core.js',import.meta.url),'utf8');
  const context=vm.createContext({module:{exports:{}},exports:{},console:{log(){}}});
  vm.runInContext(source,context,{timeout:3000});
  // All pollution attempts occur in a disposable VM, never in the host prototype or a user's book context.
  const result=vm.runInContext(`(()=>{
    const rangy=module.exports;
    const target={safe:{}};
    const payload=JSON.parse('{"__proto__":{"PDFNO_POLLUTION":true},"constructor":{"prototype":{"PDFNO_POLLUTION":true}},"prototype":{"PDFNO_POLLUTION":true},"safe":{"next":42}}');
    rangy.util.extend(target,payload,true);
    return JSON.stringify({polluted:({}).PDFNO_POLLUTION===true,ownProto:Object.hasOwn(target,'__proto__'),ownConstructor:Object.hasOwn(target,'constructor'),ownPrototype:Object.hasOwn(target,'prototype'),next:target.safe.next});
  })()`,context,{timeout:3000});
  assert.deepEqual(JSON.parse(result),{polluted:false,ownProto:false,ownConstructor:false,ownPrototype:false,next:42});
});
