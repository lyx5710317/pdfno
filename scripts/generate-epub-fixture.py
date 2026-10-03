#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Deterministic original EPUB, no fonts, images, external books or timestamps."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_STORED, ZIP_DEFLATED
from io import BytesIO
ROOT = Path(__file__).resolve().parents[1]
entries = {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/book.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:pdfno:original-epub-1</dc:identifier><dc:title>PDFno Original EPUB</dc:title><dc:language>en</dc:language><meta property="dcterms:modified">2026-10-03T00:00:00Z</meta></metadata><manifest><item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/><item id="en" href="english.xhtml" media-type="application/xhtml+xml"/><item id="ja" href="japanese.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="en"/><itemref idref="ja"/></spine></package>',
    'OEBPS/nav.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="english.xhtml">English chapter</a></li><li><a href="japanese.xhtml">日本語とルビ</a></li></ol></nav></body></html>',
    'OEBPS/english.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>English</title></head><body><h1>English chapter</h1><p>window — an original PDFno selection sample.</p>' + ''.join(f'<p>Paragraph {i}: Reading by the window brings a quiet moment. We keep the source unchanged and save our own observations. Repeated words have distinct source positions. Emoji 🌸 and combining café stay intact.</p>' for i in range(1,81)) + '</body></html>',
    'OEBPS/japanese.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml" lang="ja"><head><title>日本語</title></head><body><h1>日本語とルビ</h1><p><ruby>日本語<rt>にほんご</rt></ruby>を読みます。🌸 café</p>' + ''.join(f'<p>第{i}段落。<ruby>窓<rt>まど</rt></ruby>のそばで本を読みます。原文とルビをそのまま残します。同じ言葉でも場所は違います。</p>' for i in range(1,61)) + '</body></html>'
}
def make(values):
    buffer = BytesIO()
    with ZipFile(buffer, 'w') as archive:
        for name, value in values.items():
            info = ZipInfo(name, (2026,10,3,0,0,0)); info.compress_type = ZIP_STORED if name=='mimetype' else ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, value.encode('utf-8'))
    return buffer.getvalue()
if __name__ == '__main__':
    fixture = make(entries)
    for suffix in ['Sources/PDFnoUI/Resources/study-sample.epub','Tests/PDFnoKitTests/Fixtures/study-sample.epub']:
        (ROOT/'apple/Packages/PDFnoKit'/suffix).write_bytes(fixture)
    unsafe = dict(entries)
    unsafe['OEBPS/english.xhtml'] = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Security original fixture</title><style>@import "https://example.invalid/bad.css";p{background:url(https://example.invalid/image.png)}</style></head><body onload="window.PDFNO_BOOK_SCRIPT=1"><script>window.PDFNO_BOOK_SCRIPT=1</script><p>Safe original text.</p><img src="https://example.invalid/remote.png"/><a href="javascript:alert(1)">Blocked link</a></body></html>'
    (ROOT/'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/security-sample.epub').write_bytes(make(unsafe))
    print('Generated original EPUB fixtures:',len(fixture),'bytes')
