#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Original PalmDB/MOBI6, pure KF8 and FictionBook 2 samples; no converted/renamed book."""
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Ebooks'
UI=ROOT/'apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/Ebooks'
def u32(b,p,n): struct.pack_into('>I',b,p,n)
def vint(n):
 b=[n&127];n>>=7
 while n:b.insert(0,n&127);n>>=7
 b[-1]|=128;return bytes(b)
def index(tags,entries):
 tagx=b'TAGX'+struct.pack('>II',12+len(tags)*4,1)+bytes(x for t in tags for x in t)
 master=bytearray(192);master[:4]=b'INDX';u32(master,4,192);u32(master,24,1);u32(master,28,65001)
 offsets=[];payload=b''
 for name,control,values in entries:
  offsets.append(192+len(payload));raw=str(name).encode();payload+=bytes([len(raw)])+raw+bytes([control])+b''.join(vint(v) for v in values)
 record=bytearray(192);record[:4]=b'INDX';u32(record,4,192);u32(record,20,192+len(payload));u32(record,24,len(entries));u32(record,28,65001)
 return [bytes(master)+tagx,bytes(record)+payload+b'IDXT'+b''.join(struct.pack('>H',x) for x in offsets)]
def book(ext,kf8=False,palm=False):
 title=('Original PDFno '+ext.upper()+' sample').encode()
 if kf8:
  skeleton=b'<html xmlns="http://www.w3.org/1999/xhtml"><head><title>KF8</title></head><body></body></html>'
  fragment='<h1>Original KF8 chapter</h1><p>Pure KF8 skeleton and fragment records are real source data.</p><h2>Second KF8 heading</h2><p>日本語 😀 e\u0301 — repeated original phrase.</p>'.encode()
  text=skeleton+fragment
  rest=index([(1,1,3,0),(6,2,12,0)], [('skeleton',5,[1,0,len(skeleton)])])+index([(2,1,3,0),(4,1,12,0),(6,2,48,0)],[(skeleton.index(b'</body>'),21,[0,0,0,len(fragment)])])
  rest += [b'FDST'+struct.pack('>II',12,1)+struct.pack('>II',0,len(text))]
 else:
  text=('<html><head><title>'+title.decode()+'</title></head><body><h1>Original '+ext.upper()+' chapter one</h1><p>Original source, not a renamed EPUB.</p><p><ruby>本<rt>ほん</rt></ruby> 😀 e\u0301 repeated original phrase.</p><mbp:pagebreak/><h1>Original '+ext.upper()+' chapter two</h1><p>Second original chapter keeps the exact source.</p></body></html>').encode()
  rest=[]
 # Explicit PalmDOC literal chunks exercise genuine compression=2 without third-party compressor.
 compressed=b''.join(bytes([len(text[i:i+8])])+text[i:i+8] for i in range(0,len(text),8)) if palm else text
 header=bytearray(280);struct.pack_into('>HHIHHHH',header,0,2 if palm else 1,0,len(text),1,4096,0,0)
 header[16:20]=b'MOBI'
 for p,n in [(20,264),(24,2),(28,65001),(32,0x50444600+len(ext)),(36,8 if kf8 else 6),(84,292),(88,len(title)),(108,7 if kf8 else 2),(112,0xffffffff),(116,0),(128,64),(192,6 if kf8 else 0xffffffff),(196,1),(240,0),(244,0xffffffff),(248,4 if kf8 else 0xffffffff),(252,2 if kf8 else 0xffffffff),(260,0xffffffff)]:u32(header,p,n)
 records=[bytes(header)+b'EXTH'+struct.pack('>II',12,0)+title,compressed]+rest
 pdb=bytearray(78);pdb[:len(title[:31])]=title[:31];pdb[60:68]=b'BOOKMOBI';struct.pack_into('>H',pdb,76,len(records))
 offset=78+len(records)*8+2;table=b''
 for i,r in enumerate(records):table+=struct.pack('>I',offset)+b'\0'+i.to_bytes(3,'big');offset+=len(r)
 return bytes(pdb)+table+b'\0\0'+b''.join(records)
fb2='''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink"><description><title-info><genre>prose</genre><author><first-name>PDFno</first-name><last-name>Contributors</last-name></author><book-title>Original PDFno FB2 sample</book-title><lang>en</lang></title-info><document-info><author><nickname>PDFno</nickname></author><id>pdfno-original-fb2-v1</id><version>1.0</version></document-info></description><body><section id="one"><title><p>Original FB2 chapter one</p></title><p>FictionBook XML is parsed through the fixed public engine.</p><p>日本語 😀 é repeated original phrase.</p></section><section id="two"><title><p>Original FB2 chapter two</p></title><p>Second original section preserves durable notes.</p></section></body></FictionBook>'''.encode()
if __name__=='__main__':
 DEST.mkdir(parents=True,exist_ok=True);UI.mkdir(parents=True,exist_ok=True)
 samples={'study-sample.mobi':book('mobi'),'study-sample.azw':book('azw',palm=True),'study-sample.azw3':book('azw3',kf8=True),'study-sample.fb2':fb2}
 for name,data in samples.items():
  (DEST/name).write_bytes(data);(UI/name).write_bytes(data);print(name,len(data))
