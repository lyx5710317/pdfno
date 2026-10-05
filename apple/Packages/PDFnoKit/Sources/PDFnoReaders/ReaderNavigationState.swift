// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Transient return locations, owned by one open reader session. Never persisted as anchors.
struct ReaderNavigationHistory<Location: Equatable> {
    private(set) var locations: [Location] = []
    var previous: Location? { locations.last }
    mutating func record(_ origin: Location, destination: Location) {
        guard origin != destination, locations.last != origin else { return }
        locations.append(origin)
        if locations.count > 32 { locations.removeFirst(locations.count - 32) }
    }
    mutating func returned(to location: Location) {
        if locations.last == location { locations.removeLast() }
    }
    mutating func clear() { locations.removeAll() }
}

/// A queued layout operation must still belong to the same book-open and layout version.
struct ReaderLayoutTicket: Equatable, Sendable {
    let readerSessionID: UUID
    let documentVersion: Int
    func matches(sessionID: UUID, documentVersion: Int) -> Bool {
        readerSessionID == sessionID && self.documentVersion == documentVersion
    }
}
