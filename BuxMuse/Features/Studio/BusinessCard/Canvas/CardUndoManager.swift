//
//  CardUndoManager.swift
//  BuxMuse
//

import Combine
import Foundation

@MainActor
final class CardUndoManager: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoStack: [CardCanvasDocument] = []
    private var redoStack: [CardCanvasDocument] = []
    private let limit = 50

    func snapshot(_ document: CardCanvasDocument) {
        undoStack.append(document)
        if undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll()
        refresh()
    }

    func undo(current: CardCanvasDocument) -> CardCanvasDocument? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        refresh()
        return previous
    }

    func redo(current: CardCanvasDocument) -> CardCanvasDocument? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        refresh()
        return next
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
        refresh()
    }

    private func refresh() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
