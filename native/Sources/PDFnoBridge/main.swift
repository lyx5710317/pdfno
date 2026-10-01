// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

struct Capabilities: Encodable {
    let schemaVersion = 1
    let bridgeVersion = "0.1.0"
    let platform = "macOS"
    let keychain = "not-integrated"
    let iCloud = "disabled"
}

// Narrow protocol: capability query only; no keys, files, shell or cloud operations.
guard CommandLine.arguments.count == 2, CommandLine.arguments[1] == "capabilities" else {
    FileHandle.standardError.write(Data("Usage: PDFnoBridge capabilities\n".utf8))
    exit(64)
}
do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(Capabilities())
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Capability encoding failed\n".utf8))
    exit(70)
}
