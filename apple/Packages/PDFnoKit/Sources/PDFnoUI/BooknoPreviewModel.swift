// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

@MainActor final class BooknoPreviewModel: ObservableObject {
    @Published var enabled = false {
        didSet {
            guard enabled != oldValue else { return }
            if enabled { ledger.mode = .preview; invalidate() }
            else {
                ledger = BooknoOfflinePreview(); receiver = BooknoMockReceiver(receiverID: ledger.receiverID)
                tracker = BooknoConfirmationTracker(receiverID: ledger.receiverID, epoch: ledger.epoch)
                selectedIDs = []; includeSavedNotes = false; includeCovers = false
                mockRecordCount = 0; mockAssetCount = 0; confirmedCursor = 0; invalidate()
            }
        }
    }
    @Published var selectedIDs = Set<String>() { didSet { if selectedIDs != oldValue { invalidate() } } }
    @Published var includeSavedNotes = false { didSet { if includeSavedNotes != oldValue { invalidate() } } }
    @Published var includeCovers = false { didSet { if includeCovers != oldValue { invalidate() } } }
    @Published private(set) var choices: [BooknoPreviewChoice] = []
    @Published private(set) var unsupportedBooks: [BooknoUnsupportedBook] = []
    @Published private(set) var busy = false
    @Published private(set) var batch: BooknoPreviewBatch?
    @Published private(set) var json = ""
    @Published private(set) var notices: [String] = []
    @Published private(set) var receipt: BooknoMockReceipt?
    @Published private(set) var status = "默认关闭 · Bookno 未连接"
    @Published private(set) var error: String?
    @Published private(set) var mockRecordCount = 0
    @Published private(set) var mockAssetCount = 0
    @Published private(set) var confirmedCursor = 0
    private let catalog: @Sendable () async throws -> BooknoPreviewCatalog
    private let materialize: @Sendable ([BooknoPreviewChoice], Bool, Bool) async throws -> BooknoPreviewMaterial
    private var ledger = BooknoOfflinePreview()
    private var receiver: BooknoMockReceiver
    private var tracker: BooknoConfirmationTracker
    private var assetBytes: [String: Data] = [:]
    private var generation = UUID()
    convenience init(repository: BooknoLibraryPreviewRepository) {
        self.init(snapshot: { try await repository.catalogSnapshot() }, materialize: { selected, notes, covers in
            try await repository.materialize(selected, includeSavedNotes: notes, includeCovers: covers)
        })
    }
    convenience init(catalog: @escaping @Sendable () async throws -> [BooknoPreviewChoice],
         materialize: @escaping @Sendable ([BooknoPreviewChoice], Bool, Bool) async throws -> BooknoPreviewMaterial) {
        self.init(snapshot: { BooknoPreviewCatalog(choices: try await catalog()) }, materialize: materialize)
    }
    init(snapshot: @escaping @Sendable () async throws -> BooknoPreviewCatalog,
         materialize: @escaping @Sendable ([BooknoPreviewChoice], Bool, Bool) async throws -> BooknoPreviewMaterial) {
        self.catalog = snapshot; self.materialize = materialize
        receiver = BooknoMockReceiver(receiverID: ledger.receiverID)
        tracker = BooknoConfirmationTracker(receiverID: ledger.receiverID, epoch: ledger.epoch)
    }
    private func invalidate() {
        generation = UUID(); batch = nil; json = ""; receipt = nil; assetBytes = [:]; notices = []; error = nil
        status = enabled ? "范围已改变，请生成本机预览 · Bookno 未连接" : "默认关闭 · Bookno 未连接"
    }
    func refresh() async {
        guard !busy else { return }; invalidate(); let token = generation; busy = true; defer { busy = false }
        do {
            let fresh = try await catalog()
            guard token == generation, !Task.isCancelled else { return }
            choices = fresh.choices; unsupportedBooks = fresh.unsupported
            selectedIDs.formIntersection(Set(fresh.choices.map(\.id)))
        } catch {
            if token == generation { choices = []; unsupportedBooks = []; selectedIDs = []; self.error = Self.message(error) }
        }
    }
    func prepare() async {
        guard enabled, !busy else { return }
        let selected = choices.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty, Set(selected.map(\.id)) == selectedIDs else { error = "请明确选择本次预览的书籍。"; return }
        invalidate(); let token = generation, notes = includeSavedNotes, covers = includeCovers
        busy = true; defer { busy = false }
        do {
            let material = try await materialize(selected, notes, covers)
            guard token == generation, enabled, !Task.isCancelled else { return }
            let books = material.payloads.compactMap { if case .book(let b) = $0 { return b.externalID }; return nil }
            guard Set(books) == selectedIDs, books.count == selectedIDs.count,
                  material.payloads.allSatisfy({ if case .note(let n) = $0 { return selectedIDs.contains(n.externalBookID) }; return true }),
                  notes || material.payloads.allSatisfy({ $0.kind == .book }),
                  covers || (material.assets.isEmpty && material.payloads.allSatisfy({
                      if case .book(let b) = $0 { return b.coverAssetID == nil && b.coverOrigin == nil && b.coverSourceRevision == nil }; return true
                  })),
                  Set(material.assetBytes.keys) == Set(material.assets.map(\.assetID)),
                  material.assetBytes.values.reduce(0, { $0 + $1.count }) <= BooknoLibraryPreviewRepository.maximumCoverBytes else {
                throw BooknoPreviewError.invalidContract
            }
            for asset in material.assets {
                guard let bytes = material.assetBytes[asset.assetID] else { throw BooknoPreviewError.assetMissing }
                try BooknoExchangeCodec.validateAsset(bytes, declaration: asset)
            }
            var nextLedger = ledger, nextTracker = tracker
            let prepared = try nextLedger.stage(material.payloads, assets: material.assets)
            let bytes = try BooknoExchangeCodec.encode(prepared); _ = try BooknoExchangeCodec.decode(bytes)
            try nextTracker.register(prepared)
            ledger = nextLedger; tracker = nextTracker; batch = prepared
            json = String(decoding: bytes, as: UTF8.self); assetBytes = material.assetBytes; notices = material.notices
            status = "本机预览已生成 · 准备时的已保存快照 · 尚未运行 mock · Bookno 未连接"
        } catch { if token == generation { self.error = Self.message(error); status = "预览未生成 · 原记录保留 · Bookno 未连接" } }
    }
    func runMock(loseReceipt: Bool = false) {
        guard enabled, !busy, let batch else { return }
        var nextReceiver = receiver, nextTracker = tracker
        do {
            let result = try nextReceiver.receive(batch, assetBytes: assetBytes, loseReceiptAfterCommit: loseReceipt)
            try nextTracker.acknowledge(result)
            receiver = nextReceiver; tracker = nextTracker; receipt = result; error = nil
            mockRecordCount = receiver.recordCount; mockAssetCount = receiver.assetCount; confirmedCursor = tracker.confirmedSequence
            status = "内存 mock 已核验回执 · Bookno 未连接 · 不是实际同步"
        } catch BooknoPreviewError.mockResultUnknown {
            receiver = nextReceiver; receipt = nil; error = nil
            mockRecordCount = receiver.recordCount; mockAssetCount = receiver.assetCount
            status = "已模拟提交后丢回执 · 尚未确认 · 请重放同一批次 · Bookno 未连接"
        } catch { self.error = Self.message(error); status = "mock 未确认 · Bookno 未连接" }
    }
    func close() { enabled = false; selectedIDs = []; includeSavedNotes = false; includeCovers = false; invalidate(); choices = []; unsupportedBooks = [] }
    private static func message(_ error: Error) -> String {
        switch error {
        case BooknoPreviewError.unsupportedFormat(let format): "Bookno 预览尚未适配 \(format)；本次不生成此格式内容，原记录保留。"
        case BooknoPreviewError.selectionLimit: "请缩小选择：最多20本书、1000个对象、封面合计20MiB；不截断内容。"
        case BooknoPreviewError.sourceMismatch: "书籍、版本或来源已变化，无法验证。请刷新书目后重新生成预览。"
        case BooknoPreviewError.assetMissing, BooknoPreviewError.assetInvalid: "已保存封面缺失或无法验证。请关闭封面范围或先在本地修复封面。"
        case BooknoPreviewError.receiptMismatch: "模拟回执无法验证，未推进确认。"
        default: "本地内容、版本或批次无法验证。预览未确认，原记录保留。"
        }
    }
}
#endif
