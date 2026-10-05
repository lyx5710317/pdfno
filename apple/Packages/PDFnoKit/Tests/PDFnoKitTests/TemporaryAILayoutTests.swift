// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

private actor TemporaryLayoutTransport: AIHTTPTransport {
    private(set) var count = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse { count += 1; throw AIFailure.network }
}

/// Original inputs, isolated stores, and native component hosts never shown on screen.
@Suite(.serialized) @MainActor
struct TemporaryAILayoutTests {
    @Test func breakpointsAndFormatGatesAreExplicit() {
        #expect(!PDFnoTemporaryLayout.usesSidebar(width: 759))
        #expect(PDFnoTemporaryLayout.usesSidebar(width: 760))
        #expect(!PDFnoTemporaryLayout.usesSidebar(width: .nan))
        #expect(PDFnoTemporaryLayout.directoryColumns(width: 639) == 1)
        #expect(PDFnoTemporaryLayout.directoryColumns(width: 640) == 2)
        for format in [PDFnoReadingToolContext.Format.none, .other] {
            let context = PDFnoReadingToolContext(format: format, hasSelection: true, readingConfigured: true, byokConfigured: true)
            for tool in PDFnoReadingTool.allCases where tool != .savedSearch {
                #expect(context.availability(tool) == .unsupported)
                #expect(!context.availability(tool).canOpen)
            }
            #expect(context.availability(.savedSearch) == .enter)
        }
        let pdf = PDFnoReadingToolContext(format: .pdf, hasSelection: false, readingConfigured: false, byokConfigured: false)
        #expect(pdf.availability(.translate) == .selection && pdf.availability(.translate).canOpen)
        #expect(pdf.availability(.page) == .enter && pdf.availability(.spine) == .unsupported)
        let epub = PDFnoReadingToolContext(format: .epub, hasSelection: false, readingConfigured: false, byokConfigured: false)
        #expect(epub.availability(.spine) == .enter && epub.availability(.page) == .unsupported)
    }

