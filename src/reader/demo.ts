import type { DemoDocument } from '../domain/types';
/** Self-authored text fixtures. No PDF/EPUB parser is included. */
export const documents: DemoDocument[] = [
  {
    id: 'demo-ja',
    editionId: 'demo-ja-v1',
    title: '少しずつ、読む',
    language: 'ja',
    fingerprint:
      'ceaad9e0b01086a46b976a014722f327d6c11a5c0a9d3c09b178da163070b234',
    pages: [
      {
        title: '01 · 読む習慣',
        blocks: [
          {
            id: 'ja-1',
            text: '本を読みます。毎日、少しずつ学びます。',
            reading: {
              base: '本',
              ruby: 'ほん',
            },
          },
          {
            id: 'ja-2',
            text: '昨日は雨でした。今日は図書館で友達と会います。',
          },
        ],
      },
      {
        title: '02 · 原文をたどる',
        blocks: [
          {
            id: 'ja-3',
            text: '同じ言葉。もう一度、同じ言葉。😀を見つけました。',
          },
        ],
      },
    ],
  },
  {
    id: 'demo-en',
    editionId: 'demo-en-v1',
    title: 'A window into words',
    language: 'en',
    fingerprint:
      'fe50390b8c1bf6499260e9549839c4dc05ac6d93de9f15606805ca8858d8f17b',
    pages: [
      {
        title: '01 · A reading practice',
        blocks: [
          {
            id: 'en-1',
            text: 'Reading opens a small window onto a wider world.',
          },
          {
            id: 'en-2',
            text: 'If I have time tomorrow, I will read another chapter.',
          },
        ],
      },
      {
        title: '02 · Keeping a note',
        blocks: [
          {
            id: 'en-3',
            text: 'The note that I wrote yesterday helped me remember the sentence.',
          },
        ],
      },
    ],
  },
];
