// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Darwin
import PDFnoDomain

/// Adapters receive bounded immutable bytes. No UI, library store, subprocess or network access.
public protocol DocumentConversionAdapter: Sendable {
    var capabilities: [ConversionCapability] { get }
    func convert(_ source: Data, to output: ConversionFormat,
                 progress: @Sendable (ConversionPhase) -> Void) throws -> ConvertedDocument
}

/// Async adapters may use an actor-isolated semantic engine; file I/O still belongs to this service.
public protocol AsyncDocumentConversionAdapter: Sendable {
    var capabilities: [ConversionCapability] { get }
    func convert(_ source: Data, to output: ConversionFormat,
                 progress: @escaping @Sendable (ConversionPhase) -> Void) async throws -> ConvertedDocument
}

public struct DocumentConversionService: Sendable {
    private let adapters: [any DocumentConversionAdapter]
    private let asyncAdapters: [any AsyncDocumentConversionAdapter]
    public init(adapters: [any DocumentConversionAdapter] = [DOCXTextConversionAdapter()],
                asyncAdapters: [any AsyncDocumentConversionAdapter] = []) {
        self.adapters = adapters; self.asyncAdapters = asyncAdapters
    }
    public var capabilities: [ConversionCapability] { adapters.flatMap(\.capabilities) + asyncAdapters.flatMap(\.capabilities) }

    /// Cancellation propagates into the detached worker; completion follows the atomic commit point.
    public func convert(_ request: ConversionRequest,
                        progress: @escaping @Sendable (ConversionPhase) -> Void = { _ in }) async throws -> ConversionResult {
        try Task.checkCancellation()
        let matches: (ConversionCapability) -> Bool = { $0.input == request.input && $0.output == request.output }
        let adapterID: String
        let render: @Sendable (Data) async throws -> ConvertedDocument
        if let adapter = adapters.first(where: { $0.capabilities.contains(where: matches) }) {
            adapterID = adapter.capabilities.first(where: matches)!.adapterID
            render = { try adapter.convert($0, to: request.output, progress: progress) }
        } else if let adapter = asyncAdapters.first(where: { $0.capabilities.contains(where: matches) }) {
            adapterID = adapter.capabilities.first(where: matches)!.adapterID
            render = { try await adapter.convert($0, to: request.output, progress: progress) }
        } else { throw ConversionError.unsupportedDirection }
        let worker = Task.detached(priority: .utility) {
            try await Self.perform(request, adapterID: adapterID, render: render, progress: progress)
        }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private static func perform(_ request: ConversionRequest, adapterID: String,
                                render: @Sendable (Data) async throws -> ConvertedDocument,
                                progress: @Sendable (ConversionPhase) -> Void) async throws -> ConversionResult {
        guard request.source.isFileURL, request.source.pathExtension.lowercased() == request.input.fileExtension else { throw ConversionError.invalidSource }
        guard request.destination.isFileURL, request.destination.pathExtension.lowercased() == request.output.fileExtension,
              request.source.resolvingSymlinksInPath().standardizedFileURL != request.destination.resolvingSymlinksInPath().standardizedFileURL else {
            throw ConversionError.invalidDestination
        }
        let sourceAccess = request.source.startAccessingSecurityScopedResource()
        let outputAccess = request.destination.startAccessingSecurityScopedResource()
        defer {
            if sourceAccess { request.source.stopAccessingSecurityScopedResource() }
            if outputAccess { request.destination.stopAccessingSecurityScopedResource() }
        }
        do {
            // Keep the selected directory open for the complete conversion;
            // later path replacement cannot redirect any output operation.
            let destination = try PinnedConversionDestination.pin(request.destination)
            progress(.reading); try Task.checkCancellation()
            let source = try readSource(request.source)
            progress(.validating); try Task.checkCancellation()
            let converted = try await render(source)
            guard converted.data.count <= 16 * 1024 * 1024 else { throw ConversionError.resourceLimit }
            try destination.commit(converted.data, progress: progress)
            progress(.completed)
            return ConversionResult(destination: request.destination, byteCount: converted.data.count,
                                    adapterID: adapterID, warnings: converted.warnings, readingPDFReport: converted.readingPDFReport)
        } catch is CancellationError { throw CancellationError() }
        catch let error as ConversionError { throw error }
        catch let error as DOCXError { throw error }
        catch let error as DOCXReadingPDFError { throw error }
        catch { throw ConversionError.ioFailure }
    }

    private static func readSource(_ url: URL) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw ConversionError.invalidSource }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw ConversionError.invalidSource }
        let limit = 20 * 1024 * 1024
        guard info.st_size <= limit else { throw ConversionError.resourceLimit }
        var bytes = Data()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }
            guard bytes.count + chunk.count <= limit else { throw ConversionError.resourceLimit }
            bytes.append(chunk)
        }
        return bytes
    }

}

