#if os(iOS)
import Combine
import UIKit

final class UITextInputClient {
    typealias StateStore = SelectedRangeWritable

    let tokenizer: UITextInputTokenizer
    var beginningOfDocument: UITextPosition {
        IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        IndexedPosition(index: stringView.string.length)
    }
    var hasText: Bool {
        stringView.string.length > 0
    }

    private let stateStore: StateStore
    private let stringView: StringView
    private let textEditor: TextEditing

    init(
        stateStore: StateStore,
        stringView: StringView,
        tokenizer: UITextInputTokenizer,
        textEditor: TextEditing
    ) {
        self.stateStore = stateStore
        self.stringView = stringView
        self.tokenizer = tokenizer
        self.textEditor = textEditor
    }

//    func resetHasDeletedTextWithPendingLayoutSubviews() {
//        textEditState.hasDeletedTextWit hPendingLayoutSubviews = false
//    }

//    func notifyInputDelegateFromLayoutSubviewsIfNeeded() {
        // We notify the input delegate about selection changes in layoutSubviews so we have a chance of disabling notifying the input delegate during an editing operation.
        // We will sometimes disable notifying the input delegate when the user enters Korean text.
        // This workaround is inspired by a dialog with Alexander Blach (@lextar), developer of Textastic.
//        if textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews {
//            textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
//            inputDelegate.selectionWillChange()
//            inputDelegate.selectionDidChange()
//        }
//        if textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews {
//            textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews = false
//            textViewDelegate.textViewDidChangeSelection()
//        }
//    }
}

// MARK: - Caret
extension UITextInputClient {
    func caretRect(for position: UITextPosition) -> CGRect {
//        guard let indexedPosition = position as? IndexedPosition else {
//            fatalError("Expected position to be of type \(IndexedPosition.self)")
//        }
//        return insertionPointFrameFactory.frameOfInsertionPoint(at: indexedPosition.index)
        return CGRect(x: 5, y: 5, width: 5, height: 16)
//        return .zero
    }

    func beginFloatingCursor(at point: CGPoint) {
//        guard let view = proxyView.view, floatingInsertionPointView == nil, let position = closestPosition(to: point) else {
//            return
//        }
//        floatingInsertionPointPosition.value = point
//        let caretRect = caretRect(for: position)
//        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
//        let insertionPointView = insertionPointViewFactory.makeView()
//        insertionPointView.isFloating = true
//        insertionPointView.layer.zPosition = 5000
//        insertionPointView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
//        view.addSubview(insertionPointView)
//        self.floatingInsertionPointView = insertionPointView
//        textViewDelegate.textViewDidBeginFloatingCursor()
    }

    func updateFloatingCursor(at point: CGPoint) {
//        guard let floatingInsertionPointView, let position = closestPosition(to: point) else {
//            return
//        }
//        floatingInsertionPointPosition.value = point
//        let caretRect = caretRect(for: position)
//        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
//        floatingInsertionPointView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
    }

    func endFloatingCursor() {
//        floatingInsertionPointPosition.value = nil
//        floatingInsertionPointView?.removeFromSuperview()
//        floatingInsertionPointView = nil
//        textViewDelegate.textViewDidEndFloatingCursor()
    }
}

// MARK: - Editing
extension UITextInputClient {
    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return stringView.string.substring(with: indexedRange.range)
        } else {
            return nil
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let indexedRange = range as? IndexedRange else {
            return
        }
        textEditor.replaceText(in: indexedRange.range, with: text)
    }

    func insertText(_ text: String) {
        textEditor.insertText(text)
//        textEditState.isRestoringPreviouslyDeletedText = textEditState.hasDeletedTextWithPendingLayoutSubviews
//        textEditState.hasDeletedTextWithPendingLayoutSubviews = false
//        defer {
//            textEditState.isRestoringPreviouslyDeletedText = false
//        }
//        textEditor.insertText(text)
//        proxyView.view?.layoutIfNeeded()
    }

    func deleteBackward() {
        textEditor.deleteBackward()
    }
}

// MARK: - Selection
extension UITextInputClient {
    var selectedTextRange: UITextRange? {
        get {
            IndexedRange(stateStore.selectedRange)
        }
        set {
            // We should not use this setter. It's intended for UIKit to use. It'll invoke the setter in various scenarios, for example when navigating the text using the keyboard.
            // On the iOS 16 beta, UIKit may pass an NSRange with a negatives length (e.g. {4, -2}) when double tapping to select text. This will cause a crash when UIKit later attempts to use the selected range with NSString's -substringWithRange:. This can be tested with a string containing the following three lines:
            //    A
            //
            //    A
            // Placing the character on the second line, which is empty, and double tapping several times on the empty line to select text will cause the editor to crash. To work around this we take the non-negative value of the selected range. Last tested on August 30th, 2022.
//            let newRange = (newValue as? IndexedRange)?.range.nonNegativeLength ?? NSRange(location: 0, length: 0)
//            if newRange != state.selectedRange {
//                textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews = true
//                // The logic for determining whether or not to notify the input delegate is based on advice provided by Alexander Blach, developer of Textastic.
//                var shouldNotifyInputDelegate = false
//                if didCallPositionFromPositionWithOffset {
//                    shouldNotifyInputDelegate = true
//                    didCallPositionFromPositionWithOffset = false
//                }
//                textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = !shouldNotifyInputDelegate
//                if shouldNotifyInputDelegate {
//                    inputDelegate.selectionWillChange()
//                }
//                state.selectedRange = newRange
////                textViewController._selectedRange = newRange
//                if shouldNotifyInputDelegate {
//                    inputDelegate.selectionDidChange()
//                }
//            }
        }
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
//        guard let indexedRange = range as? IndexedRange else {
//            return []
//        }
//        return textSelectionRectFactory.selectionRects(in: indexedRange.range)
        return []
    }
}

