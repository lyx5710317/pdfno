// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor TabsNoNetwork: AIHTTPTransport {
    private(set) var calls = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse { calls += 1; throw AIFailure.network }
}
private actor TabsLateResponse: AIHTTPTransport {
    private(set) var calls = 0
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        calls += 1; try await Task.sleep(for: .seconds(1.5))
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        let payload = try JSONSerialization.jsonObject(with: Data(messages.last!["content"]!.utf8)) as! [String: String]
        let content = String(decoding: try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": payload["sourceText"]!, "text": "[Synthetic delayed result] 原创测试结果"]), as: UTF8.self)
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
            "finish_reason": "stop", "message": ["role": "assistant", "tool_calls": NSNull(), "content": content]
        ]]]))
    }
}

@Suite(.serialized) @MainActor struct MacDocumentTabsTests {
    @Test func repeatedOpenRetainsTwoReaderIdentitiesPositionsAndIndependentDraftOwners() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = TabsNoNetwork(), session = AppAISession()
        let catalogue = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue, documentFactory: { LibraryModel(root: $0, aiSession: session, learningTransport: transport) })
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active)
        a.model.reader.go(to: 1)
        let aIdentity = a.model.reader.readerSessionID, aDocument = a.model.reader.document
        a.model.learning.userText = "A 草稿 日本語 café"
        a.model.recordVisibleDraft(owner: "A-original-note", dirty: true)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active), bIdentity = b.model.epub.readerSessionID
        b.model.learning.userText = "B draft 中文 👩🏽‍🚀"
        b.model.recordVisibleDraft(owner: "B-original-note", dirty: true)
        #expect(a.id != b.id && a.model !== b.model && tabs.tabs.count == 2)
        for _ in 0..<3 {
            #expect(await tabs.open(a.id))
            #expect(tabs.active === a && a.model.reader.pageIndex == 1)
            #expect(a.model.reader.readerSessionID == aIdentity && a.model.reader.document === aDocument)
            #expect(await tabs.open(b.id))
            #expect(tabs.active === b && b.model.epub.readerSessionID == bIdentity)
        }
        #expect(a.model.learning.userText == "A 草稿 日本語 café")
        #expect(b.model.learning.userText == "B draft 中文 👩🏽‍🚀")
        #expect(a.model.documentVisibleDrafts == ["A-original-note"] && b.model.documentVisibleDrafts == ["B-original-note"])
        #expect(a.model.notes.isEmpty && b.model.epubNotes.isEmpty && catalogue.learning.notes.isEmpty)
        #expect(await transport.calls == 0)
    }

    @Test func inactiveCloseCancellationAndConfirmationNeverDiscardAnotherTab() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogue = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: TabsNoNetwork())
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue)
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active)
        a.model.recordVisibleDraft(owner: "A-note", dirty: true)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active)
        b.model.recordVisibleDraft(owner: "B-note", dirty: true)
        b.model.learning.userText = "keep B unsaved"
        await tabs.requestClose(a.id)
        #expect(tabs.pendingCloseID == a.id && tabs.active === b && tabs.tabs.count == 2)
        tabs.pendingCloseID = nil
        #expect(tabs.tabs.contains { $0 === a } && a.model.documentVisibleDrafts == ["A-note"])
        await tabs.close(a.id, confirmed: true)
        #expect(tabs.tabs.count == 1 && tabs.active === b && tabs.pendingCloseID == nil)
        #expect(b.model.learning.userText == "keep B unsaved" && b.model.documentVisibleDrafts == ["B-note"])
        #expect(a.model.reader.document == nil && a.model.documentVisibleDrafts.isEmpty)
        await tabs.requestClose(b.id)
        #expect(tabs.pendingCloseID == b.id && tabs.active === b)
        tabs.pendingCloseID = nil
        #expect(b.model.epub.book != nil)
        await tabs.close(b.id, confirmed: true)
        #expect(tabs.tabs.isEmpty && tabs.active == nil)
    }

    @Test func duplicateImportActivatesOriginalTabAndDoesNotReplaceItsDraftOrReader() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogue = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: TabsNoNetwork())
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue)
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active), identity = a.model.reader.readerSessionID
        a.model.learning.userText = "retained selection draft"
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        #expect(await tabs.openNew { await $0.openSample() })
        #expect(tabs.active === a && tabs.tabs.count == 2)
        #expect(a.model.reader.readerSessionID == identity && a.model.learning.userText == "retained selection draft")
    }

    @Test func appliedReadingConfigurationAndIndependentBYOKSessionReachBothTabsWithoutSending() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = TabsNoNetwork()
        let catalogue = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue)
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active)
        #expect(await catalogue.learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "synthetic-reading-ui-credential"))
        #expect(a.model.learning.hasSessionCredential && b.model.learning.hasSessionCredential)
        #expect(a.model.learning.config == catalogue.learning.config && b.model.learning.config == catalogue.learning.config)
        a.model.learning.userText = "A independent source draft"; b.model.learning.userText = "B independent source draft"
        catalogue.byok.temporarySecret = "synthetic-reading-ui-credential"
        #expect(await catalogue.byok.apply())
        await a.model.byok.load(); await b.model.byok.load()
        #expect(a.model.byok.hasSessionCredential && b.model.byok.hasSessionCredential)
        #expect(a.model.byok.draft == catalogue.byok.draft && b.model.byok.draft == catalogue.byok.draft)
        #expect(a.model.learning.config != a.model.byok.draft)
        await catalogue.learning.clearSessionCredential()
        #expect(!a.model.learning.hasSessionCredential && !b.model.learning.hasSessionCredential)
        #expect(a.model.byok.hasSessionCredential && b.model.byok.hasSessionCredential)
        #expect(a.model.learning.userText == "A independent source draft" && b.model.learning.userText == "B independent source draft")
        #expect(await transport.calls == 0)
    }

    @Test func savedBookSearchActivatesExistingTabWithoutReopeningItsReaderOrPosition() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogue = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: TabsNoNetwork())
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue)
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active), book = try #require(a.model.reader.book)
        a.model.reader.go(to: 1); a.model.learning.userText = "Search must keep draft"
        let identity = a.model.reader.readerSessionID
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let target = LibrarySearchTarget(book: LocalBookIdentity(format: .pdf, bookID: book.id,
            editionID: book.editionID, fileSHA256: book.fileSHA256), kind: .book)
        #expect(await tabs.openSearchTarget(target))
        #expect(tabs.active === a && tabs.tabs.count == 2 && a.model.reader.readerSessionID == identity)
        #expect(a.model.reader.pageIndex == 1 && a.model.learning.userText == "Search must keep draft")
    }

    @Test func backupAndNewDirectoryRestoreKeepBothTabsAndRejectUnsavedWork() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-Backup-" + UUID().uuidString)
        let root = parent.appendingPathComponent("Library")
        defer { try? FileManager.default.removeItem(at: parent) }
        let transport = TabsNoNetwork(), session = AppAISession()
        let catalogue = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue, documentFactory: { LibraryModel(root: $0, aiSession: session, learningTransport: transport) })
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active)
        a.model.reader.go(to: 1)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active)
        let aIdentity = a.model.reader.readerSessionID, bIdentity = b.model.epub.readerSessionID
        catalogue.prepareRecoveryManagement()
        let recovery = try #require(catalogue.recoveryManagement)
        a.model.learning.userText = "Unsaved A must block maintenance"
        await recovery.export(to: parent)
        #expect(recovery.lastExportedPackage == nil && recovery.message.contains("草稿"))
        #expect(a.model.reader.readerSessionID == aIdentity && b.model.epub.readerSessionID == bIdentity)
        #expect(a.model.learning.userText == "Unsaved A must block maintenance" && tabs.active === b)
        a.model.learning.userText = ""
        b.model.recordVisibleDraft(owner: "B-visible-draft", dirty: true)
        await recovery.export(to: parent)
        #expect(recovery.lastExportedPackage == nil && b.model.documentVisibleDrafts == ["B-visible-draft"])
        b.model.recordVisibleDraft(owner: "B-visible-draft", dirty: false)
        await recovery.export(to: parent)
        let package = try #require(recovery.lastExportedPackage)
        #expect(FileManager.default.fileExists(atPath: package.path))
        tabs.reconcileAfterMaintenance()
        #expect(tabs.tabs.count == 2 && tabs.active === b)
        #expect(a.model.displayedDocumentID == a.id && a.model.reader.pageIndex == 1 && b.model.displayedDocumentID == b.id)
        #expect(!catalogue.storageMaintenance && catalogue.storeWriteGate.snapshot.phase == .writable)
        await recovery.inspect(package)
        #expect(recovery.backupPreview != nil)
        await recovery.restore(to: parent)
        tabs.reconcileAfterMaintenance()
        let recovered = try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("PDFnoRecovered-") }
        #expect(recovered.count == 1 && recovered[0] != root && recovery.backupPreview == nil)
        #expect(tabs.tabs.count == 2 && tabs.active === b && a.model.reader.pageIndex == 1)
        #expect(a.model.displayedDocumentID == a.id && b.model.displayedDocumentID == b.id)
        #expect(await transport.calls == 0)
    }

    @Test func recycleBlocksOtherTabsDraftThenRemovesOnlyMovedTabAndRestoresSavedBook() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-Recycle-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogue = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: TabsNoNetwork())
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue)
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active)
        a.model.reader.go(to: 1)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active)
        catalogue.prepareRecoveryManagement()
        let recovery = try #require(catalogue.recoveryManagement)
        await recovery.refresh()
        let book = try #require(recovery.books.first { $0.id == a.id })
        await recovery.preview(.book(book))
        let preview = try #require(recovery.changePreview)
        b.model.learning.userText = "Keep B"
        await recovery.confirmChange()
        #expect(recovery.changePreview?.snapshotSHA256 == preview.snapshotSHA256 && recovery.changePreview?.target == preview.target && b.model.learning.userText == "Keep B")
        #expect(a.model.reader.document != nil && tabs.tabs.count == 2)
        b.model.learning.userText = ""
        // Refresh the exact preview after progress writes; no stale preview is auto-applied.
        await a.model.saveDocumentPosition(); await recovery.preview(.book(book))
        await recovery.confirmChange(); tabs.reconcileAfterMaintenance()
        #expect(tabs.tabs.count == 1 && tabs.active === b && b.model.displayedDocumentID == b.id)
        #expect(a.model.reader.document == nil)
        let entry = try #require(recovery.tombstones.first { !$0.restored })
        await recovery.previewRestore(entry.id); await recovery.confirmChange()
        #expect(recovery.tombstones.first { $0.id == entry.id }?.restored == true)
        #expect(await tabs.open(a.id))
        #expect(tabs.active?.id == a.id && tabs.active?.model.reader.pageIndex == 1)
        #expect(b.model.displayedDocumentID == b.id && tabs.tabs.count == 2)
    }

    @Test func lateAIResultStaysWithItsOriginalTabAndConfirmedCloseCancelsOnlyThatTask() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Tabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = TabsLateResponse(), session = AppAISession()
        let catalogue = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        await catalogue.load()
        let tabs = MacDocumentTabs(catalogue: catalogue, documentFactory: { LibraryModel(root: $0, aiSession: session, learningTransport: transport) })
        #expect(await tabs.openNew { await $0.openSample() })
        let a = try #require(tabs.active), book = try #require(a.model.reader.book)
        let page = try #require(a.model.reader.document?.page(at: 0)), text = try #require(page.string)
        let range = (text as NSString).range(of: "window"), selection = try #require(page.selection(for: range))
        let bounds = selection.bounds(for: page), quote = try #require(selection.string)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 0, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)])
        #expect(a.model.reader.resolution(of: anchor) == .exact)
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: a.model.reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
        #expect(await catalogue.learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "synthetic-reading-ui-credential"))
        a.model.learning.prepare(source); a.model.learning.start(confirmed: true, sourceIsCurrent: a.model.isCurrentAISource)
        for _ in 0..<100 { if await transport.calls == 1 { break }; try await Task.sleep(for: .milliseconds(20)) }
        let firstCalls = await transport.calls
        #expect(a.model.learning.busy && firstCalls == 1)
        #expect(await tabs.openNew { await $0.openEPUBSample() })
        let b = try #require(tabs.active)
        b.model.learning.userText = "B unaffected draft"
        await tabs.requestClose(a.id)
        #expect(tabs.pendingCloseID == a.id && tabs.active === b && a.model.learning.busy)
        tabs.pendingCloseID = nil
        for _ in 0..<200 { if !a.model.learning.busy { break }; try await Task.sleep(for: .milliseconds(20)) }
        #expect(a.model.learning.result?.source.bookID == a.id && b.model.learning.result == nil)
        #expect(a.model.learning.notes.isEmpty && b.model.learning.notes.isEmpty)
        a.model.learning.start(confirmed: true, sourceIsCurrent: a.model.isCurrentAISource)
        for _ in 0..<100 { if await transport.calls == 2 { break }; try await Task.sleep(for: .milliseconds(20)) }
        await tabs.close(a.id, confirmed: true)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!a.model.learning.busy && tabs.active === b && tabs.tabs.count == 1)
        #expect(b.model.learning.result == nil && b.model.learning.userText == "B unaffected draft")
        #expect(try await catalogue.learning.repository.load().notes.isEmpty)
    }
}
#endif
