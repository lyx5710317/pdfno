// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain

/// Display-only source projection. Internal links select a candidate locally, never open a URL,
/// send a request, create a highlight or change the reader's canonical document.
public struct EnglishSentenceComponentsView: View {
    let review: EnglishLearningReview
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedID: String?
    public init(review: EnglishLearningReview) { self.review = review }
    private func color(_ role: EnglishSentenceRole) -> Color {
        let rgb: (Double, Double, Double)
        if colorScheme == .dark {
            switch role {
            case .subject: rgb = (0.40, 0.67, 1); case .predicate: rgb = (1, 0.48, 0.54)
            case .object: rgb = (0.62, 0.87, 0.60); case .attributive: rgb = (0.81, 0.61, 1)
            case .adverbial: rgb = (1, 0.75, 0.40)
            case .complement, .other: return .primary
            }
        } else {
            switch role {
            case .subject: rgb = (0.02, 0.25, 0.55); case .predicate: rgb = (0.65, 0.08, 0.12)
            case .object: rgb = (0.03, 0.36, 0.14); case .attributive: rgb = (0.40, 0.17, 0.60)
            case .adverbial: rgb = (0.55, 0.24, 0.02)
            case .complement, .other: return .primary
            }
        }
        return Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }
    private var attributedSource: AttributedString {
        var result = AttributedString()
        for segment in EnglishSentenceProjection.runs(source: review.source.anchor.quote, components: review.components, selectedID: selectedID) {
            var run = AttributedString(segment.text)
            if let role = segment.role, let id = segment.componentID,
               let index = review.components.firstIndex(where: { $0.id == id }) {
                run.foregroundColor = color(role)
                run.link = URL(string: "pdfno-english-component://candidate/\(index)")
                if id == selectedID { run.underlineStyle = .single }
            }
            result += run
        }
        return result
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(attributedSource).font(.body).textSelection(.enabled)
                .accessibilityIdentifier("english-components-source")
                .accessibilityLabel(review.source.anchor.quote)
                .accessibilityHint("成分颜色仅表示候选；可从下方文字按钮选择成分并阅读中文解释。")
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "pdfno-english-component", url.host == "candidate",
                          let index = Int(url.path.dropFirst()), review.components.indices.contains(index),
                          !review.components[index].inferred else { return .discarded }
                    selectedID = review.components[index].id; return .handled
                })
            Text("句子成分均为待核对候选；补语／表语保留独立文字标签。点击有色片段或下方文字标签查看中文解释。")
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(EnglishSentenceRole.allCases, id: \.self) { role in
                        Label(role.labelZh, systemImage: "square.fill").foregroundStyle(color(role))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(role.colorLabelZh + "：" + role.labelZh)
                            .accessibilityIdentifier("english-component-legend-" + role.rawValue)
                    }
                }
            }.accessibilityIdentifier("english-components-legend")
            if review.components.isEmpty { Text("没有可验证的句子成分；只显示原句，不猜测涂色。") }
            if EnglishSentenceProjection.hasOverlaps(review.components) {
                Text("候选包含重叠或嵌套修饰，原句一次显示清晰的一层；选择列表中的其他候选可切换。")
                    .foregroundStyle(.secondary).accessibilityIdentifier("english-components-overlap")
            }
            ForEach(review.components.filter { !$0.inferred }) { item in
                Button {
                    selectedID = item.id
                } label: {
                    Text(verbatim: item.role.labelZh + "（候选） · " + (item.span?.quote ?? "") + (item.ambiguous ? " · 不确定" : ""))
                        .foregroundStyle(color(item.role))
                }.buttonStyle(.bordered).accessibilityIdentifier("english-component-" + item.role.rawValue)
            }
            if review.components.contains(where: \.inferred) {
                Text("省略／推断成分 · 仅作解释，不在原句中涂色").font(.headline)
                ForEach(review.components.filter(\.inferred)) { item in
                    Button(item.role.labelZh + (item.omitted ? " · 省略（推断）" : " · 结构推断")) { selectedID = item.id }
                        .accessibilityIdentifier("english-component-omitted-" + item.role.rawValue)
                }
            }
            if let item = review.components.first(where: { $0.id == selectedID }) {
                Text(item.role.labelZh + (item.inferred ? " · 推断（无原文范围）" : " · 成分候选") + (item.ambiguous ? " · 不确定" : ""))
                    .font(.headline).accessibilityIdentifier("english-component-selected-label")
                Text(verbatim: item.explanationZh).textSelection(.enabled).accessibilityIdentifier("english-component-explanation")
                if let span = item.span { Text(verbatim: "原文 code point [\(span.start), \(span.end))").foregroundStyle(.secondary) }
            }
        }.onChange(of: review.requestID) { _, _ in selectedID = nil }
    }
}