    @Test func configurationOwnersRemainIndependentInTheDirectory() {
        let officialOnly = PDFnoReadingToolContext(format: .pdf, hasSelection: true, readingConfigured: true, byokConfigured: false)
        for tool in [PDFnoReadingTool.translate, .explain, .japanese, .english] { #expect(officialOnly.availability(tool) == .enter) }
        #expect(officialOnly.availability(.byok) == .configuration)
        let byokOnly = PDFnoReadingToolContext(format: .epub, hasSelection: true, readingConfigured: false, byokConfigured: true)
        #expect(byokOnly.availability(.byok) == .enter)
        for tool in [PDFnoReadingTool.translate, .explain, .japanese, .english] { #expect(byokOnly.availability(tool) == .configuration) }
    }

    @Test func actualSettingsAndCatalogRenderWithoutRequestsOrWrites() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-TemporaryAI-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = TemporaryLayoutTransport(), session = AppAISession()
        let library = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        #expect(await library.learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-layout-fixture-credential"))
        // Repository assigns its own config identity/generation on explicit save.
        let configuration = library.learning.config
        library.byok.temporarySecret = "original-independent-layout-credential"
        #expect(await library.byok.apply())
        let sample = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
        let book = BookRecord(title: "Original layout PDF", fileSHA256: LibraryRepository.digest(sample), originalFilename: "original.pdf", pageCount: 2)
        try library.reader.open(data: sample, book: book)
        _ = NSApplication.shared
        let nativeHost = NSHostingView(rootView: PDFCanvas(session: library.reader).frame(width: 760, height: 640))
        let nativeWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640), styleMask: [], backing: .buffered, defer: false)
        nativeWindow.isReleasedWhenClosed = false; nativeWindow.contentView = nativeHost
        defer { nativeWindow.close() }
        nativeHost.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100))
        #expect(!nativeWindow.isVisible)
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first))
        library.reader.captureSelection()
        let anchor = try #require(library.reader.capturedSelection)
        let source = try #require(library.captureAISource())
        library.learning.prepare(source)
        let result = AIResult(request: AIRequest(source: source, provider: configuration, kind: .translate), text: "Original layout result · 原创结果", fromCache: false)
        library.learning.result = result; library.learning.userText = "Original unsaved draft · 日本語 cafe\u{301}"
        let file = root.appendingPathComponent("learning-v1.json")
        let before = try Data(contentsOf: file)
        for scheme in [ColorScheme.light, .dark] {
            for width in [CGFloat(360), 759, 760, 1120] {
                let label = (scheme == .light ? "light" : "dark") + "-" + String(Int(width))
                try await render(AISettingsView(learning: library.learning, byok: library.byok, library: library), width: width, scheme: scheme, name: "settings-ai-" + label)
                try await render(AISettingsView(learning: library.learning, byok: library.byok, library: library, initialCategory: .tools), width: width, scheme: scheme, name: "settings-tools-" + label)
                try await render(ReadingToolsWorkspace(library: library), width: width, scheme: scheme, name: "catalog-" + label)
            }
        }
        for width in [CGFloat(360), 1120] {
            for category in [PDFnoSettingsCategory.general, .backup, .shortcuts, .diagnostics, .about] {
                try await render(AISettingsView(learning: library.learning, byok: library.byok, library: library, initialCategory: category),
                                 width: width, scheme: .light, name: "settings-" + category.rawValue + "-light-" + String(Int(width)))
            }
            try await render(BYOKSettingsView(model: library.byok), width: width, scheme: .light, name: "byok-light-" + String(Int(width)))
            try await render(AILearningWorkspace(library: library, learning: library.learning), width: width, scheme: .light, name: "selection-detail-light-" + String(Int(width)))
        }
        #expect(library.reader.capturedSelection == anchor && library.reader.resolution(of: anchor) == .exact)
        #expect(library.learning.source == source && library.learning.result == result)
        #expect(library.learning.userText == "Original unsaved draft · 日本語 cafe\u{301}")
        #expect(library.learning.config == configuration && library.learning.hasSessionCredential)
        let byokSnapshot = await library.byok.session.snapshot()
        #expect(library.byok.hasSessionCredential && byokSnapshot.hasSessionCredential)
        #expect(await session.selection.attemptsUsed() == 0)
        #expect(await transport.count == 0 && library.learning.notes.isEmpty)
        #expect(try Data(contentsOf: file) == before)
        let context = PDFnoReadingToolContext(library: library)
        #expect(context.availability(.english) == .enter && context.availability(.byok) == .enter)
    }

    @Test func planningAndLongRecipientCardsRenderInBothColumnCounts() async throws {
        for scheme in [ColorScheme.light, .dark] {
            for width in [CGFloat(360), 688, 880] {
                try await render(VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                    PDFnoPlannedDirectory()
                    PDFnoSettingsCard("接收方与来源 · 原创示例") {
                        Text("https://original.example.invalid/" + String(repeating: "long-original-path/", count: 8))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        PDFnoStatusMessage(text: "未配置 · 尚未选择原文 · 原创草稿保留，不能自动发送或保存。")
                    }
                }.padding(PDFnoDesign.Space.section), width: width, scheme: scheme,
                   name: "planning-" + (scheme == .light ? "light" : "dark") + "-" + String(Int(width)))
            }
        }
    }

    private func render<V: View>(_ content: V, width: CGFloat, scheme: ColorScheme, name: String) async throws {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: content.frame(width: width, height: 840).preferredColorScheme(scheme))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 840), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        host.frame = NSRect(x: 0, y: 0, width: width, height: 840)
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
        #expect(!window.isVisible && host.fittingSize.width <= width)
        if let directory = ProcessInfo.processInfo.environment["PDFNO_TEMP_AI_LAYOUT_PREVIEW"] {
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
        }
    }
}
#endif