/// Owns one directory descriptor; pathname identity checks are read-only.
/// Creation, installation and cleanup always address the pinned directory.
private final class PinnedConversionDestination {
    private let directory: URL
    private let filename: String
    private let directoryDescriptor: Int32
    private let identity: stat
    private static let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC

    private init(directory: URL, filename: String, descriptor: Int32, identity: stat) {
        self.directory = directory; self.filename = filename
        directoryDescriptor = descriptor; self.identity = identity
    }
    deinit { _ = Darwin.close(directoryDescriptor) }

    static func pin(_ destination: URL) throws -> PinnedConversionDestination {
        let directory = destination.deletingLastPathComponent(), filename = destination.lastPathComponent
        guard !filename.isEmpty, filename != ".", filename != "..", !filename.contains("/"),
              !destination.path.utf8.contains(0) else { throw ConversionError.invalidDestination }
        let descriptor = open(directory.path, directoryFlags)
        guard descriptor >= 0 else { throw ConversionError.invalidDestination }
        do {
            var info = stat(), existing = stat()
            guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
                throw ConversionError.invalidDestination
            }
            // Inspect the destination relative to that same directory, including
            // dangling symlinks. Final no-replace installation remains atomic.
            if fstatat(descriptor, filename, &existing, AT_SYMLINK_NOFOLLOW) == 0 { throw ConversionError.destinationExists }
            guard errno == ENOENT else { throw ConversionError.invalidDestination }
            return PinnedConversionDestination(directory: directory, filename: filename, descriptor: descriptor, identity: info)
        } catch { _ = Darwin.close(descriptor); throw error }
    }

    private func verifyPathIdentity() throws {
        let current = open(directory.path, Self.directoryFlags)
        guard current >= 0 else { throw ConversionError.invalidDestination }
        defer { _ = Darwin.close(current) }
        var info = stat()
        guard fstat(current, &info) == 0, info.st_dev == identity.st_dev, info.st_ino == identity.st_ino else {
            throw ConversionError.invalidDestination
        }
    }

    func commit(_ data: Data, progress: @Sendable (ConversionPhase) -> Void) throws {
        try Task.checkCancellation(); try verifyPathIdentity()
        let temporary = ".pdfno-conversion-" + UUID().uuidString + ".tmp"
        let descriptor = openat(directoryDescriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw ConversionError.ioFailure }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); _ = unlinkat(directoryDescriptor, temporary, 0) }
        progress(.writing); try Task.checkCancellation(); try verifyPathIdentity()
        for offset in stride(from: 0, to: data.count, by: 64 * 1024) {
            try Task.checkCancellation()
            try handle.write(contentsOf: data.subdata(in: offset..<min(offset + 64 * 1024, data.count)))
        }
        try handle.synchronize(); try handle.close()
        try Task.checkCancellation(); try verifyPathIdentity()
        // Same-directory hard-link installation is atomic and fails if ANY destination appeared.
        // No post-commit cancellation check: a completed output must be reported as completed.
        guard linkat(directoryDescriptor, temporary, directoryDescriptor, filename, 0) == 0 else {
            if errno == EEXIST { throw ConversionError.destinationExists }
            throw ConversionError.ioFailure
        }
    }
}
