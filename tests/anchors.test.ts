import { describe, it, expect } from 'vitest';
import { JSDOM } from 'jsdom';
import { documents } from '../src/reader/demo';
import {
  cpToUtf16,
  utf16ToCp,
  snapshot,
  resolve,
  validateQuotedSpan,
  canonicalText,
  selectionOffsets,
} from '../src/domain/anchors';
describe('source anchors', () => {
  it('maps supplementary characters without splitting UTF-16 pairs', () => {
    expect(cpToUtf16('A😀か\u3099', 2)).toBe(3);
    expect(utf16ToCp('A😀B', 3)).toBe(2);
    expect(() => utf16ToCp('A😀B', 2)).toThrow();
    expect(() => cpToUtf16('A', 1.5)).toThrow();
  });
  it('keeps duplicate quotations distinct and rejects replaced editions', () => {
    const d = documents[0];
    const b = d.pages[1].blocks[0];
    const start = Array.from(
      b.text.slice(0, b.text.lastIndexOf('同じ言葉')),
    ).length;
    const s = snapshot(d, 1, b.id, start, start + 5);
    expect(s.quote.exact).toBe('同じ言葉。');
    expect(s.quote.prefix).toContain('もう一度');
    expect(resolve(d, s)).toBe('exact');
    expect(resolve({ ...d, editionId: 'replacement' }, s)).toBe('needs-rebind');
    expect(Object.isFrozen(s.quote)).toBe(true);
  });
  it('excludes author ruby and preserves kana and combining marks', () => {
    const dom = new JSDOM(
      '<p id="p"><ruby>本<rt>ほん</rt><rp>(</rp></ruby>を😀読みます。</p>',
    );
    const p = dom.window.document.querySelector('#p')!;
    expect(canonicalText(p)).toBe('本を😀読みます。');
    const range = dom.window.document.createRange();
    range.selectNodeContents(p);
    expect(selectionOffsets(p, range)).toEqual({ start: 0, end: 8 });
  });
  it('rejects fabricated model spans and out-of-range snapshots', () => {
    expect(validateQuotedSpan('😀を読む', 'を', 1, 2)).toBe(true);
    expect(validateQuotedSpan('😀を読む', 'を', 0, 1)).toBe(false);
    expect(() => snapshot(documents[0], 0, 'ja-1', 0, 1000)).toThrow(
      'INVALID_SPAN',
    );
  });
});
