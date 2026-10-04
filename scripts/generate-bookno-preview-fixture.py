#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate original metadata-only preview fixture; never read books or a Library."""
from pathlib import Path
import hashlib
import json

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")

def content_hash(payload):
    return hashlib.sha256(canonical({"version": "swift-json-verbatim-1", "payload": payload})).hexdigest()

def fixture():
    book_id = "10000000-0000-0000-0000-000000000001"
    edition_id = "20000000-0000-0000-0000-000000000001"
    note_id = "30000000-0000-0000-0000-000000000001"
    external_book = "pdfno:book:pdf:" + book_id
    quote = " A😀か\u3099👩‍💻\n本 "
    # Synthetic source-byte identity, not an actual PDF document or user's book.
    source_hash = hashlib.sha256(b"original fixture source bytes").hexdigest()
    book = {"bookUUID": book_id, "externalID": external_book, "title": "原创样书", "authors": [],
            "edition": {"id": edition_id, "format": "pdf", "sourceFileSHA256": source_hash}}
    anchor = {"schemaVersion": 1, "editionID": edition_id, "fileSHA256": source_hash, "quote": quote,
              "extractionVersion": "pdfkit-selection-1", "regions": [
                  {"pageIndex": 0, "x": 12, "y": 34, "width": 90, "height": 15, "quote": quote}]}
    note = {"externalID": "pdfno:note:pdf:highlight:" + note_id, "noteUUID": note_id,
            "externalBookID": external_book, "annotationKind": "highlight", "quote": quote,
            "userText": "\n  原创备注か\u3099😀  ", "aiAttachments": [],
            "source": {"bookUUID": book_id, "format": "pdf", "offsetUnit": "pdfUserSpace",
                       "textNormalizationVersion": "native-verbatim-1", "anchor": {"pdf": {"_0": anchor}}}}
    mutations = []
    for kind, dto in [("book", book), ("note", note)]:
        semantic = {kind: {"_0": dto.copy()}}
        payload = {kind: {"_0": dto.copy()}}
        if kind == "note":
            payload[kind]["_0"]["localEditRevision"] = 12
        mutations.append({"revision": 1, "baseRevision": 0, "contentHash": content_hash(semantic), "payload": payload})
    return {"protocolName": "pdfno-bookno-exchange-preview", "schemaVersion": 1,
            "canonicalizationVersion": "swift-json-verbatim-1", "sourceNamespace": "pdfno", "mode": "preview",
            "receiverID": "40000000-0000-0000-0000-000000000001", "batchID": "60000000-0000-0000-0000-000000000001",
            "cursor": {"epoch": "50000000-0000-0000-0000-000000000001", "sequence": 1},
            "mutations": mutations, "assets": [], "tombstones": []}

if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Bookno/proposed-preview-v1.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(fixture(), ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
