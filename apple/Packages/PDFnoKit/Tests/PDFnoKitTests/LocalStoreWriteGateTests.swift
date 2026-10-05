// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoServices

struct LocalStoreWriteGateTests {
    private func gate() -> LocalStoreWriteGate {
        .shared(root: FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Gate-" + UUID().uuidString))
    }
    @Test func allInstancesAndRootAliasesShareAdmission() throws {
        let first = gate(), second = LocalStoreWriteGate.shared(root: first.root.appendingPathComponent(".").standardizedFileURL)
        #expect(first === second)
        let pause = try first.beginPause(); defer { pause.finish() }
        #expect(throws: LocalStoreWriteGateError.paused) { try second.beginWrite() }
        #expect(throws: LocalStoreWriteGateError.paused) { try second.beginPause() }
        let independent = try gate().beginWrite(); independent.finish()
    }
    @Test func pauseFencesNewWritesAndDrainsEveryAdmittedWriter() async throws {
        let gate = gate(), first = try gate.beginWrite(), second = try gate.beginWrite()
        let pause = try gate.beginPause(); defer { pause.finish() }
        #expect(gate.snapshot.phase == .draining && gate.snapshot.activeWrites == 2)
        #expect(throws: LocalStoreWriteGateError.invalidPause) { try pause.assertReady() }
        #expect(throws: LocalStoreWriteGateError.paused) { try gate.beginWrite() }
        let drained = Task { try await pause.drain() }
        first.finish(); first.finish()
        #expect(gate.snapshot.activeWrites == 1 && gate.snapshot.phase == .draining)
        #expect(throws: LocalStoreWriteGateError.invalidPause) { try pause.assertReady() }
        second.finish(); try await drained.value; try pause.assertReady()
        #expect(gate.snapshot.activeWrites == 0 && gate.snapshot.phase == .paused)
    }
    @Test func prePauseEpochCannotAdmitLateWorkAfterReload() async throws {
        let gate = gate(), old = gate.snapshot.epoch
        let pause = try gate.beginPause(); try await pause.drain(); pause.finish()
        #expect(gate.snapshot.phase == .writable && gate.snapshot.epoch != old)
        #expect(throws: LocalStoreWriteGateError.staleEpoch) { try gate.beginWrite(expectedEpoch: old) }
        let current = try gate.beginWrite(expectedEpoch: gate.snapshot.epoch); current.finish()
        #expect(throws: LocalStoreWriteGateError.invalidPause) { try pause.assertReady() }
    }
    @Test func failedRecoveryRetainsFenceUntilExplicitRecoveryAndReload() async throws {
        let gate = gate(), failed = try gate.beginPause(); try await failed.drain()
        failed.retainFenceUntilRecovery(); failed.finish()
        #expect(gate.snapshot.phase == .recoveryRequired)
        #expect(throws: LocalStoreWriteGateError.paused) { try gate.beginWrite() }
        #expect(throws: LocalStoreWriteGateError.paused) { try gate.beginPause() }
        let recovery = try gate.beginPause(allowRetainedFence: true); try await recovery.drain()
        failed.finish() // An obsolete scope cannot release the newer recovery fence.
        #expect(gate.snapshot.phase == .paused)
        recovery.finish(); let write = try gate.beginWrite(); write.finish()
    }
    @Test func cancelledDrainCannotAuthorizeMutationAndScopeReleaseIsExplicit() async throws {
        let gate = gate(), lease = try gate.beginWrite(), pause = try gate.beginPause()
        let task = Task { try await pause.drain() }; task.cancel(); lease.finish()
        do { try await task.value; Issue.record("Cancelled drain unexpectedly completed") }
        catch { #expect(error is CancellationError) }
        #expect(gate.snapshot.phase == .paused)
        pause.finish(); #expect(gate.snapshot.phase == .writable)
    }
    @Test func abandonedLeasesAndPauseReleaseWithoutCounterUnderflow() async throws {
        let gate = gate()
        var lease: LocalStoreWriteGate.WriteLease? = try gate.beginWrite()
        #expect(gate.snapshot.activeWrites == 1)
        withExtendedLifetime(lease) {}; lease = nil
        #expect(gate.snapshot.activeWrites == 0)
        var pause: LocalStoreWriteGate.Pause? = try gate.beginPause()
        try await pause?.drain(); withExtendedLifetime(pause) {}; pause = nil
        #expect(gate.snapshot.phase == .writable)
    }
    @Test func recoveryFenceAndEpochSurviveAllCallerRecreation() async throws {
        var first: LocalStoreWriteGate? = gate()
        let root = try #require(first).root
        var pause: LocalStoreWriteGate.Pause? = try first?.beginPause()
        try await pause?.drain()
        let blockedEpoch = try #require(first).snapshot.epoch
        pause?.retainFenceUntilRecovery(); pause?.finish()
        first = nil; pause = nil
        let recreated = LocalStoreWriteGate.shared(root: root)
        #expect(recreated.snapshot.epoch == blockedEpoch && recreated.snapshot.phase == .recoveryRequired)
        #expect(throws: LocalStoreWriteGateError.paused) { try recreated.beginWrite() }
        let recovery = try recreated.beginPause(allowRetainedFence: true)
        try await recovery.drain(); recovery.finish()
        #expect(throws: LocalStoreWriteGateError.staleEpoch) { try recreated.beginWrite(expectedEpoch: blockedEpoch) }
    }
}
