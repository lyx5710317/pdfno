// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import ImageIO
import UniformTypeIdentifiers
import zlib
import PDFnoDomain

public struct CBZEntry: Sendable {
    public let path: String
    public let method: Int
    public let expandedSize: Int
    public let crc: UInt32
    public let payload: Range<Int>
}
/// No filesystem extraction, external command, archive fallback or unbounded decompression.
public struct CBZArchive: Sendable {
    public let data: Data
    public let entries: [CBZEntry]
    public let pages: [ComicPage]
    public init(data: Data) throws {
        let entries = try Self.index(data)
        var pages: [ComicPage] = [], totalPixels = 0
        for entry in entries {
            try Task.checkCancellation()
            let bytes = try Self.expand(entry, from: data)
            let parts = entry.path.split(separator: "/")
            if entry.path.hasSuffix("/") || parts.contains(where: { $0.hasPrefix(".") || $0 == "__MACOSX" }) { continue }
            let ext = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
            if ["png", "jpg", "jpeg"].contains(ext) {
                let page = try Self.inspect(bytes, path: entry.path)
                totalPixels += page.width * page.height
                guard totalPixels <= ComicLimits.totalImagePixels else { throw ComicError.resourceLimit }
                // Decode only a bounded thumbnail to reject corrupt raster payloads during import.
                _ = try Self.thumbnail(bytes)
                pages.append(page)
            } else if ["gif", "webp", "svg", "bmp", "tif", "tiff", "heic", "avif", "jpe", "jfif"].contains(ext) {
                throw ComicError.invalidImage
            }
        }
        guard !pages.isEmpty else { throw ComicError.noPages }
        self.data = data; self.entries = entries
        self.pages = pages.sorted { ComicPageOrder.precedes($0.path, $1.path) }
    }
    public func pagePNG(at index: Int) throws -> Data {
        guard pages.indices.contains(index), let entry = entries.first(where: { $0.path == pages[index].path }) else { throw ComicError.sourceMismatch }
        return try Self.thumbnail(Self.expand(entry, from: data))
    }
    public static func readFile(_ url: URL) throws -> Data {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard info.isRegularFile == true, let size = info.fileSize, size <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: ComicLimits.archiveBytes + 1) ?? Data()
        guard data.count <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        return data
    }
    public static func index(_ data: Data) throws -> [CBZEntry] {
        guard data.count <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        let b = Array(data)
        guard b.count >= 22 else { throw ComicError.invalidArchive }
        func u16(_ p: Int) -> Int { Int(b[p]) | Int(b[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard let end = stride(from: b.count - 22, through: max(0, b.count - 65557), by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == b.count
        }), u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == u16(end + 10) else { throw ComicError.invalidArchive }
        let count = u16(end + 10), start = u32(end + 16)
        guard count > 0, count <= ComicLimits.entries else { throw ComicError.resourceLimit }
        guard start + u32(end + 12) == end else { throw ComicError.invalidArchive }
        func extraIsSafe(_ from: Int, _ size: Int) -> Bool {
            var p = from
            while p < from + size {
                guard p + 4 <= from + size, u16(p) != 1, p + 4 + u16(p + 2) <= from + size else { return false }
                p += 4 + u16(p + 2)
            }
            return p == from + size
        }
        var p = start, total = 0, entries: [CBZEntry] = [], names = Set<String>(), ranges: [Range<Int>] = []
        for _ in 0..<count {
            guard p + 46 <= end, u32(p) == 0x02014b50 else { throw ComicError.invalidArchive }
            let flags = u16(p + 8), method = u16(p + 10), crc = u32(p + 16), compressed = u32(p + 20), expanded = u32(p + 24)
            let n = u16(p + 28), extra = u16(p + 30), comment = u16(p + 32), local = u32(p + 42)
            let mode = (u32(p + 38) >> 16) & 0xf000
            guard p + 46 + n + extra + comment <= end, n > 0, n <= 1024, flags & ~0x080e == 0, (method != 0 || flags & 6 == 0),
                  method == 0 || method == 8, u16(p + 34) == 0, [0, 0x4000, 0x8000].contains(mode),
                  let name = String(bytes: b[(p + 46)..<(p + 46 + n)], encoding: .utf8), EPUBArchive.isSafePath(name),
                  (flags & 0x0800 != 0 || name.utf8.allSatisfy { $0 < 128 }),
                  names.insert(name.precomposedStringWithCanonicalMapping.lowercased()).inserted,
                  extraIsSafe(p + 46 + n, extra) else { throw ComicError.invalidArchive }
            guard expanded <= ComicLimits.entryBytes, compressed <= data.count else { throw ComicError.resourceLimit }
            total += expanded; guard total <= ComicLimits.expandedBytes else { throw ComicError.resourceLimit }
            guard local + 30 <= start, u32(local) == 0x04034b50, u16(local + 6) == flags,
                  u16(local + 8) == method, u16(local + 26) == n else { throw ComicError.invalidArchive }
            let localExtra = u16(local + 28), payload = local + 30 + n + localExtra
            guard payload + compressed <= start, payload <= start,
                  Array(b[(local + 30)..<(local + 30 + n)]) == Array(b[(p + 46)..<(p + 46 + n)]),
                  extraIsSafe(local + 30 + n, localExtra) else { throw ComicError.invalidArchive }
            var finish = payload + compressed
            if flags & 8 == 0 {
                guard u32(local + 14) == crc, u32(local + 18) == compressed, u32(local + 22) == expanded else { throw ComicError.invalidArchive }
            } else {
                guard finish + 12 <= start else { throw ComicError.invalidArchive }
                if u32(finish) == 0x08074b50 { finish += 4 }
                guard finish + 12 <= start, u32(finish) == crc, u32(finish + 4) == compressed, u32(finish + 8) == expanded else { throw ComicError.invalidArchive }
                finish += 12
            }
            let range = local..<finish
            guard !ranges.contains(where: { $0.overlaps(range) }), !name.hasSuffix("/") || expanded == 0 else { throw ComicError.invalidArchive }
            ranges.append(range)
            entries.append(CBZEntry(path: name, method: method, expandedSize: expanded, crc: UInt32(crc), payload: payload..<(payload + compressed)))
            p += 46 + n + extra + comment
        }
        guard p == end else { throw ComicError.invalidArchive }
        return entries
    }
    static func expand(_ entry: CBZEntry, from data: Data) throws -> Data {
        let input = data.subdata(in: entry.payload)
        let output: Data
        if entry.method == 0 {
            guard input.count == entry.expandedSize else { throw ComicError.invalidArchive }; output = input
        } else {
            var stream = z_stream()
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw ComicError.invalidArchive }
            defer { inflateEnd(&stream) }
            // Allocate only the declared bounded output plus one byte to detect dishonest sizes.
            let capacity = entry.expandedSize + 1
            var bytes = [UInt8](repeating: 0, count: capacity)
            let status = input.withUnsafeBytes { raw in
                bytes.withUnsafeMutableBytes { out in
                    stream.next_in = UnsafeMutablePointer(mutating: raw.bindMemory(to: UInt8.self).baseAddress)
                    stream.avail_in = uInt(input.count)
                    stream.next_out = out.bindMemory(to: UInt8.self).baseAddress
                    stream.avail_out = uInt(capacity)
                    return inflate(&stream, Z_FINISH)
                }
            }
            guard status == Z_STREAM_END, stream.total_out == entry.expandedSize,
                  stream.total_in == input.count else { throw ComicError.invalidArchive }
            output = Data(bytes.prefix(entry.expandedSize))
        }
        let crc = output.withUnsafeBytes { raw in crc32(0, raw.bindMemory(to: UInt8.self).baseAddress, uInt(output.count)) }
        guard UInt32(crc) == entry.crc else { throw ComicError.invalidArchive }
        return output
    }
    private static func source(_ data: Data) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1, let type = CGImageSourceGetType(source),
              [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String),
              CGImageSourceGetStatus(source) == .statusComplete else { throw ComicError.invalidImage }
        return source
    }
    private static func inspect(_ data: Data, path: String) throws -> ComicPage {
        let source = try source(data)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw ComicError.invalidImage }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let rotated = [5, 6, 7, 8].contains(orientation)
        let page = ComicPage(path: path, width: rotated ? height : width, height: rotated ? width : height)
        guard page.isValid else { throw ComicError.resourceLimit }
        return page
    }
    private static func thumbnail(_ data: Data) throws -> Data {
        let source = try source(data)
        // Always inspect dimensions before the first raster allocation.
        _ = try inspect(data, path: "page.png")
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: ComicLimits.thumbnailDimension,
            kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ComicError.invalidImage }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { throw ComicError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), out.length <= ComicLimits.entryBytes else { throw ComicError.invalidImage }
        return out as Data
    }
}
