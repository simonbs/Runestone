#if os(iOS)
import UIKit

final class UITextInteractionEditingStateChangeHandler: NSObject, EditingStateChangeHandler {
    weak var textInput: (UIView & UITextInput)? {
        didSet {
            if textInput !== oldValue {
                editableTextInteraction.textInput = textInput
                nonEditableTextInteraction.textInput = textInput
            }
        }
    }
    var isEditingEnabled = true
    var isSelectionEnabled = true

    private let editableTextInteraction = UITextInteraction(for: .editable)
    private let nonEditableTextInteraction = UITextInteraction(for: .nonEditable)
    private var isPerformingNonEditableTextInteraction = false

    func willBeginEditing() {
        //        if !isPerformingNonEditableTextInteraction {
        if let textInput {
            installEditableInteraction(in: textInput)
        }
        //        }
    }

    func didEndEditing() {
        if let textInput {
            installNonEditableInteraction(in: textInput)
        }
    }
}

private extension UITextInteractionEditingStateChangeHandler {
    func installEditableInteraction(in view: UIView & UITextInput) {
        guard editableTextInteraction.view == nil else {
            return
        }
//      isInputAccessoryViewEnabled = true
        nonEditableTextInteraction.view?.removeInteraction(nonEditableTextInteraction)
        view.addInteraction(editableTextInteraction)
//        standardCaretHider.setupCaretViewObserver()
//        standardFloatingCaretHider.setupFloatingCaretViewObserver()
//        customFloatingCaretLayouter.setupFloatingCaretViewObserver()
        if #available(iOS 17, *) {
            // Workaround for a bug where the caret does not appear until the user taps again on iOS 17 (FB12622609).
            view.sbs_textSelectionDisplayInteraction?.isActivated = true
        }
    }

    func installNonEditableInteraction(in view: UIView) {
        guard nonEditableTextInteraction.view == nil else {
            return
        }
//      isInputAccessoryViewEnabled = false
        editableTextInteraction.view?.removeInteraction(editableTextInteraction)
        view.addInteraction(nonEditableTextInteraction)
//        standardCaretHider.setupCaretViewObserver()
//        standardFloatingCaretHider.setupFloatingCaretViewObserver()
//        customFloatingCaretLayouter.setupFloatingCaretViewObserver()
//        for gestureRecognizer in nonEditableTextInteraction.gesturesForFailureRequirements {
//            gestureRecognizer.require(toFail: beginEditingGestureRecognizer)
//        }
    }

    func removeAndAddEditableTextInteraction() {
        // There seems to be a bug in UITextInput (or UITextInteraction?) where updating the markedTextRange of a
        // UITextInput will cause the caret to disappear. Removing the editable text interaction and adding it back
        // will work around this issue.
        DispatchQueue.main.async {
            if self.editableTextInteraction.view != nil {
                let view = self.editableTextInteraction.view
                view?.removeInteraction(self.editableTextInteraction)
                view?.addInteraction(self.editableTextInteraction)
            }
        }
    }
}

extension UITextInteractionEditingStateChangeHandler: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
        if interaction.textInteractionMode == .editable {
            return isEditingEnabled
        } else if interaction.textInteractionMode == .nonEditable {
            // The private UITextLoupeInteraction and UITextNonEditableInteraction class will end up in this case.
            // The latter is likely created from UITextInteraction(for: .nonEditable) but we want to disable both
            // when selection is disabled.
            return isSelectionEnabled
        } else {
            return true
        }
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
        if interaction.textInteractionMode == .nonEditable {
            // When long-pressing our instance of UITextInput, the UITextInteraction will make the text input first
            // responder. In this case the user wants to select text in the text view but not start editing, so we
            // set a flag that tells us that we should not install editable text interaction in this case.
            isPerformingNonEditableTextInteraction = true
        }
    }

    func interactionDidEnd(_ interaction: UITextInteraction) {
        if interaction.textInteractionMode == .nonEditable {
            isPerformingNonEditableTextInteraction = false
        }
    }
}
#endif
