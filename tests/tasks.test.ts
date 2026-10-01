import { describe, it, expect } from 'vitest';
import { documents } from '../src/reader/demo';
import { snapshot } from '../src/domain/anchors';
import { applyEvent, mockProvider } from '../src/domain/tasks';
import type { LearningTask } from '../src/domain/types';
const source = snapshot(documents[0], 0, 'ja-1', 0, 7);
describe('mock task contract', () => {
  it('preserves request source while a new selection is captured', async () => {
    let task: LearningTask = {
      id: 'a',
      bookId: source.bookId,
      mode: 'grammar',
      source,
      status: 'queued',
      output: '',
    };
    const other = snapshot(documents[1], 0, 'en-1', 0, 7);
    for await (const e of mockProvider('success').analyze(
      source,
      'grammar',
      new AbortController().signal,
    ))
      task = applyEvent(task, e);
    expect(task.source).toBe(source);
    expect(task.source.bookId).not.toBe(other.bookId);
    expect(task.status).toBe('completed');
    expect(applyEvent(task, { type: 'fail', code: 'late' })).toBe(task);
  });
  it('supports actual cancellation of a waiting generator', async () => {
    const c = new AbortController();
    const iterable = mockProvider('hold').analyze(source, 'translate', c.signal);
    const stream = iterable[Symbol.asyncIterator]();
    expect((await stream.next()).done).toBe(false);
    const pending = stream.next();
    c.abort();
    expect((await pending).done).toBe(true);
  });
  it('reports failure and partial results independently', async () => {
    for (const scenario of ['rate-limit', 'partial'] as const) {
      let task: LearningTask = {
        id: scenario,
        bookId: source.bookId,
        mode: 'translate',
        source,
        status: 'queued',
        output: '',
      };
      for await (const e of mockProvider(scenario).analyze(
        source,
        'translate',
        new AbortController().signal,
      ))
        task = applyEvent(task, e);
      expect(task.status).toBe(scenario === 'partial' ? 'partial' : 'failed');
      expect(Boolean(task.output)).toBe(scenario === 'partial');
    }
  });
});
