#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Original real 7z/RAR STORE fixtures; stdlib raw LZMA, no external archiver."""
from pathlib import Path
import struct,zlib,lzma,hashlib,json
def crc(b):return zlib.crc32(b)&0xffffffff
def u32(n):return struct.pack('<I',n)
def var(n):
    out=bytearray()
    while n>=128:out.append((n&127)|128);n>>=7
    out.append(n);return bytes(out)
def seven(n):
    for i in range(8):
        if n<(1<<(7*(i+1))):
            return bytes([(((1<<i)-1)<<(8-i))|(n>>(8*i))])+n.to_bytes(8,'little')[:i]
    return b'\xff'+n.to_bytes(8,'little')
def png(w,h,color):
    def chunk(t,b):return u32(len(b))[::-1]+t+b+u32(crc(t+b))[::-1]
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+bytes(color)*w)*h))+chunk(b'IEND',b'')
pages=[('pages/10.PNG',png(12,20,(80,120,220))),('pages/2.png',png(30,10,(100,180,60))),('pages/1.png',png(12,20,(200,90,120))),('ComicInfo.xml',b'<ComicInfo/>')]
def cb7(entries,codec='copy',solid=False):
    raw=[b for _,b in entries]
    if solid:raw=[b''.join(raw)]
    if codec=='copy':coder=b'\x01\x00';packed=raw
    elif codec=='lzma':
        coder=b'\x23\x03\x01\x01\x05\x5d'+u32(65536)
        packed=[lzma.compress(b,format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA1,'dict_size':65536,'lc':3,'lp':0,'pb':2}]) for b in raw]
    elif codec=='lzma2':
        coder=b'\x21\x21\x01\x08'
        packed=[lzma.compress(b,format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA2,'dict_size':65536}]) for b in raw]
    streams=b'\x06'+seven(0)+seven(len(packed))+b'\x09'+b''.join(seven(len(b)) for b in packed)+b'\0'
    streams+=b'\x07\x0b'+seven(len(raw))+b'\0'+(b'\x01'+coder)*len(raw)+b'\x0c'+b''.join(seven(len(b)) for b in raw)+b'\0'
    if solid:
        streams+=b'\x08\x0d'+seven(len(entries))+b'\x09'+b''.join(seven(len(b)) for _,b in entries[:-1])+b'\x0a\x01'+b''.join(u32(crc(b)) for _,b in entries)+b'\0'
    else:streams+=b'\x08\x0a\x01'+b''.join(u32(crc(b)) for _,b in entries)+b'\0'
    streams+=b'\0'
    names=b'\0'+b''.join((name+'\0').encode('utf-16-le') for name,_ in entries)
    header=b'\x01\x04'+streams+b'\x05'+seven(len(entries))+b'\x11'+seven(len(names))+names+b'\0\0'
    payload=b''.join(packed)
    start=struct.pack('<QQI',len(payload),len(header),crc(header))
    return b'7z\xbc\xaf\x27\x1c\0\x04'+u32(crc(start))+start+payload+header
def rar4(entries,main_flags=0,file_flags=0x8000,method=0x30):
    def head(t,flags,body):
        header=bytes([t])+struct.pack('<HH',flags,len(body)+7)+body
        return struct.pack('<H',crc(header)&0xffff)+header
    out=b'Rar!\x1a\x07\0'+head(0x73,main_flags,bytes(6))
    for name,b in entries:
        name=name.encode('ascii')
        body=struct.pack('<IIBIIBBHI',len(b),len(b),3,crc(b),0,29,method,len(name),0o100644)+name
        out+=head(0x74,file_flags,body)+b
    return out+head(0x7b,0,b'')
def rar5(entries,main_flags=0,compression=0,flags=2):
    def head(t,flags,body):
        b=var(t)+var(flags)+body
        b=var(len(b))+b
        return u32(crc(b))+b
    out=b'Rar!\x1a\x07\x01\0'+head(1,0,var(main_flags))
    for name,b in entries:
        name=name.encode('utf-8')
        body=var(len(b))+var(4)+var(len(b))+var(0o100644)+u32(crc(b))+var(compression)+var(1)+var(len(name))+name
        out+=head(2,flags,body)+b
    return out+head(5,0,var(0))
def generate(root):
    directory=root/'apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Comics'
    inventory=[]
    for name,data in [('original-copy.cb7',cb7(pages)),('original-lzma.cb7',cb7(pages,'lzma')),('original-lzma2.cb7',cb7(pages,'lzma2')),('original-rar4.cbr',rar4(pages)),('original-rar5.cbr',rar5(pages)),('refused-solid.cb7',cb7(pages,'lzma2',True))]:
        content='\n'.join(data.hex()[i:i+64] for i in range(0,len(data)*2,64))+'\n'
        (directory/(name+'.hex')).write_text(content)
        inventory.append({'name':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'hexSHA256':hashlib.sha256(content.encode()).hexdigest(),'generator':'scripts/generate-native-comic-fixtures.py','license':'AGPL-3.0-or-later','source':'Original PDFno colors/PNG/XML and container records; Python stdlib raw LZMA compression'})
    (directory/'NATIVE-SOURCE.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n')
    return inventory
if __name__=='__main__':
    import sys
    print(json.dumps(generate(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]),indent=2))
