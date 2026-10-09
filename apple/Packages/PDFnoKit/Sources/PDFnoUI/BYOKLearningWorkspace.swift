// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct BYOKSettingsSheet: View {
    @ObservedObject var model: BYOKSettingsModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            BYOKSettingsView(model: model).navigationTitle("HTTPS BYOK选文 · 独立会话配置")
                .toolbar { ToolbarItem { Button("完成") { dismiss() }.accessibilityIdentifier("byok-settings-close") } }
        }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: PDFnoDesign.Metric.sheetIdeal, minHeight: 560)
    }
}

struct BYOKSelectionEntry: View {
    @ObservedObject var library: LibraryModel
    let identifier: String
    var disabled = false
    let present: () -> Void
    var body: some View {
        Button("BYOK选文 · 翻译/解释") {
            Task { await library.prepareBYOKSelection(); present() }
        }.disabled(disabled).accessibilityIdentifier(identifier)
            .help("独立HTTPS会话配置；先预览域名、模型与完整选文，不会自动发送")
    }
}

struct BYOKLearningWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var model: BYOKSettingsModel
    var embedded = false
    var close: (() -> Void)? = nil
    var consentRevision: UUID? = nil
    @Environment(\.pdfnoWorkspaceNavigation) private var navigation
    @Environment(\.dismiss) private var dismiss
    @State private var kind = AILearningKind.translate
    @State private var settings = false
    @State private var saving = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFnoAdaptiveActions {
                    Button("重新固定选文") { Task { await library.prepareBYOKSelection(kind: kind) } }
                        .disabled(model.busy || saving).accessibilityIdentifier("byok-recapture")
                    Button("完成（取消未完成请求）") { library.invalidateBYOKSelection(); finish() }
                        .disabled(saving).accessibilityIdentifier("byok-close")
                }.padding()
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: PDFnoDesign.Space.section) {
                        if library.byokOfflineTransport {
                            Text("离线transport替身 · 不发送真实API").accessibilityIdentifier("byok-offline-fixture")
                        }
                        Text("独立会话配置；只发送下方固定选文。服务选择不会发送请求或保存密钥。").font(.caption).foregroundStyle(.secondary)
                        Button("配置HTTPS BYOK") { if let navigation { navigation.showSettings() } else { settings = true } }.accessibilityIdentifier("byok-selection-settings")
                        Picker("选文任务", selection: $kind) {
                            Text("翻译").tag(AILearningKind.translate)
                            Text("段落解释").tag(AILearningKind.explain)
                        }.pickerStyle(.segmented).accessibilityIdentifier("byok-kind").disabled(model.busy || saving)
                        BYOKSelectionConsentView(model: model, sourceIsCurrent: library.isCurrentBYOKSource, consentRevision: consentRevision)
                        if let result = model.result {
                            if let explanation = result.paragraphExplanation {
                                ParagraphExplanationResultView(explanation: explanation, source: result.source, library: library, current: library.isCurrentBYOKSource(result.source), summaryIdentifier: "byok-result") { finish() }
                            }
                            TextField("你的笔记（与模型结果独立）", text: $library.byokUserText, axis: .vertical).lineLimit(3...8)
                                .accessibilityIdentifier("byok-user-note")
                            Button("保存BYOK学习笔记") {
                                saving = true
                                Task { _ = await library.saveBYOKResult(); saving = false }
                            }.buttonStyle(PDFnoActionStyle(role: .primary)).disabled(!result.canSaveSelectionResult || saving || result.provider != model.draft || !library.isCurrentBYOKSource(result.source)
                                || library.learning.notes.contains { $0.result.requestID == result.requestID })
                                .accessibilityIdentifier("byok-save-note")
                            Button("引用 · 回到原文") {
                                Task {
                                    if library.isCurrentBYOKSource(result.source), await library.returnToAISource(result.source) { finish() }
                                }
                            }.accessibilityIdentifier("byok-result-source")
                        }
                        if let status = library.byokSaveStatus { PDFnoStatusMessage(text: status, kind: saving ? .busy : .information, identifier: "byok-save-status") }
                        Text("只有手动保存才写学习笔记；关闭不会自动保存结果。").font(.caption).foregroundStyle(.secondary)
                    }.font(PDFnoDesign.TypeStyle.body).padding(PDFnoDesign.Space.section).frame(maxWidth: .infinity, alignment: .leading)
                }.accessibilityIdentifier("byok-selection-workspace")
            }.navigationTitle("BYOK固定选文")
        }.frame(minWidth: embedded ? 0 : PDFnoDesign.Metric.sheetMinimum, idealWidth: embedded ? 300 : PDFnoDesign.Metric.sheetIdeal, minHeight: embedded ? 0 : 600)
            .onChange(of: model.preview?.request.kind) { _, value in if let value { kind = value } }
            .onChange(of: kind) { _, value in
                if model.preview?.request.kind != value { Task { await library.prepareBYOKSelection(kind: value) } }
            }
            .onDisappear { library.invalidateBYOKSelection() }
            .sheet(isPresented: $settings) { BYOKSettingsSheet(model: model) }
    }
    private func finish() { if let close { close() } else { dismiss() } }
}
#endif
