// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG
import Foundation

/// Original text-only PDFs created in memory. Never reads files, network or a user's library.
enum OriginalPageTranslationUITestPDF {
    static func data(mode: String) -> Data? {
        guard ["multi", "blank", "over-budget"].contains(mode) else { return nil }
        let lines = mode == "blank" ? [] : (0..<(mode == "multi" ? 18 : 60)).map {
            "Original page fixture line \($0 + 1): A small garden grows beside a quiet window."
        }
        let stream = (["BT", "/F1 9 Tf"] + lines.enumerated().map { index, text in
            "1 0 0 1 32 \(760 - index * 11) Tm (\(text)) Tj"
        } + ["ET"]).joined(separator: "\n")
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream"
        ]
        var data = Data("%PDF-1.4\n".utf8), offsets = [0]
        for (index, object) in objects.enumerated() {
            offsets.append(data.count); data.append(Data("\(index + 1) 0 obj\n\(object)\nendobj\n".utf8))
        }
        let start = data.count
        data.append(Data("xref\n0 6\n0000000000 65535 f \n".utf8))
        for offset in offsets.dropFirst() { data.append(Data(String(format: "%010d 00000 n \n", offset).utf8)) }
        data.append(Data("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n\(start)\n%%EOF\n".utf8))
        return data
    }
}
#endif
