// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct PDFPageTranslationWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    @ObservedObject var translation: PDFPageTranslationModel
    @ObservedObject var learning: AILearningModel
    @State private var confirmed = false
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("独立双语文本对照 · 原 PDF 保留。仅翻译提取文字，不覆盖原版式；图片、表格结构与阅读顺序不保证还原。")
                        .font(.callout).foregroundStyle(.secondary)
                    if translation.offlineTransport {
                        Text("离线 UI 测试替身 · 所有请求已拦截").accessibilityIdentifier("page-offline-fixture")
                    }
                    if let preparationError = translation.preparationError {
                        Text(preparationError).foregroundStyle(.red).accessibilityIdentifier("page-preparation-error")
                    }
                    if let plan = translation.plan {
                        Text("PDF 第 \(plan.snapshot.pageIndex + 1) 页 · 完整可提取文本 \(plan.snapshot.text.utf16.count) UTF-16 单位 · \(plan.sources.count) 段")
                            .font(.headline).accessibilityIdentifier("page-scope")
                        Text("接收方：api.deepseek.com · deepseek-flash · 简体中文。仅按下列完整计划发送 sourceText/task，不上传 PDF、图片、文件名、笔记或其他页面。")
                        Text("本页最多 \(plan.sources.count) 次请求，每段 ≤500 UTF-16、1024 输出 tokens、30 秒；本页合计 ≤\(plan.maxOutputTokens) 输出 tokens，请求超时预算合计 \(plan.maxDurationSeconds) 秒。整页会话额度已用 \(translation.attemptsUsed) / 6；失败和取消也计入。费用未知，取消后已发请求可能仍收费。无自动重试。")
                            .font(.callout).accessibilityIdentifier("page-limits")
                        DisclosureGroup("完整原文预览（全部分段也在下方）") {
                            Text(plan.snapshot.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("page-full-preview")
                        }
                        SecureField("亲自输入本次临时密钥", text: $translation.temporarySecret)
                            .accessibilityIdentifier("page-session-key").disabled(translation.busy)
                        Text("密钥仅用于本次发送；发送后输入框清空，完成、取消或关闭清除会话凭据，不保存到文件或 Keychain。")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("我确认发送本页全部分段及以上接收方、上限和可能费用", isOn: $confirmed)
                            .disabled(translation.busy).accessibilityIdentifier("page-scope-consent")
                        HStack {
                            Button("发送本页全部 \(plan.sources.count) 段") {
                                translation.start(confirmed: confirmed, sourceIsCurrent: library.isCurrentAISource)
                                confirmed = false
                            }.buttonStyle(.borderedProminent).accessibilityIdentifier("page-start")
                                .disabled(!confirmed || translation.temporarySecret.isEmpty || translation.busy || translation.segments.contains(where: { $0.result != nil }) || plan.sources.count > 6 - translation.attemptsUsed)
                            if translation.busy { Button("取消剩余分段") { translation.cancel(); confirmed = false }.accessibilityIdentifier("page-cancel") }
                            Button("回到原 PDF 页") {
                                Task { translation.cancel(); if let source = plan.sources.first, await library.returnToAISource(source) { dismiss() } }
                            }.accessibilityIdentifier("page-return-source")
                        }
                        Text(translation.status).accessibilityIdentifier("page-status")
                        if let error = translation.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("page-error") }
                        if plan.sources.count > 6 - translation.attemptsUsed, !translation.busy, translation.segments.allSatisfy({ $0.result == nil }) {
                            Text(PDFPageTranslationFailure.budget.localizedDescription).foregroundStyle(.red)
                        }
                        ForEach($translation.segments) { $segment in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("第 \(segment.id + 1) / \(plan.sources.count) 段 · \(segment.source.anchor.locationLabel)").font(.headline)
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top, spacing: 20) {
                                        original(segment).frame(minWidth: 280)
                                        translated(segment).frame(minWidth: 280)
                                    }
                                    VStack(alignment: .leading, spacing: 12) { original(segment); translated(segment) }
                                }
                                if let result = segment.result {
                                    TextField("此段学习笔记（可选）", text: $segment.userText, axis: .vertical)
                                        .accessibilityIdentifier("page-user-note-\(segment.id)")
                                    let saved = learning.notes.contains(where: { $0.result.requestID == result.requestID })
                                    Button(saved ? "此段学习笔记已保存" : "保存此段到学习笔记") {
                                        let userText = segment.userText
                                        Task {
                                            notice = await learning.savePageResult(result, userText: userText, sourceIsCurrent: library.isCurrentAISource)
                                                ? "学习笔记已保存 · 原文与 AI 结果和用户正文分别保留" : learning.error
                                        }
                                    }.disabled(saved).accessibilityIdentifier("page-save-\(segment.id)")
                                }
                            }.padding().background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if let notice { Text(notice).accessibilityIdentifier("page-note-status") }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.navigationTitle("当前 PDF 页 · 双语对照")
            .toolbar { ToolbarItem { Button("完成（取消未完成请求）") { translation.cancel(); dismiss() }.accessibilityIdentifier("page-close") } }
        }.frame(minWidth: 520, idealWidth: 860, minHeight: 560, idealHeight: 740)
        .onChange(of: translation.temporarySecret) { _, _ in confirmed = false }
        .onDisappear { translation.cancel() }
    }
    private func original(_ segment: PDFPageTranslationSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("原文").font(.caption).foregroundStyle(.secondary)
            Text(segment.source.anchor.quote).textSelection(.enabled).accessibilityIdentifier("page-original-\(segment.id)")
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
    private func translated(_ segment: PDFPageTranslationSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("译文").font(.caption).foregroundStyle(.secondary)
            if let result = segment.result { Text(result.text).textSelection(.enabled).accessibilityIdentifier("page-result-\(segment.id)") }
            else if let failure = segment.failure { Text("此段未完成：" + failure.localizedDescription).foregroundStyle(.red) }
            else { Text("尚未完成").foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}
#endif
