// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct ReadingSelectionActions: View {
    let available: Bool
    let busy: Bool
    let highlight: () -> Void
    let note: () -> Void
    let translate: () -> Void
    let explain: () -> Void
    let japanese: () -> Void
    let english: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            action("高亮", "highlighter", "selection-highlight", highlight)
            action("笔记", "note.text", "selection-note", note)
            action("翻译", "character.bubble", "selection-translate", translate)
            action("解释", "sparkles", "selection-explain", explain)
            Menu {
                Button("日语选文学习", action: japanese).accessibilityIdentifier("selection-japanese")
                Button("英语结构与语法", action: english).accessibilityIdentifier("selection-english")
            } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多选文操作")
                .accessibilityIdentifier("selection-more").menuStyle(.borderlessButton).fixedSize()
            Spacer(minLength: 0)
        }.font(.system(size: 11)).buttonStyle(ProfessionalLibraryActionStyle())
            .padding(8).background(PDFnoDesign.Palette.chrome)
            .disabled(!available || busy)
    }
    private func action(_ title: String, _ symbol: String, _ identifier: String, _ command: @escaping () -> Void) -> some View {
        Button(action: command) { Label(title, systemImage: symbol) }.accessibilityIdentifier(identifier)
    }
}

/// Provider choice changes presentation and a consent revision, never sends or applies settings.
/// Both result owners stay mounted so switching providers retains their independent drafts.
struct ReadingSelectionWorkspace: View {
    @ObservedObject var library: LibraryModel
    let close: () -> Void
    private enum Service: String, CaseIterable { case reading, byok }
    @State private var service = Service.reading
    @State private var consentRevision = UUID()
    var body: some View {
        VStack(spacing: 0) {
            Picker("服务来源", selection: $service) {
                Text("阅读配置").tag(Service.reading)
                Text("独立 HTTPS BYOK").tag(Service.byok)
            }.font(.system(size: 12)).padding(10).accessibilityIdentifier("selection-service")
                .disabled(library.learning.busy || library.learning.saving || library.byok.busy || library.byok.saving)
            Divider()
            ZStack {
                AILearningWorkspace(library: library, learning: library.learning, embedded: true,
                    close: close, consentRevision: consentRevision)
                    .opacity(service == .reading ? 1 : 0).allowsHitTesting(service == .reading)
                    .disabled(service != .reading).accessibilityHidden(service != .reading)
                BYOKLearningWorkspace(library: library, model: library.byok, embedded: true, close: close, consentRevision: consentRevision)
                    .opacity(service == .byok ? 1 : 0).allowsHitTesting(service == .byok)
                    .disabled(service != .byok).accessibilityHidden(service != .byok)
            }
        }.onChange(of: service) { _, value in
            consentRevision = UUID()
            if value == .byok {
                Task {
                    await library.byok.load()
                    if let preview = library.byok.preview, library.isCurrentBYOKSource(preview.request.source) { return }
                    await library.prepareBYOKSelection(kind: library.learning.kind)
                }
            }
        }
    }
}
#endif
