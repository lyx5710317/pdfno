// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Reuse the existing trusted selection/progress/CSP bridge; source HTML is never installed.
public enum TextFormatHTML {
    public static func render(_ document: TextFormatDocument, sessionID: UUID, usesEngine: Bool = false) -> String {
        let semantic = DOCXDocument(blocks: document.blocks.map {
            DOCXBlock(id: $0.id, runs: $0.runs.map { DOCXRun($0.text, bold: $0.bold, italic: $0.italic) },
                      headingLevel: $0.headingLevel, listLevel: $0.listLevel, table: $0.table, row: $0.row, cell: $0.cell, start: $0.start)
        })
        return DOCXHTML.render(semantic, sessionID: sessionID, usesMammoth: usesEngine)
            .replacingOccurrences(of: "pdfno-docx", with: "pdfno-text")
            .replacingOccurrences(of: "messageHandlers.docx", with: "messageHandlers.textformat")
            .replacingOccurrences(of: "pdfnoDOCX", with: "pdfnoText")
    }
    public static func fragment(_ document: TextFormatDocument) -> String {
        let html = render(document, sessionID: UUID())
        guard let start = html.range(of: "<body><main>"), let end = html.range(of: "</main>") else { return "" }
        return String(html[start.upperBound..<end.lowerBound])
    }
}
