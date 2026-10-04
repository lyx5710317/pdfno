// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#ifndef PDFNO_COMIC_CODECS_H
#define PDFNO_COMIC_CODECS_H
#include <stddef.h>
#include <stdint.h>
typedef struct PDFnoComicDecoder PDFnoComicDecoder;
typedef struct {
    const char *path;
    int64_t size;
    int directory;
} PDFnoComicEntry;
// 7 = 7z; 4 = RAR4; 5 = RAR5. Caller keeps bounded input alive until close.
PDFnoComicDecoder *pdfno_comic_open(const void *, size_t, int, size_t, int *);
// 1 = entry, 0 = EOF, -1 = unsupported/corrupt, -2 = allocation budget.
int pdfno_comic_next(PDFnoComicDecoder *, PDFnoComicEntry *);
int64_t pdfno_comic_read(PDFnoComicDecoder *, void *, size_t);
size_t pdfno_comic_peak(PDFnoComicDecoder *);
size_t pdfno_comic_live(PDFnoComicDecoder *);
void pdfno_comic_close(PDFnoComicDecoder *);
#endif
