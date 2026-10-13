// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

struct DocumentConversationWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject private var conversation: DocumentConversationModel
    @ObservedObject private var selectionConversation: ReadingConversationModel
    @Environment(\.pdfnoWorkspaceNavigation) private var navigation
    @State private var showConsent = false
    let close: () -> Void
    init(library: LibraryModel, close: @escaping () -> Void) {
        self.library = library; conversation = library.documentConversation
        selectionConversation = library.conversation; self.close = close
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if selectionConversation.current != nil, library.canResumeSelectionConversation {
                    Button("选文对话") { library.resumeSelectionConversation() }
                        .font(.caption).accessibilityIdentifier("document-ai-resume-selection")
                        .help("恢复已有选文回答与草稿")
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("关闭全文对话")
            }.padding(10)
            if conversation.loading { ProgressView("正在读取全文…").padding() }
            if let error = conversation.error {
                Text(error).font(.callout).foregroundStyle(.red).padding(12).accessibilityIdentifier("document-ai-error")
                if conversation.source == nil { Button("重新读取") { Task { await conversation.prepare() } } }
            }
            if conversation.confirmed || !conversation.answers.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(conversation.answers) { answer in
                            Text(answer.question).font(.callout).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(verbatim: answer.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("document-ai-answer")
                            Button("复制") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(answer.text, forType: .string) }.font(.caption)
                        }
                        if conversation.busy { ProgressView("正在回答…") }
                    }.padding(12)
                }.frame(maxHeight: .infinity)
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("询问这份文档…", text: $conversation.draft, axis: .vertical).lineLimit(1...3)
                        .textFieldStyle(.roundedBorder).onSubmit { conversation.sendFollowup() }
                        .disabled(conversation.busy || !conversation.confirmed).accessibilityIdentifier("document-ai-input")
                    if conversation.busy { Button("停止") { conversation.stop() } }
                    else { Button { conversation.sendFollowup() } label: { Image(systemName: "arrow.up") }
                        .disabled(!conversation.confirmed || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("发送全文追问") }
                }.padding(12)
            } else {
                Spacer(minLength: 24)
                VStack(spacing: 14) {
                    Image(systemName: "doc.text").font(.system(size: 28)).foregroundStyle(.blue)
                    Text(library.readingEPUB ? library.epub.book?.title ?? "当前文档" : library.reader.book?.title ?? "当前文档")
                        .font(.headline).multilineTextAlignment(.center).lineLimit(2)
                    if let source = conversation.source {
                        Text("\(source.format) · \(source.text.utf16.count) 字符").font(.caption).foregroundStyle(.secondary)
                    }
                    Button { showConsent = true } label: {
                        Text("开始对话").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(conversation.loading || conversation.source == nil || !conversation.connectionAvailable)
                        .accessibilityIdentifier("document-ai-start")
                    if !conversation.connectionAvailable {
                        Button("配置api") { close(); navigation?.showSettings() }.font(.caption)
                    }
                }.padding(18).frame(maxWidth: .infinity)
                    .background(PDFnoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(PDFnoDesign.Palette.border) }
                    .accessibilityIdentifier("document-ai-document-card")
                    .padding(14)
            }
        }.background(PDFnoDesign.Palette.surface)
            .confirmationDialog("发送完整文档？", isPresented: $showConsent, titleVisibility: .visible) {
                Button("发送并开始对话") { conversation.confirmAndStart() }.accessibilityIdentifier("document-ai-confirm-send")
                Button("取消", role: .cancel) {}.accessibilityIdentifier("document-ai-cancel-send")
            } message: {
                Text("将当前完整文档（\(conversation.source?.text.utf16.count ?? 0) 字符）发送至 \(conversation.receiverDescription)。本会话追问沿用该全文和会话消息。")
                    .accessibilityIdentifier("document-ai-consent")
            }
            .task(id: library.readingEPUB ? library.epub.readerSessionID : library.reader.readerSessionID) { await conversation.prepare() }
    }
}
#endif
