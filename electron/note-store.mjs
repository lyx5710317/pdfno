// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import { readFile, writeFile, rename, mkdir, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { parseStore, validNote } from '../shared/note-schema.mjs';
export { parseStore, validNote };
export class NoteStore {
  constructor(directory) {
    this.directory = directory;
    this.file = path.join(directory, 'notes-v1.json');
    this.queue = Promise.resolve();
  }
  async load() {
    try {
      const raw = await readFile(this.file, 'utf8');
      if (Buffer.byteLength(raw) > 20 * 1024 * 1024)
        throw new Error('STORE_INVALID');
      return parseStore(raw);
    } catch (e) {
      if (e.code === 'ENOENT') return [];
      throw new Error('STORE_UNREADABLE', { cause: e });
    }
  }
  save(note) {
    const work = this.queue.then(async () => {
      if (!validNote(note)) throw new Error('NOTE_INVALID');
      const notes = await this.load();
      const index = notes.findIndex((n) => n.id === note.id);
      if (index >= 0) {
        if (
          note.revision !== notes[index].revision + 1 ||
          note.bookId !== notes[index].bookId ||
          note.createdAt !== notes[index].createdAt
        )
          throw new Error('REVISION_CONFLICT');
        notes[index] = note;
      } else {
        if (note.revision !== 1 || notes.length >= 2000)
          throw new Error('NOTE_LIMIT');
        notes.push(note);
      }
      await mkdir(this.directory, { recursive: true, mode: 0o700 });
      try {
        await copyFile(this.file, this.file + '.backup');
      } catch (e) {
        if (e.code !== 'ENOENT') throw e;
      }
      const temp = this.file + '.tmp';
      await writeFile(
        temp,
        JSON.stringify({ schemaVersion: 1, notes }, null, 2),
        { mode: 0o600 },
      );
      await rename(temp, this.file);
      return notes;
    });
    this.queue = work.catch(() => {});
    return work;
  }
}
