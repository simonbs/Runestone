#if os(iOS)
import UIKit

struct UITextInputSelectionEventHandler: SelectionEventHandling {
    private weak var textInput: UITextInput?

    init(textInput: UITextInput) {
        self.textInput = textInput
    }

    func selectionWillChange() {
        if let textInput {
            textInput.inputDelegate?.selectionWillChange(textInput)
        }
    }

    func selectionDidChange() {
        if let textInput {
            textInput.inputDelegate?.selectionDidChange(textInput)
        }
    }
}
#endif
