#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Deterministic original OOXML fixtures; no Word/third-party document or font needed."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_STORED, ZIP_DEFLATED
from io import BytesIO
from xml.sax.saxutils import escape
ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX'
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R = 'http://schemas.openxmlformats.org/package/2006/relationships'
T = 'http://schemas.openxmlformats.org/package/2006/content-types'
OFFICE = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument'
entries = {
    '[Content_Types].xml': f'<Types xmlns="{T}"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
    '_rels/.rels': f'<Relationships xmlns="{R}"><Relationship Id="rId1" Type="{OFFICE}" Target="word/document.xml"/></Relationships>',
    'word/styles.xml': f'<w:styles xmlns:w="{W}"><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:outlineLvl w:val="0"/></w:pPr></w:style><w:style w:type="paragraph" w:styleId="CustomHeading"><w:basedOn w:val="Heading1"/></w:style></w:styles>',
}
def document(body):
    return f'<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="{W}"><w:body>{body}</w:body></w:document>'
def paragraph(text, properties=''):
    return f'<w:p>{properties}<w:r><w:t xml:space="preserve">{escape(text)}</w:t></w:r></w:p>'
entries['word/document.xml'] = document(
    paragraph('Original DOCX chapter', '<w:pPr><w:pStyle w:val="CustomHeading"/></w:pPr>') +
    '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>window</w:t></w:r><w:r><w:t xml:space="preserve"> — 日本語🌸 café &amp; &lt;script&gt;literal&lt;/script&gt;</w:t></w:r></w:p>' +
    paragraph('window appears again.') +
    paragraph('Second heading', '<w:pPr><w:outlineLvl w:val="1"/></w:pPr>') +
    paragraph('A list item', '<w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr>') +
    '<w:tbl><w:tr><w:tc>' + paragraph('Cell one') + '</w:tc><w:tc>' + paragraph('Cell two') + '</w:tc></w:tr></w:tbl>' +
    '<w:p><w:r><w:rPr><w:i/></w:rPr><w:t>Emphasis</w:t><w:tab/><w:t>after tab</w:t><w:br/><w:t>after break</w:t></w:r></w:p><w:sectPr/>'
)
def make(values, method=ZIP_DEFLATED):
    output = BytesIO()
    with ZipFile(output, 'w') as archive:
        for name, value in values.items():
            info = ZipInfo(name, (2026,10,3,0,0,0)); info.compress_type = method
            info.external_attr = 0o100644 << 16
            archive.writestr(info, value.encode('utf-8') if isinstance(value,str) else value)
    return output.getvalue()
