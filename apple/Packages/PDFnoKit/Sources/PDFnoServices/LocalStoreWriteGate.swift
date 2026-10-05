// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum LocalStoreWriteGateError: LocalizedError, Sendable, Equatable {
    case paused, staleEpoch, invalidPause
    public var errorDescription: String? {
        switch self {
        case .paused: "书库正在维护或等待恢复，请稍后再保存。"
        case .staleEpoch, .invalidPause: "书库状态已变化，请重新确认后操作。"
        }
    }
}

/// Same-process admission only. Every actual store writer must acquire a lease;
/// disabling controls or cancelling a task does not enroll a repository writer.
/// This gate does not provide cross-process isolation or disk durability.
public final class LocalStoreWriteGate: @unchecked Sendable {
    public enum Phase: Sendable { case writable, draining, paused, recoveryRequired }
    public struct Snapshot: Sendable {
        public let epoch: UUID
        public let activeWrites: Int
        public let phase: Phase
    }
    private final class Registry: @unchecked Sendable {
        let lock = NSLock()
        // Process-lifetime ownership preserves epoch and recovery fences across
        // model/repository recreation. Startup still must recover disk journals.
        var gates: [String: LocalStoreWriteGate] = [:]
        func shared(_ root: URL) -> LocalStoreWriteGate {
            let root = root.standardizedFileURL.resolvingSymlinksInPath()
            lock.lock(); defer { lock.unlock() }
            if let gate = gates[root.path] { return gate }
            let gate = LocalStoreWriteGate(root: root); gates[root.path] = gate; return gate
        }
    }
    private static let registry = Registry()
    public static func shared(root: URL) -> LocalStoreWriteGate { registry.shared(root) }
    public let root: URL
    private let lock = NSLock()
    private var epoch = UUID()
    private var writes: Set<UUID> = []
    private var pauseID: UUID?
    private var retainFence = false
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private init(root: URL) { self.root = root }

    public var snapshot: Snapshot {
        lock.lock(); defer { lock.unlock() }
        let phase: Phase = pauseID != nil ? (writes.isEmpty ? .paused : .draining) : (retainFence ? .recoveryRequired : .writable)
        return Snapshot(epoch: epoch, activeWrites: writes.count, phase: phase)
    }
    /// The caller holds this through the complete mutation, including queued
    /// actor work. An expected epoch fences work captured before a root reload.
    public func beginWrite(expectedEpoch: UUID? = nil) throws -> WriteLease {
        lock.lock(); defer { lock.unlock() }
        guard pauseID == nil, !retainFence else { throw LocalStoreWriteGateError.paused }
        guard expectedEpoch == nil || expectedEpoch == epoch else { throw LocalStoreWriteGateError.staleEpoch }
        let id = UUID(); writes.insert(id); return WriteLease(owner: self, id: id)
    }
    /// Fences new admissions synchronously, before the host cancels/drains tasks.
    /// Recovery of a retained fence must be an explicit startup/recovery path.
    public func beginPause(allowRetainedFence: Bool = false) throws -> Pause {
        lock.lock(); defer { lock.unlock() }
        guard pauseID == nil, !retainFence || allowRetainedFence else { throw LocalStoreWriteGateError.paused }
        let id = UUID(); pauseID = id; epoch = UUID(); retainFence = false
        return Pause(owner: self, id: id, epoch: epoch)
    }
    private func finishWrite(_ id: UUID) {
        lock.lock()
        guard writes.remove(id) != nil else { lock.unlock(); return }
        let ready = writes.isEmpty ? Array(waiters.values) : []
        if writes.isEmpty { waiters.removeAll() }
        lock.unlock()
        for continuation in ready { continuation.resume() }
    }
    private func waitForDrain(_ id: UUID, continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if pauseID != id { lock.unlock(); continuation.resume(throwing: LocalStoreWriteGateError.invalidPause) }
        else if writes.isEmpty { lock.unlock(); continuation.resume() }
        else { waiters[UUID()] = continuation; lock.unlock() }
    }
    private func assertReady(_ id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        guard pauseID == id, writes.isEmpty else { throw LocalStoreWriteGateError.invalidPause }
    }
    private func keepFenced(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        if pauseID == id { retainFence = true }
    }
    private func finishPause(_ id: UUID) {
        lock.lock()
        guard pauseID == id else { lock.unlock(); return }
        pauseID = nil
        let cancelled = Array(waiters.values); waiters.removeAll()
        lock.unlock()
        for continuation in cancelled { continuation.resume(throwing: LocalStoreWriteGateError.invalidPause) }
    }
    public final class WriteLease: @unchecked Sendable {
        private let owner: LocalStoreWriteGate
        private let id: UUID
        fileprivate init(owner: LocalStoreWriteGate, id: UUID) { self.owner = owner; self.id = id }
        public func finish() { owner.finishWrite(id) }
        deinit { finish() }
    }
    public final class Pause: @unchecked Sendable {
        private let owner: LocalStoreWriteGate
        private let id: UUID
        public let epoch: UUID
        public var root: URL { owner.root }
        fileprivate init(owner: LocalStoreWriteGate, id: UUID, epoch: UUID) { self.owner = owner; self.id = id; self.epoch = epoch }
        /// Cancellation never reports a drain while a writer still holds a lease.
        /// The host must finish this scope in defer; if recovery/reload is unsafe,
        /// retainFenceUntilRecovery() leaves future admissions blocked instead.
        public func drain() async throws {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { owner.waitForDrain(id, continuation: $0) }
            try Task.checkCancellation()
            try assertReady()
        }
        public func assertReady() throws { try owner.assertReady(id) }
        public func retainFenceUntilRecovery() { owner.keepFenced(id) }
        public func finish() { owner.finishPause(id) }
        deinit { finish() }
    }
}
