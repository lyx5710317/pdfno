// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
// Hidden windows, original fixtures, temporary stores and synthetic credentials only.
import AppKit
import PDFKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor NativeConversationDeferredHTTP: AIHTTPTransport {
    private var entries: [(URLRequest,CheckedContinuation<AIHTTPResponse,Error>)] = []
    func send(_ request: URLRequest) async throws -> AIHTTPResponse { try await withCheckedThrowingContinuation { entries.append((request,$0)) } }
    func count() -> Int { entries.count }
    func finish(_ index: Int) throws {
        let (request,continuation) = entries[index]
        let bytes = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]]), content = try #require(messages.last?["content"])
        let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any]), quote = try #require(input["sourceText"] as? String)
        let output = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1,"sourceQuote": quote,"text": "Original native response " + String(index)])
        let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop","message": ["role": "assistant","content": String(decoding: output,as: UTF8.self)]]]])
        continuation.resume(returning: .init(status: 200,body: envelope))
    }
}

@Suite(.serialized) @MainActor struct ReadingConversationNativeTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("Original-Conversation-Native-" + UUID().uuidString) }
    private func pdf(_ library: LibraryModel) async throws -> (NSWindow,AISourceSnapshot) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let bytes = try originalSample(), book = try await library.repository.importPDF(bytes,filename: "Original.pdf",pageCount: 2)
        try library.reader.open(data: bytes,book: book)
        let view = PDFView(), window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view; view.frame = window.contentView!.bounds; library.reader.attach(view)
        view.setCurrentSelection(try #require(library.reader.document?.findString("window",withOptions: []).first),animate: false)
        let anchor = try #require(await AnnotationReader.pdf(library.reader).capture())
        guard case .pdf(let pdf) = anchor else { throw AIFailure.stale }
        await library.annotations.bind(.pdf(library.reader))
        return (window,.init(bookID: book.id,readerSessionID: library.reader.readerSessionID,documentVersion: 0,anchor: .pdf(pdf)))
    }
    private func finish(_ model: ReadingConversationModel) async throws {
        let end = Date().addingTimeInterval(3)
        while model.busy && Date() < end { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!model.busy)
    }
    @Test func toolPreferencesDefaultOffAreIndependentAndDoNotRequireAnyDocument() throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let preferences = AIReadingToolsPreferences(root: r)
        #expect(!preferences.japanese && !preferences.english && preferences.isEnabled(.translate))
        preferences.set(.japanese,enabled: true)
        #expect(preferences.japanese && !preferences.english)
        let reopened = AIReadingToolsPreferences(root: r); #expect(reopened.japanese && !reopened.english)
        reopened.set(.english,enabled: true); reopened.set(.japanese,enabled: false)
        let final = AIReadingToolsPreferences(root: r); #expect(!final.japanese && final.english)
        #expect(final.isEnabled(.explain) && final.isEnabled(.summarize))
    }
    @Test func unknownPreferenceSchemaStaysOffAndIsNeverOverwritten() throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        try FileManager.default.createDirectory(at: r,withIntermediateDirectories: true)
        let file = r.appendingPathComponent("ai-reading-tools-v1.json")
        let original = Data("{\"schemaVersion\":99,\"japanese\":true,\"english\":true}".utf8)
        try original.write(to: file)
        let preferences = AIReadingToolsPreferences(root: r)
        #expect(!preferences.japanese && !preferences.english && preferences.error != nil)
        preferences.set(.japanese,enabled: true)
        let after = try Data(contentsOf: file)
        #expect(!preferences.japanese && after == original)
    }
    @Test func unconfiguredTaskShowsGuidanceWithoutGeneratingOrSavingAnything() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let library = LibraryModel(root: r,aiSession: AppAISession()), (window,source) = try await pdf(library)
        defer { library.reader.close(); window.close() }
        library.conversation.open(.explain,source: source)
        #expect(library.conversation.current?.status.contains("设置 → AI") == true)
        #expect(!library.conversation.busy && library.conversation.current?.answers.isEmpty == true)
        #expect(try await library.annotations.repository.load().notes.isEmpty)
    }
    @Test func firstAnswerAndFollowupRemainInSameThreadAndEachExplicitSaveDeduplicates() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let library = LibraryModel(root: r,aiSession: AppAISession()), (window,source) = try await pdf(library)
        defer { library.reader.close(); window.close() }
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original mock"
        #expect(await library.learning.applyConnection(config,temporarySecret: ""))
        library.conversation.open(.summarize,source: source); try await finish(library.conversation)
        let id = try #require(library.conversation.currentID)
        #expect(library.conversation.current?.answers.count == 1 && library.hasUnsavedDocumentLearning)
        #expect(try await library.annotations.repository.load().notes.isEmpty)
        library.showingSelectionAI = false; library.conversation.open(.summarize,source: source)
        #expect(library.conversation.currentID == id && library.conversation.current?.answers.count == 1)
        library.conversation.setDraft("Original follow-up"); library.conversation.sendFollowup(); library.conversation.sendFollowup()
        try await finish(library.conversation)
        let current = try #require(library.conversation.current), answer = try #require(current.answers.last)
        #expect(current.answers.count == 2 && current.turns.count == 4 && current.id == id)
        #expect(answer.result.text.contains("2 条消息") && answer.result.conversation?.question == "Original follow-up")
        #expect(await library.conversation.addToNotes(answer)); #expect(await library.conversation.addToNotes(answer))
        let saved = try #require(try await library.annotations.repository.load().notes.first)
        #expect(library.annotations.records.count == 1 && saved.aiResult == answer.result && saved.anchor.quote == source.anchor.quote)
        library.annotations.begin(saved); library.annotations.editor.setText("Original edited note",for: AnnotationBodySnapshot(saved)); await library.annotations.save(saved)
        let edited = try #require(try await library.annotations.repository.load().notes.first)
        #expect(edited.aiResult == answer.result && edited.userText == "Original edited note")
    }
    @Test func fiveTasksHaveSeparateThreadsAndDisablingRetainsAnswersAndSavedNotes() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let library = LibraryModel(root: r,aiSession: AppAISession()), (window,source) = try await pdf(library)
        defer { library.reader.close(); window.close() }
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original mock"; library.learning.config = config
        library.learning.tools.set(.japanese,enabled: true); library.learning.tools.set(.english,enabled: true)
        for task in ReadingConversationTask.allCases {
            library.conversation.open(task,source: source); try await finish(library.conversation)
            #expect(library.conversation.current?.task == task && library.conversation.current?.answers.first?.result.conversation?.task == task)
        }
        #expect(library.conversation.threads.count == 5)
        let english = try #require(library.conversation.current), answer = try #require(english.answers.first)
        #expect(await library.conversation.addToNotes(answer))
        library.learning.tools.set(.english,enabled: false)
        #expect(library.conversation.current?.answers.count == 1 && library.annotations.records.first?.aiResult == answer.result)
        library.conversation.setDraft("Must not send while disabled"); library.conversation.sendFollowup()
        #expect(!library.conversation.busy && library.conversation.current?.answers.count == 1)
        library.discardDocumentPresentation()
        #expect(library.conversation.threads.isEmpty && library.conversation.currentID == nil)
        #expect(try await library.annotations.repository.load().notes.count == 1)
    }
    @Test func modelsShareOnlyConnectionAndToolsWhileConversationContextIsDocumentOwned() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let catalogue = LibraryModel(root: r,aiSession: AppAISession()), tabs = MacDocumentTabs(catalogue: catalogue)
        let first = tabs.makeDocumentModel(), second = tabs.makeDocumentModel()
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original shared mock"
        #expect(await catalogue.learning.applyConnection(config,temporarySecret: ""))
        #expect(first.learning.config == catalogue.learning.config && second.learning.config == catalogue.learning.config)
        catalogue.learning.tools.set(.japanese,enabled: true)
        #expect(first.learning.tools.japanese && second.learning.tools.japanese)
        let (window,source) = try await pdf(first); defer { first.reader.close(); window.close() }
        first.conversation.open(.explain,source: source); try await finish(first.conversation)
        #expect(first.conversation.current?.answers.count == 1 && second.conversation.threads.isEmpty && catalogue.conversation.threads.isEmpty)
    }
    @Test func nativeCommentFactoryDisablesAutomaticCompletionAndPreservesExactUnicodeEdits() throws {
        var body = ""
        let binding = Binding(get: { body },set: { body = $0 })
        let coordinator = NativeNoteBodyInput.Coordinator(text: binding)
        let scroll = NativeNoteBodyInput.makeEditor(coordinator: coordinator,identifier: "Original-conversation-note",enabled: true)
        let view = try #require(scroll.documentView as? NSTextView)
        #expect(!view.isAutomaticTextCompletionEnabled && !view.isAutomaticSpellingCorrectionEnabled && !view.isAutomaticTextReplacementEnabled)
        view.insertText("Original saved comment 日本語🌸",replacementRange: NSRange(location: 0,length: 0))
        #expect(view.string == "Original saved comment 日本語🌸" && body == view.string)
        withExtendedLifetime(scroll) {}
    }
    @Test func stoppedOldThreadAndClosedDocumentRejectLateResponsesWithoutCrossThreadLanding() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = NativeConversationDeferredHTTP(), library = LibraryModel(root: r,aiSession: AppAISession(),learningTransport: transport)
        let (window,source) = try await pdf(library); defer { library.reader.close(); window.close() }
        var config = AIProviderConfig(); config.mode = .openAICompatible; config.label = "Original intercepted service"
        config.endpoint = "https://fixture.invalid/v1"; config.model = "synthetic-conversation-only"
        #expect(await library.learning.applyConnection(config,temporarySecret: "original-synthetic-credential-never-live"))
        library.conversation.open(.explain,source: source)
        for _ in 0..<100 { if await transport.count() == 1 { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(await transport.count() == 1)
        await library.learning.load()
        #expect(library.conversation.busy && library.conversation.current?.pendingQuestion != nil)
        let firstID = try #require(library.conversation.currentID)
        library.conversation.open(.translate,source: source)
        for _ in 0..<100 { if await transport.count() == 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(await transport.count() == 2)
        try await transport.finish(1); try await finish(library.conversation); try await transport.finish(0)
        for _ in 0..<5 { await Task.yield() }
        #expect(library.conversation.current?.task == .translate && library.conversation.current?.answers.count == 1)
        #expect(library.conversation.threads.first { $0.id == firstID }?.answers.isEmpty == true)
        library.conversation.open(.summarize,source: source)
        for _ in 0..<100 { if await transport.count() == 3 { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(await transport.count() == 3)
        library.discardDocumentPresentation(); try await transport.finish(2)
        for _ in 0..<5 { await Task.yield() }
        #expect(library.conversation.threads.isEmpty && !library.conversation.busy)
        #expect(try await library.annotations.repository.load().notes.isEmpty)
    }
    @Test func connectionApplyKeepsSessionKeyOffDiskAndInvalidEndpointRevokesItWithoutSending() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = NativeConversationDeferredHTTP(), library = LibraryModel(root: r,aiSession: AppAISession(),learningTransport: transport)
        var config = AIProviderConfig(); config.mode = .openAICompatible; config.label = "Original intercepted service"
        config.endpoint = "https://fixture.invalid/v1"; config.model = "synthetic-conversation-only"
        let synthetic = "original-synthetic-credential-never-live"
        #expect(await library.learning.applyConnection(config,temporarySecret: synthetic))
        #expect(library.learning.hasSessionCredential && library.learning.conversationConnectionAvailable)
        let stored = try await library.learning.repository.load(), encoded = try JSONEncoder().encode(stored)
        #expect(!String(decoding: encoded,as: UTF8.self).contains(synthetic))
        let previous = library.learning.config
        #expect(await library.learning.applyConnection(previous,temporarySecret: ""))
        #expect(library.learning.hasSessionCredential)
        let applied = library.learning.config
        var invalid = applied; invalid.endpoint = "https://other.invalid/?key=rejected"
        #expect(await library.learning.applyConnection(invalid,temporarySecret: "") == false)
        #expect(!library.learning.hasSessionCredential && library.learning.config == applied && !library.learning.conversationConnectionAvailable)
        #expect(await transport.count() == 0)
    }
}
#endif
