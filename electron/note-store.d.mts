import type { LearningNote } from '../src/domain/types';
export function validNote(n: unknown): n is LearningNote;
export function parseStore(raw: string): LearningNote[];
export class NoteStore {
  constructor(directory: string);
  file: string;
  load(): Promise<LearningNote[]>;
  save(note: LearningNote): Promise<LearningNote[]>;
}
