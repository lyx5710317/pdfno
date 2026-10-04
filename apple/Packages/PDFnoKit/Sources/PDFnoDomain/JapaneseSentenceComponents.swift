// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum JapaneseSentenceRole: String, Codable, Sendable, CaseIterable {
    case topic, subject, predicate, object, attributive, adverbial, other
    public var labelZh: String {
        switch self {
        case .topic: "主题"; case .subject: "主语"; case .predicate: "谓语"; case .object: "宾语"
        case .attributive: "定语／修饰语"; case .adverbial: "状语"; case .other: "其他结构"
        }
    }
    public var colorLabelZh: String {
        switch self {
        case .topic: "青色"; case .subject: "蓝色"; case .predicate: "红色"; case .object: "绿色"
        case .attributive: "紫色"; case .adverbial: "橙色"; case .other: "正文色"
        }
    }
}
public struct JapaneseSentenceComponent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let role: JapaneseSentenceRole
    public let span: JapaneseSpan?
    public let ambiguous: Bool
    public let omitted: Bool
    public let explanationZh: String
    public init(id: String, role: JapaneseSentenceRole, span: JapaneseSpan?, ambiguous: Bool, omitted: Bool, explanationZh: String) {
        self.id = id; self.role = role; self.span = span; self.ambiguous = ambiguous; self.omitted = omitted; self.explanationZh = explanationZh
    }
}
public struct JapaneseSentenceRun: Sendable, Equatable {
    public let text: String
    public let start: Int
    public let end: Int
    public let componentID: String?
    public let role: JapaneseSentenceRole?
}
/// One selectable, nonoverlapping layer. The selected candidate has priority; other overlapping
/// candidates remain in the explanation list, never silently merged or given invented offsets.
public enum JapaneseSentenceProjection {
    public static func runs(source: String, components: [JapaneseSentenceComponent], selectedID: String? = nil) -> [JapaneseSentenceRun] {
        let eligible = components.filter { !$0.omitted && $0.span?.isValid(in: source) == true }
        let sorted = eligible.sorted { a, b in
            if (a.id == selectedID) != (b.id == selectedID) { return a.id == selectedID }
            if a.span!.start != b.span!.start { return a.span!.start < b.span!.start }
            if a.span!.end != b.span!.end { return a.span!.end > b.span!.end }
            return a.id < b.id
        }
        var visible: [JapaneseSentenceComponent] = []
        for item in sorted where !visible.contains(where: { $0.span!.overlaps(item.span!) }) { visible.append(item) }
        visible.sort { $0.span!.start < $1.span!.start }
        let scalars = Array(source.unicodeScalars)
        func slice(_ start: Int, _ end: Int) -> String { String(String.UnicodeScalarView(scalars[start..<end])) }
        var result: [JapaneseSentenceRun] = [], position = 0
        for item in visible {
            let span = item.span!
            if position < span.start { result.append(JapaneseSentenceRun(text: slice(position, span.start), start: position, end: span.start, componentID: nil, role: nil)) }
            result.append(JapaneseSentenceRun(text: slice(span.start, span.end), start: span.start, end: span.end, componentID: item.id, role: item.role))
            position = span.end
        }
        if position < scalars.count { result.append(JapaneseSentenceRun(text: slice(position, scalars.count), start: position, end: scalars.count, componentID: nil, role: nil)) }
        return result
    }
    public static func hasOverlaps(_ components: [JapaneseSentenceComponent]) -> Bool {
        components.enumerated().contains { index, item in
            guard let span = item.span else { return false }
            return components.dropFirst(index + 1).contains { $0.span.map(span.overlaps) ?? false }
        }
    }
}
