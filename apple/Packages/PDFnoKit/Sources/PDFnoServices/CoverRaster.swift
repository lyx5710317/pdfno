// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import PDFnoDomain

struct CoverRaster: Sendable {
    let png: Data
    let width: Int
    let height: Int
    static func image(_ data: Data, maximum: Int, byteLimit: Int = CoverLimits.inputBytes) throws -> CoverRaster {
        try Task.checkCancellation()
        guard data.count <= byteLimit else { throw CoverError.resourceLimit }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1, CGImageSourceGetStatus(source) == .statusComplete,
              let type = CGImageSourceGetType(source),
              [UTType.png.identifier, UTType.jpeg.identifier, UTType.heic.identifier, UTType.tiff.identifier].contains(type as String),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw CoverError.invalidImage }
        guard width > 0, height > 0, width <= CoverLimits.inputDimension, height <= CoverLimits.inputDimension,
              width * height <= CoverLimits.inputPixels else { throw CoverError.resourceLimit }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maximum,
            kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { throw CoverError.invalidImage }
        return try encode(image)
    }
    static func encode(_ image: CGImage) throws -> CoverRaster {
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil) else { throw CoverError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), bytes.length <= CoverLimits.inputBytes else { throw CoverError.resourceLimit }
        return CoverRaster(png: bytes as Data, width: image.width, height: image.height)
    }
    /// The temporary PDFDocument is never the reader's annotated document and never escapes this actor's call.
    static func pdf(_ data: Data) throws -> CoverRaster {
        guard let document = PDFDocument(data: data), !document.isLocked, let page = document.page(at: 0),
              let original = page.pageRef else { throw CoverError.sourceMismatch }
        let box = page.bounds(for: .cropBox)
        guard box.width.isFinite, box.height.isFinite, box.width > 0, box.height > 0 else { throw CoverError.sourceMismatch }
        let rotated = page.rotation % 180 != 0
        let w = rotated ? box.height : box.width, h = rotated ? box.width : box.height
        let scale = Double(CoverLimits.thumbnailDimension) / max(w, h)
        let width = max(1, Int(w * scale)), height = max(1, Int(h * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CoverError.invalidImage }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.concatenate(original.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(original)
        guard let image = context.makeImage() else { throw CoverError.invalidImage }
        return try encode(image)
    }
}
