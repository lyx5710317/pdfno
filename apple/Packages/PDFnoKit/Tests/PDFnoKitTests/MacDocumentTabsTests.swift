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
}
#endif
