// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Testing
import PDFnoDomain
@testable import PDFnoUI

/// Inspect native menus without opening a window or executing a real AI request.
@Suite(.serialized) @MainActor struct SelectionAIMenuNativeTests {
    @Test func defaultToolsKeepAllThreeActionsAndLanguagePreferencesRemainIndependent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Original-Menu-Native-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = AIReadingToolsPreferences(root: root)
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        let coordinator = NativeSelectionAIMenu.Coordinator()
        var callbacks = 0
        func update() { coordinator.update(button, tasks: ReadingConversationTask.allCases.filter { preferences.isEnabled($0) }) { _ in callbacks += 1 } }
        update()
        #expect(button.itemTitles == ["AI", "解释", "翻译", "总结"])
        // AppKit installs its own menu-control action when the menu is assigned.
        #expect(button.itemArray[0].target !== coordinator && button.pullsDown)
        #expect(button.itemArray[0].action != #selector(NativeSelectionAIMenu.Coordinator.chooseCommand(_:)))
        coordinator.chooseCommand(button.itemArray[0])
        #expect(callbacks == 0)
        #expect(button.action == nil && button.target == nil && !button.autoenablesItems)
        preferences.set(.english, enabled: true); update()
        #expect(button.itemTitles == ["AI", "解释", "翻译", "总结", "英语学习"])
        preferences.set(.japanese, enabled: true); preferences.set(.english, enabled: false); update()
        #expect(button.itemTitles == ["AI", "解释", "翻译", "总结", "日语学习"])
        #expect(callbacks == 0)
        coordinator.detach(button)
    }

    @Test func realLanguageLeavesHaveUniqueNativeNamesAndDispatchOnlyTheirOwnCommand() throws {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        let coordinator = NativeSelectionAIMenu.Coordinator()
        var received: [NativeSelectionAIMenu.Command] = []
        coordinator.update(button, tasks: ReadingConversationTask.allCases) { received.append($0) }
        let menu = try #require(button.menu)
        #expect(!menu.autoenablesItems && received.isEmpty)
        let japanese = try #require(menu.item(withTitle: "日语学习")), english = try #require(menu.item(withTitle: "英语学习"))
        #expect(japanese.target !== coordinator && english.target !== coordinator)
        for parent in [japanese, english] {
            #expect(parent.action != #selector(NativeSelectionAIMenu.Coordinator.chooseCommand(_:)))
            coordinator.chooseCommand(parent); #expect(received.isEmpty)
            let submenu = try #require(parent.submenu)
            #expect(!submenu.autoenablesItems && submenu.items.count == 2)
            for leaf in submenu.items {
                #expect(!leaf.title.isEmpty && leaf.accessibilityLabel() == leaf.title)
                #expect(leaf.accessibilityIdentifier() == leaf.identifier?.rawValue)
                #expect(leaf.target === coordinator && leaf.action == #selector(NativeSelectionAIMenu.Coordinator.chooseCommand(_:)) && leaf.isEnabled)
            }
        }
        let conversation = try #require(english.submenu?.item(withTitle: "对话"))
        let review = try #require(japanese.submenu?.item(withTitle: "假名与语法审阅"))
        #expect(conversation.accessibilityIdentifier() == "selection-ai-english-conversation")
        #expect(review.accessibilityIdentifier() == "selection-ai-japanese-review")
        coordinator.chooseCommand(english); #expect(received.isEmpty)
        coordinator.chooseCommand(conversation); coordinator.chooseCommand(review)
        #expect(received == [.conversation(.english), .japaneseReview])
        coordinator.update(button, tasks: [.explain]) { received.append($0) }
        #expect(conversation.target == nil && conversation.action == nil)
        coordinator.chooseCommand(conversation); #expect(received.count == 2)
        let explanation = try #require(button.menu?.item(withTitle: "解释"))
        coordinator.detach(button)
        #expect(button.menu == nil && explanation.target == nil && explanation.action == nil)
        coordinator.chooseCommand(explanation); #expect(received.count == 2)
    }
}
#endif
