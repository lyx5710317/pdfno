// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// The native host verifies the exact reader source before creating this token.
/// Revocation and the synchronous file transaction share this lock, so a source
/// invalidation cannot race between the last check and the manifest replacement.
/// Source geometry/DOM resolution remains the host's native-reader responsibility.
public final class EnglishLearningSourceCommitFence: @unchecked Sendable {
    private let lock = NSLock()
    private let root: URL
    private let sourceBytes: Data
    private let epoch: UUID
    private var current = true
    public init(root: URL, source: AISourceSnapshot) throws {
        guard source.isValid else { throw AIFailure.stale }
        switch source.anchor { case .pdf, .epub: break; default: throw AIFailure.stale }
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        sourceBytes = try encoder.encode(source)
        let gate = LocalStoreWriteGate.shared(root: self.root).snapshot
        guard gate.phase == .writable else { throw AIFailure.stale }
        epoch = gate.epoch
    }
    public func invalidate() { lock.lock(); current = false; lock.unlock() }
    func withValidatedCommit(root: URL, source: AISourceSnapshot, _ commit: () throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard current, root.standardizedFileURL.resolvingSymlinksInPath() == self.root,
              try encoder.encode(source) == sourceBytes,
              LocalStoreWriteGate.shared(root: self.root).snapshot.epoch == epoch else { throw AIFailure.stale }
        let suffix: String, limit: Int
        switch source.anchor {
        case .pdf(let anchor):
            let state = try LibraryRepository.decode(BoundedFileReader.read(self.root.appendingPathComponent("library-v1.json"), limit: 10 * 1024 * 1024))
            guard state.books.contains(where: { $0.id == source.bookID && $0.editionID == anchor.editionID && $0.fileSHA256 == anchor.fileSHA256 }) else { throw AIFailure.stale }
            suffix = "pdf"; limit = 200 * 1024 * 1024
        case .epub(let anchor):
            let state = try EPUBRepository.decode(BoundedFileReader.read(self.root.appendingPathComponent("epub-v1.json"), limit: 10 * 1024 * 1024))
            guard state.books.contains(where: { $0.id == source.bookID && $0.editionID == anchor.editionID && $0.fileSHA256 == anchor.fileSHA256 }) else { throw AIFailure.stale }
            suffix = "epub"; limit = 20 * 1024 * 1024
        default: throw AIFailure.stale
        }
        let asset = self.root.appendingPathComponent("Originals").appendingPathComponent(source.anchor.fileSHA256 + "." + suffix)
        guard LibraryRepository.digest(try BoundedFileReader.read(asset, limit: limit)) == source.anchor.fileSHA256 else { throw AIFailure.stale }
        try Task.checkCancellation()
        try commit()
    }
}
