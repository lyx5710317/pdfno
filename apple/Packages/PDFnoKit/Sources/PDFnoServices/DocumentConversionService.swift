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

public struct DocumentConversionService: Sendable {
    private let adapters: [any DocumentConversionAdapter]
    public init(adapters: [any DocumentConversionAdapter] = [DOCXTextConversionAdapter()]) { self.adapters = adapters }
    public var capabilities: [ConversionCapability] { adapters.flatMap(\.capabilities) }

    /// Cancellation propagates into the detached worker; completion follows the atomic commit point.
    public func convert(_ request: ConversionRequest,
                        progress: @escaping @Sendable (ConversionPhase) -> Void = { _ in }) async throws -> ConversionResult {
        try Task.checkCancellation()
        guard let adapter = adapters.first(where: { $0.capabilities.contains { $0.input == request.input && $0.output == request.output } }) else {
            throw ConversionError.unsupportedDirection
        }
        let worker = Task.detached(priority: .utility) { try Self.perform(request, adapter: adapter, progress: progress) }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private static func perform(_ request: ConversionRequest, adapter: any DocumentConversionAdapter,
                                progress: @Sendable (ConversionPhase) -> Void) throws -> ConversionResult {
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
            try ensureNewDestination(request.destination)
            progress(.reading); try Task.checkCancellation()
            let source = try readSource(request.source)
            progress(.validating); try Task.checkCancellation()
            let converted = try adapter.convert(source, to: request.output, progress: progress)
            guard converted.data.count <= 16 * 1024 * 1024 else { throw ConversionError.resourceLimit }
            progress(.writing); try Task.checkCancellation()
            try commit(converted.data, to: request.destination)
            progress(.completed)
            return ConversionResult(destination: request.destination, byteCount: converted.data.count,
                                    adapterID: adapter.capabilities.first!.adapterID, warnings: converted.warnings)
        } catch is CancellationError { throw CancellationError() }
        catch let error as ConversionError { throw error }
        catch { throw ConversionError.ioFailure }
    }

    private static func ensureNewDestination(_ url: URL) throws {
        var info = stat()
        if lstat(url.path, &info) == 0 { throw ConversionError.destinationExists }
        guard errno == ENOENT else { throw ConversionError.invalidDestination }
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &directory), directory.boolValue else {
            throw ConversionError.invalidDestination
        }
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

    private static func commit(_ data: Data, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".pdfno-conversion-" + UUID().uuidString + ".tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw ConversionError.ioFailure }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        for offset in stride(from: 0, to: data.count, by: 64 * 1024) {
            try Task.checkCancellation()
            try handle.write(contentsOf: data.subdata(in: offset..<min(offset + 64 * 1024, data.count)))
        }
        try handle.synchronize(); try handle.close()
        try Task.checkCancellation()
        // Same-directory hard-link installation is atomic and fails if ANY destination appeared.
        // No post-commit cancellation check: a completed output must be reported as completed.
        guard link(temporary.path, destination.path) == 0 else {
            if errno == EEXIST { throw ConversionError.destinationExists }
            throw ConversionError.ioFailure
        }
    }
}
