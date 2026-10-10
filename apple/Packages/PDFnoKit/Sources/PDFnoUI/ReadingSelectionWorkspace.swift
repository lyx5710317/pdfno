// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

struct ReadingSelectionActions: View {
    var includeNote = true
    var includeHighlight = true
    let available: Bool
    let busy: Bool
    let highlight: () -> Void
    let note: () -> Void
    let translate: () -> Void
    let explain: () -> Void
    let japanese: () -> Void
    let english: () -> Void
    @Environment(\.pdfnoReaderRailExpanded) private var expanded
    var body: some View {
        VStack(spacing: 5) {
            if includeHighlight { action("高亮", "highlighter", "selection-highlight", highlight) }
            if includeNote { action("笔记", "note.text", "selection-note", note) }
            action("翻译", "character.bubble", "selection-translate", translate)
            action("解释", "sparkles", "selection-explain", explain)
            Menu {
                Button("日语选文学习", action: japanese).accessibilityIdentifier("selection-japanese")
                Button("英语结构与语法", action: english).accessibilityIdentifier("selection-english")
            } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多选文操作")
                .accessibilityIdentifier("selection-more").menuStyle(.borderlessButton).fixedSize()
        }.font(.system(size: 11)).buttonStyle(PDFnoActionStyle(role: .quiet))
            .labelStyle(PDFnoReaderRailLabelStyle(expanded: expanded))
            .disabled(!available || busy)
    }
    private func action(_ title: String, _ symbol: String, _ identifier: String, _ command: @escaping () -> Void) -> some View {
        Button(action: command) { Label(title, systemImage: symbol).frame(maxWidth: .infinity).frame(minHeight: 32) }.accessibilityIdentifier(identifier).help(title)
    }
}

/// A rail and a selection sheet present the same document-owned conversation.
struct ReadingSelectionWorkspace: View {
    @ObservedObject var library: LibraryModel
    let close: () -> Void
    var body: some View { ReadingConversationWorkspace(library: library, close: close) }
}
extension LibraryModel {
    var hasUnsavedBYOKPresentation: Bool {
        guard let result = byok.result else { return !byokUserText.isEmpty }
        return !learning.notes.contains { $0.result.requestID == result.requestID && $0.userText == byokUserText }
    }
    func reconnectBYOKPresentation(kind: AILearningKind) -> Bool {
        guard let result = byok.result, result.kind == kind,
              ReadingSkillIdentity.matches(result.source, learning.source),
              ReadingSkillIdentity.matches(result.provider, byok.draft), isCurrentAISource(result.source) else { return false }
        byokSource = result.source
        return true
    }
}
#endif
