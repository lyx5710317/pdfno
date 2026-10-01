import { describe, it, expect } from 'vitest';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { NoteStore, parseStore } from '../electron/note-store.mjs';
import { allowedRenderer, resourcePath } from '../electron/security.mjs';
import { validateProvider } from '../src/domain/provider';
import { snapshot } from '../src/domain/anchors';
import { documents } from '../src/reader/demo';
const source = snapshot(documents[0], 0, 'ja-1', 0, 7);
const note = {
  id: 'note-1',
  bookId: source.bookId,
  source,
  quote: source.quote.exact,
  userText: 'my edit',
  aiText: '',
  revision: 1,
  createdAt: '2026-10-01T00:00:00Z',
  updatedAt: '2026-10-01T00:00:00Z',
};
describe('storage and security boundaries', () => {
  it('persists revisions, keeps a backup and rejects stale writes', async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), 'pdfno-test-'));
    try {
      const store = new NoteStore(directory);
      await store.save(note);
      await store.save({ ...note, userText: 'edited', revision: 2 });
      expect((await new NoteStore(directory).load())[0].userText).toBe(
        'edited',
      );
      expect(
        parseStore(await readFile(store.file + '.backup', 'utf8'))[0].revision,
      ).toBe(1);
      await expect(store.save(note)).rejects.toThrow('REVISION_CONFLICT');
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
  it('preserves unreadable or future-version data and refuses overwrite', async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), 'pdfno-test-'));
    try {
      const store = new NoteStore(directory);
      const raw = JSON.stringify({ schemaVersion: 99, notes: [] });
      await writeFile(store.file, raw);
      await expect(store.save(note)).rejects.toThrow('STORE_UNREADABLE');
      expect(await readFile(store.file, 'utf8')).toBe(raw);
      expect(() =>
        parseStore(
          JSON.stringify({
            schemaVersion: 1,
            notes: [{ ...note, apiKey: 'not-allowed' }],
          }),
        ),
      ).toThrow();
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
  it('denies navigation origins and traversal', () => {
    expect(allowedRenderer('pdfno://app/index.html')).toBe(true);
    expect(allowedRenderer('pdfno://evil/index.html')).toBe(false);
    expect(allowedRenderer('https://example.com')).toBe(false);
    expect(allowedRenderer('http://127.0.0.1:5173', true)).toBe(true);
    expect(allowedRenderer('http://localhost:5173', true)).toBe(false);
    expect(() =>
      resourcePath('pdfno://app/%2e%2e%2fsecret', '/app/dist'),
    ).toThrow();
  });
  it('rejects credential URLs and insecure remote endpoints', () => {
    expect(
      validateProvider({
        endpoint: 'http://127.0.0.1:11434/v1',
        model: 'local',
      }),
    ).toBeNull();
    expect(
      validateProvider({
        endpoint: 'https://api.example.com/v1',
        model: 'model',
      }),
    ).toBeNull();
    for (const endpoint of [
      'http://example.com/v1',
      'https://name:pass@example.com/v1',
      'https://example.com/v1?key=x',
    ])
      expect(validateProvider({ endpoint, model: 'model' })).not.toBeNull();
  });
});
