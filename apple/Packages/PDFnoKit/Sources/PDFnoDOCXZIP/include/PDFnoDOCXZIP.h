// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#ifndef PDFNO_DOCX_ZIP_H
#define PDFNO_DOCX_ZIP_H
#include <stddef.h>
#include <stdint.h>
int pdfno_docx_inflate(const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size);
uint32_t pdfno_docx_crc(const uint8_t *input, size_t input_size);
#endif
