/** Inventory from Koodo 90e659f CLAUDE.md; these are candidate formats, not implemented capabilities. */
export const candidateFormats = [
  'PDF',
  'EPUB',
  'MOBI',
  'AZW3',
  'AZW',
  'TXT',
  'FB2',
  'CBR',
  'CBZ',
  'CBT',
  'CB7',
  'MD',
  'DOCX',
  'HTML',
  'XML',
  'XHTML',
  'MHTML',
  'HTM',
] as const;
export const readerCapabilities = {
  engine: 'self-authored-demo',
  realFileReading: false,
  demoSelection: true,
  demoPageSnapshot: true,
} as const;
export interface ReaderAdapter {
  probe(): typeof readerCapabilities;
}
export const demoAdapter: ReaderAdapter = { probe: () => readerCapabilities };