// MARK: - Marking
extension UITextInputClient {
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
//        let cappedSelectedRange = preferredSelectedRange.capped(to: stringView.string.length)
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

// MARK: - Ranges and Positions
extension UITextInputClient {
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
//        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
//            return nil
//        }
//        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
//        return IndexedRange(range)
        return nil
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
//        guard let indexedPosition = position as? IndexedPosition else {
//            return nil
//        }
//        let newPosition = indexedPosition.index + offset
//        guard newPosition >= 0 && newPosition <= stringView.string.length else {
//            return nil
//        }
//        didCallPositionFromPositionWithOffset = true
//        return IndexedPosition(index: newPosition)
        return nil
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        return nil
//        guard let indexedPosition = position as? IndexedPosition else {
//            return nil
//        }
//        switch direction {
//        case .right:
//            let newLocation = characterNavigationLocationFactory.location(
//                movingFrom: indexedPosition.index,
//                byCharacterCount: offset,
//                inDirection: .forward
//            )
//            return IndexedPosition(index: newLocation)
//        case .left:
//            let newLocation = characterNavigationLocationFactory.location(
//                movingFrom: indexedPosition.index,
//                byCharacterCount: offset,
//                inDirection: .backward
//            )
//            return IndexedPosition(index: newLocation)
//        case .up:
//            let newLocation = lineNavigationLocationFactory.location(
//                movingFrom: indexedPosition.index,
//                byLineCount: offset,
//                inDirection: .backward
//            )
//            return IndexedPosition(index: newLocation)
//        case .down:
//            let newLocation = lineNavigationLocationFactory.location(
//                movingFrom: indexedPosition.index,
//                byLineCount: offset,
//                inDirection: .forward
//            )
//            return IndexedPosition(index: newLocation)
//        @unknown default:
//            return nil
//        }
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? IndexedPosition, let otherIndexedPosition = other as? IndexedPosition else {
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst may pass <uninitialized> to `position`. I'm not sure what the right way to deal with that is but returning .orderedSame seems to work.
            return .orderedSame
            #else
            fatalError("Positions must be of type \(IndexedPosition.self)")
            #endif
        }
        if indexedPosition.index < otherIndexedPosition.index {
            return .orderedAscending
        } else if indexedPosition.index > otherIndexedPosition.index {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        switch direction {
        case .left, .up:
            return IndexedPosition(index: indexedRange.range.lowerBound)
        case .right, .down:
            return IndexedPosition(index: indexedRange.range.upperBound)
        @unknown default:
            return nil
        }
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        // This implementation seems to match the behavior of UITextView.
//        guard let indexedPosition = position as? IndexedPosition else {
//            return nil
//        }
//        switch direction {
//        case .left, .up:
//            let leftIndex = max(indexedPosition.index - 1, 0)
//            return IndexedRange(location: leftIndex, length: indexedPosition.index - leftIndex)
//        case .right, .down:
//            let rightIndex = min(indexedPosition.index + 1, stringView.string.length)
//            return IndexedRange(location: indexedPosition.index, length: rightIndex - indexedPosition.index)
//        @unknown default:
//            return nil
//        }
        return nil
    }

    func firstRect(for range: UITextRange) -> CGRect {
//        guard let indexedRange = range as? IndexedRange else {
//            fatalError("Expected range to be of type \(IndexedRange.self)")
//        }
//        return firstRectFactory.firstRect(for: indexedRange.range)
        return .zero
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
//        let index = locationRaycaster.location(closestTo: point)
//        return IndexedPosition(index: index)
        return nil
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
//        guard let indexedRange = range as? IndexedRange else {
//            return nil
//        }
//        let index = locationRaycaster.location(closestTo: point)
//        let minimumIndex = indexedRange.range.lowerBound
//        let maximumIndex = indexedRange.range.upperBound
//        let cappedIndex = min(max(index, minimumIndex), maximumIndex)
//        return IndexedPosition(index: cappedIndex)
        return nil
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
//        let index = locationRaycaster.location(closestTo: point)
//        let cappedIndex = max(index - 1, 0)
//        let range = stringView.string.customRangeOfComposedCharacterSequence(at: cappedIndex)
//        return IndexedRange(range)
        return nil
    }
}

// MARK: - Writing Direction
extension UITextInputClient {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}
#endif
