// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

private actor HomeSettingsNoNetwork: AIHTTPTransport {
    private(set) var calls = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse { calls += 1; throw AIFailure.network }
}

@Suite(.serialized) @MainActor struct HomeSettingsNavigationTests {
    @Test func mountedMainWindowRoutesKeepRealReaderSourceResultAndDraftWithoutWrites() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-HomeSettings-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = HomeSettingsNoNetwork()
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        await library.load(); await library.openSample()
        let navigation = PDFnoWorkspaceNavigation()
        let state = HomeSettingsHostState()
        let host = NSHostingView(rootView: HomeSettingsHost(library: library, navigation: navigation, state: state))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        navigation.showReader(); await settle(host)
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        let native = try #require(library.reader.view), document = try #require(library.reader.document)
        let anchor = try #require(library.reader.capturedSelection), identity = library.reader.readerSessionID
        let source = try #require(library.captureAISource())
        library.learning.prepare(source)
        let result = AIResult(request: AIRequest(source: source, provider: library.learning.config, kind: .translate), text: "Original offline result 原创结果", fromCache: false)
        library.learning.result = result; library.learning.userText = "Unsaved 日本語 cafe\u{301} 👩🏽‍🚀"
        await settle(host)
        let before = try persistentBytes(root)
        for width in [CGFloat(1280), 720, 1280] {
            for scheme in [ColorScheme.light, .dark] {
                state.width = width; state.scheme = scheme
                window.setContentSize(NSSize(width: width, height: 520))
                navigation.showSettings(); await settle(host)
                #expect(host.fittingSize.width <= width && !window.isVisible && !window.isKeyWindow)
                navigation.returnFromSettings(readerAvailable: true); await settle(host)
                #expect(navigation.route == .reader)
                navigation.showLibrary(); await settle(host)
                navigation.showSettings(); await settle(host)
                navigation.returnFromSettings(readerAvailable: true); await settle(host)
                #expect(navigation.route == .library)
                navigation.showReader(); await settle(host)
                #expect(library.reader.view === native && library.reader.document === document && library.reader.readerSessionID == identity)
                #expect(library.reader.capturedSelection == anchor && library.reader.resolution(of: anchor) == .exact)
                #expect(library.learning.source == source && library.learning.result == result)
                #expect(library.learning.userText == "Unsaved 日本語 cafe\u{301} 👩🏽‍🚀")
            }
        }
        #expect(try persistentBytes(root) == before)
        #expect(await transport.calls == 0)
        #expect(library.learning.notes.isEmpty && !library.learning.hasSessionCredential)
    }
    private func settle<V: View>(_ host: NSHostingView<V>) async {
        host.layoutSubtreeIfNeeded(); try? await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
    }
    private func persistentBytes(_ root: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        for case let file as URL in enumerator {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            guard !relative.contains("cover"), !relative.contains("cache"), try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            result[relative] = try Data(contentsOf: file)
        }
        return result
    }
}
@MainActor private final class HomeSettingsHostState: ObservableObject {
    @Published var width: CGFloat = 1280
    @Published var scheme = ColorScheme.light
}
private struct HomeSettingsHost: View {
    let library: LibraryModel
    let navigation: PDFnoWorkspaceNavigation
    @ObservedObject var state: HomeSettingsHostState
    var body: some View {
        LibraryWorkspace(model: library, navigation: navigation).frame(width: state.width, height: 520).preferredColorScheme(state.scheme)
    }
}
#endif
