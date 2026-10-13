// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CoreGraphics
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor OriginalDocumentHTTP: AIHTTPTransport {
    var requests: [URLRequest] = []
    let variant: String
    init(_ variant: String = "valid") { self.variant = variant }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        let document = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        var content: [String: Any] = ["schemaVersion": 1, "documentIdentity": document["documentIdentity"]!, "text": "Original whole-document reply · 日本語 原创"]
        if variant == "identity" { content["documentIdentity"] = "different-document" }
        if variant == "extra" { content["unrequested"] = "original fixture" }
        if variant == "empty" { content["text"] = " " }
        var message: [String: Any] = ["role": "assistant", "content": String(decoding: try JSONSerialization.data(withJSONObject: content), as: UTF8.self)]
        if variant == "tools" { message["tool_calls"] = [["id": "original-fixture"]] }
        if variant == "role" { message["role"] = "user" }
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
            "finish_reason": variant == "truncated" ? "length" : "stop", "message": message
        ]]]))
    }
}
private actor OriginalDeferredDocumentHTTP: AIHTTPTransport {
    private var pending: [(URLRequest, CheckedContinuation<AIHTTPResponse, Error>)] = []
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        try await withCheckedThrowingContinuation { pending.append((request, $0)) }
    }
    func count() -> Int { pending.count }
    func finish() async throws {
        let (request, continuation) = pending.removeFirst()
        continuation.resume(returning: try await OriginalDocumentHTTP().send(request))
    }
}

