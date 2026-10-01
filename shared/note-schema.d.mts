import type { LearningNote } from '../src/domain/types';
export function validNote(n: unknown): n is LearningNote;
export function parseStore(raw: string): LearningNote[];
