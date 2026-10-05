# Same-root writer admission foundation

Integration base: accepted `7bea8ec` plus UI refinement. This foundation adds a
process-lifetime `LocalStoreWriteGate` registry keyed by canonical managed root.
Admission is synchronous, so it can cover synchronous edit-draft checkpoints as
well as queued actor writes. Leases are idempotently released, including deinit.
Pause fences new admissions before waiting for admitted work to finish. Its epoch
changes before drain, allowing callers to refuse late work captured before reload.
Failed recovery/reload can retain the fence across model/repository recreation;
only an explicit recovery path can acquire another pause and reopen the root.

The host holds its pause until transaction recovery/operation and validated reload
finish. Cancellation cannot authorize an undrained operation. This is same-process
coordination, not a filesystem transaction, cross-process lock or durability claim.

Validation copies the exact service and test sources into a minimal SwiftPM target
with the same macOS14/iOS17 declarations, separate scratch/cache directories and
the batch's heavy-check lock. Final **7 methods / 1 suite passed**, including two
same-root owners, two admitted writers, refused late epoch, cancellation, explicit
retained-fence recovery and recreation after all original callers are released.
Raw log: `.build/IntegrationGateEvidence/swift-final.log`; no app/UI was launched.
This lightweight run does not replace the full package or Mobile build.

Repository enrollment, recovery host lifecycle, source commit validation and
actual integration/UI acceptance are subsequent work. Until enrollment is done,
this class alone does not make the existing writers safe for recovery operations.
Existing 50 UI methods and signing/cloud/account metadata remain unchanged.
Independent security remains UNVERIFIED / platform-blocked.
