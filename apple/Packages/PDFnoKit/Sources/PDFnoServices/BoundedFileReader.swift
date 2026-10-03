// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Darwin

public enum BoundedFileReadError: LocalizedError, Sendable {
    case invalidFile, resourceLimit, changedFile, unreadable
    public var errorDescription: String? {
        switch self {
        case .invalidFile: "只接受普通本地文件；不会读取目录或特殊文件。"
        case .resourceLimit: "文件超过此格式的读取大小限制。"
        case .changedFile: "文件在读取期间发生变化；请重新选择文件。"
        case .unreadable: "无法安全读取此文件；原文件未改写。"
        }
    }
}

/// Bounds allocation on the opened regular file, rather than trusting pathname metadata.
public enum BoundedFileReader {
    public static func read(_ url: URL, limit: Int) throws -> Data {
        try read(url, limit: limit, didReadChunk: { _ in })
    }
    // Internal deterministic hook for growth/replacement regressions; production never supplies one.
    static func read(_ url: URL, limit: Int, didReadChunk: (Int) throws -> Void) throws -> Data {
        guard url.isFileURL, limit >= 0, limit < Int.max else { throw BoundedFileReadError.invalidFile }
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw BoundedFileReadError.unreadable }
        defer { Darwin.close(descriptor) }
        var initial = stat()
        guard fstat(descriptor, &initial) == 0, (initial.st_mode & S_IFMT) == S_IFREG, initial.st_size >= 0 else {
            throw BoundedFileReadError.invalidFile
        }
        guard initial.st_size <= limit else { throw BoundedFileReadError.resourceLimit }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 64 * 1024)
        result.reserveCapacity(min(Int(initial.st_size), buffer.count))
        while true {
            try Task.checkCancellation()
            let requested = min(buffer.count, limit - result.count + 1)
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, requested) }
            if count < 0 { if errno == EINTR { continue }; throw BoundedFileReadError.unreadable }
            if count == 0 { break }
            guard count <= limit - result.count else { throw BoundedFileReadError.resourceLimit }
            result.append(contentsOf: buffer.prefix(count))
            try didReadChunk(result.count)
        }
        var final = stat()
        guard fstat(descriptor, &final) == 0, final.st_size == initial.st_size,
              final.st_mtimespec.tv_sec == initial.st_mtimespec.tv_sec,
              final.st_mtimespec.tv_nsec == initial.st_mtimespec.tv_nsec,
              result.count == initial.st_size else { throw BoundedFileReadError.changedFile }
        return result
    }
}
