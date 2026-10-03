// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor AuditInterceptedTransport: AIHTTPTransport {
    private(set) var count = 0
    func send(_ request: URLRequest) -> AIHTTPResponse {
        count += 1
        // Deliberate synthetic failure verifies failures consume the shared cap.
        return AIHTTPResponse(status: 429, body: Data("Original synthetic failure".utf8))
    }
}

struct AppAISessionTests {
    @Test @MainActor func recreatedModelsShareThreeIndependentProcessSessionCaps() async throws {
        let session = AppAISession(),probeTransport = AuditInterceptedTransport(),selectionTransport = AuditInterceptedTransport(),pageTransport = AuditInterceptedTransport()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bookID = UUID(),editionID = UUID(),digest = String(repeating: "a", count: 64)
        let anchor = PDFSourceAnchor(editionID: editionID, fileSHA256: digest, quote: "window", regions: [PageRegion(pageIndex: 0,x: 1,y: 1,width: 30,height: 10,quote: "window")])
        let source = AISourceSnapshot(bookID: bookID,readerSessionID: UUID(),documentVersion: 0,anchor: .pdf(anchor))
        // Destroy/recreate each model at every send, as multiple library windows do.
        for _ in 0..<6 {
            let model = DeepSeekTestModel(service: DeepSeekSelfTest(transport: probeTransport,budget: session.probe))
            model.temporaryKey = "synthetic-audit-credential";model.confirmed = true;model.send()
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
            #expect(!model.busy);model.close();model.clearRecords()
        }
        for _ in 0..<6 {
            let model = AILearningModel(root: root,transport: selectionTransport,aiSession: session)
            await model.load();#expect(await model.saveConfig(DeepSeekSelectionPolicy.configuration(),temporarySecret: "synthetic-audit-credential"))
            model.prepare(source);model.start(confirmed: true,sourceIsCurrent: { _ in true })
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
            #expect(!model.busy);await model.clearSessionCredential()
        }
        for _ in 0..<9 {
            let model = PDFPageTranslationModel(transport: pageTransport,aiSession: session)
            model.prepare(PDFPageTextSnapshot(bookID: bookID,readerSessionID: UUID(),editionID: editionID,fileSHA256: digest,pageIndex: 0,text: "window"))
            model.temporarySecret = "synthetic-audit-credential";model.start(confirmed: true,sourceIsCurrent: { _ in true })
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
            #expect(!model.busy);model.cancel()
        }
        #expect(await probeTransport.count == 3)
        #expect(await selectionTransport.count == 3)
        #expect(await pageTransport.count == 6)
        #expect(await session.probe.attemptsUsed() == 3)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await session.page.attemptsUsed() == 6)
        let windowA = LibraryModel(root: root, aiSession: session),windowB = LibraryModel(root: root, aiSession: session)
        // Credentials remain owned by models, never by the shared counter owner.
        #expect(!windowA.learning.hasSessionCredential && !windowB.learning.hasSessionCredential)
    }
}
