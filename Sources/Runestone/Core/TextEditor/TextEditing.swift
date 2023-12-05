import Foundation

protocol TextEditing {
    func insertText(_ text: String)
    func replaceText(in range: NSRange, with newText: String)
    func deleteBackward()
    func deleteForward()
    func deleteWordForward()
    func deleteWordBackward()
}
