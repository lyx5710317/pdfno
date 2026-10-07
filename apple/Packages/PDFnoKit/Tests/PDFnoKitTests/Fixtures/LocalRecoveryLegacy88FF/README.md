# Self-authored legacy recovery packages

These two directory packages were exported by the actual frozen service at
`88ff6d6ce3471b9191b521dca6261fc8dde775e3`. They are synthetic storage fixtures,
not personal libraries, not downloaded books, and not native rendering fixtures.
The Original assets deliberately contain small authored storage bytes; the tests
do not claim PDF/EPUB/Kindle/comic decoding or rendering coverage for these bytes.

`standard` uses the old complete 13-adapter profile. `with-english` uses the same
profile plus the audited English adapter; it has no saved English note payload.
Each contains 17 authored format records before one FB2 book is moved to trash,
leaving 16 active books, exact notes/progress, AI/Japanese mock saved records,
metadata, one old tombstone and original/retained assets. Neither contains the new
bundled-examples sidecar or any automatically inferred provenance.

Generation used a git archive of that commit's complete PDFnoKit package. Its
411 other tracked package files were verified against their Git blob hashes.
Only `LocalRecoveryTests.swift` was appended with this exporter, using the frozen
file's existing private `RecoveryFixture`, `recoveryFormats`, and `learning` helper:

```swift
struct LegacyRecoveryFixtureExporter {
    @Test func exportActual88FFPackages() async throws {
        let output = URL(fileURLWithPath: try #require(
            ProcessInfo.processInfo.environment["PDFNO_LEGACY_FIXTURE_OUTPUT"]))
        for english in [false, true] {
            let f = try RecoveryFixture(); defer { f.cleanup() }
            var books: [LocalRecoveryBook] = []
            for format in recoveryFormats { books.append(try f.add(format)) }
            try f.learning(books[0])
            let additional: [LocalRecoveryAdditionalAdapter] = english ? [try .englishLearning()] : []
            let service = try LocalRecoveryService(root: f.root, additionalAdapters: additional)
            _ = try await service.moveToTrash(service.previewMoveToTrash(.book(books.last!)), permit: f.permit)
            _ = try await service.exportBackup(to: output.appendingPathComponent(
                english ? "with-english" : "standard"), permit: f.permit)
        }
    }
}
```

Run `swift test --package-path <frozen package> --jobs 1 --filter
LegacyRecoveryFixtureExporter` inside the project's existing heavy-check lock,
with the explicit fixture-output variable pointing to a fresh directory. No GUI
or real Library is involved. Random UUIDs/dates are intentionally frozen in these
committed outputs; regeneration changes their bytes. `PROVENANCE.json` records
the exact source and all 64 package-file SHA256 values. The current-version tests
copy the packages into new temporary roots and preserve the committed originals.
