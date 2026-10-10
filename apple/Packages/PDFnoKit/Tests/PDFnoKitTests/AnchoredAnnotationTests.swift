// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI
#if os(macOS)
import AppKit
import SwiftUI
#endif

struct AnchoredAnnotationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Original-Annotations-"+UUID().uuidString) }
    private func anchor(_ book: BookRecord) -> AnnotationAnchor {
        .pdf(PDFSourceAnchor(editionID: book.editionID,fileSHA256: book.fileSHA256,quote: "window",regions: [.init(pageIndex: 0,x: 72,y: 650,width: 40,height: 16,quote: "window")]))
    }
    @Test func languageUsesMetadataAndPrimaryWholeDocumentWithKoreanExcluded() {
        let chinese=String(repeating: "这是原创阅读文本，文字选择与学习。",count: 12)
        let japanese=String(repeating: "これは自作の読書資料です。日本語の文章を学びます。",count: 12)
        let english=String(repeating: "Original English reading about language and annotations. ",count: 12)
        #expect(DocumentWritingLanguage.classify(metadata: "zh-Hans",text: chinese) == .simplifiedChinese)
        #expect(DocumentWritingLanguage.classify(metadata: "zh-Hant-TW",text: chinese) == .traditionalChinese)
        #expect(DocumentWritingLanguage.classify(metadata: "ja-JP",text: japanese) == .japanese)
        #expect(DocumentWritingLanguage.classify(metadata: "en",text: chinese).permitsVerticalReflow)
        #expect(DocumentWritingLanguage.classify(metadata: "broken/value",text: japanese) == .japanese)
        #expect(!DocumentWritingLanguage.classify(metadata: "ja",text: english).permitsVerticalReflow)
        #expect(!DocumentWritingLanguage.classify(text: english+"漢").permitsVerticalReflow)
        #expect(!DocumentWritingLanguage.classify(metadata: "ko",text: String(repeating: "이것은 한국어 독서 자료입니다 漢字 ",count: 20)).permitsVerticalReflow)
        #expect(DocumentWritingLanguage.classify(text: chinese+" 2026 ABC 3.14").permitsVerticalReflow)
        #expect(!DocumentWritingLanguage.classify(text: "").permitsVerticalReflow)
    }
    @Test func oneSourceOneRecordTypeAndCommentSurviveRestart() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root) }
        let book=BookRecord(title: "Original",fileSHA256: String(repeating: "a",count: 64),originalFilename: "original.pdf",pageCount: 1)
        let repository=AnnotationRepository(root: root)
        let marked=try await repository.mark(bookID: book.id,anchor: anchor(book),kind: .highlight)
        #expect(marked.userText.isEmpty && marked.revision==1)
        let commented=try await repository.save(expected: marked,text: "  原创批注\nか\u{3099}👩🏽‍🚀 e\u{301} ")
        let underlined=try await repository.mark(bookID: book.id,anchor: anchor(book),kind: .underline)
        let existing=try await repository.mark(bookID: book.id,anchor: anchor(book),kind: .note)
        #expect(underlined.id==marked.id && existing.id==marked.id && existing.kind == .underline)
        #expect(underlined.userText.utf8.elementsEqual(commented.userText.utf8))
        #expect(try await AnnotationRepository(root: root).load().notes == [underlined])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(AnnotationRepository.filename+".backup").path))
        let cleared=try await repository.save(expected: underlined,text: "")
        #expect(cleared.anchor==marked.anchor && cleared.kind == .underline && cleared.userText.isEmpty)
    }
    @Test func orientationDoesNotDuplicateTheSameEPUBExcerpt() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root) }
        let book=EPUBBook(fileSHA256: String(repeating: "b",count: 64),title: "Original",originalFilename: "original.epub")
        var source=EPUBAnchor(editionID: book.editionID,fileSHA256: book.fileSHA256,resourceHref: "Text/one.xhtml",spineIndex: 0,start: 0,end: 3,quote: "日本語",prefix: "",suffix: "",vertical: false)
        let repository=AnnotationRepository(root: root),first=try await repository.mark(bookID: book.id,anchor: .epub(source),kind: .highlight)
        source=source.withVertical(true)
        let second=try await repository.mark(bookID: book.id,anchor: .epub(source),kind: .underline)
        #expect(first.id==second.id && second.anchor==first.anchor)
        #expect(try await repository.load().notes.count==1)
    }
    @Test func explicitFutureAIProvenanceIsPreservedWithoutRelabellingManualMarks() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root) }
        let book=BookRecord(title: "Original",fileSHA256: String(repeating: "e",count: 64),originalFilename: "Original.pdf",pageCount: 1)
        let repository=AnnotationRepository(root: root),resultID=UUID()
        // Data-contract drill only. No AI transport, UI flow or legacy migration.
        let explicit=AnchoredAnnotation(bookID: book.id,anchor: anchor(book),kind: .note,origin: .explicitlySavedAI,sourceRecordID: resultID)
        let saved=try await repository.save(expected: explicit,text: "Original offline result explicitly saved in a future flow")
        let manual=try await repository.mark(bookID: book.id,anchor: anchor(book),kind: .highlight)
        #expect(manual.origin == .manual && manual.sourceRecordID==nil && manual.id != saved.id)
        let reopened=try await AnnotationRepository(root: root).load().notes
        #expect(reopened.count==2 && reopened.first?.origin == .explicitlySavedAI && reopened.first?.sourceRecordID==resultID)
        #expect(reopened.first?.anchor==manual.anchor)
    }
    @Test func staleWriterAndFutureNestedFieldsAreRefusedWithoutOverwriting() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root) }
        let book=BookRecord(title: "Original",fileSHA256: String(repeating: "c",count: 64),originalFilename: "original.pdf",pageCount: 1)
        let first=AnnotationRepository(root: root),second=AnnotationRepository(root: root)
        let original=try await first.mark(bookID: book.id,anchor: anchor(book),kind: .highlight)
        _=try await second.save(expected: original,text: "Newer saved text")
        await #expect(throws: NoteBodyEditError.self) { try await first.save(expected: original,text: "Stale text") }
        let file=root.appendingPathComponent(AnnotationRepository.filename)
        var object=try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var notes=try #require(object["notes"] as? [[String: Any]]);notes[0]["futureExplicitAISaveOrigin"]="preserve";object["notes"]=notes
        let bytes=try JSONSerialization.data(withJSONObject: object);try bytes.write(to: file)
        await #expect(throws: LibraryError.self) { try await first.mark(bookID: book.id,anchor: anchor(book),kind: .underline) }
        #expect(try Data(contentsOf: file)==bytes)
    }
    @Test func additiveAnnotationsAndLegacyNotesBothRoundTripThroughBackupAndTrash() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent+"-backup"));try? FileManager.default.removeItem(at: root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent+"-restored"));try? FileManager.default.removeItem(at: root) }
        let library=LibraryRepository(root: root),book=try await library.importPDF(originalSample(),filename: "Original.pdf",pageCount: 2)
        guard case .pdf(let source)=anchor(book) else { return }
        let old=ReadingNote(bookID: book.id,anchor: source,userText: "Original legacy body")
        try await library.saveNote(old)
        let oldFile=root.appendingPathComponent("library-v1.json"),oldBytes=try Data(contentsOf: oldFile)
        let annotations=AnnotationRepository(root: root),mark=try await annotations.mark(bookID: book.id,anchor: .pdf(source),kind: .highlight)
        _=try await annotations.save(expected: mark,text: "New annotation comment")
        #expect(try Data(contentsOf: oldFile)==oldBytes)
        let service=try LocalRecoveryService(root: root),permit=LocalRecoveryWritePermit(pausedRoot: root,writerEpoch: UUID())
        let backup=root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent+"-backup")
        let preview=try await service.exportBackup(to: backup,permit: permit)
        let restored=root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent+"-restored")
        _=try await service.restoreBackup(at: backup,preview: preview,to: restored,permit: permit)
        #expect(try await LibraryRepository(root: restored).load().notes == [old])
        #expect(try await AnnotationRepository(root: restored).load().notes.first?.userText=="New annotation comment")
        let target=try #require(try await service.books().first)
        let removal=try await service.previewMoveToTrash(.book(target));_=try await service.moveToTrash(removal,permit: permit)
        #expect(try await annotations.load().notes.isEmpty)
        let tombstone=try #require(try await service.tombstones().first)
        let restore=try await service.previewRestoreTombstone(tombstone.id);_=try await service.restoreTombstone(restore,permit: permit)
        #expect(try await annotations.load().notes.count==1)
        #expect(try await library.load().notes == [old])
    }
    #if os(macOS)
    @Test @MainActor func nativeInputKeepsExactPasteDraftAndSaveCancelWithTwoDocuments() async throws {
        let root=root();defer { try? FileManager.default.removeItem(at: root) }
        let book=BookRecord(title: "Original",fileSHA256: String(repeating: "d",count: 64),originalFilename: "original.pdf",pageCount: 1)
        let model=AnnotationModel(root: root),record=AnchoredAnnotation(bookID: book.id,anchor: anchor(book),kind: .note)
        model.begin(record);let snapshot=AnnotationBodySnapshot(record)
        let binding=Binding(get: { model.editor.drafts[snapshot.key]?.text ?? "" },set: { model.editor.setText($0,for: snapshot) })
        let coordinator=NativeNoteBodyInput.Coordinator(text: binding),scroll=NativeNoteBodyInput.makeEditor(coordinator: coordinator,identifier: "original-annotation-input",enabled: true)
        let input=try #require(scroll.documentView as? NSTextView),text=" 原创粘贴\nか\u{3099} 👩🏽‍🚀 e\u{301} "
        let pasteboard=NSPasteboard(name: .init("PDFno-Original-Annotation-Paste-"+UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents();pasteboard.setString(text,forType: .string)
        #expect(input.readSelection(from: pasteboard,type: .string))
        #expect(input.string.utf8.elementsEqual(text.utf8))
        model.editing=nil
        let reopened=AnnotationModel(root: root)
        #expect(reopened.editor.drafts[snapshot.key]?.text.utf8.elementsEqual(text.utf8)==true)
        let other=AnchoredAnnotation(bookID: UUID(),anchor: anchor(book),kind: .note)
        reopened.begin(other);reopened.editor.setText("Other document draft",for: AnnotationBodySnapshot(other))
        reopened.begin(record);await reopened.save(record)
        #expect(try await reopened.repository.load().notes.first?.userText.utf8.elementsEqual(text.utf8)==true)
        #expect(reopened.editor.drafts[snapshot.key]==nil && reopened.editor.drafts.count==1)
        reopened.cancel(other)
        #expect(try SavedBodyDraftJournal<AnnotationBodySnapshot>(root: root).load().isEmpty)
        reopened.begin(try #require(reopened.records.first));reopened.editor.setText("Discarded edit",for: AnnotationBodySnapshot(try #require(reopened.records.first)))
        reopened.cancel(try #require(reopened.records.first))
        #expect(try await reopened.repository.load().notes.first?.userText.utf8.elementsEqual(text.utf8)==true)
        withExtendedLifetime((scroll,coordinator)) {}
    }
    #endif
}
