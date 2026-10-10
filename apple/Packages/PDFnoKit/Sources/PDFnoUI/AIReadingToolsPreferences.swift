// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import Combine
import PDFnoDomain
import PDFnoServices

/// Two opt-in preferences independent of document selection. The file contains only booleans.
@MainActor final class AIReadingToolsPreferences: ObservableObject {
    private struct State: Codable { var schemaVersion = 1; var japanese = false; var english = false }
    private static func decode(_ bytes: Data) throws -> State {
        guard JapaneseLearningJSON.hasUniqueKeys(bytes),
              let keys = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(keys.keys) == Set(["schemaVersion","japanese","english"]) else { throw AIFailure.store }
        let value = try JSONDecoder().decode(State.self,from: bytes)
        guard value.schemaVersion == 1 else { throw AIFailure.store }; return value
    }
    private static var owners: [String: AIReadingToolsPreferences] = [:]
    static func shared(root: URL) -> AIReadingToolsPreferences {
        let path = root.standardizedFileURL.path
        if let owner = owners[path] { return owner }; let owner = AIReadingToolsPreferences(root: root); owners[path] = owner; return owner
    }
    @Published private(set) var japanese = false
    @Published private(set) var english = false
    @Published private(set) var error: String?
    private let root: URL
    private var file: URL { root.appendingPathComponent("ai-reading-tools-v1.json") }
    init(root: URL) {
        self.root = root
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let state = try Self.decode(BoundedFileReader.read(file, limit: 1024))
            japanese = state.japanese; english = state.english
        } catch { self.error = "AI工具设置无法读取；保持关闭，已有笔记保留。" }
    }
    func isEnabled(_ task: ReadingConversationTask) -> Bool {
        switch task { case .japanese: japanese; case .english: english; default: true }
    }
    func set(_ task: ReadingConversationTask, enabled: Bool) {
        guard task == .japanese || task == .english else { return }
        var state = State(japanese: japanese, english: english)
        if task == .japanese { state.japanese = enabled } else { state.english = enabled }
        do {
            let write = try LocalStoreWriteGate.shared(root: root).beginWrite(); defer { write.finish() }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { _ = try Self.decode(BoundedFileReader.read(file, limit: 1024)) }
            try JSONEncoder().encode(state).write(to: file, options: .atomic)
            japanese = state.japanese; english = state.english; error = nil
        } catch { self.error = "AI工具设置未保存；已有内容和笔记保留。" }
    }
}
#endif
