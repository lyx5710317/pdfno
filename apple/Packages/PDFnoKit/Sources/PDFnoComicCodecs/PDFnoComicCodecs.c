// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#define PDFNO_CODEC_ALLOC_IMPLEMENTATION 1
#include "PDFnoComicCodecs.h"
#include "PDFnoBudget.h"
#include "archive.h"
#include "archive_entry.h"
#include <errno.h>

typedef union Allocation Allocation;
union Allocation {
    max_align_t alignment;
    struct { size_t bytes; struct PDFnoComicDecoder *owner; Allocation *next, *previous; } h;
};
struct PDFnoComicDecoder {
    struct archive *archive;
    size_t limit, live, peak;
    int exhausted;
    Allocation *allocations;
};
static _Thread_local PDFnoComicDecoder *active;

void *pdfno_codec_malloc(size_t n) {
    PDFnoComicDecoder *d = active;
    if (!d || n > SIZE_MAX - sizeof(Allocation) || n + sizeof(Allocation) > d->limit - d->live) {
        if (d) d->exhausted = 1;
        errno = ENOMEM; return NULL;
    }
    Allocation *a = malloc(sizeof(Allocation) + n);
    if (!a) { d->exhausted = 1; return NULL; }
    a->h.bytes = sizeof(Allocation) + n; a->h.owner = d; a->h.previous = NULL; a->h.next = d->allocations;
    if (a->h.next) a->h.next->h.previous = a;
    d->allocations = a; d->live += a->h.bytes;
    if (d->live > d->peak) d->peak = d->live;
    return a + 1;
}
void pdfno_codec_free(void *p) {
    if (!p) return;
    Allocation *a = (Allocation *)p - 1;
    PDFnoComicDecoder *d = a->h.owner;
    if (a->h.previous) a->h.previous->h.next = a->h.next; else d->allocations = a->h.next;
    if (a->h.next) a->h.next->h.previous = a->h.previous;
    d->live -= a->h.bytes; free(a);
}
void *pdfno_codec_calloc(size_t n, size_t size) {
    if (size && n > SIZE_MAX / size) { if (active) active->exhausted = 1; errno = ENOMEM; return NULL; }
    void *p = pdfno_codec_malloc(n * size); if (p) memset(p, 0, n * size); return p;
}
void *pdfno_codec_realloc(void *p, size_t n) {
    if (!p) return pdfno_codec_malloc(n);
    if (!n) { pdfno_codec_free(p); return NULL; }
    Allocation *a = (Allocation *)p - 1;
    // Count old + new simultaneously; measured peak bounds real transient allocations too.
    void *q = pdfno_codec_malloc(n);
    if (q) { size_t old = a->h.bytes - sizeof(Allocation); memcpy(q, p, old < n ? old : n); pdfno_codec_free(p); }
    return q;
}
char *pdfno_codec_strdup(const char *s) {
    size_t n = strlen(s); char *p = pdfno_codec_malloc(n + 1); if (p) memcpy(p, s, n + 1); return p;
}
PDFnoComicDecoder *pdfno_comic_open(const void *bytes, size_t size, int format, size_t limit, int *status) {
    *status = -1;
    if (!bytes || size > 100u * 1024u * 1024u || !limit || limit > 64u * 1024u * 1024u) return NULL;
    PDFnoComicDecoder *d = calloc(1, sizeof(*d)); if (!d) { *status = -2; return NULL; }
    d->limit = limit; active = d;
    d->archive = archive_read_new();
    int result = d->archive ? archive_read_support_filter_none(d->archive) : ARCHIVE_FATAL;
    if (result == ARCHIVE_OK) {
        switch (format) {
        case 7: result = archive_read_support_format_7zip(d->archive); break;
        case 4: result = archive_read_support_format_rar(d->archive); break;
        case 5: result = archive_read_support_format_rar5(d->archive); break;
        default: result = ARCHIVE_FATAL;
        }
    }
    if (result == ARCHIVE_OK) result = archive_read_open_memory(d->archive, bytes, size);
    active = NULL;
    if (result != ARCHIVE_OK || d->exhausted) { *status = d->exhausted ? -2 : -1; pdfno_comic_close(d); return NULL; }
    *status = 0; return d;
}
int pdfno_comic_next(PDFnoComicDecoder *d, PDFnoComicEntry *out) {
    if (!d || !out) return -1;
    active = d; struct archive_entry *e = NULL;
    int result = archive_read_next_header(d->archive, &e);
    if (d->exhausted) { active = NULL; return -2; }
    if (result == ARCHIVE_EOF) { active = NULL; return 0; }
    if (result != ARCHIVE_OK || !e || archive_entry_is_encrypted(e) ||
        archive_entry_symlink(e) || archive_entry_hardlink(e) || archive_entry_sparse_count(e)) { active = NULL; return -1; }
    unsigned type = archive_entry_filetype(e);
    if (type != AE_IFREG && type != AE_IFDIR) { active = NULL; return -1; }
    out->path = archive_entry_pathname_utf8(e); out->size = archive_entry_size(e); out->directory = type == AE_IFDIR;
    active = NULL;
    if (d->exhausted) return -2;
    if (!out->path || out->size < 0 || out->size > 16 * 1024 * 1024 || (out->directory && out->size)) return -1;
    return 1;
}
int64_t pdfno_comic_read(PDFnoComicDecoder *d, void *out, size_t capacity) {
    if (!d || !out || !capacity || capacity > 64 * 1024) return -1;
    active = d; int64_t n = archive_read_data(d->archive, out, capacity); active = NULL;
    if (d->exhausted) return -2;
    return n < 0 ? -1 : n;
}
size_t pdfno_comic_peak(PDFnoComicDecoder *d) { return d ? d->peak : 0; }
size_t pdfno_comic_live(PDFnoComicDecoder *d) { return d ? d->live : 0; }
void pdfno_comic_close(PDFnoComicDecoder *d) {
    if (!d) return;
    active = d; if (d->archive) archive_read_free(d->archive); active = NULL;
    // Preserve failure cleanup even if an upstream exceptional path left an allocation.
    while (d->allocations) pdfno_codec_free(d->allocations + 1);
    free(d);
}
