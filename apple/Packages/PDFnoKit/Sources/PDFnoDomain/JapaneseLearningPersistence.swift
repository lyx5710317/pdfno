// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Revalidate decoded candidates; Codable alone never grants a persisted source/span trust.
extension JapaneseLearningReview {
    public var isPersistable: Bool {
        let request = JapaneseLearningRequest(id: requestID, source: source, provider: provider, authorReadings: authorReadings)
        guard (try? request.validate()) != nil, [JapaneseLearningPolicy.promptVersion, JapaneseLearningPolicy.legacyPromptVersion].contains(promptVersion),
              status != .unavailable, components.count <= JapaneseLearningPolicy.maxComponents, readings.count <= JapaneseLearningPolicy.maxReadings,
              grammar.count <= JapaneseLearningPolicy.maxGrammar, warnings.count <= 96,
              warnings.allSatisfy({ Self.plain($0, limit: 400) }),
              translationZh.map({ Self.plain($0, limit: 2000) }) ?? true,
              (status == .reviewable) == warnings.isEmpty,
              Set(readings.map(\.id) + grammar.map(\.id) + components.map(\.id)).count == readings.count + grammar.count + components.count else { return false }
        for item in readings {
            guard Self.plain(item.id, limit: 64), item.span.isValid(in: source.anchor.quote),
                  !item.candidates.isEmpty, item.candidates.count <= 4, item.candidates.allSatisfy(JapaneseLearningValidator.isKana),
                  Set(item.candidates).count == item.candidates.count,
                  item.ambiguous || item.candidates.count == 1,
                  Self.plain(item.explanationZh, limit: 300, nonempty: item.ambiguous),
                  !authorReadings.contains(where: { $0.span.overlaps(item.span) }),
                  !readings.contains(where: { $0.id != item.id && $0.span.overlaps(item.span) }) else { return false }
        }
        guard grammar.allSatisfy({ Self.plain($0.id, limit: 64) && $0.span.isValid(in: source.anchor.quote) &&
            Self.plain($0.labelZh, limit: 80) && Self.plain($0.explanationZh, limit: 600) }) else { return false }
        var keys: Set<String> = []
        for item in components {
            guard Self.plain(item.id, limit: 64), Self.plain(item.explanationZh, limit: 400),
                  item.omitted == (item.span == nil), !item.omitted || item.ambiguous,
                  item.span.map({ $0.isValid(in: source.anchor.quote) }) ?? true,
                  keys.insert(item.role.rawValue + ":" + (item.span?.correctionKey ?? "omitted")).inserted else { return false }
        }
        guard !components.contains(where: { $0.ambiguous || $0.omitted }) || !warnings.isEmpty else { return false }
        return !readings.contains(where: \.ambiguous) || !warnings.isEmpty
    }
    private static func plain(_ value: String, limit: Int, nonempty: Bool = true) -> Bool {
        value.utf16.count <= limit && !value.unicodeScalars.contains { $0.value == 0 } &&
        (!nonempty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
extension JapaneseLearningNote {
    public var isPersistable: Bool {
        review.isPersistable && (try? JapaneseLearningNote(id: id, review: review, userText: userText, corrections: corrections)) != nil
    }
}
