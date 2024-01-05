import Foundation

protocol TextSetting {
    func setText(_ newText: String, preservingUndoStack: Bool)
}
