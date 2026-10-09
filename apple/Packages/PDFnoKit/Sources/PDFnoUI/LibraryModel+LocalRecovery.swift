// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

@MainActor enum LibraryMaintenanceOwners {
    private final class WeakOwner { weak var value: LibraryModel?; init(_ value: LibraryModel) { self.value = value } }
    private static var owners: [URL: [WeakOwner]] = [:]
    private static var visibleDrafts: [URL: Set<String>] = [:]
    static func register(_ library: LibraryModel, root: URL) {
        let key = LocalStoreWriteGate.shared(root: root).root
        owners[key, default: []].removeAll { $0.value == nil }
        owners[key, default: []].append(WeakOwner(library))
    }
    static func all(root: URL) -> [LibraryModel] { owners[LocalStoreWriteGate.shared(root: root).root, default: []].compactMap(\.value) }
    static func setDraft(root: URL, owner: String, dirty: Bool) {
        let root = LocalStoreWriteGate.shared(root: root).root
        if dirty { visibleDrafts[root, default: []].insert(owner) }
        else { visibleDrafts[root, default: []].remove(owner) }
    }
    static func hasDraft(root: URL) -> Bool { !visibleDrafts[LocalStoreWriteGate.shared(root: root).root, default: []].isEmpty }
}
enum LibraryMaintenanceFailure: LocalizedError {
    case drafts, reload
    var errorDescription: String? {
        switch self {
        case .drafts: "请先保存或明确取消未保存的笔记，再管理书库。草稿已保留。"
        case .reload: "书库恢复或重载未完成，写入保持暂停；现有文件已保留。"
        }
    }
}
extension LibraryModel {
    func recoveryService() throws -> LocalRecoveryService {
        try LocalRecoveryService(root: recordRoot, additionalAdapters: [.englishLearning()])
    }
    func prepareRecoveryManagement() {
        do {
            let service = try recoveryService()
            recoveryManagement = LocalRecoveryManagementModel(service: service, withPausedWriters: { [weak self] operation in
                guard let self else { throw LocalRecoveryError.writerNotPaused }
                try await withPausedStoreWriters(operation)
            })
        } catch { self.error = error.localizedDescription }
    }
    func recoverStorageOnStartup() async -> Bool {
        if startupRecoveryCompleted, storeWriteGate.snapshot.phase == .writable { return true }
        // A second window uses the already recovered process-owned root. It
        // must not close the first window's reader merely to load its sidebar.
        if storeWriteGate.snapshot.phase == .writable,
           let readyOwner = LibraryMaintenanceOwners.all(root: recordRoot).first(where: { $0 !== self && $0.startupRecoveryCompleted }) {
            needsRecoveryDraftReview = readyOwner.needsRecoveryDraftReview
            if needsRecoveryDraftReview { noteEditing.requireReviewAfterMaintenance(); recordEditing.editor.requireReviewAfterMaintenance() }
            startupRecoveryCompleted = true; return true
        }
        if let active = LibraryMaintenanceOwners.all(root: recordRoot).compactMap({ $0.startupRecoveryTask }).first {
            return await active.value
        }
        if storeWriteGate.snapshot.phase == .draining || storeWriteGate.snapshot.phase == .paused {
            storageMaintenance = true; isBusy = true; canImport = false
            do {
                while storeWriteGate.snapshot.phase == .draining || storeWriteGate.snapshot.phase == .paused {
                    try await Task.sleep(for: .milliseconds(20))
                }
            } catch { self.error = error.localizedDescription; return false }
            storageMaintenance = false; isBusy = false
            return await recoverStorageOnStartup()
        }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            let owners = LibraryMaintenanceOwners.all(root: recordRoot)
            let pause: LocalStoreWriteGate.Pause
            do { pause = try storeWriteGate.beginPause(allowRetainedFence: true) }
            catch { self.error = error.localizedDescription; canImport = false; return false }
            defer { pause.finish(); if startupRecoveryCompleted { for library in owners { library.covers.resumeAfterMaintenance() } } }
            for library in owners { library.beginStorageMaintenance() }
            do {
                try await pause.drain(); try pause.assertReady()
                for library in owners { library.closeStorageReaders() }
                var recovered = false
                if FileManager.default.fileExists(atPath: recordRoot.path) {
                    let receipts = try await recoveryService().recoverPendingTransactions(permit: .init(pausedRoot: recordRoot, writerEpoch: pause.epoch))
                    recovered = !receipts.isEmpty || FileManager.default.fileExists(atPath: recordRoot.appendingPathComponent("local-recovery-v1.json").path)
                }
                for library in owners { library.needsRecoveryDraftReview = recovered }
                try await reloadAfterStorageMaintenance(owners, validateRecoverySnapshot: false, reviewDrafts: recovered)
                for library in owners { library.startupRecoveryCompleted = true; library.storageMaintenance = false; library.isBusy = false }
                return true
            } catch {
                pause.retainFenceUntilRecovery()
                for library in owners { library.canImport = false; library.error = error.localizedDescription }
                return false
            }
        }
        startupRecoveryTask = task
        let result = await task.value; startupRecoveryTask = nil
        return result
    }
    /// The pause remains active through recovery, mutation and validated reload.
    /// Dirty editor/visible reader drafts prevent an operation before any change.
    func withPausedStoreWriters(_ operation: @escaping LocalRecoveryPausedOperation) async throws {
        let owners = LibraryMaintenanceOwners.all(root: recordRoot)
        guard !LibraryMaintenanceOwners.hasDraft(root: recordRoot), owners.allSatisfy({ !$0.hasPendingEditorChanges }) else { throw LibraryMaintenanceFailure.drafts }
        let pause = try storeWriteGate.beginPause()
        var validated = false
        defer {
            if validated { for library in owners { library.storageMaintenance = false; library.isBusy = false } }
            pause.finish()
            if validated { for library in owners { library.covers.resumeAfterMaintenance() } }
        }
        for library in owners { library.beginStorageMaintenance() }
        let permit = LocalRecoveryWritePermit(pausedRoot: recordRoot, writerEpoch: pause.epoch), service = try recoveryService()
        do {
            try await pause.drain(); try pause.assertReady()
            guard !LibraryMaintenanceOwners.hasDraft(root: recordRoot), owners.allSatisfy({ !$0.hasPendingEditorChanges }) else { throw LibraryMaintenanceFailure.drafts }
            for library in owners { library.closeStorageReaders() }
            if !FileManager.default.fileExists(atPath: recordRoot.path) {
                try FileManager.default.createDirectory(at: recordRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            }
            _ = try await service.recoverPendingTransactions(permit: permit)
            try await operation(permit)
            _ = try await service.recoverPendingTransactions(permit: permit)
            try await reloadAfterStorageMaintenance(owners)
            validated = true
        } catch {
            // Bounded recovery must finish even if the original UI task was
            // cancelled. Keep the fence when validation cannot prove safety.
            let original = error
            do {
                try await Task { @MainActor in
                    try await pause.drain(); try pause.assertReady()
                    for library in owners { library.closeStorageReaders() }
                    _ = try await service.recoverPendingTransactions(permit: permit)
                    try await reloadAfterStorageMaintenance(owners)
                }.value
                validated = true
            } catch {
                pause.retainFenceUntilRecovery()
                for library in owners { library.canImport = false; library.startupRecoveryCompleted = false; library.error = LibraryMaintenanceFailure.reload.localizedDescription }
                throw LibraryMaintenanceFailure.reload
            }
            throw original
        }
    }
    var hasPendingEditorChanges: Bool {
        noteEditing.journalError != nil || recordEditing.editor.journalError != nil ||
        noteEditing.drafts.values.contains { !$0.text.utf8.elementsEqual($0.baseline.userText.utf8) } ||
        recordEditing.editor.drafts.values.contains { !$0.text.utf8.elementsEqual($0.baseline.userText.utf8) }
    }
    private func beginStorageMaintenance() {
        storageMaintenance = true; canImport = false; isBusy = true; progressSequence += 1
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        invalidateJapaneseLearning(); invalidateEnglishLearning(); invalidateBYOKSelection()
        booknoPreview.close(); activeSavedSearch?.cancel(); noteEditing.invalidatePendingSavesForMaintenance(); recordEditing.editor.invalidatePendingSavesForMaintenance()
    }
    private func closeStorageReaders() {
        reader.close(); epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate()
        readingEPUB = false; readingComic = false
    }
    private func reloadAfterStorageMaintenance(_ owners: [LibraryModel], validateRecoverySnapshot: Bool = true, reviewDrafts: Bool = true) async throws {
        // Validate all active stores before any observer is allowed to write.
        if validateRecoverySnapshot, FileManager.default.fileExists(atPath: recordRoot.path) { _ = try await recoveryService().books() }
        for library in owners {
            await library.covers.invalidateAfterMaintenance()
            await library.reloadStoredLibrary()
            guard library.canImport, library.englishStoreError == nil, library.japaneseStoreError == nil else { throw LibraryMaintenanceFailure.reload }
            if reviewDrafts {
                library.needsRecoveryDraftReview = true
                library.noteEditing.requireReviewAfterMaintenance(); library.recordEditing.editor.requireReviewAfterMaintenance()
            }
        }
    }
    func recordVisibleDraft(owner: String, dirty: Bool) {
        if dirty { documentVisibleDrafts.insert(owner) } else { documentVisibleDrafts.remove(owner) }
        LibraryMaintenanceOwners.setDraft(root: recordRoot, owner: owner, dirty: dirty)
    }
}
#endif
