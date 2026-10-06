// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct EPUBChapterTranslationWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    @ObservedObject var translation: EPUBChapterTranslationModel
    @ObservedObject var learning: AILearningModel
    @State private var confirmed = false
    @State private var saveNotices: [UUID: String] = [:]
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: PDFnoDesign.Space.section) {
                        Text("章节范围：当前完整 spine 文档。一个文档可能包含多个目录章节，一个目录章节也可能跨文档。本首片不按目录锚点推断逻辑章节。")
                            .foregroundStyle(.secondary).accessibilityIdentifier("chapter-definition")
                        Text("独立双语正文 · 原 EPUB 字节不改。保留基字，作者 ruby 读音不发送；图片与原版式不重建。结果仅在内存，退出应用前请主动保存需要的学习笔记。")
                            .font(.callout).foregroundStyle(.secondary)
                        if translation.offlineTransport {
                            Text("离线 UI 测试替身 · 所有请求已拦截").accessibilityIdentifier("chapter-offline-fixture")
                        }
                        if let snapshot = translation.preview {
                            Text(snapshot.scopeLabel).font(.headline).accessibilityIdentifier("chapter-scope")
                        }
                        if let error = translation.preparationError {
                            PDFnoStatusMessage(text: error, kind: .error, identifier: "chapter-preparation-error")
                        }
                        if let plan = translation.plan {
                            PDFnoSettingsCard("来源、接收方与现有范围", symbol: "book") {
                            Text("接收方：api.deepseek.com · deepseek-flash · 简体中文。只发送下列全部原文分段的 sourceText/task；不发送 EPUB、文件名、书籍身份、目录、上下文、笔记或历史结果。")
                            Text(verbatim: "完整计划 \(plan.sources.count) 段 / 最多 6 次请求；每段 ≤500 UTF-16、1024 输出 tokens、30 秒。合计 ≤\(plan.maxOutputTokens) 输出 tokens、\(plan.maxDurationSeconds) 秒请求超时预算。章节会话额度已用 \(translation.attemptsUsed) / 6。失败和取消也计入，费用未知，已发请求可能收费；无自动重试。")
                                .font(.callout).accessibilityIdentifier("chapter-limits")
                            DisclosureGroup("完整原文预览（全部分段也在下方）") {
                                Text(plan.snapshot.text ?? "").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityIdentifier("chapter-full-preview")
                            }
                            if !translation.submitted {
                                SecureField("亲自输入本次临时密钥", text: $translation.temporarySecret)
                                    .accessibilityIdentifier("chapter-session-key").disabled(translation.busy)
                                Text("发送后输入框清空；完成、取消或关闭清除本次凭据。不保存到文件或 Keychain，不使用选文或自测密钥。")
                                    .font(.caption).foregroundStyle(.secondary)
                                Toggle("我确认发送此 spine 文档全部分段、接收方、预算及可能费用", isOn: $confirmed)
                                    .disabled(translation.busy).accessibilityIdentifier("chapter-scope-consent")
                                Button("发送完整文档全部 \(plan.sources.count) 段") {
                                    translation.start(confirmed: confirmed, sourceIsCurrent: library.isCurrentAISource); confirmed = false
                                }.buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("chapter-start")
                                    .disabled(!confirmed || translation.temporarySecret.isEmpty || translation.busy || plan.sources.count > 6 - translation.attemptsUsed)
                            }
                            if translation.busy {
                                Button("取消剩余分段") { translation.cancel(); confirmed = false }.accessibilityIdentifier("chapter-cancel")
                            }
                            Button("回到此文档原文") { returnToSource(plan.sources.first) }.accessibilityIdentifier("chapter-return-source")
                            PDFnoStatusMessage(text: translation.status, kind: translation.busy ? .busy : .information, identifier: "chapter-status")
                            if let error = translation.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "chapter-error") }
                            }
                            cards(plan: plan, segments: $translation.segments, width: geometry.size.width, retained: false)
                        }
                        ForEach($translation.retainedBatches) { $batch in
                            Divider()
                            Text("保留的已完成分段 · " + batch.plan.snapshot.scopeLabel).font(.headline)
                            Text("来源变化后，先主动回到该来源，再保存。关闭窗口保留内存结果；退出应用前请主动保存需要的学习笔记。")
                                .font(.caption).foregroundStyle(.secondary)
                            cards(plan: batch.plan, segments: $batch.segments, width: geometry.size.width, retained: true)
                        }
                    }.font(PDFnoDesign.TypeStyle.body).padding(PDFnoDesign.Space.section).frame(maxWidth: .infinity, alignment: .leading)
                }.accessibilityIdentifier("chapter-scroll")
            }.navigationTitle("当前 EPUB spine 文档 · 双语对照")
            .toolbar { ToolbarItem { Button("完成（取消未完成请求）") { translation.cancel(); dismiss() }.accessibilityIdentifier("chapter-close") } }
        }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: 860, minHeight: 560, idealHeight: 740)
        .onChange(of: translation.temporarySecret) { _, _ in confirmed = false }
        .onDisappear { translation.cancel() }
    }
    private func returnToSource(_ source: AISourceSnapshot?) {
        Task { translation.cancel(); if let source, await library.returnToAISource(source) { dismiss() } }
    }
    @ViewBuilder private func cards(plan: EPUBChapterTranslationPlan, segments: Binding<[EPUBChapterTranslationSegment]>, width: CGFloat, retained: Bool) -> some View {
        ForEach(segments) { $segment in
            if !retained || segment.result != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("第 \(segment.id + 1) / \(plan.sources.count) 段 · " + segment.source.anchor.locationLabel).font(.headline)
                    if width >= 720 {
                        HStack(alignment: .top, spacing: 20) { original(segment); translated(segment) }
                    } else { VStack(alignment: .leading, spacing: 12) { original(segment); translated(segment) } }
                    if let result = segment.result {
                        TextField("此段学习笔记（可选）", text: $segment.userText, axis: .vertical).lineLimit(3...8)
                            .autocorrectionDisabled(true)
                            .accessibilityIdentifier("chapter-user-note-\(segment.id)")
                        Button("引用 · 回到此段原文") { returnToSource(segment.source) }
                            .accessibilityIdentifier("chapter-segment-return-\(segment.id)")
                        let saved = learning.notes.contains(where: { $0.result.requestID == result.requestID })
                        Button(saved ? "此段学习笔记已保存" : "保存此段到学习笔记") {
                            let text = segment.userText
                            saveNotices[result.requestID] = "正在保存"
                            Task {
                                saveNotices[result.requestID] = await learning.saveChapterResult(result, userText: text, validateSource: library.validateChapterSource)
                                    ? "学习笔记已保存 · 原文、译文与用户正文分别保留" : (learning.error ?? "学习笔记未保存")
                            }
                        }.buttonStyle(PDFnoActionStyle(role: .primary)).disabled(saved || translation.busy).accessibilityIdentifier("chapter-save-\(segment.id)")
                        if let notice = saveNotices[result.requestID] { PDFnoStatusMessage(text: notice, kind: saved ? .success : .information, identifier: "chapter-note-status-\(segment.id)") }
                    }
                }.pdfnoCard()
            }
        }
    }
    private func original(_ segment: EPUBChapterTranslationSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("原文").font(.caption).foregroundStyle(.secondary)
            PDFnoTextViewport(text: segment.source.anchor.quote, identifier: "chapter-original-\(segment.id)", height: 180)
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
    private func translated(_ segment: EPUBChapterTranslationSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("译文").font(.caption).foregroundStyle(.secondary)
            if let result = segment.result { PDFnoTextViewport(text: result.text, identifier: "chapter-result-\(segment.id)", height: 180) }
            else if let failure = segment.failure { PDFnoStatusMessage(text: "此段未完成：" + failure.localizedDescription, kind: .error) }
            else { PDFnoStatusMessage(text: "尚未完成", kind: .information) }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}
#endif
