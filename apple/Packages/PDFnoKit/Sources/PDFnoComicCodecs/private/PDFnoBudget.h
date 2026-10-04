// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#ifndef PDFNO_BUDGET_H
#define PDFNO_BUDGET_H
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stddef.h>
#include "PDFnoCodecNames.h"
void *pdfno_codec_malloc(size_t);
void *pdfno_codec_calloc(size_t, size_t);
void *pdfno_codec_realloc(void *, size_t);
void pdfno_codec_free(void *);
char *pdfno_codec_strdup(const char *);
#if !defined(PDFNO_CODEC_ALLOC_IMPLEMENTATION) && !defined(PDFNO_CODEC_WRAPPER)
#define malloc pdfno_codec_malloc
#define calloc pdfno_codec_calloc
#define realloc pdfno_codec_realloc
#define free pdfno_codec_free
#define strdup pdfno_codec_strdup
#endif
#endif