@Suite(.serialized) @MainActor struct DocumentConversationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Document-Contract-" + UUID().uuidString) }
    private func source(_ text: String = "Original 中文 日本語 cafe\u{301} 👩🏽‍🚀\nComplete second paragraph") throws -> DocumentConversationSource {
        try .init(bookID: UUID(), readerSessionID: UUID(), fileSHA256: String(repeating: "a", count: 64), format: "PDF", text: text)
    }
    private func settle(_ model: DocumentConversationModel) async throws {
        let deadline = Date().addingTimeInterval(3)
        while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(!model.busy)
    }

    @Test func completeSourceIdentityAndHistoryNeverNormalizeOrCrossDocuments() throws {
        let original = try source(), composed = try DocumentConversationSource(bookID: original.bookID,
            readerSessionID: original.readerSessionID, fileSHA256: original.fileSHA256, format: "PDF",
            text: original.text.replacingOccurrences(of: "cafe\u{301}", with: "café"))
        #expect(original.identity != composed.identity)
        let turns = [DocumentConversationTurn(role: .user, text: "Original question", sourceIdentity: original.identity),
                     .init(role: .assistant, text: "Original answer", sourceIdentity: original.identity)]
        let plan = try DocumentConversationPlan(source: original, provider: DeepSeekSelectionPolicy.configuration(), history: turns, question: "Original follow-up")
        #expect(plan.source.text.utf8.elementsEqual(original.text.utf8) && plan.history == turns)
        #expect(throws: DocumentConversationFailure.historyLimit) {
            try DocumentConversationPlan(source: composed, provider: plan.provider, history: turns, question: plan.question)
        }
        #expect(throws: DocumentConversationFailure.historyLimit) {
            try DocumentConversationPlan(source: original, provider: plan.provider, history: [turns[1], turns[0]], question: plan.question)
        }
    }

    @Test func prepareAndUnconfirmedFollowupSendNothingThenExplicitConfirmAnswersWithoutSaving() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = OriginalDocumentHTTP(), library = LibraryModel(root: r, aiSession: AppAISession(), learningTransport: transport)
        await library.load(); await library.openSample()
        #expect(await library.learning.applyConnection(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-document-synthetic-key"))
        let model = library.documentConversation
        await model.prepare(); let captured = try #require(model.source), pdf = try #require(library.reader.document)
        for index in 0..<pdf.pageCount { #expect(captured.text.contains(try #require(pdf.page(at: index)?.string))) }
        model.draft = "Original unconfirmed follow-up"; model.sendFollowup()
        #expect(await transport.requests.isEmpty && model.answers.isEmpty && !model.confirmed)
        model.confirmAndStart(); try await settle(model)
        #expect(await transport.requests.count == 1 && model.answers.count == 1 && model.confirmed)
        #expect(model.answers[0].text.contains("Original whole-document reply"))
        #expect(try await library.annotations.repository.load().notes.isEmpty)
        #expect(try await library.learning.repository.load().notes.isEmpty)
        model.draft = "Original follow-up after confirmation"; model.sendFollowup(); try await settle(model)
        #expect(await transport.requests.count == 2 && model.answers.count == 2 && model.draft.isEmpty)
    }

    @Test func interceptedWireContainsOnlyCompleteDocumentAndItsOwnHistory() async throws {
        let document = try source(), config = DeepSeekSelectionPolicy.configuration(), credentials = SessionCredentialStore(), reference = UUID()
        try await credentials.put("original-document-synthetic-key", reference: reference)
        let transport = OriginalDocumentHTTP(), provider = DocumentConversationHTTPProvider(transport: transport,
            credentials: credentials, reference: reference, budget: AppAISession().selection)
        let history = [DocumentConversationTurn(role: .user, text: "Original previous question", sourceIdentity: document.identity),
                       .init(role: .assistant, text: "Original previous answer", sourceIdentity: document.identity)]
        let plan = try DocumentConversationPlan(source: document, provider: config, history: history, question: "Original next question")
        let coordinator = DocumentConversationCoordinator()
        await #expect(throws: AIFailure.consent) { try await coordinator.run(plan, confirmed: false, provider: provider) }
        #expect(await transport.requests.isEmpty)
        #expect(try await coordinator.run(plan, confirmed: true, provider: provider).contains("Original whole-document reply"))
        let request = try #require(await transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions" && !request.httpShouldHandleCookies)
        let wire = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(wire["stream"] as? Bool == false && wire["tools"] == nil)
        let messages = wire["messages"] as! [[String: String]]
        #expect(messages.map { $0["role"]! } == ["system", "user", "user", "assistant", "user"])
        let payload = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        #expect(Set(payload.keys) == ["documentIdentity", "documentText"])
        #expect(payload["documentText"]!.utf8.elementsEqual(document.text.utf8) && payload["documentIdentity"] == document.identity)
        #expect(messages[2]["content"] == history[0].text && messages[3]["content"] == history[1].text && messages[4]["content"] == plan.question)
        #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains("original-document-synthetic-key"))
    }

    @Test func malformedTruncatedOrForeignDocumentRepliesNeverBecomeAnswers() async throws {
        for variant in ["identity", "extra", "empty", "tools", "truncated", "role"] {
            let transport = OriginalDocumentHTTP(variant), credentials = SessionCredentialStore(), reference = UUID()
            try await credentials.put("original-document-synthetic-key", reference: reference)
            let plan = try DocumentConversationPlan(source: source(), provider: DeepSeekSelectionPolicy.configuration(), history: [], question: "Original question")
            let provider = DocumentConversationHTTPProvider(transport: transport, credentials: credentials, reference: reference, budget: AppAISession().selection)
            await #expect(throws: AIFailure.output) { try await provider.answer(plan) }
            #expect(await transport.requests.count == 1)
        }
    }

    @Test func stopCredentialClearAndDocumentCloseDiscardNoncooperativeLateOutput() async throws {
        for change in ["stop", "credential", "document"] {
            let r = root(); defer { try? FileManager.default.removeItem(at: r) }
            let transport = OriginalDeferredDocumentHTTP(), library = LibraryModel(root: r, aiSession: AppAISession(), learningTransport: transport)
            await library.load(); await library.openSample()
            #expect(await library.learning.applyConnection(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-document-synthetic-key"))
            let model = library.documentConversation; await model.prepare(); model.confirmAndStart()
            let deadline = Date().addingTimeInterval(3)
            while await transport.count() == 0 && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
            try #require(await transport.count() == 1)
            if change == "stop" { model.stop() }
            else if change == "credential" { await library.learning.clearSessionCredential() }
            else { library.reader.close() }
            try await transport.finish(); try await Task.sleep(for: .milliseconds(20))
            #expect(!model.busy && model.answers.isEmpty)
            #expect(try await library.annotations.repository.load().notes.isEmpty)
        }
    }

    @Test func incompleteScanAndOversizedOriginalsRefuseBeforeAnyTransport() async throws {
        #expect(throws: DocumentConversationFailure.incomplete) { try source(" ") }
        #expect(throws: DocumentConversationFailure.tooLarge) { try source(String(repeating: "x", count: 60001)) }
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = OriginalDocumentHTTP(), library = LibraryModel(root: r, aiSession: AppAISession(), learningTransport: transport)
        let buffer = NSMutableData(), consumer = try #require(CGDataConsumer(data: buffer))
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil); context.endPDFPage(); context.closePDF()
        let data = buffer as Data, book = BookRecord(title: "Original blank fixture", fileSHA256: LibraryRepository.digest(data), originalFilename: "original-blank.pdf", pageCount: 1)
        try library.reader.open(data: data, book: book)
        await library.documentConversation.prepare(); library.documentConversation.confirmAndStart()
        #expect(library.documentConversation.source == nil && library.documentConversation.error != nil)
        #expect(await transport.requests.isEmpty && library.documentConversation.answers.isEmpty)
    }
}
#endif
