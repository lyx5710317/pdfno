// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
export type Mode = 'translate' | 'grammar' | 'reading' | 'page';
export type TaskStatus =
  'queued' | 'streaming' | 'completed' | 'partial' | 'failed' | 'cancelled';
export interface DemoBlock {
  id: string;
  text: string;
  reading?: { base: string; ruby: string };
}
export interface DemoDocument {
  id: string;
  editionId: string;
  title: string;
  language: 'ja' | 'en';
  fingerprint: string;
  pages: { title: string; blocks: DemoBlock[] }[];
}
export interface SourceSnapshot {
  readonly id: string;
  readonly bookId: string;
  readonly editionId: string;
  readonly sourceFileSha256: string;
  readonly extractionVersion: 'demo-text-1';
  readonly offsetUnit: 'unicode-code-point';
  readonly pageIndex: number;
  readonly blockId: string;
  readonly span: { readonly start: number; readonly end: number };
  readonly quote: {
    readonly exact: string;
    readonly prefix: string;
    readonly suffix: string;
  };
  readonly scope: 'selection' | 'demo-page';
}
export interface LearningTask {
  id: string;
  bookId: string;
  mode: Mode;
  source: SourceSnapshot;
  status: TaskStatus;
  output: string;
  error?: string;
}
export type ModelEvent =
  | { type: 'stream'; text: string }
  | { type: 'complete' }
  | { type: 'partial'; reason: string }
  | { type: 'fail'; code: string };
export interface LearningNote {
  id: string;
  bookId: string;
  source: SourceSnapshot;
  quote: string;
  userText: string;
  aiText: string;
  revision: number;
  createdAt: string;
  updatedAt: string;
}
export interface NativeCapabilities {
  schemaVersion: 1;
  bridgeVersion: string;
  platform: 'macOS';
  keychain: 'not-integrated';
  iCloud: 'disabled';
}
export interface DesktopBridge {
  loadNotes(): Promise<LearningNote[]>;
  saveNote(note: LearningNote): Promise<LearningNote[]>;
  nativeCapabilities(): Promise<NativeCapabilities | { unavailable: true }>;
}
declare global {
  interface Window {
    pdfno?: DesktopBridge;
  }
}
