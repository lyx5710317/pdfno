// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import Testing

/// Exercise Foundation's actual KVC predicate path, without starting an App or AX session.
private final class IdentitySnapshot: NSObject {
    @objc dynamic var identifier: String
    private let alias: String
    private(set) var labelReads = 0
    private(set) var titleReads = 0
    @objc dynamic var label: String { labelReads += 1; return alias }
    @objc dynamic var title: String { titleReads += 1; return alias }
    @objc dynamic var identifiers: [String] { [identifier, label, title] }
    init(identifier: String, alias: String) {
        self.identifier = identifier; self.alias = alias; super.init()
    }
}

@Suite struct UITestIdentityPredicateTests {
    @Test(arguments: ["japanese-learning-budget", "japanese-components-source"])
    func exactIdentifierDoesNotFetchTitleOrLabel(_ id: String) {
        let snapshot = IdentitySnapshot(identifier: id, alias: "synthetic title")
        #expect(NSPredicate(format: "identifier == %@", id).evaluate(with: snapshot))
        #expect(snapshot.labelReads == 0)
        #expect(snapshot.titleReads == 0)
    }

    @Test func aLabelAliasCannotBecomeAnExactIdentifier() {
        let snapshot = IdentitySnapshot(identifier: "different-identifier", alias: "japanese-learning-budget")
        #expect(NSPredicate(format: "%@ IN identifiers", "japanese-learning-budget").evaluate(with: snapshot))
        #expect(snapshot.titleReads == 1)
        #expect(snapshot.labelReads == 1)
        #expect(!NSPredicate(format: "identifier == %@", "japanese-learning-budget").evaluate(with: snapshot))
        #expect(snapshot.titleReads == 1)
        #expect(snapshot.labelReads == 1)
    }

    @Test func identifierArgumentRemainsData() {
        let id = "synthetic' OR identifier != ''"
        let predicate = NSPredicate(format: "identifier == %@", id)
        #expect(predicate.evaluate(with: IdentitySnapshot(identifier: id, alias: "")))
        #expect(!predicate.evaluate(with: IdentitySnapshot(identifier: "different", alias: id)))
    }
}
#endif
