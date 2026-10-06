// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain
#if os(macOS)
import AppKit
#endif

/// Display-only source projection. Internal links select a candidate locally, never open a URL,
/// send a request, create a highlight or change the reader's canonical document.
public struct JapaneseSentenceComponentsView: View {
    let review: JapaneseLearningReview
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedID: String?
    public init(review: JapaneseLearningReview) { self.review = review }
    private func color(_ role: JapaneseSentenceRole) -> Color {
        let rgb: (Double, Double, Double)
        if colorScheme == .dark {
            switch role {
            case .subject: rgb = (0.40, 0.67, 1); case .predicate: rgb = (1, 0.48, 0.54)
            case .object: rgb = (0.62, 0.87, 0.60); case .attributive: rgb = (0.81, 0.61, 1)
            case .adverbial: rgb = (1, 0.75, 0.40); case .topic: rgb = (0.54, 0.87, 0.92)
            case .other: return .primary
            }
        } else {
            switch role {
            case .subject: rgb = (0.02, 0.25, 0.55); case .predicate: rgb = (0.65, 0.08, 0.12)
            case .object: rgb = (0.03, 0.36, 0.14); case .attributive: rgb = (0.40, 0.17, 0.60)
            case .adverbial: rgb = (0.55, 0.24, 0.02); case .topic: rgb = (0, 0.32, 0.35)
            case .other: return .primary
            }
        }
        return Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }
    private var attributedSource: AttributedString {
        var result = AttributedString()
        for segment in JapaneseSentenceProjection.runs(source: review.source.anchor.quote, components: review.components, selectedID: selectedID) {
            var run = AttributedString(segment.text)
            if let role = segment.role, let id = segment.componentID,
               let index = review.components.firstIndex(where: { $0.id == id }) {
                run.foregroundColor = color(role)
                run.link = URL(string: "pdfno-japanese-component://candidate/\(index)")
                if id == selectedID { run.underlineStyle = .single }
            }
            result += run
        }
        return result
    }
    #if os(macOS)
    private var nativeAttributedSource: NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for segment in JapaneseSentenceProjection.runs(source: review.source.anchor.quote, components: review.components, selectedID: selectedID) {
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.preferredFont(forTextStyle: .body), .foregroundColor: NSColor.labelColor]
            if let role = segment.role, let id = segment.componentID,
               let index = review.components.firstIndex(where: { $0.id == id }) {
                attributes[.foregroundColor] = NSColor(color(role))
                attributes[.link] = URL(string: "pdfno-japanese-component://candidate/\(index)")
                if id == selectedID { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            }
            result.append(NSAttributedString(string: segment.text, attributes: attributes))
        }
        return result
    }
    #endif
    private func selectCandidateLink(_ url: URL) {
        guard url.scheme == "pdfno-japanese-component", url.host == "candidate",
              let index = Int(url.path.dropFirst()), review.components.indices.contains(index),
              !review.components[index].omitted else { return }
        selectedID = review.components[index].id
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(macOS)
            NativeJapaneseSourceText(content: nativeAttributedSource, quote: review.source.anchor.quote,
                                     onCandidateLink: selectCandidateLink)
                .frame(maxWidth: .infinity, alignment: .leading)
            #else
            Text(attributedSource).font(.body).textSelection(.enabled)
                .accessibilityIdentifier("japanese-components-source")
                .accessibilityLabel(review.source.anchor.quote)
                .accessibilityHint("成分颜色仅表示候选；可从下方文字按钮选择成分并阅读中文解释。")
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "pdfno-japanese-component", url.host == "candidate",
                          let index = Int(url.path.dropFirst()), review.components.indices.contains(index),
                          !review.components[index].omitted else { return .discarded }
                    selectedID = review.components[index].id; return .handled
                })
            #endif
            Text("句子成分均为待核对候选；主题与主语分开。点击有色片段或下方文字标签查看中文解释。")
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(JapaneseSentenceRole.allCases, id: \.self) { role in
                        Label(role.labelZh, systemImage: "square.fill").foregroundStyle(color(role))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(role.colorLabelZh + "：" + role.labelZh)
                            .accessibilityIdentifier("japanese-component-legend-" + role.rawValue)
                    }
                }
            }.accessibilityIdentifier("japanese-components-legend")
            if review.components.isEmpty { Text("没有可验证的句子成分；只显示原句，不猜测涂色。") }
            if JapaneseSentenceProjection.hasOverlaps(review.components) {
                Text("候选包含重叠或嵌套修饰，原句一次显示清晰的一层；选择列表中的其他候选可切换。")
                    .foregroundStyle(.secondary).accessibilityIdentifier("japanese-components-overlap")
            }
            ForEach(review.components.filter { !$0.omitted }) { item in
                Button {
                    selectedID = item.id
                } label: {
                    Text(verbatim: item.role.labelZh + "（候选） · " + (item.span?.quote ?? "") + (item.ambiguous ? " · 不确定" : ""))
                        .foregroundStyle(color(item.role))
                }.buttonStyle(.bordered).accessibilityIdentifier("japanese-component-" + item.role.rawValue)
            }
            if review.components.contains(where: \.omitted) {
                Text("省略成分 · 仅推测解释，不在原句中涂色").font(.headline)
                ForEach(review.components.filter(\.omitted)) { item in
                    Button(item.role.labelZh + " · 省略（推测）") { selectedID = item.id }
                        .accessibilityIdentifier("japanese-component-omitted-" + item.role.rawValue)
                }
            }
            if let item = review.components.first(where: { $0.id == selectedID }) {
                Text(item.role.labelZh + (item.omitted ? " · 省略（推测）" : " · 成分候选") + (item.ambiguous ? " · 不确定" : ""))
                    .font(.headline).accessibilityIdentifier("japanese-component-selected-label")
                Text(verbatim: item.explanationZh).textSelection(.enabled).accessibilityIdentifier("japanese-component-explanation")
                    .id(item.id)
                if let span = item.span { Text(verbatim: "原文 code point [\(span.start), \(span.end))").foregroundStyle(.secondary) }
            }
        }.onChange(of: review.requestID) { _, _ in selectedID = nil }
    }
}
