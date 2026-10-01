import type { LearningNote } from './types';
/** Proposed contracts only. No Bookno endpoint, CloudKit container or converter is connected. */
export interface CoverAsset {
  assetId: string;
  sha256: string;
  mimeType: 'image/png' | 'image/jpeg';
  byteLength: number;
  width: number;
  height: number;
}
export interface BooknoBook {
  externalBookID: string;
  title: string;
  authors: string[];
  cover: CoverAsset;
}
export interface BooknoExchangeAdapter {
  preview(
    book: BooknoBook,
    notes: LearningNote[],
  ): Promise<{ books: number; covers: number; notes: number }>;
}
export interface SyncAdapter {
  capabilities(): {
    enabled: boolean;
    backend: 'undecided' | 'iCloudDrive' | 'CloudKit';
  };
}
export interface ConversionAdapter {
  probe(
    inputFormat: string,
    targetFormat: string,
  ): { supported: boolean; reason: string };
}
export const moduleStatus = {
  bookno: '契约草案；API 与封面传输未接入',
  icloud: '方案与设备范围待定；权限未启用',
  conversion: '转换方向与引擎待选；未接入',
} as const;
