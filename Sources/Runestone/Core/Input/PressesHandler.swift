#if os(iOS)
import Combine
import UIKit

struct PressesHandler {
    private let locationNavigator: LocationNavigator
    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let _stringView: CurrentValueSubject<StringView, Never>
    private let markedRange: CurrentValueSubject<NSRange?, Never>
    private var textInput: UITextInput? {
        _textView.value.value
    }
    private var stringView: StringView {
        _stringView.value
    }

    init(
        locationNavigator: LocationNavigator,
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        stringView: CurrentValueSubject<StringView, Never>,
        markedRange: CurrentValueSubject<NSRange?, Never>
    ) {
        self.locationNavigator = locationNavigator
        self._textView = textView
        self._stringView = stringView
        self.markedRange = markedRange
    }

    func handlePressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let keyCode = presses.first?.key?.keyCode, presses.count == 1 else {
            return
        }
        guard markedRange.value != nil else {
            return
        }
        handleKeyPressDuringMultistageTextInput(keyCode: keyCode)
    }
}

private extension PressesHandler {
    private func handleKeyPressDuringMultistageTextInput(keyCode: UIKeyboardHIDUsage) {
        // When editing multistage text input (that is, we have a marked text) we let the user unmark the text
        // by pressing the arrow keys or Escape. This isn't common in iOS apps but it's the default behavior
        // on macOS and I think that works quite well for plain text editors on iOS too.
        guard let markedRange = markedRange.value, let markedText = stringView.substring(in: markedRange) else {
            return
        }
        // We only unmark the text if the marked text contains specific characters only.
        // Some languages use multistage text input extensively and for those iOS presents a UI when
        // navigating with the arrow keys. We do not want to interfere with that interaction.
        let characterSet = CharacterSet(charactersIn: "`´^¨")
        guard markedText.rangeOfCharacter(from: characterSet.inverted) == nil else {
            return
        }
        switch keyCode {
        case .keyboardUpArrow:
            locationNavigator.moveUp()
            textInput?.unmarkText()
        case .keyboardRightArrow:
            locationNavigator.moveRight()
            textInput?.unmarkText()
        case .keyboardDownArrow:
            locationNavigator.moveDown()
            textInput?.unmarkText()
        case .keyboardLeftArrow:
            locationNavigator.moveLeft()
            textInput?.unmarkText()
        case .keyboardEscape:
            textInput?.unmarkText()
        default:
            break
        }
    }
}
#endif
