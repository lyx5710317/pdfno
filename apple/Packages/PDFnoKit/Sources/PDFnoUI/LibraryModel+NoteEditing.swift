// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

extension LibraryModel {
    func reloadEditedNote(_ baseline: NoteBodySnapshot) async {
        do {
            let fresh: NoteBodySnapshot
            switch baseline {
            case .pdf:
                guard let note = try await repository.load().notes.first(where: { $0.id == baseline.noteID && $0.bookID == baseline.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .pdf(note); if let i = notes.firstIndex(where: { $0.id == note.id }) { notes[i] = note }
            case .epub:
                guard let note = try await epubRepository.load().notes.first(where: { $0.id == baseline.noteID && $0.bookID == baseline.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .epub(note); if let i = epubNotes.firstIndex(where: { $0.id == note.id }) { epubNotes[i] = note }
            case .learning:
                guard let note = try await learning.repository.load().notes.first(where: { $0.id == baseline.noteID && $0.result.source.bookID == baseline.bookID }) else { throw NoteBodyEditError.conflict }
                fresh = .learning(note); if let i = learning.notes.firstIndex(where: { $0.id == note.id }) { learning.notes[i] = note }
            }
            noteEditing.rebase(fresh)
        } catch { noteEditing.reportReloadFailure(baseline) }
    }
    func saveEditedNote(_ baseline: NoteBodySnapshot) async {
        let pdfSession = reader.readerSessionID
        #if os(macOS)
        let epubSession = epub.readerSessionID
        #endif
        guard let saved = await noteEditing.save(baseline) else { return }
        // Publish the existing arrays for sidebar/search observers. Avoid a
        // whole-library reload that could replace a newly opened reader.
        switch saved {
        case .pdf(let note):
            if let i = notes.firstIndex(where: { $0.id == note.id && $0.bookID == note.bookID }) { notes[i] = note }
            if !readingEPUB, !readingComic, reader.book?.id == note.bookID, reader.readerSessionID == pdfSession {
                #if os(macOS)
                if !docx.isActive, !textFormats.isActive, !ebook.isActive { reader.project(notes) }
                #else
                reader.project(notes)
                #endif
            }
        case .epub(let note):
            if let i = epubNotes.firstIndex(where: { $0.id == note.id && $0.bookID == note.bookID }) { epubNotes[i] = note }
            #if os(macOS)
            if readingEPUB, epub.book?.id == note.bookID, epub.readerSessionID == epubSession {
                _ = await epub.command("notes", notes: epubNotes.filter { $0.bookID == note.bookID })
            }
            #endif
        case .learning(let note):
            if let i = learning.notes.firstIndex(where: { $0.id == note.id }) { learning.notes[i] = note }
        }
    }
}
