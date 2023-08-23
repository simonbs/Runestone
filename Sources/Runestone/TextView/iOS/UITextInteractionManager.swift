#if os(iOS)
import Combine
import UIKit

final class UITextInteractionManager: NSObject {
    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let isEditable: CurrentValueSubject<Bool, Never>
    private let isSelectable: CurrentValueSubject<Bool, Never>
    private let editableTextInteraction = UITextInteraction(for: .editable)
    private let nonEditableTextInteraction = UITextInteraction(for: .nonEditable)
    private let beginEditingGestureRecognizer: UIGestureRecognizer
    private let standardCaretHider: StandardCaretHider
    private let standardFloatingCaretHider: StandardFloatingCaretHider
    private let customFloatingCaretLayouter: CustomFloatingCaretLayouter
    private var isPerformingNonEditableTextInteraction = false
    private var cancellables: Set<AnyCancellable> = []
    private var textView: TextView? {
        _textView.value.value
    }

    init(
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        isEditable: CurrentValueSubject<Bool, Never>,
        isSelectable: CurrentValueSubject<Bool, Never>,
        beginEditingGestureRecognizer: UIGestureRecognizer,
        standardCaretHider: StandardCaretHider,
        standardFloatingCaretHider: StandardFloatingCaretHider,
        customFloatingCaretLayouter: CustomFloatingCaretLayouter
    ) {
        self._textView = textView
        self.isEditable = isEditable
        self.isSelectable = isSelectable
        self.beginEditingGestureRecognizer = beginEditingGestureRecognizer
        self.standardCaretHider = standardCaretHider
        self.standardFloatingCaretHider = standardFloatingCaretHider
        self.customFloatingCaretLayouter = customFloatingCaretLayouter
        super.init()
        editableTextInteraction.delegate = self
        nonEditableTextInteraction.delegate = self
        textView.map(\.value).sink { [weak self] textView in
            self?.editableTextInteraction.textInput = textView
            self?.nonEditableTextInteraction.textInput = textView
        }.store(in: &cancellables)
    }

    func installEditableInteraction() {
        guard editableTextInteraction.view == nil else {
            return
        }
//      isInputAccessoryViewEnabled = true
        textView?.removeInteraction(nonEditableTextInteraction)
        textView?.addInteraction(editableTextInteraction)
        standardCaretHider.setupCaretViewObserver()
        standardFloatingCaretHider.setupFloatingCaretViewObserver()
        customFloatingCaretLayouter.setupFloatingCaretViewObserver()
    }

    func installNonEditableInteraction() {
        guard nonEditableTextInteraction.view == nil else {
            return
        }
//      isInputAccessoryViewEnabled = false
        textView?.removeInteraction(editableTextInteraction)
        textView?.addInteraction(nonEditableTextInteraction)
        standardCaretHider.setupCaretViewObserver()
        standardFloatingCaretHider.setupFloatingCaretViewObserver()
        customFloatingCaretLayouter.setupFloatingCaretViewObserver()
        for gestureRecognizer in nonEditableTextInteraction.gesturesForFailureRequirements {
            gestureRecognizer.require(toFail: beginEditingGestureRecognizer)
        }
    }

    func removeAndAddEditableTextInteraction() {
        // There seems to be a bug in UITextInput (or UITextInteraction?) where updating the markedTextRange of a UITextInput will cause the caret to disappear. Removing the editable text interaction and adding it back will work around this issue.
        DispatchQueue.main.async {
            if self.editableTextInteraction.view != nil {
                self.textView?.removeInteraction(self.editableTextInteraction)
                self.textView?.addInteraction(self.editableTextInteraction)
            }
        }
    }
}

extension UITextInteractionManager: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
        if interaction.textInteractionMode == .editable {
            return isEditable.value
        } else if interaction.textInteractionMode == .nonEditable {
            // The private UITextLoupeInteraction and UITextNonEditableInteractionclass will end up in this case. The latter is likely created from UITextInteraction(for: .nonEditable) but we want to disable both when selection is disabled.
            return isSelectable.value
        } else {
            return true
        }
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
        if interaction.textInteractionMode == .nonEditable {
            // When long-pressing our instance of UITextInput, the UITextInteraction will make the text input first responder.
            // In this case the user wants to select text in the text view but not start editing, so we set a flag that tells us
            // that we should not install editable text interaction in this case.
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
