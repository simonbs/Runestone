import Foundation

protocol EditingStateChangeHandler {
    func willBeginEditing()
    func didBeginEditing()
    func didCancelBeginEditing()
    func didEndEditing()
}

extension EditingStateChangeHandler {
    func willBeginEditing() {}
    func didBeginEditing() {}
    func didCancelBeginEditing() {}
    func didEndEditing() {}
}
