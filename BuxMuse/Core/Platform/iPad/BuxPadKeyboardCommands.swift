//
//  BuxPadKeyboardCommands.swift
//  BuxMuse — iPadOS desktop keyboard shortcuts (Magic Keyboard / trackpad). iPhone ignores.
//

import SwiftUI

enum BuxPadKeyboardCommand: Equatable {
    case newExpense
    case focusSearch
    case save
    case openSettings
    case close
    case undo
    case redo
    case selectPreviousRow
    case selectNextRow
    case openExpenseWindow
    case openStudioWindow
}

struct BuxPadKeyboardCommands: Commands {
    @ObservedObject var padBrain: BuxPadNavigationBrain

    private var context: BuxPadKeyboardContext {
        padBrain.keyboardContext
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(context.newItemMenuTitle) {
                padBrain.postPadKeyboardCommand(.newExpense)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!context.isNewItemEnabled)
        }

        CommandMenu(BuxCatalogLabel.string("Find", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
            Button(context.findMenuTitle) {
                padBrain.postPadKeyboardCommand(.focusSearch)
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!context.isFindEnabled)
        }

        CommandGroup(after: .saveItem) {
            Button(BuxCatalogLabel.string("Save", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.save)
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandGroup(replacing: .appSettings) {
            Button(BuxCatalogLabel.string("Settings", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.openSettings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .sidebar) {
            Button(context.closeMenuTitle) {
                padBrain.postPadKeyboardCommand(.close)
            }
            .keyboardShortcut("w", modifiers: .command)

            Button(BuxCatalogLabel.string("Dismiss Overlay", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.close)
            }
            .keyboardShortcut(.escape, modifiers: [])
        }

        CommandGroup(replacing: .undoRedo) {
            Button(BuxCatalogLabel.string("Undo", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.undo)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button(BuxCatalogLabel.string("Redo", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.redo)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!padBrain.canExpenseRedo)
        }

        CommandMenu(BuxCatalogLabel.string("List", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
            Button(BuxCatalogLabel.string("Previous Item", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.selectPreviousRow)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button(BuxCatalogLabel.string("Next Item", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.selectNextRow)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
        }

        CommandMenu("Window") {
            Button(BuxCatalogLabel.string("New Expense Window", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.openExpenseWindow)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button(BuxCatalogLabel.string("New Studio Window", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                padBrain.postPadKeyboardCommand(.openStudioWindow)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
