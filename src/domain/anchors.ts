import type { DemoDocument, SourceSnapshot } from './types';
export const codePoints = (text: string) => Array.from(text);
export function cpToUtf16(text: string, offset: number): number {
  if (
    !Number.isInteger(offset) ||
    offset < 0 ||
    offset > codePoints(text).length
  )
    throw new Error('INVALID_SPAN');
  return codePoints(text).slice(0, offset).join('').length;
}
export function utf16ToCp(text: string, offset: number): number {
  if (
    !Number.isInteger(offset) ||
    offset < 0 ||
    offset > text.length ||
    cpToUtf16(text, codePoints(text.slice(0, offset)).length) !== offset
  )
    throw new Error('INVALID_UTF16_BOUNDARY');
  return codePoints(text.slice(0, offset)).length;
}
export function snapshot(
  document: DemoDocument,
  pageIndex: number,
  blockId: string,
  start: number,
  end: number,
  scope: SourceSnapshot['scope'] = 'selection',
): SourceSnapshot {
  const page = document.pages[pageIndex];
  const text =
    scope === 'demo-page'
      ? page?.blocks.map((b) => b.text).join('\n')
      : page?.blocks.find((b) => b.id === blockId)?.text;
  if (
    text === undefined ||
    !Number.isInteger(start) ||
    !Number.isInteger(end) ||
    start < 0 ||
    end <= start ||
    end > codePoints(text).length
  )
    throw new Error('INVALID_SPAN');
  const cp = codePoints(text);
  return Object.freeze({
    id: crypto.randomUUID(),
    bookId: document.id,
    editionId: document.editionId,
    sourceFileSha256: document.fingerprint,
    extractionVersion: 'demo-text-1',
    offsetUnit: 'unicode-code-point',
    pageIndex,
    blockId,
    span: Object.freeze({ start, end }),
    quote: Object.freeze({
      exact: cp.slice(start, end).join(''),
      prefix: cp.slice(Math.max(0, start - 64), start).join(''),
      suffix: cp.slice(end, end + 64).join(''),
    }),
    scope,
  });
}
export function resolve(
  document: DemoDocument,
  source: SourceSnapshot,
): 'exact' | 'needs-rebind' | 'source-missing' {
  if (document.id !== source.bookId) return 'source-missing';
  if (
    document.editionId !== source.editionId ||
    document.fingerprint !== source.sourceFileSha256
  )
    return 'needs-rebind';
  try {
    const current = snapshot(
      document,
      source.pageIndex,
      source.blockId,
      source.span.start,
      source.span.end,
      source.scope,
    );
    return current.quote.exact === source.quote.exact &&
      current.quote.prefix === source.quote.prefix &&
      current.quote.suffix === source.quote.suffix
      ? 'exact'
      : 'needs-rebind';
  } catch {
    return 'needs-rebind';
  }
}
export function validateQuotedSpan(
  text: string,
  quote: string,
  start: number,
  end: number,
): boolean {
  return (
    Number.isInteger(start) &&
    Number.isInteger(end) &&
    start >= 0 &&
    end > start &&
    end <= codePoints(text).length &&
    codePoints(text).slice(start, end).join('') === quote
  );
}
/** Does not use normalize/trim; author ruby annotations never enter canonical text. */
export function canonicalText(node: Node): string {
  if (node.nodeType === 3) return node.textContent ?? '';
  if (
    node.nodeType === 1 &&
    ['RT', 'RP', 'SCRIPT', 'STYLE'].includes((node as Element).tagName)
  )
    return '';
  return Array.from(node.childNodes).map(canonicalText).join('');
}
export function selectionOffsets(
  block: Element,
  range: Range,
): { start: number; end: number } | null {
  if (
    !block.contains(range.startContainer) ||
    !block.contains(range.endContainer)
  )
    return null;
  const prefix = range.cloneRange();
  prefix.selectNodeContents(block);
  prefix.setEnd(range.startContainer, range.startOffset);
  const start = codePoints(canonicalText(prefix.cloneContents())).length;
  const selected = canonicalText(range.cloneContents());
  if (!selected) return null;
  return { start, end: start + codePoints(selected).length };
}
