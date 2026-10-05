// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public struct EnglishSentenceRun: Sendable, Equatable {
    public let text: String
    public let start: Int
    public let end: Int
    public let componentID: String?
    public let role: EnglishSentenceRole?
}
/// One selectable, nonoverlapping layer. The selected candidate has priority; other overlapping
/// candidates remain in the explanation list, never silently merged or given invented offsets.
public enum EnglishSentenceProjection {
    public static func runs(source: String, components: [EnglishSentenceComponent], selectedID: String? = nil) -> [EnglishSentenceRun] {
        let eligible = components.filter { !$0.omitted && !$0.inferred && $0.span?.isValid(in: source) == true }
        let sorted = eligible.sorted { a, b in
            if (a.id == selectedID) != (b.id == selectedID) { return a.id == selectedID }
            if a.span!.start != b.span!.start { return a.span!.start < b.span!.start }
            if a.span!.end != b.span!.end { return a.span!.end > b.span!.end }
            return a.id < b.id
        }
        var visible: [EnglishSentenceComponent] = []
        for item in sorted where !visible.contains(where: { $0.span!.overlaps(item.span!) }) { visible.append(item) }
        visible.sort { $0.span!.start < $1.span!.start }
        let scalars = Array(source.unicodeScalars)
        func slice(_ start: Int, _ end: Int) -> String { String(String.UnicodeScalarView(scalars[start..<end])) }
        var result: [EnglishSentenceRun] = [], position = 0
        for item in visible {
            let span = item.span!
            if position < span.start { result.append(EnglishSentenceRun(text: slice(position, span.start), start: position, end: span.start, componentID: nil, role: nil)) }
            result.append(EnglishSentenceRun(text: slice(span.start, span.end), start: span.start, end: span.end, componentID: item.id, role: item.role))
            position = span.end
        }
        if position < scalars.count { result.append(EnglishSentenceRun(text: slice(position, scalars.count), start: position, end: scalars.count, componentID: nil, role: nil)) }
        return result
    }
    public static func hasOverlaps(_ components: [EnglishSentenceComponent]) -> Bool {
        components.enumerated().contains { index, item in
            guard let span = item.span else { return false }
            return components.dropFirst(index + 1).contains { $0.span.map(span.overlaps) ?? false }
        }
    }
}
