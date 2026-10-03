// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Apple SDK/system zlib only. No downloaded implementation or archive extraction.
#include "PDFnoDOCXZIP.h"
#include <zlib.h>
#include <limits.h>
int pdfno_docx_inflate(const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size) {
    if (input_size > UINT_MAX || output_size > UINT_MAX) return 0;
    uint8_t empty;
    z_stream stream = {0};
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)input_size;
    stream.next_out = output_size ? output : &empty;
    stream.avail_out = output_size ? (uInt)output_size : 1;
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return 0;
    int status = inflate(&stream, Z_FINISH);
    int valid = status == Z_STREAM_END && stream.total_in == input_size && stream.total_out == output_size;
    inflateEnd(&stream);
    return valid;
}
uint32_t pdfno_docx_crc(const uint8_t *input, size_t input_size) {
    return (uint32_t)crc32(0, input, (uInt)input_size);
}
