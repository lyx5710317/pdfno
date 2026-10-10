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
    @State private var sourceExpanded = false
    @State private var settings = false
    @State private var copiedAnswerID: UUID?
    init(library: LibraryModel, close: @escaping () -> Void) {
        self.library = library; conversation = library.conversation; learning = library.learning
        tools = library.learning.tools; self.close = close
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label("选文学习", systemImage: "sparkles").font(.headline)
                if let thread = conversation.current { Text(thread.task.title).font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                if let current = conversation.current {
                    Menu { ForEach(conversation.threads) { thread in
                        Button(thread.task.title + " · " + String(thread.source.anchor.quote.prefix(24))) { conversation.select(thread.id) }
                    }
                        Divider()
                        Button("新建此选文对话") { conversation.open(current.task,source: current.source,fresh: true) }
                    } label: { Image(systemName: "bubble.left.and.bubble.right") }.help("本文件对话").accessibilityLabel("本文件对话").accessibilityIdentifier("ai-conversation-threads")
                }
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain)
                    .help("关闭，保留本文件对话").accessibilityLabel("关闭选文学习").accessibilityIdentifier("ai-close")
            }.padding(12)
            Divider()
            if let thread = conversation.current {
                VStack(alignment: .leading,spacing: 8) {
                    Button { sourceExpanded.toggle() } label: {
                        Label("原文 · " + thread.source.anchor.locationLabel,systemImage: sourceExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption).lineLimit(1).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("ai-conversation-source-toggle").accessibilityValue(sourceExpanded ? "已展开" : "已收起")
                    if sourceExpanded {
                        ScrollView { Text(verbatim: thread.source.anchor.quote).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            .frame(maxHeight: 110).accessibilityIdentifier("ai-conversation-source")
                        Button("回到原文") { Task { _ = await library.returnToAISource(thread.source) } }
                            .accessibilityIdentifier("ai-conversation-return")
                    }
                }.padding(12)
                if let host = try? BYOKSelectionPolicy.finalURL(learning.config).host, learning.config.mode == .openAICompatible {
                    Text("仅发送固定选文与本对话消息至 " + host).font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal,12).padding(.bottom,6)
                } else if learning.config.mode == .mock {
                    Text("本地 mock · 不联网").font(.caption2).foregroundStyle(.secondary).padding(.horizontal,12)
                }
                Divider()
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
                            Text(thread.status).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("ai-conversation-status")
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
                    Text("选择一段原文，开始对话").font(.headline)
                    Text("选文浮动菜单可直接开始解释、翻译或总结。日语与英语可在设置 → AI工具开启。").font(.callout).foregroundStyle(.secondary)
                    Menu("使用当前选文") { ForEach(ReadingConversationTask.allCases.filter { tools.isEnabled($0) },id: \.self) { task in
                        Button(task.title) { if let source = library.captureAISource() { conversation.open(task,source: source) } }
                    } }.accessibilityIdentifier("ai-conversation-start")
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
