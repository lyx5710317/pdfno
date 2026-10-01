import type { LearningNote } from '../domain/types';
import { parseStore, validNote } from '../../shared/note-schema.mjs';
const key = 'pdfno-demo-notes-v1';
export async function loadNotes(): Promise<LearningNote[]> {
  if (window.pdfno) return window.pdfno.loadNotes();
  const raw = localStorage.getItem(key);
  return raw ? parseStore(raw) : [];
}
export async function saveNote(note: LearningNote): Promise<LearningNote[]> {
  if (window.pdfno) return window.pdfno.saveNote(note);
  if (!validNote(note)) throw new Error('NOTE_INVALID');
  const notes = await loadNotes();
  const i = notes.findIndex((n) => n.id === note.id);
  if (i >= 0) {
    if (note.revision !== notes[i].revision + 1)
      throw new Error('REVISION_CONFLICT');
    notes[i] = note;
  } else notes.push(note);
  localStorage.setItem(key, JSON.stringify({ schemaVersion: 1, notes }));
  return notes;
}
