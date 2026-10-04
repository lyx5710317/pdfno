// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CoreText
import CoreGraphics
import PDFnoDomain

/// Original finite Core Text renderer. It consumes checked Mammoth DTOs, never raw HTML or source paths.
/// Core Graphics writes into bounded memory; the Services transaction alone creates filesystem output.
enum DOCXReadingPDFRenderer {
    static func render(_ document: DOCXDocument, sourceSHA256: String,
                       progress: @Sendable (ConversionPhase) -> Void = { _ in }) throws -> ConvertedDocument {
        guard document.isValid, DOCXBook.validHash(sourceSHA256) else { throw DOCXReadingPDFError.invalidSemanticDocument }
        try Task.checkCancellation()
        let settings = DOCXReadingPDFSettings(), text = try attributedBody(document, settings: settings)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var media = CGRect(x: 0, y: 0, width: settings.pageWidth, height: settings.pageHeight)
        let bytes = NSMutableData()
        guard let consumer = CGDataConsumer(data: bytes),
              let context = CGContext(consumer: consumer, mediaBox: &media,
                                      [kCGPDFContextTitle: "DOCX 阅读版PDF", kCGPDFContextCreator: "PDFno / Apple Core Text reading PDF",
                                       kCGPDFContextSubject: "Reading PDF; DOCX SHA-256: " + sourceSHA256 + "; " + DOCXDocument.extractionVersion] as CFDictionary) else {
            throw DOCXReadingPDFError.layoutFailure
        }
        var closed = false
        defer { if !closed { context.closePDF() } }
        let body = CGRect(x: settings.margin, y: 60, width: media.width - settings.margin * 2,
                          height: media.height - settings.margin - 60)
        let path = CGPath(rect: body, transform: nil)
        var offset = 0, pages = 0, fonts = Set<String>()
        while offset < text.length {
            try Task.checkCancellation()
            guard pages < settings.maximumPages else { throw DOCXReadingPDFError.resourceLimit }
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.location == offset, visible.length > 0,
                  offset + visible.length <= text.length else { throw DOCXReadingPDFError.layoutFailure }
            try inspect(frame, body: body, fonts: &fonts)
            context.beginPDFPage(nil); pages += 1
            context.textMatrix = .identity
            // Quartz emits per-glyph ActualText for ambiguous Unicode/font mappings.
            CTFrameDraw(frame, context)
            try drawLabel("DOCX 阅读版PDF", at: CGPoint(x: settings.margin, y: media.height - 31), in: context, fonts: &fonts)
            let footer = CTLineCreateWithAttributedString(label("\(pages)"))
            let width = CTLineGetTypographicBounds(footer, nil, nil, nil)
            context.textPosition = CGPoint(x: (media.width - width) / 2, y: 30)
            CTLineDraw(footer, context)
            context.endPDFPage()
            offset += visible.length
            guard bytes.length <= 16 * 1024 * 1024 else { throw DOCXReadingPDFError.resourceLimit }
            // Repeated pagination phase permits deterministic cancellation between real pages.
            progress(.paginating)
        }
        try Task.checkCancellation(); context.closePDF(); closed = true
        guard bytes.length <= 16 * 1024 * 1024 else { throw DOCXReadingPDFError.resourceLimit }
        let report = DOCXReadingPDFReport(sourceSHA256: sourceSHA256, pageCount: pages, semanticBlockCount: document.blocks.count,
                                         canonicalUTF16Count: document.text.utf16.count, fonts: fonts.sorted(), settings: settings,
                                         semanticWarnings: document.warnings)
        return ConvertedDocument(data: bytes as Data, warnings: [], readingPDFReport: report)
    }

