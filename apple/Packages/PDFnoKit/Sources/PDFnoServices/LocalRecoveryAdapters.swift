// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// A trusted decoder must validate the COMPLETE file, including unknown fields,
/// source spans and duplicates. Registry admission is intentionally one audited seam.
public struct LocalRecoveryAssociation: Sendable {
    public let recordID: UUID
    public let bookID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let format: String?
    public init(recordID: UUID, bookID: UUID, editionID: UUID, fileSHA256: String, format: String? = nil) {
        self.format = format
        self.recordID = recordID; self.bookID = bookID; self.editionID = editionID; self.fileSHA256 = fileSHA256
    }
}
public struct LocalRecoveryAdditionalAdapter: Sendable {
    public let filename: String
    let validate: @Sendable (Data) throws -> Void
    let associations: @Sendable (Data) throws -> [LocalRecoveryAssociation]
    public init(filename: String, validate: @escaping @Sendable (Data) throws -> Void,
                associations: @escaping @Sendable (Data) throws -> [LocalRecoveryAssociation]) throws {
        guard filename == "english-learning-v1.json" else { throw LocalRecoveryError.unsupportedStore(filename) }
        self.filename = filename; self.validate = validate; self.associations = associations
    }
}
struct RecoveryAdapter: Sendable {
    let filename: String
    let format: String?
    let collections: [String]
    let validate: @Sendable (Data) throws -> Void
    let extraAssociations: (@Sendable (Data) throws -> [LocalRecoveryAssociation])?
    init(_ filename: String, format: String? = nil, collections: [String],
         validate: @escaping @Sendable (Data) throws -> Void,
         extraAssociations: (@Sendable (Data) throws -> [LocalRecoveryAssociation])? = nil) {
        self.filename = filename; self.format = format; self.collections = collections
        self.validate = validate; self.extraAssociations = extraAssociations
    }
}
struct RecoveryRegistry: Sendable {
    var adapters: [String: RecoveryAdapter]
    init(additional: [LocalRecoveryAdditionalAdapter]) throws {
        let standard: [RecoveryAdapter] = [
            .init("library-v1.json", format: "pdf", collections: ["books", "notes"]) { _ = try LibraryRepository.decode($0) },
            .init("epub-v1.json", format: "epub", collections: ["books", "notes"]) { _ = try EPUBRepository.decode($0) },
            .init("comics-v1.json", format: "cbz", collections: ["books"]) { _ = try ComicRepository.decode($0) },
            .init("comics-cbt-v1.json", format: "cbt", collections: ["books"]) { _ = try ComicRepository.decode($0, format: .cbt) },
            .init("comics-cb7-v1.json", format: "cb7", collections: ["books"]) { _ = try ComicRepository.decode($0, format: .cb7) },
            .init("comics-cbr-v1.json", format: "cbr", collections: ["books"]) { _ = try ComicRepository.decode($0, format: .cbr) },
            .init("docx-mammoth-v1.json", format: "docx", collections: ["books", "notes"]) { _ = try DOCXRepository.decode($0) },
            .init("text-formats-v1.json", format: "variable", collections: ["books", "notes"]) { _ = try TextFormatRepository.decode($0) },
            .init("ebook-kookit-v1.json", format: "variable", collections: ["books", "notes"]) { _ = try EbookRepository.decode($0) },
            .init("learning-v1.json", collections: ["notes"]) { _ = try AILearningRepository.decode($0) },
            .init("japanese-learning-v1.json", collections: ["notes"]) { _ = try JapaneseLearningRepository.decode($0) },
            .init("book-metadata-v1.json", collections: ["records"]) { _ = try LocalBookMetadataRepository.decode($0) },
            .init("covers-v1.json", collections: ["records"], validate: Self.validateCovers)
        ]
        adapters = Dictionary(uniqueKeysWithValues: standard.map { ($0.filename, $0) })
        for item in additional {
            guard adapters[item.filename] == nil else { throw LocalRecoveryError.conflict }
            adapters[item.filename] = RecoveryAdapter(item.filename, collections: ["notes"], validate: item.validate, extraAssociations: item.associations)
        }
    }
    static func object(_ data: Data) throws -> [String: Any] {
        guard data.count <= LocalRecoveryLimits.manifestBytes, JapaneseLearningJSON.hasUniqueKeysForStore(data),
              let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = value["schemaVersion"] as? Int, version == 1,
              !(value["schemaVersion"] is NSNull) else { throw LocalRecoveryError.invalidPackage }
        // NSNumber Boolean compares equal to 1. Require its literal JSON scalar to be numeric.
        guard let number = value["schemaVersion"] as? NSNumber, String(cString: number.objCType) != "c" else { throw LocalRecoveryError.invalidPackage }
        return value
    }
    static func encode(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]) }
    func decode(_ filename: String, _ data: Data) throws -> [String: Any] {
        guard let adapter = adapters[filename] else { throw LocalRecoveryError.unsupportedStore(filename) }
        let object = try Self.object(data); try adapter.validate(data)
        for key in adapter.collections { guard let rows = object[key] as? [[String: Any]], rows.count <= 10000 else { throw LocalRecoveryError.limit } }
        if let associations = adapter.extraAssociations {
            let links = try associations(data), rows = object["notes"] as! [[String: Any]]
            guard links.count == rows.count, Set(links.map(\.recordID)).count == links.count,
                  Set(links.map(\.recordID)) == Set(try rows.map { try Self.id($0) }),
                  links.allSatisfy({ LibraryRepository.isDigest($0.fileSHA256) }) else { throw LocalRecoveryError.integrity }
        }
        return object
    }
    static func id(_ row: [String: Any]) throws -> UUID {
        if let value = row["id"] as? String, let id = UUID(uuidString: value) { return id }
        let identity = (row["identity"] ?? row["book"]) as? [String: Any]
        guard let value = identity?["bookID"] as? String, let id = UUID(uuidString: value) else { throw LocalRecoveryError.integrity }
        return id
    }
    static func identity(_ row: [String: Any]) throws -> (UUID, UUID, String) {
        guard let id = (row["id"] ?? row["bookID"]) as? String, let bookID = UUID(uuidString: id),
              let edition = row["editionID"] as? String, let editionID = UUID(uuidString: edition),
              let hash = row["fileSHA256"] as? String, LibraryRepository.isDigest(hash) else { throw LocalRecoveryError.integrity }
        return (bookID, editionID, hash)
    }
    static func association(_ row: [String: Any]) throws -> LocalRecoveryAssociation {
        let recordID = try id(row)
        if let value = (row["identity"] ?? row["book"]) as? [String: Any] {
            let identity = try identity(value)
            return .init(recordID: recordID, bookID: identity.0, editionID: identity.1, fileSHA256: identity.2, format: (value["format"] as? String)?.lowercased())
        }
        let result = (row["result"] ?? row["review"]) as? [String: Any]
        let source = result?["source"] as? [String: Any]
        guard let book = (source?["bookID"] ?? row["bookID"]) as? String, let bookID = UUID(uuidString: book),
              var anchor = (source?["anchor"] ?? row["anchor"]) as? [String: Any] else { throw LocalRecoveryError.integrity }
        let kind = source != nil ? anchor.keys.first : nil
        if anchor.count == 1, let wrapper = anchor.values.first as? [String: Any], let nested = wrapper["_0"] as? [String: Any] { anchor = nested }
        guard let edition = anchor["editionID"] as? String, let editionID = UUID(uuidString: edition),
              let hash = anchor["fileSHA256"] as? String, LibraryRepository.isDigest(hash) else { throw LocalRecoveryError.integrity }
        let format = kind.map { ["pdf", "pdfPage"].contains($0) ? "pdf" : "epub" } ?? anchor["format"] as? String
        return .init(recordID: recordID, bookID: bookID, editionID: editionID, fileSHA256: hash, format: format)
    }
    static func validateCovers(_ data: Data) throws {
        let object = try object(data)
        guard Set(object.keys) == ["schemaVersion", "records"], let rows = object["records"] as? [[String: Any]], rows.count <= 10000 else { throw LocalRecoveryError.invalidPackage }
        var ids: Set<UUID> = []
        for row in rows {
            let required: Set<String> = ["identity", "origin", "byteLength", "width", "height", "revision", "updatedAt", "extractorVersion"]
            guard required.isSubset(of: Set(row.keys)), Set(row.keys).isSubset(of: required.union(["resourcePath", "imageSHA256", "mimeType"])),
                  let identity = row["identity"] as? [String: Any], Set(identity.keys) == ["bookID", "editionID", "fileSHA256", "format"] else { throw LocalRecoveryError.invalidPackage }
            let record = try JSONDecoder().decode(CoverRecord.self, from: encode(row))
            guard ids.insert(record.identity.bookID).inserted, LibraryRepository.isDigest(record.identity.fileSHA256),
                  record.revision > 0, record.revision < Int.max, record.updatedAt.timeIntervalSince1970.isFinite,
                  !record.extractorVersion.isEmpty, record.extractorVersion.utf8.count <= 128 else { throw LocalRecoveryError.invalidPackage }
            if record.origin == .placeholder {
                guard record.imageSHA256 == nil, record.mimeType == nil, record.byteLength == 0, record.width == 0, record.height == 0, record.resourcePath == nil else { throw LocalRecoveryError.integrity }
            } else {
                guard record.imageSHA256.map(LibraryRepository.isDigest) == true, record.mimeType == "image/png", record.byteLength > 0,
                      record.byteLength <= CoverLimits.inputBytes, record.width > 0, record.height > 0,
                      max(record.width, record.height) <= CoverLimits.assetDimension else { throw LocalRecoveryError.integrity }
                let requiredFormat: [CoverOrigin: CoverFormat] = [.pdfFirstPage: .pdf, .epubEmbedded: .epub, .cbzFirstImage: .cbz, .cbtFirstImage: .cbt, .cb7FirstImage: .cb7, .cbrFirstImage: .cbr]
                if let format = requiredFormat[record.origin] { guard record.identity.format == format else { throw LocalRecoveryError.integrity } }
                if [.epubEmbedded, .cbzFirstImage, .cbtFirstImage, .cb7FirstImage, .cbrFirstImage].contains(record.origin) {
                    guard record.resourcePath.map(EPUBArchive.isSafePath) == true else { throw LocalRecoveryError.integrity }
                } else { guard record.resourcePath == nil else { throw LocalRecoveryError.integrity } }
            }
        }
    }
}
