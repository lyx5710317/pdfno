// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    /// The host must retain one adapter for the library lifetime, as it does noteEditing.
    /// A separate v1 journal leaves legacy drafts byte-for-byte untouched.
    func makeRecordEditingAdapter() async -> RecordEditingAdapter {
        RecordEditingAdapter(root: await repository.root, library: self)
    }
}

@MainActor
final class RecordEditingAdapter {
    let editor: RecordEditingModel
    private weak var library: LibraryModel?
    init(root: URL, library: LibraryModel) {
        self.library = library
        editor = RecordEditingModel(root: root, filename: "record-edit-drafts-v1.json") {
            [text = library.textFormats.repository, ebook = library.ebook.repository, japanese = library.japaneseRepository] snapshot, body in
            switch snapshot {
            case .text(let n): return .text(try await text.updateNoteBody(expected: n, text: body))
            case .ebook(let n): return .ebook(try await ebook.updateNoteBody(expected: n, text: body))
            case .japanese(let n): return .japanese(try await japanese.updateNoteBody(expected: n, text: body))
            }
        }
    }
    func save(_ note: RecordBodySnapshot) async {
        guard let library else { return }
        let textSession = library.textFormats.reader.readerSessionID, ebookSession = library.ebook.reader.readerSessionID
        guard let saved = await editor.save(note) else { return }
        publish(saved, library: library, textSession: textSession, ebookSession: ebookSession)
    }
    func reload(_ note: RecordBodySnapshot) async {
        guard let library else { return }
        do {
            let fresh: RecordBodySnapshot
            switch note {
            case .text:
                guard let n = try await library.textFormats.repository.load().notes.first(where: { $0.id == note.noteID && $0.bookID == note.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .text(n)
            case .ebook:
                guard let n = try await library.ebook.repository.load().notes.first(where: { $0.id == note.noteID && $0.bookID == note.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .ebook(n)
            case .japanese:
                guard let n = try await library.japaneseRepository.load().notes.first(where: { $0.id == note.noteID && $0.review.source.bookID == note.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .japanese(n)
            }
            publish(fresh, library: library, textSession: nil, ebookSession: nil); editor.rebase(fresh)
        } catch { editor.reportReloadFailure(note) }
    }
    private func publish(_ note: RecordBodySnapshot, library: LibraryModel, textSession: UUID?, ebookSession: UUID?) {
        switch note {
        case .text(let n): library.textFormats.publishEditedNote(n, session: textSession)
        case .ebook(let n): library.ebook.publishEditedNote(n, session: ebookSession)
        case .japanese(let n):
            if let i = library.japaneseNotes.firstIndex(where: { $0.id == n.id }) { library.japaneseNotes[i] = n }
        }
    }
}
#endif
