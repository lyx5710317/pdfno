// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CryptoKit
import PDFnoDomain
import PDFnoServices

/// Independent local export; never opens a window, writes a repository or alters a live reader.
public struct DOCXReadingPDFService: Sendable {
    private let service: DocumentConversionService
    public init() {
        service = DocumentConversionService(adapters: [], asyncAdapters: [DOCXReadingPDFConversionAdapter()])
    }
    public var capabilities: [ConversionCapability] { service.capabilities }
    public func convert(source: URL, destination: URL,
                        progress: @escaping @Sendable (ConversionPhase) -> Void = { _ in }) async throws -> ConversionResult {
        try await service.convert(.init(source: source, destination: destination, output: .readingPDF), progress: progress)
    }
}

public struct DOCXReadingPDFConversionAdapter: AsyncDocumentConversionAdapter {
    public static let adapterID = "docx-mammoth-reading-pdf-1"
    public init() {}
    public var capabilities: [ConversionCapability] {
        [.init(input: .docx, output: .readingPDF, adapterID: Self.adapterID)]
    }
    public func convert(_ source: Data, to output: ConversionFormat,
                        progress: @escaping @Sendable (ConversionPhase) -> Void) async throws -> ConvertedDocument {
        guard output == .readingPDF else { throw ConversionError.unsupportedDirection }
        try Task.checkCancellation()
        let hash = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        progress(.converting); try Task.checkCancellation()
        let document = try await Self.semanticDocument(source, hash: hash)
        try Task.checkCancellation(); progress(.paginating); try Task.checkCancellation()
        return try DOCXReadingPDFRenderer.render(document, sourceSHA256: hash, progress: progress)
    }
    @MainActor private static func semanticDocument(_ data: Data, hash: String) async throws -> DOCXDocument {
        try Task.checkCancellation()
        let reader = DOCXReaderSession()
        defer { reader.close() }
        do {
            return try await withTaskCancellationHandler {
                try await reader.open(data: data, book: DOCXBook(fileSHA256: hash, title: "DOCX 阅读版PDF", originalFilename: "source.docx"), notes: [])
                try Task.checkCancellation()
                guard let document = reader.document, document.isValid else { throw DOCXReadingPDFError.invalidSemanticDocument }
                return document
            } onCancel: { Task { @MainActor in reader.close() } }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }
}
#endif
