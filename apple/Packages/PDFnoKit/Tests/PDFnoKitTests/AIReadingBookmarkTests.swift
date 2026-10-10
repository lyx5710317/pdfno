// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Original offline fixtures only; no real book, network transport or credential.
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoServices

@Suite(.serialized) struct AIReadingBookmarkTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-AI-Bookmark-"+UUID().uuidString) }
    private func book() -> BookRecord { BookRecord(title: "Original",fileSHA256: String(repeating: "a",count: 64),originalFilename: "Original.pdf",pageCount: 2) }
    private func source(_ book: BookRecord) -> AISourceSnapshot {
        .init(bookID: book.id,readerSessionID: UUID(),documentVersion: 0,anchor: .pdf(.init(editionID: book.editionID,fileSHA256: book.fileSHA256,quote: "window",regions: [.init(pageIndex: 0,x: 72,y: 650,width: 40,height: 16,quote: "window")])))
    }
    private func provider() -> AIProviderConfig { var p=AIProviderConfig();p.mode = .mock;p.label="Original mock";return p }
    private func result(_ book: BookRecord,kind: AILearningKind = .summarize) -> AIResult { AIResult(request: .init(source: source(book),provider: provider(),kind: kind),text: "原创模拟结果：原文只讨论窗口。",fromCache: false) }
    private func bookmark(_ book: BookRecord,page: Int=0,title: String="窗口") -> ReadingBookmark {
        .init(bookID: book.id,location: .pdf(.init(editionID: book.editionID,fileSHA256: book.fileSHA256,pageIndex: page,x: 72,y: 650)),title: title)
    }
    @Test func summaryHasItsOwnPlanConsentCacheAndSelectedScope() async throws {
        let b=book(),s=source(b),p=provider(),summary=AIRequest(source: s,provider: p,kind: .summarize),translation=AIRequest(source: s,provider: p,kind: .translate)
        let plan=try ReadingSkillInputPlan(request: .text(summary))
        #expect(plan.manifest.skillID==ReadingSkillID.summarizeSelection.rawValue)
        #expect(summary.promptVersion=="selection-summary-1")
        #expect(try AIJobCoordinator.fingerprint(summary) != AIJobCoordinator.fingerprint(translation))
        let output=try await LocalMockAIProvider().analyze(summary)
        #expect(output.sourceQuote==s.anchor.quote && output.text.contains("总结") && !output.text.isEmpty)
        #expect(ReadingSkillRegistry.builtin.entries.count==8)
    }
    @Test func explicitAdditionIsIdempotentSeparateFromManualAndEditsOnlyComment() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let b=book(),ai=result(b),repository=AnnotationRepository(root: r)
        #expect(try await repository.load().notes.isEmpty)
        let first=try await repository.addAIResult(ai,comment: " 初始批注\nか\u{3099} 👩🏽‍🚀 ")
        let repeated=try await repository.addAIResult(ai,comment: "重复点击不得覆盖")
        #expect(first==repeated && first.aiResult==ai && first.origin == .explicitlySavedAI && first.sourceRecordID==ai.requestID)
        let edited=try await repository.save(expected: first,text: " 独立修改批注 ")
        #expect(edited.aiResult==ai && edited.anchor==first.anchor && edited.displayTitle=="AI 总结")
        let manual=try await repository.mark(bookID: b.id,anchor: first.anchor,kind: .highlight)
        #expect(manual.origin == .manual && manual.aiResult==nil && manual.id != first.id)
        let restarted=try await AnnotationRepository(root: r).load()
        #expect(restarted.notes.count==2 && restarted.notes.first?.aiResult==ai && restarted.notes.first?.userText==edited.userText)
        await #expect(throws: NoteBodyEditError.self) { try await repository.save(expected: first,text: "迟到写入") }
    }
    @Test func unknownAIResultFieldsAndInvalidSummaryProfileCannotOverwrite() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let repo=AnnotationRepository(root: r),saved=try await repo.addAIResult(result(book()),comment: "保留")
        let file=r.appendingPathComponent(AnnotationRepository.filename)
        var object=try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String:Any])
        var notes=try #require(object["notes"] as? [[String:Any]]),ai=try #require(notes[0]["aiResult"] as? [String:Any]);ai["futureTool"]="keep";notes[0]["aiResult"]=ai;object["notes"]=notes
        let bytes=try JSONSerialization.data(withJSONObject: object);try bytes.write(to: file)
        await #expect(throws: LibraryError.self) { try await repo.save(expected: saved,text: "覆盖") }
        #expect(try Data(contentsOf: file)==bytes)
        let invalid=AIResult(request: .init(source: result(book()).source,provider: provider(),kind: .summarize,profile: .paragraphExplanation),text: "错误契约",fromCache: false)
        #expect(!invalid.isValidAnnotationResult)
    }
    @Test func bookmarkRenameDeleteCASAndRestartPreserveOtherBook() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let a=book(),b=book(),repo=BookmarkRepository(root: r)
        let first=try await repo.add(bookmark(a)),same=try await repo.add(bookmark(a,title: "不覆盖")),second=try await repo.add(bookmark(a,page: 1)),other=try await repo.add(bookmark(b))
        #expect(first==same && second.id != first.id && other.id != first.id)
        let renamed=try await repo.rename(first,title: "序章：Window")
        #expect(renamed.location==first.location && renamed.revision==2)
        await #expect(throws: NoteBodyEditError.self) { try await repo.rename(first,title: "旧写者") }
        await #expect(throws: NoteBodyEditError.self) { try await repo.delete(first) }
        try await repo.delete(renamed)
        #expect(try await BookmarkRepository(root: r).load().bookmarks == [second,other])
    }
    @Test func EPUBOrientationIsSamePositionButDifferentSpansRemainDistinct() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let repo=BookmarkRepository(root: r),b=EPUBBook(fileSHA256: String(repeating: "b",count: 64),title: "原创",originalFilename: "Original.epub")
        let a=EPUBAnchor(editionID: b.editionID,fileSHA256: b.fileSHA256,resourceHref: "Text/one.xhtml",spineIndex: 0,start: 0,end: 3,quote: "日本語",prefix: "",suffix: "",vertical: false)
        let first=try await repo.add(.init(bookID: b.id,location: .epub(a),title: "横排")),rotated=try await repo.add(.init(bookID: b.id,location: .epub(a.withVertical(true)),title: "竖排"))
        #expect(first==rotated && first.location == .epub(a))
        let next=EPUBAnchor(editionID: b.editionID,fileSHA256: b.fileSHA256,resourceHref: a.resourceHref,spineIndex: 0,start: 4,end: 7,quote: "自作品",prefix: "",suffix: "",vertical: true)
        _=try await repo.add(.init(bookID: b.id,location: .epub(next),title: "第二处"))
        #expect(try await repo.load().bookmarks.count==2)
    }
    @Test func corruptFutureBookmarksRefuseWritesWithoutRepairOrLoss() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let repo=BookmarkRepository(root: r),b=book(),record=try await repo.add(bookmark(b)),file=r.appendingPathComponent(BookmarkRepository.filename)
        var object=try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String:Any]);object["futureSchemaField"]="preserve"
        let bytes=try JSONSerialization.data(withJSONObject: object);try bytes.write(to: file)
        await #expect(throws: LibraryError.self) { try await repo.rename(record,title: "不得覆盖") }
        #expect(try Data(contentsOf: file)==bytes)
        let invalid=ReadingBookmark(bookID: b.id,location: record.location,title: "\n")
        #expect(!invalid.isValid)
        await #expect(throws: LibraryError.self) { try await repo.add(invalid) }
    }
    @Test func bothSidecarsRoundTripBackupTrashAndRestoreWithoutLegacyMigration() async throws {
        let r=root(),backup=r.appendingPathExtension("backup"),restored=r.appendingPathExtension("restored")
        defer { for p in [r,backup,restored] { try? FileManager.default.removeItem(at: p) } }
        let library=LibraryRepository(root: r),book=try await library.importPDF(originalSample(),filename: "Original.pdf",pageCount: 2)
        let ai=try await AnnotationRepository(root: r).addAIResult(result(book),comment: "原创批注"),bm=try await BookmarkRepository(root: r).add(bookmark(book))
        let service=try LocalRecoveryService(root: r),permit=LocalRecoveryWritePermit(pausedRoot: r,writerEpoch: UUID())
        let preview=try await service.exportBackup(to: backup,permit: permit)
        _=try await service.restoreBackup(at: backup,preview: preview,to: restored,permit: permit)
        #expect(try await AnnotationRepository(root: restored).load().notes == [ai])
        #expect(try await BookmarkRepository(root: restored).load().bookmarks == [bm])
        let target=try #require(try await service.books().first),remove=try await service.previewMoveToTrash(.book(target))
        _=try await service.moveToTrash(remove,permit: permit)
        #expect(try await BookmarkRepository(root: r).load().bookmarks.isEmpty)
        #expect(try await AnnotationRepository(root: r).load().notes.isEmpty)
        let tombstone=try #require(try await service.tombstones().first),restore=try await service.previewRestoreTombstone(tombstone.id)
        _=try await service.restoreTombstone(restore,permit: permit)
        #expect(try await BookmarkRepository(root: r).load().bookmarks == [bm])
        #expect(try await AnnotationRepository(root: r).load().notes == [ai])
    }
}
