// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum SourceValidationError: Error { case invalidSpan, invalidUTF16Boundary }
public enum UnicodeOffsets {
    public static func utf16Offset(in text: String, codePointOffset: Int) throws -> Int {
        let scalars = Array(text.unicodeScalars)
        guard (0...scalars.count).contains(codePointOffset) else { throw SourceValidationError.invalidSpan }
        return scalars.prefix(codePointOffset).reduce(0) { $0 + ($1.value > 0xffff ? 2 : 1) }
    }
    public static func codePointOffset(in text: String, utf16Offset: Int) throws -> Int {
        guard utf16Offset >= 0 else { throw SourceValidationError.invalidUTF16Boundary }
        var units = 0
        for (index, scalar) in text.unicodeScalars.enumerated() {
            if units == utf16Offset { return index }
            units += scalar.value > 0xffff ? 2 : 1
            if units > utf16Offset { throw SourceValidationError.invalidUTF16Boundary }
        }
        guard units == utf16Offset else { throw SourceValidationError.invalidUTF16Boundary }
        return text.unicodeScalars.count
    }
    public static func quotedSpan(in text: String, quote: String, start: Int, end: Int) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard start >= 0, end > start, end <= scalars.count else { return false }
        // Swift String equality treats canonically equivalent Unicode as equal.
        // Source spans must preserve the original scalar sequence instead.
        return scalars[start..<end].elementsEqual(quote.unicodeScalars)
    }
}

/// Preserves author ruby separately. This is a fixture/domain rule, not an EPUB parser.
public enum CanonicalFragment: Sendable {
    case text(String)
    case authorRuby(base: String, reading: String)
    case auxiliary(String)
    public var sourceText: String {
        switch self { case .text(let value): value; case .authorRuby(let base, _): base; case .auxiliary: "" }
    }
}

public enum LearningTaskStatus: String, Codable, Sendable {
    case queued, streaming, completed, partial, failed, cancelled
    public var isTerminal: Bool { [.completed, .partial, .failed, .cancelled].contains(self) }
}
public enum LearningEvent: Sendable { case stream(String), complete, partial(String), failure(String), cancel }
public struct LearningTaskState: Sendable {
    public let id: UUID
    public let source: PDFSourceAnchor
    public private(set) var status: LearningTaskStatus = .queued
    public private(set) var output = ""
    public private(set) var error: String?
    public init(id: UUID = UUID(), source: PDFSourceAnchor) { self.id = id; self.source = source }
    public mutating func apply(_ event: LearningEvent, taskID: UUID) {
        guard taskID == id, !status.isTerminal else { return }
        switch event {
        case .stream(let text): output += text; status = .streaming
        case .complete: status = .completed
        case .partial(let reason): status = .partial; error = reason
        case .failure(let code): status = .failed; error = code
        case .cancel: status = .cancelled
        }
    }
}

public enum ProviderValidation {
    public static func validate(endpoint: String, model: String) -> Bool {
        guard endpoint.utf8.count <= 2048, !endpoint.unicodeScalars.contains(where: { $0.value <= 32 || $0.value == 127 }),
              !model.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return false }
        guard let url = URLComponents(string: endpoint), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, model.count <= 200 else { return false }
        let loopback = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased())
        return url.scheme == "https" || (url.scheme == "http" && loopback)
    }
}
