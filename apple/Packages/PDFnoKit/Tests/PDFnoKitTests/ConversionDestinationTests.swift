// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

private struct OriginalDirectorySwapAdapter: DocumentConversionAdapter {
    var capabilities: [ConversionCapability] { [.init(input: .docx, output: .plainText, adapterID: "original-directory-swap")] }
    func convert(_ source: Data, to output: ConversionFormat, progress: @Sendable (ConversionPhase) -> Void) throws -> ConvertedDocument {
        ConvertedDocument(data: Data("Original harmless audit output".utf8), warnings: [])
    }
}
enum DirectorySwap: CaseIterable, Sendable { case symlink, directory, ancestorSymlink }
private final class StagingObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var sawStaging: Bool { lock.withLock { value } }
    func record(_ value: Bool) { lock.withLock { self.value = value } }
}

struct ConversionDestinationTests {
    private func swapDirectory(_ kind: DirectorySwap, at phase: ConversionPhase, cancel: Bool = false) async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("PDFno-Conversion-Directory-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let selectedContainer = root.appendingPathComponent("selected"), movedContainer = root.appendingPathComponent("original-directory")
        let replacementContainer = root.appendingPathComponent("replacement")
        let selected = kind == .ancestorSymlink ? selectedContainer.appendingPathComponent("child") : selectedContainer
        let moved = kind == .ancestorSymlink ? movedContainer.appendingPathComponent("child") : movedContainer
        let replacement = kind == .ancestorSymlink ? replacementContainer.appendingPathComponent("child") : replacementContainer
        let actualReplacement = kind == .directory ? selected : replacement
        try manager.createDirectory(at: selected, withIntermediateDirectories: true)
        try manager.createDirectory(at: replacement, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("original.docx"), bytes = Data("Original audit source".utf8)
        try bytes.write(to: source)
        let sentinel = Data("Original existing replacement file".utf8)
        try sentinel.write(to: replacement.appendingPathComponent("existing.txt"))
        let service = DocumentConversionService(adapters: [OriginalDirectorySwapAdapter()]), observation = StagingObservation()
        let conversion: @Sendable () async throws -> ConversionResult = {
            try await service.convert(.init(source: source, destination: selected.appendingPathComponent("result.txt"), output: .plainText)) { event in
                if event == phase {
                    observation.record(!(try! FileManager.default.contentsOfDirectory(atPath: selected.path)).isEmpty)
                    try! FileManager.default.moveItem(at: selectedContainer, to: movedContainer)
                    if kind == .directory { try! FileManager.default.moveItem(at: replacementContainer, to: selectedContainer) }
                    else { try! FileManager.default.createSymbolicLink(at: selectedContainer, withDestinationURL: replacementContainer) }
                    if cancel { withUnsafeCurrentTask { $0?.cancel() } }
                }
            }
        }
        if cancel { await #expect(throws: CancellationError.self) { try await conversion() } }
        else { await #expect(throws: ConversionError.invalidDestination) { try await conversion() } }
        // Writing now starts with a private staging file present. The path swap
        // and cancellation cases therefore exercise cleanup after creation.
        #expect(observation.sawStaging == (phase == .writing))
        #expect(try Data(contentsOf: source) == bytes)
        #expect(try manager.contentsOfDirectory(atPath: moved.path).isEmpty)
        #expect(try manager.contentsOfDirectory(atPath: actualReplacement.path) == ["existing.txt"])
        #expect(try Data(contentsOf: actualReplacement.appendingPathComponent("existing.txt")) == sentinel)
    }
    @Test(arguments: DirectorySwap.allCases)
    func writingDirectorySwapRefusesOutputAndCleansPinnedStaging(_ kind: DirectorySwap) async throws {
        try await swapDirectory(kind, at: .writing)
    }
    @Test(arguments: [ConversionPhase.reading, .validating])
    func directorySwapBeforeStagingRefusesOutput(_ phase: ConversionPhase) async throws {
        try await swapDirectory(.symlink, at: phase)
    }
    @Test func cancellationAfterDirectorySwapCleansPinnedStaging() async throws {
        try await swapDirectory(.symlink, at: .writing, cancel: true)
    }
    @Test func existingSymlinkParentIsRejectedWithoutModifyingItsTarget() async throws {
        let manager = FileManager.default, root = manager.temporaryDirectory.appendingPathComponent("PDFno-Conversion-Alias-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), target = root.appendingPathComponent("target"), alias = root.appendingPathComponent("alias")
        let bytes = Data("Original alias source".utf8); try bytes.write(to: source)
        try manager.createDirectory(at: target, withIntermediateDirectories: false)
        try manager.createSymbolicLink(at: alias, withDestinationURL: target)
        await #expect(throws: ConversionError.invalidDestination) {
            try await DocumentConversionService(adapters: [OriginalDirectorySwapAdapter()]).convert(.init(source: source, destination: alias.appendingPathComponent("result.txt"), output: .plainText))
        }
        #expect(try manager.contentsOfDirectory(atPath: target.path).isEmpty)
        #expect(try Data(contentsOf: source) == bytes)
    }
    @Test func ordinaryUnicodeDestinationStillCompletesWithoutStagingResidue() async throws {
        let manager = FileManager.default, root = manager.temporaryDirectory.appendingPathComponent("PDFno-Conversion-Unicode-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), parent = root.appendingPathComponent("原创 日本語🌸")
        let bytes = Data("Original unicode source".utf8); try bytes.write(to: source)
        try manager.createDirectory(at: parent, withIntermediateDirectories: false)
        let output = parent.appendingPathComponent("副本 café.txt")
        let result = try await DocumentConversionService(adapters: [OriginalDirectorySwapAdapter()]).convert(.init(source: source, destination: output, output: .plainText))
        #expect(result.destination == output && result.byteCount == 30)
        #expect(try Data(contentsOf: output) == Data("Original harmless audit output".utf8))
        #expect(try manager.contentsOfDirectory(atPath: parent.path) == [output.lastPathComponent])
        #expect(try Data(contentsOf: source) == bytes)
    }
}
