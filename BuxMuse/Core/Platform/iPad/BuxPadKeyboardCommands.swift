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

        CommandMenu("Find") {
            Button(context.findMenuTitle) {
                padBrain.postPadKeyboardCommand(.focusSearch)
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!context.isFindEnabled)
        }

        CommandGroup(after: .saveItem) {
            Button("Save") {
                padBrain.postPadKeyboardCommand(.save)
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                padBrain.postPadKeyboardCommand(.openSettings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .sidebar) {
            Button(context.closeMenuTitle) {
                padBrain.postPadKeyboardCommand(.close)
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Dismiss Overlay") {
                padBrain.postPadKeyboardCommand(.close)
            }
            .keyboardShortcut(.escape, modifiers: [])
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                padBrain.postPadKeyboardCommand(.undo)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo") {
                padBrain.postPadKeyboardCommand(.redo)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!padBrain.canExpenseRedo)
        }

        CommandMenu("List") {
            Button("Previous Item") {
                padBrain.postPadKeyboardCommand(.selectPreviousRow)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Next Item") {
                padBrain.postPadKeyboardCommand(.selectNextRow)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
        }

        CommandMenu("Window") {
            Button("New Expense Window") {
                padBrain.postPadKeyboardCommand(.openExpenseWindow)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Studio Window") {
                padBrain.postPadKeyboardCommand(.openStudioWindow)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
