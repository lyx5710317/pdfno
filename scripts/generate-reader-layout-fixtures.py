#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Reproduce the original annotation and Aa EPUB fixtures without changing their bytes.

All prose is PDFno-authored test text. The historical ZIP dates and attributes
are fixed intentionally; no current time, external files, or network are used.
"""
from pathlib import Path
import argparse
import hashlib
import io
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures'

ANNOTATION_CONTAINER = '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'
ANNOTATION_OPF = '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:pdfno:self-authored-annotation-1</dc:identifier><dc:title>自作の批注資料</dc:title><dc:language>ja</dc:language><meta property="dcterms:modified">2026-10-10T00:00:00Z</meta></metadata><manifest><item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>'
ANNOTATION_NAV = '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>目次</title></head><body><nav epub:type="toc"><ol><li><a href="one.xhtml">自作の第一章</a></li><li><a href="two.xhtml">自作の第二章</a></li></ol></nav></body></html>'
ANNOTATION_BODY = '<p>日本語の原文に下線と批注を付けます。がと🌸、数字2026、Englishも含みます。</p>' + '<p>これは自作の読書資料です。第一章の文章を学び、選んだ原文に戻ります。</p>' * 50
ANNOTATION_CHAPTER = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>第一章</title></head><body><h1>第一章</h1>{body}</body></html>'
AA_CONTAINER = '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'
AA_OPF = '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:pdfno:aa-original-1</dc:identifier><dc:title>PDFno Original EPUB</dc:title><dc:language>ja</dc:language><meta property="dcterms:modified">2026-10-03T00:00:00Z</meta></metadata><manifest><item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/><item id="en" href="english.xhtml" media-type="application/xhtml+xml"/><item id="ja" href="japanese.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="en"/><itemref idref="ja"/></spine></package>'
AA_NAV = '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="english.xhtml">English chapter</a></li><li><a href="japanese.xhtml">日本語とルビ</a></li></ol></nav></body></html>'
AA_BODY = ''.join('<p>第{i}段落。<ruby>日本語<rt>にほんご</rt></ruby>の原文を読みます。🌸 café 。同じ言葉でも場所は違います。</p>'.format(i=i) for i in range(1, 20))
AA_CHAPTER = '<html xmlns="http://www.w3.org/1999/xhtml" lang="ja"><head><title>第一章</title></head><body><h1>第一章</h1>{body}</body></html>'

EXPECTED = {
    'ReadingModes/original-vertical-continuous.epub': '0839cc8788c33696f6b89c27bcbf6fb23193a108aaff0db5ca23edf65a3f1f26',
    'Annotations/original-japanese-annotations.epub': '7a4b7100f072233f3462d0645c5593b64ace41ebd06c8d278c7627b1cad9f484',
    'ReadingModes/original-aa-fixed.epub': 'e985b16039bd346d8711cfaaca7dd76bac11b70fb65f24d54081abc70e40d107',
    'ReadingModes/original-aa-japanese.epub': 'be3e7fe22c22e19a76b95b117d63ab3e0b0589c19264299f5bb20c57e79bc649',
}


def archive(annotation=False, fixed=False):
    container, opf, nav = (ANNOTATION_CONTAINER, ANNOTATION_OPF, ANNOTATION_NAV) if annotation else (AA_CONTAINER, AA_OPF, AA_NAV)
    chapter = (ANNOTATION_CHAPTER.format(body=ANNOTATION_BODY) if annotation else AA_CHAPTER.format(body=AA_BODY))
    if fixed:
        opf = opf.replace('</metadata>', '<meta property="rendition:layout">pre-paginated</meta></metadata>')
    first, second = ('one.xhtml', 'two.xhtml') if annotation else ('english.xhtml', 'japanese.xhtml')
    entries = [('mimetype', 'application/epub+zip'), ('META-INF/container.xml', container),
               ('OEBPS/book.opf', opf), ('OEBPS/nav.xhtml', nav),
               ('OEBPS/' + first, chapter), ('OEBPS/' + second, chapter.replace('第一章', '第二章'))]
    return zip_entries(entries, annotation=annotation)


def zip_entries(entries, annotation=False):
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w') as zipped:
        for name, text in entries:
            item = zipfile.ZipInfo(name, (2026, 10, 10, 16, 25, 20) if annotation else (2026, 10, 3, 0, 0, 0))
            item.create_system = 3
            item.external_attr = 25165824 if annotation else 2175008768
            item.compress_type = zipfile.ZIP_STORED if annotation or name == 'mimetype' else zipfile.ZIP_DEFLATED
            zipped.writestr(item, text.encode('utf-8'))
    return output.getvalue()


def continuous_archive():
    # Retain a short English selection and the original canonical section names,
    # while making the document body Japanese for the vertical-layout policy.
    paragraphs = '<p>window — an original PDFno selection sample.</p>' + ''.join(
        f'<p>第{i}段落。これは自作の読書資料です。窓のそばで原文を読み、選んだ場所と気づきを記録します。</p>'
        for i in range(1, 81))
    first = AA_CHAPTER.format(body=paragraphs)
    second = AA_CHAPTER.format(body=AA_BODY).replace('第一章', '第二章')
    return zip_entries([('mimetype', 'application/epub+zip'), ('META-INF/container.xml', AA_CONTAINER),
                        ('OEBPS/book.opf', AA_OPF), ('OEBPS/nav.xhtml', AA_NAV),
                        ('OEBPS/english.xhtml', first), ('OEBPS/japanese.xhtml', second)])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify generated and checked-in bytes without writing.')
    args = parser.parse_args()
    for relative, expected in EXPECTED.items():
        data = (continuous_archive() if relative.endswith('-vertical-continuous.epub') else
                archive(annotation=relative.startswith('Annotations/'), fixed=relative.endswith('-fixed.epub')))
        actual = hashlib.sha256(data).hexdigest()
        if actual != expected:
            raise SystemExit(f'Generated fixture changed: {relative}: {actual}')
        path = FIXTURES / relative
        if args.check:
            if path.read_bytes() != data:
                raise SystemExit(f'Checked-in fixture differs from its original generator: {relative}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(f'Verified {len(EXPECTED)} byte-identical original reader EPUB fixtures.' if args.check else
          f'Generated {len(EXPECTED)} original reader EPUB fixtures.')


if __name__ == '__main__':
    main()
