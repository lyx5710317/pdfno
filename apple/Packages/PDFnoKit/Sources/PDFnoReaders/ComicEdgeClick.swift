// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain

/// A click remains a normal canvas event. Only a short, stationary, unmodified
/// single click can request a turn, after the double-click interval has elapsed.
struct ComicEdgeClick {
    enum Edge { case left, right }
    enum Turn { case previous, next }
    private var down: (point: CGPoint, time: TimeInterval, edge: Edge)?
    mutating func cancel() { down = nil }
    mutating func begin(point: CGPoint, size: CGSize, time: TimeInterval, single: Bool, unmodified: Bool) {
        down = nil
        guard single, unmodified, size.width >= 100, size.height >= 100,
              point.x >= 0, point.x <= size.width, point.y >= 16, point.y <= size.height - 16 else { return }
        let strip = min(72, max(36, size.width * 0.08))
        if point.x <= strip { down = (point, time, .left) }
        else if point.x >= size.width - strip { down = (point, time, .right) }
    }
    mutating func move(to point: CGPoint) {
        if let down, hypot(point.x - down.point.x, point.y - down.point.y) > 4 { cancel() }
    }
    mutating func end(point: CGPoint, time: TimeInterval, single: Bool, unmodified: Bool, direction: ComicDirection) -> Turn? {
        defer { cancel() }
        guard let down, single, unmodified, time >= down.time, time - down.time <= 0.55,
              hypot(point.x - down.point.x, point.y - down.point.y) <= 4 else { return nil }
        switch (down.edge, direction) {
        case (.left, .leftToRight), (.right, .rightToLeft): return .previous
        case (.right, .leftToRight), (.left, .rightToLeft): return .next
        }
    }
}
#endif
