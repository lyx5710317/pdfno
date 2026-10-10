// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoReaders
struct ComicEdgeClickTests {
    @Test func bothDirectionsUseOnlyTheCanvasEdges() {
        for direction in [ComicDirection.leftToRight, .rightToLeft] {
            for x in [CGFloat(4), 400, 796] {
                var click = ComicEdgeClick()
                click.begin(point: CGPoint(x: x, y: 250), size: CGSize(width: 800, height: 500), time: 1, single: true, unmodified: true)
                let turn = click.end(point: CGPoint(x: x, y: 250), time: 1.1, single: true, unmodified: true, direction: direction)
                if x == 400 { #expect(turn == nil) }
                else { #expect(turn == ((x < 400) == (direction == .leftToRight) ? .previous : .next)) }
                #expect(click.end(point: CGPoint(x: x, y: 250), time: 1.2, single: true, unmodified: true, direction: direction) == nil)
            }
        }
    }
    @Test func dragHoldDoubleClickModifiersAndCancellationNeverTurn() {
        for reason in 0..<6 {
            var click = ComicEdgeClick()
            click.begin(point: CGPoint(x: 795, y: 250), size: CGSize(width: 800, height: 500), time: 1, single: reason != 2, unmodified: reason != 3)
            if reason == 0 { click.move(to: CGPoint(x: 700, y: 250)); click.move(to: CGPoint(x: 795, y: 250)) }
            if reason == 4 { click.cancel() }
            let result = click.end(point: CGPoint(x: 795, y: 250), time: reason == 1 ? 1.8 : 1.1,
                single: reason != 5, unmodified: true, direction: .leftToRight)
            #expect(result == nil)
        }
    }
    @Test func outsideCanvasAndTopBottomStripsDoNotTurn() {
        for point in [CGPoint(x: -1,y: 200), CGPoint(x: 801,y: 200), CGPoint(x: 3,y: 5), CGPoint(x: 797,y: 497)] {
            var click = ComicEdgeClick()
            click.begin(point: point, size: CGSize(width: 800,height: 500), time: 1, single: true, unmodified: true)
            #expect(click.end(point: point, time: 1.1, single: true, unmodified: true, direction: .leftToRight) == nil)
        }
    }
}
#endif
