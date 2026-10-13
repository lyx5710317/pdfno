// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import PDFnoDomain

struct ReadingConversationWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject private var conversation: ReadingConversationModel
    @ObservedObject private var learning: AILearningModel
    @ObservedObject private var tools: AIReadingToolsPreferences
    let close: () -> Void
    @Environment(\.pdfnoWorkspaceNavigation) private var navigation
    @State private var settings = false
    @State private var copiedAnswerID: UUID?
    init(library: LibraryModel, close: @escaping () -> Void) {
        self.library = library; conversation = library.conversation; learning = library.learning
        tools = library.learning.tools; self.close = close
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain)
                    .help("关闭，保留本文件对话").accessibilityLabel("关闭选文学习").accessibilityIdentifier("ai-close")
            }.padding(12)
            Divider()
            if let thread = conversation.current {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(thread.answers) { answer in
                                Text(verbatim: answer.question).font(.callout).padding(10)
                                    .frame(maxWidth: .infinity, alignment: .trailing).background(Color.blue.opacity(0.07),in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading,spacing: 8) {
                                    Text(verbatim: answer.result.displayText).textSelection(.enabled)
                                        .frame(maxWidth: .infinity,alignment: .leading).accessibilityIdentifier("ai-conversation-answer-" + answer.id.uuidString)
                                    HStack(spacing: 12) {
                                        Button(copiedAnswerID == answer.id ? "已复制" : "复制") { NSPasteboard.general.clearContents(); if NSPasteboard.general.setString(answer.result.displayText,forType: .string) { copiedAnswerID = answer.id } }
                                            .accessibilityIdentifier("ai-conversation-copy-" + answer.id.uuidString)
                                        Button(conversation.savedAnswers.contains(answer.id) ? "已加入笔记" : "加入笔记") { Task { _ = await conversation.addToNotes(answer) } }
                                            .disabled(conversation.savedAnswers.contains(answer.id) || conversation.savingAnswers.contains(answer.id))
                                            .accessibilityIdentifier("ai-conversation-save-" + answer.id.uuidString)
                                    }.font(.caption).buttonStyle(.borderless)
                                }.id(answer.id)
                            }
                            if let pending = thread.pendingQuestion { Text(verbatim: pending).font(.callout).foregroundStyle(.secondary); ProgressView("正在生成…") }
                            if let failed = thread.failedQuestion { Text(verbatim: failed).font(.callout).foregroundStyle(.secondary) }
                            if thread.failedQuestion != nil || thread.invalidated {
                                Text(thread.status).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("ai-conversation-status")
                            }
                            if !conversation.connectionAvailable { Button("打开设置 → AI") { openSettings() }.accessibilityIdentifier("ai-conversation-settings") }
                            if thread.failedQuestion != nil, !conversation.busy {
                                Button("重试") { conversation.retry() }.disabled(!conversation.connectionAvailable || thread.invalidated || !tools.isEnabled(thread.task))
                                    .accessibilityIdentifier("ai-conversation-retry")
                            }
                            if let status = conversation.saveStatus { Text(status).font(.caption).accessibilityIdentifier("ai-conversation-save-status") }
                            Color.clear.frame(height: 1).id("end")
                        }.padding(12)
                    }.accessibilityIdentifier("ai-conversation-messages")
                        .onChange(of: thread.answers.count) { _, _ in proxy.scrollTo("end",anchor: .bottom) }
                }
                Divider()
                HStack(alignment: .bottom,spacing: 8) {
                    Button { Task { _ = await library.returnToAISource(thread.source) } } label: { Image(systemName: "arrow.up.left") }
                        .help("回到原文").accessibilityLabel("回到原文").accessibilityIdentifier("ai-conversation-return")
                    TextField("继续询问这段选文…",text: Binding(get: { conversation.current?.draft ?? "" },set: { conversation.setDraft($0) }),axis: .vertical)
                        .lineLimit(1...3).textFieldStyle(.roundedBorder).onSubmit { conversation.sendFollowup() }
                        .disabled(conversation.busy || thread.invalidated || !tools.isEnabled(thread.task))
                        .accessibilityIdentifier("ai-conversation-input")
                    if conversation.busy {
                        Button("停止") { conversation.stop() }.accessibilityIdentifier("ai-conversation-stop")
                    } else {
                        Button { conversation.sendFollowup() } label: { Image(systemName: "arrow.up") }
                            .keyboardShortcut(.return,modifiers: .command)
                            .disabled(thread.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !conversation.connectionAvailable || thread.invalidated || !tools.isEnabled(thread.task))
                            .help("发送追问").accessibilityLabel("发送追问").accessibilityIdentifier("ai-conversation-send")
                    }
                }.padding(12)
            } else {
                VStack(alignment: .leading,spacing: 14) {
                    Text("请选择原文后使用选文 AI 菜单。").font(.callout)
                    if !conversation.connectionAvailable { Button("打开设置 → AI") { openSettings() }.accessibilityIdentifier("ai-conversation-settings") }
                    Spacer()
                }.padding(16).frame(maxWidth: .infinity,alignment: .leading)
            }
        }.background(PDFnoDesign.Palette.surface)
            .sheet(isPresented: $settings) { AISettingsView(learning: learning,library: library) }
    }
    private func openSettings() {
        if let navigation { close(); navigation.showSettings() } else { settings = true }
    }
}
#endif
