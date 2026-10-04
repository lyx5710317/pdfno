// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG && os(macOS)
import Foundation

/// Isolated CI fixture: let the launched app create a real backup write failure
/// inside its own store. The runner never mutates an app-owned sandbox file.
@MainActor
final class NoteEditingFilesystemUITestFixture {
    private let backup: URL
    private var attempt = 0
    init?(root: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard environment["PDFNO_UI_TEST_NOTE_FAILURE"] == "backup-directory",
              let token = environment["PDFNO_UI_TEST_SESSION"], let uuid = UUID(uuidString: token) else { return nil }
        let expected = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + uuid.uuidString)
        guard root.standardizedFileURL.resolvingSymlinksInPath().path == expected.standardizedFileURL.resolvingSymlinksInPath().path,
              let values = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true else { return nil }
        backup = root.appendingPathComponent("library-v1.json.backup")
    }
    func prepareAttempt() throws {
        let manager = FileManager.default
        var backup = self.backup
        backup.removeAllCachedResourceValues()
        if attempt == 0 {
            let values = try backup.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileWriteUnknown) }
            try manager.removeItem(at: backup)
            try manager.createDirectory(at: backup, withIntermediateDirectories: false)
            attempt = 1
        } else if attempt == 1 {
            let values = try backup.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  try manager.contentsOfDirectory(atPath: backup.path).isEmpty else { throw CocoaError(.fileWriteUnknown) }
            try manager.removeItem(at: backup)
            attempt = 2
        }
    }
}
#endif
