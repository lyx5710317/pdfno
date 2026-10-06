// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

/// The reader is the navigation authority; citations never supply model-made coordinates.
struct ParagraphExplanationResultView: View {
    let explanation: ParagraphExplanation
    let source: AISourceSnapshot
    @ObservedObject var library: LibraryModel
    var current = true
    var saved = false
    private var sourceCanReturn: Bool { current && (saved ? library.canReturnToSavedParagraphSource(source) : library.isCurrentParagraphSource(source)) }
    var summaryIdentifier = "ai-result"
    let returned: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("段落解释 · 结构与引文已核验，解释与推断待人工审阅")
                .font(.headline).accessibilityIdentifier("paragraph-result")
            if !explanation.canSave {
                PDFnoStatusMessage(text: explanation.displayText, identifier: "paragraph-insufficient")
            }
            ForEach(explanation.payload.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.kind.title).font(.headline).accessibilityIdentifier("paragraph-kind-" + item.id)
                    Text(verbatim: item.text).textSelection(.enabled).accessibilityIdentifier(item.id == explanation.payload.items.first?.id ? summaryIdentifier : "paragraph-item-" + item.id)
                    Text("原文依据：" + item.evidenceRefs.joined(separator: "、")).font(.caption)
                }
            }
            ForEach(explanation.citations) { citation in
                VStack(alignment: .leading, spacing: 6) {
                    Text("原文 [" + citation.id + "] · " + citation.sourceRefID).font(.caption)
                    Text(verbatim: citation.quote).textSelection(.enabled).accessibilityIdentifier("paragraph-quote-" + citation.id)
                    if let range = try? citation.span.utf16Range(in: source.anchor.quote) {
                        Text("选文内 UTF-16 \(range.lowerBound)–\(range.upperBound) · " + location(citation)).font(.caption)
                    }
                    Button("依据 · 回到原文") {
                        Task {
                            guard sourceCanReturn,
                                  let target = try? citation.navigationSource(in: source) else {
                                library.learning.error = AIFailure.stale.localizedDescription; return
                            }
                            library.learning.cancel()
                            if await library.returnToAISource(target) { returned() }
                        }
                    }.disabled(!sourceCanReturn).accessibilityIdentifier("paragraph-source-" + citation.id)
                }
            }
            if !sourceCanReturn {
                PDFnoStatusMessage(text: "来源已不适用于当前阅读状态；结果保留供阅读。回跳需原书版本及原文依据可验证；新保存需重新选文生成。", identifier: "paragraph-stale")
            }
            Text("仅限显示的选文；来源核验不表示模型解释或推断正确。只有手动保存才写入本地；新生成不会覆盖已保存的用户正文。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func location(_ citation: ParagraphCitation) -> String {
        if case .epub(let anchor) = try? citation.navigationSource(in: source).anchor {
            return "EPUB · " + anchor.resourceHref + " · 资源 UTF-16 \(anchor.start)–\(anchor.end)"
        }
        return "PDF · 回到原始选区（不推算引用子矩形）"
    }
}
#endif
