// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct BookmarkState: Codable, Sendable {
    public var schemaVersion=1
    public var bookmarks: [ReadingBookmark]=[]
    public init() {}
}
public actor BookmarkRepository {
    public static let filename="bookmarks-v1.json"
    public let root: URL
    public init(root: URL) { self.root=root }
    public func load() throws -> BookmarkState {
        let file=root.appendingPathComponent(Self.filename)
        guard FileManager.default.fileExists(atPath: file.path) else { return BookmarkState() }
        return try Self.decode(BoundedFileReader.read(file,limit: 5*1024*1024))
    }
    public static func decode(_ bytes: Data) throws -> BookmarkState {
        guard bytes.count<=5*1024*1024,JapaneseLearningJSON.hasUniqueKeysForStore(bytes),
              let object=try JSONSerialization.jsonObject(with: bytes) as? [String:Any],
              let version=object["schemaVersion"] as? NSNumber,String(cString: version.objCType) != "c",version.intValue==1,
              let state=try? JSONDecoder().decode(BookmarkState.self,from: bytes),state.bookmarks.count<=10000,state.bookmarks.allSatisfy(\.isValid),Set(state.bookmarks.map(\.id)).count==state.bookmarks.count else { throw LibraryError.unreadableStore }
        func sameKeys(_ a: Any,_ b: Any) -> Bool {
            if let a=a as? [String:Any],let b=b as? [String:Any] { return Set(a.keys)==Set(b.keys) && a.allSatisfy { k,v in b[k].map { sameKeys(v,$0) } == true } }
            if let a=a as? [Any],let b=b as? [Any] { return a.count==b.count && zip(a,b).allSatisfy { sameKeys($0,$1) } }
            return !(a is [String:Any]) && !(b is [String:Any]) && !(a is [Any]) && !(b is [Any])
        }
        guard sameKeys(object,try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))) else { throw LibraryError.unreadableStore }
        return state
    }
    public func add(_ candidate: ReadingBookmark) throws -> ReadingBookmark {
        let operation=try LocalStoreWriteGate.shared(root: root).beginWrite();defer { operation.finish() }
        let lock=BookmarkTransactions.shared.lock(root);lock.lock();defer { lock.unlock() }
        guard candidate.isValid else { throw LibraryError.sourceMismatch }
        var state=try load()
        if let existing=state.bookmarks.first(where: { $0.bookID==candidate.bookID && $0.location.isSamePosition(as: candidate.location) }) { return existing }
        guard !state.bookmarks.contains(where: { $0.id==candidate.id }) else { throw NoteBodyEditError.conflict }
        state.bookmarks.append(candidate);try commit(state);return candidate
    }
    public func rename(_ expected: ReadingBookmark,title: String) throws -> ReadingBookmark {
        let operation=try LocalStoreWriteGate.shared(root: root).beginWrite();defer { operation.finish() }
        let lock=BookmarkTransactions.shared.lock(root);lock.lock();defer { lock.unlock() }
        var state=try load();guard let index=state.bookmarks.firstIndex(where: { $0.id==expected.id }),state.bookmarks[index]==expected else { throw NoteBodyEditError.conflict }
        var next=expected;next.title=title;next.revision+=1;next.updatedAt=Date();guard next.isValid else { throw NoteBodyEditError.tooLong }
        state.bookmarks[index]=next;try commit(state);return next
    }
    public func delete(_ expected: ReadingBookmark) throws {
        let operation=try LocalStoreWriteGate.shared(root: root).beginWrite();defer { operation.finish() }
        let lock=BookmarkTransactions.shared.lock(root);lock.lock();defer { lock.unlock() }
        var state=try load();guard let index=state.bookmarks.firstIndex(where: { $0.id==expected.id }),state.bookmarks[index]==expected else { throw NoteBodyEditError.conflict }
        state.bookmarks.remove(at: index);try commit(state)
    }
    private func commit(_ state: BookmarkState) throws {
        let file=root.appendingPathComponent(Self.filename);_=try load()
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];let bytes=try encoder.encode(state);_=try Self.decode(bytes)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: file.path) { try BoundedFileReader.read(file,limit: 5*1024*1024).write(to: file.appendingPathExtension("backup"),options: .atomic) }
        try bytes.write(to: file,options: .atomic)
    }
}
private final class BookmarkTransactions: @unchecked Sendable {
    static let shared=BookmarkTransactions()
    private let registry=NSLock()
    private var locks: [URL:NSRecursiveLock]=[:]
    func lock(_ root: URL) -> NSRecursiveLock {
        registry.lock();defer { registry.unlock() };let key=root.standardizedFileURL.resolvingSymlinksInPath()
        if let value=locks[key] { return value };let value=NSRecursiveLock();locks[key]=value;return value
    }
}