def variants():
    yield 'study-sample.docx', entries
    formal = dict(entries)
    formal['word/styles.xml'] = entries['word/styles.xml'].replace('</w:styles>', '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/></w:style></w:styles>')
    formal['word/document.xml'] = entries['word/document.xml'].replace('w:val="CustomHeading"','w:val="Heading1"').replace('<w:outlineLvl w:val="1"/>','<w:pStyle w:val="Heading2"/>')
    formal['word/numbering.xml'] = f'<w:numbering xmlns:w="{W}"><w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>'
    formal['word/_rels/document.xml.rels'] = f'<Relationships xmlns="{R}"><Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="numbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>'
    yield 'mammoth-sample.docx', formal
    linked = dict(formal)
    linked['word/_rels/document.xml.rels'] = formal['word/_rels/document.xml.rels'].replace('</Relationships>', '<Relationship Id="link" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.invalid/never-open" TargetMode="External"/></Relationships>')
    linked['word/document.xml'] = formal['word/document.xml'].replace('<w:sectPr/>', '<w:p><w:hyperlink xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="link"><w:r><w:t>Ordinary hyperlink label</w:t></w:r></w:hyperlink></w:p><w:sectPr/>')
    yield 'hyperlink-sample.docx', linked
    yield 'stored-sample.docx', entries
    external = dict(entries)
    external['word/_rels/document.xml.rels'] = f'<Relationships xmlns="{R}"><Relationship Id="external" Type="hyperlink" Target="https://example.invalid/unreachable" TargetMode="External"/></Relationships>'
    yield 'external.docx', external
    for label, payload in [('entities','<!DOCTYPE document [<!ENTITY ex SYSTEM "file:///etc/passwd">]>'), ('expansion','<!DOCTYPE document [<!ENTITY a "123"><!ENTITY b "&a;&a;&a;">]>')]:
        bad = dict(entries); bad['word/document.xml'] = payload + document(paragraph('Safe original text'))
        yield label+'.docx', bad
    bad = dict(entries); bad['word/document.xml'] = document(paragraph('Safe') + '<w:altChunk/>'); yield 'altchunk.docx', bad
    bad = dict(entries); bad['word/embeddings/synthetic.bin'] = b'Original inert bytes'; yield 'embedded.docx', bad
    bad = dict(entries); bad['word/vbaProject.bin'] = b'Original inert bytes'; yield 'macro.docx', bad
    bad = dict(entries); bad['word/document.xml'] = document('<w:p>'*65 + '<w:r><w:t>deep</w:t></w:r>' + '</w:p>'*65); yield 'deep.docx', bad
    bad = dict(entries); bad['word/styles.xml'] = f'<w:styles xmlns:w="{W}"><w:style w:styleId="a"><w:basedOn w:val="b"/></w:style><w:style w:styleId="b"><w:basedOn w:val="a"/></w:style></w:styles>'; yield 'cycle.docx', bad
    bad = dict(entries); bad['word/document.xml'] = document(paragraph('Safe')).encode('utf-16'); yield 'utf16.docx', bad
    bad = dict(entries); bad['../escape.xml'] = 'Synthetic traversal'; yield 'traversal.docx', bad
    bad = dict(entries); bad['word/overbudget.bin'] = b'A'*(4*1024*1024+1); yield 'oversize.docx', bad
    bad = dict(entries); bad['word/document.xml'] = document(paragraph('A'*1_000_001)); yield 'textbudget.docx', bad
    bad = dict(entries); bad['word/document.xml'] = document(paragraph('A')*10001); yield 'paragraphbudget.docx', bad
if __name__ == '__main__':
    FIXTURES.mkdir(parents=True, exist_ok=True)
    for name, values in variants():
        (FIXTURES/name).write_bytes(make(values,ZIP_STORED if name=='stored-sample.docx' else ZIP_DEFLATED))
    original=make(entries)
    central=original.index(b'PK\x01\x02')
    crc=bytearray(original); crc[central+16] ^= 1; (FIXTURES/'bad-crc.docx').write_bytes(crc)
    local=bytearray(original); local[30]=ord('/'); (FIXTURES/'local-mismatch.docx').write_bytes(local)
    encrypted=bytearray(original); encrypted[6] |= 1; encrypted[central+8] |= 1; (FIXTURES/'encrypted.docx').write_bytes(encrypted)
    # Streaming writer exercises real ZIP data descriptors, including each declared CRC.
    class Stream(BytesIO):
        def seekable(self): return False
        def seek(self,*args): raise OSError('unseekable fixture')
    stream=Stream()
    with ZipFile(stream,'w',ZIP_DEFLATED) as archive:
        for name,value in entries.items():
            info=ZipInfo(name,(2026,10,3,0,0,0));info.compress_type=ZIP_DEFLATED;info.external_attr=0o100644<<16
            archive.writestr(info,value.encode())
    (FIXTURES/'descriptor-sample.docx').write_bytes(stream.getvalue())
    (ROOT/'apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.docx').write_bytes((FIXTURES/'mammoth-sample.docx').read_bytes())
    print('Generated',len(list(FIXTURES.glob('*.docx'))),'original DOCX fixtures')
