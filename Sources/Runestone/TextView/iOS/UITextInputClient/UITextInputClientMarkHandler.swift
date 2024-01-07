import UIKit

final class UITextInputClientMarkHandler {
    // swiftlint:disable unused_setter_value
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { nil }
        set {}
    }
    // swiftlint:enable unused_setter_value
    var markedTextRange: UITextRange? {
        get {
//            if let markedRange = state.markedRange {
//                return IndexedRange(markedRange)
//            } else {
//                return nil
//            }
            return nil
        }
        set {
//            state.markedRange = (newValue as? IndexedRange)?.range.nonNegativeLength
        }
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        if let markedText {
            let attributedMarkedText = NSAttributedString(string: markedText)
            setAttributedMarkedText(attributedMarkedText, selectedRange: selectedRange)
        } else {
            setAttributedMarkedText(nil, selectedRange: selectedRange)
        }
    }

    func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
//        let range = state.markedRange ?? state.selectedRange
//        let markedTextString = markedText?.string ?? ""
//        state.markedRange = if !markedTextString.isEmpty {
//            NSRange(location: range.location, length: markedTextString.utf16.count)
//        } else {
//            nil
//        }
//        textEditor.replaceText(in: range, with: markedTextString)
//        state.inlinePredictionRange = if #available(iOS 17, *), markedText?.hasForegroundColorAttribute ?? false {
//            // If the text has a foreground color attribute then we assume it's an inline prediction.
//            state.markedRange
//        } else {
//            nil
//        }
//        // The selected range passed to setMarkedText(_:selectedRange:) is local to the marked range.
//        let preferredSelectedRange = NSRange(location: range.location + selectedRange.location, length: selectedRange.length)
//        let cappedSelectedRange = preferredSelectedRange.capped(to: stringView.length)
//        inputDelegate.selectionWillChange()
//        state.selectedRange = cappedSelectedRange
//        inputDelegate.selectionDidChange()
//        textInteractionManager.removeAndAddEditableTextInteraction()
    }

    func unmarkText() {
//        state.inlinePredictionRange = nil
//        inputDelegate.selectionWillChange()
//        state.markedRange = nil
//        inputDelegate.selectionDidChange()
//        textInteractionManager.removeAndAddEditableTextInteraction()
    }
}
