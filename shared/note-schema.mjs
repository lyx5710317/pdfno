// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
const text = (v, max) => typeof v === 'string' && v.length <= max;
const id = (v) => text(v, 100) && v.length > 0;
export function validNote(n) {
  if (
    !n ||
    typeof n !== 'object' ||
    Object.keys(n).some(
      (k) =>
        ![
          'id',
          'bookId',
          'source',
          'quote',
          'userText',
          'aiText',
          'revision',
          'createdAt',
          'updatedAt',
        ].includes(k),
    )
  )
    return false;
  const s = n.source;
  return (
    id(n.id) &&
    id(n.bookId) &&
    text(n.quote, 50000) &&
    n.quote.length > 0 &&
    text(n.userText, 50000) &&
    text(n.aiText, 100000) &&
    Number.isSafeInteger(n.revision) &&
    n.revision > 0 &&
    text(n.createdAt, 40) &&
    text(n.updatedAt, 40) &&
    Number.isFinite(Date.parse(n.createdAt)) &&
    Number.isFinite(Date.parse(n.updatedAt)) &&
    s &&
    id(s.id) &&
    s.bookId === n.bookId &&
    id(s.editionId) &&
    /^[a-f0-9]{64}$/.test(s.sourceFileSha256) &&
    s.extractionVersion === 'demo-text-1' &&
    s.offsetUnit === 'unicode-code-point' &&
    Number.isSafeInteger(s.pageIndex) &&
    s.pageIndex >= 0 &&
    id(s.blockId) &&
    ['selection', 'demo-page'].includes(s.scope) &&
    s.span &&
    Number.isSafeInteger(s.span.start) &&
    Number.isSafeInteger(s.span.end) &&
    s.span.start >= 0 &&
    s.span.end > s.span.start &&
    s.span.end - s.span.start === Array.from(n.quote).length &&
    s.quote &&
    s.quote.exact === n.quote &&
    text(s.quote.prefix, 256) &&
    text(s.quote.suffix, 256) &&
    Object.keys(s).every((k) =>
      [
        'id',
        'bookId',
        'editionId',
        'sourceFileSha256',
        'extractionVersion',
        'offsetUnit',
        'pageIndex',
        'blockId',
        'span',
        'quote',
        'scope',
      ].includes(k),
    ) &&
    Object.keys(s.quote).every((k) =>
      ['exact', 'prefix', 'suffix'].includes(k),
    ) &&
    Object.keys(s.span).every((k) => ['start', 'end'].includes(k))
  );
}
export function parseStore(raw) {
  const data = JSON.parse(raw);
  if (
    data.schemaVersion !== 1 ||
    !Array.isArray(data.notes) ||
    data.notes.length > 2000 ||
    !data.notes.every(validNote) ||
    new Set(data.notes.map((n) => n.id)).size !== data.notes.length
  )
    throw new Error('STORE_INVALID');
  return data.notes;
}
