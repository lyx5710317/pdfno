#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Independent original CBT fixture from Python's USTAR writer; stored as source-friendly hex."""
from pathlib import Path
import hashlib
import io
import json
import struct
import tarfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Comics"

def png(width, height):
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    rows = b"".join(b"\0" + bytes((40, 100, 180)) * width for _ in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")

output = io.BytesIO()
with tarfile.open(fileobj=output, mode="w", format=tarfile.USTAR_FORMAT, encoding="utf-8") as archive:
    for name, payload in [("pages/10.PNG", png(30, 10)), ("pages/2.png", png(12, 20)), ("pages/1.png", png(12, 20)),
                          ("ComicInfo.xml", b"<ComicInfo><Title>Original PDFno CBT</Title></ComicInfo>")]:
        info = tarfile.TarInfo(name); info.size = len(payload); info.mode = 0o644
        archive.addfile(info, io.BytesIO(payload))
raw = output.getvalue()
# Independently re-read real records; no archive extracted to the filesystem.
with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
    assert archive.getnames() == ["pages/10.PNG", "pages/2.png", "pages/1.png", "ComicInfo.xml"]
hex_source = "\n".join(raw[i:i + 32].hex() for i in range(0, len(raw), 32)) + "\n"
TARGET.mkdir(parents=True, exist_ok=True)
(TARGET / "original-ustar.cbt.hex").write_text(hex_source, encoding="utf-8")
metadata = {"generator": "scripts/generate-cbt-fixture.py", "license": "AGPL-3.0-or-later", "decodedBytes": len(raw),
            "decodedSHA256": hashlib.sha256(raw).hexdigest(), "hexSHA256": hashlib.sha256(hex_source.encode()).hexdigest()}
(TARGET / "SOURCE.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print(json.dumps(metadata))
