// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

struct SearchPreviewRegressionTests {
    private func entry(userText: String, quote: String, generatedText: String) -> LibrarySearchEntry {
        let identity = LocalBookIdentity(format: .pdf, bookID: UUID(), editionID: UUID(), fileSHA256: String(repeating: "a", count: 64))
        let book = LibrarySearchBook(identity: identity, title: "Original Saved AI Fixture")
        return LibrarySearchEntry(book: book, kind: .aiAnnotation, noteID: UUID(), userText: userText, quote: quote, generatedText: generatedText)
    }
    @Test func fullQuotePreviewWinsOverIncidentalCommonWordInComment() throws {
        let quote = "Reading opens a small window onto a wider world."
        let value = entry(userText: "Original committed comment", quote: quote, generatedText: "Original offline explanation. SavedSearchMarker.")
        let response = try LibrarySearchIndex.search(quote, books: [value.book], entries: [value])
        let hit = try #require(response.groups.first?.hits.first)
        #expect(response.totalCount == 1 && hit.entry == value)
        #expect(hit.preview == quote)
        #expect(try LibrarySearchIndex.search("SavedSearchMarker", books: [value.book], entries: [value]).groups.first?.hits.first?.preview == value.generatedText)
    }
    @Test func splitFieldQueryShowsMostRelevantTextWithStableTiesAndUnchangedIdentity() throws {
        let value = entry(userText: "Original comet observation", quote: "Window opens onto a garden", generatedText: "A wider garden with petals")
        let best = try LibrarySearchIndex.search("comet wider petals", books: [value.book], entries: [value])
        #expect(best.totalCount == 1 && best.groups.first?.hits.first?.entry == value)
        #expect(best.groups.first?.hits.first?.preview == value.generatedText)
        let tied = try LibrarySearchIndex.search("comet window", books: [value.book], entries: [value])
        #expect(tied.totalCount == 1 && tied.groups.first?.hits.first?.preview == value.userText)
        #expect(try LibrarySearchIndex.search("comet missing", books: [value.book], entries: [value]).totalCount == 0)
    }
}
