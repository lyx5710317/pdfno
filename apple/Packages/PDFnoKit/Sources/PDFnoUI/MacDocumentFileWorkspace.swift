// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

enum MacDocumentFileAction { case settings, translation, trash }
struct MacDocumentFilePanel: Identifiable {
    let id = UUID()
    let model: LibraryModel
    let action: MacDocumentFileAction
    let recovery: LocalRecoveryManagementModel?
}
struct MacDocumentMoreMenu: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject private var epub: EPUBReaderSession
    let open: (MacDocumentFileAction) -> Void
    init(model: LibraryModel, open: @escaping (MacDocumentFileAction) -> Void) {
        self.model = model; self.epub = model.epub; self.open = open
    }
    var body: some View {
        Menu {
            Text(model.displayedDocumentTitle)
            Button("文件设置…") { open(.settings) }.disabled(model.currentDocumentCover == nil)
                .accessibilityIdentifier("document-file-settings")
            Button("阅读翻译…") { open(.translation) }
                .disabled(![PDFnoReadingToolContext.Format.pdf, .epub].contains(PDFnoReadingToolContext(library: model).format))
                .accessibilityIdentifier("document-reading-translation")
            Divider()
            Button("移至回收站…") { open(.trash) }.accessibilityIdentifier("document-move-to-trash")
        } label: { Image(systemName: "ellipsis").frame(width: 22, height: 28) }
            .disabled(model.isBusy || model.storageMaintenance || model.hasDocumentSaveInFlight)
            .accessibilityLabel("当前文件更多操作").accessibilityIdentifier("document-more")
            .menuStyle(.borderlessButton).fixedSize()
    }
}
struct MacDocumentFileWorkspace: View {
    let panel: MacDocumentFilePanel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            switch panel.action {
            case .translation: ReadingTranslationWorkspace(library: panel.model)
            case .settings:
                if let cover = panel.model.currentDocumentCover {
                    VStack(spacing: 0) {
                        Text("文件设置 · " + panel.model.displayedDocumentTitle).font(.headline).padding(14)
                        Divider()
                        LibraryCoverEditor(covers: panel.model.covers, item: cover)
                    }.frame(width: 600, height: 560)
                } else {
                    VStack(spacing: 16) {
                        Text("文件设置 · " + panel.model.displayedDocumentTitle).font(.headline)
                        Text("此格式暂无自选封面设置。")
                        Button("完成") { dismiss() }.accessibilityIdentifier("cover-editor-done")
                    }.padding(24).frame(width: 480, height: 260)
                }
            case .trash:
                if let recovery = panel.recovery {
                    MacDocumentTrashWorkspace(recovery: recovery)
                }
            }
        }
    }
}
private struct MacDocumentTrashWorkspace: View {
    @ObservedObject var recovery: LocalRecoveryManagementModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            LocalRecoveryWorkspace(model: recovery, mode: .change)
            Button("完成") { dismiss() }.disabled(recovery.busy).accessibilityIdentifier("local-recovery-close").padding()
        }.frame(width: 600, height: 420)
    }
}
extension LibraryModel {
    var currentDocumentCover: LibraryCoverItem? {
        guard let id = displayedDocumentID else { return nil }
        if let book = books.first(where: { $0.id == id }) { return .init(identity: CoverIdentity(book), title: book.title, subtitle: "PDF", accessibilityID: "current-file-cover") }
        if let book = epubBooks.first(where: { $0.id == id }) { return .init(identity: CoverIdentity(book), title: book.title, subtitle: "EPUB", accessibilityID: "current-file-cover") }
        if let book = docx.books.first(where: { $0.id == id }) { return .init(identity: CoverIdentity(book), title: book.title, subtitle: "DOCX", accessibilityID: "current-file-cover") }
        if let book = comicBooks.first(where: { $0.id == id }) { return .init(identity: CoverIdentity(book), title: book.title, subtitle: "漫画", accessibilityID: "current-file-cover") }
        return nil
    }
}
#endif
