// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import PDFnoDomain

/// Real menu items preserve accessible names for the language subcommands.
/// Constructing or opening the menu never invokes a reading action.
@MainActor struct NativeSelectionAIMenu: NSViewRepresentable {
    enum Command: Equatable {
        case conversation(ReadingConversationTask), japaneseReview, englishReview
    }
    let tasks: [ReadingConversationTask]
    let onCommand: (Command) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13)
        button.imagePosition = .imageLeft
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        button.setAccessibilityIdentifier("selection-ai-menu")
        button.setAccessibilityLabel("AI")
        context.coordinator.update(button, tasks: tasks, onCommand: onCommand)
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.update(button, tasks: tasks, onCommand: onCommand)
    }
    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        coordinator.detach(button)
    }

    @MainActor final class Coordinator: NSObject {
        private var tasks: [ReadingConversationTask]?
        private var commands: [NSMenuItem: Command] = [:]
        private var onCommand: ((Command) -> Void)?

        func update(_ button: NSPopUpButton, tasks: [ReadingConversationTask], onCommand: @escaping (Command) -> Void) {
            self.onCommand = onCommand
            guard self.tasks != tasks else { return }
            detach(button)
            self.tasks = tasks
            self.onCommand = onCommand
            let menu = NSMenu(title: "AI")
            menu.autoenablesItems = false
            // Pull-down buttons hide their first item and use it as the caption.
            let caption = NSMenuItem(title: "AI", action: nil, keyEquivalent: "")
            caption.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            menu.addItem(caption)
            for task in tasks {
                let identifier = "selection-ai-" + task.rawValue
                if task == .japanese || task == .english {
                    let parent = namedItem(task.title, identifier: identifier)
                    let submenu = NSMenu(title: task.title)
                    submenu.autoenablesItems = false
                    submenu.addItem(actionItem("对话", identifier: identifier + "-conversation", command: .conversation(task)))
                    let review: Command = task == .japanese ? .japaneseReview : .englishReview
                    submenu.addItem(actionItem(task == .japanese ? "假名与语法审阅" : "结构与语法审阅", identifier: identifier + "-review", command: review))
                    parent.submenu = submenu
                    menu.addItem(parent)
                } else {
                    menu.addItem(actionItem(task.title, identifier: identifier, command: .conversation(task)))
                }
            }
            button.autoenablesItems = false
            button.target = nil
            button.action = nil
            button.menu = menu
        }
        private func namedItem(_ title: String, identifier: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(identifier)
            item.setAccessibilityIdentifier(identifier)
            item.setAccessibilityLabel(title)
            item.isEnabled = true
            return item
        }
        private func actionItem(_ title: String, identifier: String, command: Command) -> NSMenuItem {
            let item = namedItem(title, identifier: identifier)
            item.target = self
            item.action = #selector(chooseCommand(_:))
            commands[item] = command
            return item
        }
        @objc func chooseCommand(_ item: NSMenuItem) {
            guard let command = commands[item], let callback = onCommand else { return }
            // Closing the popover may dismantle this view during the callback.
            callback(command)
        }
        func detach(_ button: NSPopUpButton) {
            onCommand = nil
            for item in commands.keys { item.target = nil; item.action = nil }
            commands.removeAll()
            tasks = nil
            button.menu = nil
        }
    }
}
#endif