    private static func font(size: Double, bold: Bool = false, italic: Bool = false) -> CTFont {
        // Installed system fonts only. Core Text performs language/glyph fallback; no fonts are vendored or fetched.
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "Helvetica",
            kCTFontCascadeListAttribute: ["PingFangSC-Regular", "HiraginoSans-W3"].map {
                CTFontDescriptorCreateWithNameAndSize($0 as CFString, size)
            }
        ] as CFDictionary)
        let base = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        var traits: CTFontSymbolicTraits = []
        if bold { traits.insert(.traitBold) }; if italic { traits.insert(.traitItalic) }
        return traits.isEmpty ? base : (CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, traits) ?? base)
    }
    private static func attributes(size: Double, bold: Bool = false, italic: Bool = false) -> [NSAttributedString.Key: Any] {
        [NSAttributedString.Key(kCTFontAttributeName as String): font(size: size, bold: bold, italic: italic),
         NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.12, alpha: 1)]
    }
    private static func attributedBody(_ document: DOCXDocument, settings: DOCXReadingPDFSettings) throws -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for block in document.blocks {
            try Task.checkCancellation()
            let begin = result.length
            let size = block.headingLevel.map { max(13, 22 - Double($0) * 2) } ?? settings.bodyFontSize
            let base = attributes(size: size, bold: block.headingLevel != nil)
            if let table = block.table, let row = block.row, let cell = block.cell {
                result.append(NSAttributedString(string: "[表\(table + 1) 行\(row + 1) 格\(cell + 1)] ", attributes: base))
            } else if block.listLevel != nil {
                result.append(NSAttributedString(string: "• ", attributes: base))
            }
            for run in block.runs {
                try Task.checkCancellation()
                result.append(NSAttributedString(string: run.text, attributes: attributes(size: size, bold: run.bold || block.headingLevel != nil, italic: run.italic)))
            }
            result.append(NSAttributedString(string: "\n", attributes: base))
            var spacing: CGFloat = block.headingLevel == nil ? 6 : 10
            var leading: CGFloat = 4
            var indent: CGFloat = CGFloat(block.listLevel.map { min($0 + 1, 9) * 14 } ?? 0)
            let style: CTParagraphStyle = withUnsafePointer(to: &spacing) { space in
                withUnsafePointer(to: &leading) { line in
                    withUnsafePointer(to: &indent) { inset in
                        let values = [CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size, value: space),
                                      CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: line),
                                      CTParagraphStyleSetting(spec: .headIndent, valueSize: MemoryLayout<CGFloat>.size, value: inset),
                                      CTParagraphStyleSetting(spec: .firstLineHeadIndent, valueSize: MemoryLayout<CGFloat>.size, value: inset)]
                        return CTParagraphStyleCreate(values, values.count)
                    }
                }
            }
            result.addAttribute(NSAttributedString.Key(kCTParagraphStyleAttributeName as String), value: style,
                                range: NSRange(location: begin, length: result.length - begin))
        }
        return result
    }
    private static func label(_ text: String) -> CFAttributedString {
        NSAttributedString(string: text, attributes: attributes(size: 9)) as CFAttributedString
    }
    private static func drawLabel(_ text: String, at point: CGPoint, in context: CGContext, fonts: inout Set<String>) throws {
        let line = CTLineCreateWithAttributedString(label(text))
        try inspect(line, fonts: &fonts)
        context.textPosition = point; CTLineDraw(line, context)
    }
    private static func inspect(_ frame: CTFrame, body: CGRect, fonts: inout Set<String>) throws {
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        for (index, line) in lines.enumerated() {
            try Task.checkCancellation()
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            // Include typographic overhang tolerance; refuse content that would be silently clipped.
            guard origins[index].x >= -1, origins[index].x + width <= body.width + 1,
                  origins[index].y + ascent <= body.height + 1, origins[index].y - descent >= -1 else {
                throw DOCXReadingPDFError.layoutFailure
            }
            try inspect(line, fonts: &fonts)
        }
    }
    private static func inspect(_ line: CTLine, fonts: inout Set<String>) throws {
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            try Task.checkCancellation()
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            guard !glyphs.contains(0) else { throw DOCXReadingPDFError.missingGlyph }
            let values = CTRunGetAttributes(run) as NSDictionary
            if let value = values[kCTFontAttributeName] {
                let name = CTFontCopyPostScriptName(value as! CTFont) as String
                // LastResort uses nonzero placeholder glyphs for unsupported Unicode; those are not readable text.
                guard name != "LastResort" else { throw DOCXReadingPDFError.missingGlyph }
                fonts.insert(name)
            }
        }
    }
}
#endif
