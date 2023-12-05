import Foundation

protocol TextSetting {
    func setText(_ newText: NSString, preservingUndoStack: Bool)
}
