@testable import Runestone
import XCTest

final class TextInputStringTokenizerTests: XCTestCase {
    private struct Entities {
        let textInputView: TextInputView
        let tokenizer: UITextInputTokenizer
    }

    func testAsd() {
        let entities = makeEntities()
        let fromPosition = entities.textInputView.beginningOfDocument
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = entities.tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        print(position)
    }
}

private extension TextInputStringTokenizerTests {
    private var sampleText: String {
        return """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras commodo pretium lorem et scelerisque. Sed urna massa, eleifend vel suscipit et, finibus ut nisi. Praesent ullamcorper justo ut lectus faucibus venenatis. Suspendisse lobortis libero sed odio iaculis, quis blandit ante accumsan.

Quisque sed hendrerit diam. Quisque ut enim ligula.
Donec laoreet, massa sed commodo tincidunt, dui neque ullamcorper sapien, laoreet efficitur nisi est semper velit.
"""
    }

    private func makeEntities() -> Entities {
        let textInputView = TextInputView(theme: DefaultTheme())
        let stringLength = textInputView.stringView.string.length
        textInputView.layoutLines(toLocation: stringLength)
        let stringView = StringView(string: sampleText)
        let lineManager = LineManager(stringView: stringView)
        let lineControllerStorage = LineControllerStorage(stringView: stringView)
        lineControllerStorage.delegate = self
        let tokenizer = TextInputStringTokenizer(textInput: textInputView,
                                                 stringView: stringView,
                                                 lineManager: lineManager,
                                                 lineControllerStorage: lineControllerStorage)
        return Entities(textInputView: textInputView, tokenizer: tokenizer)
    }
}

extension TextInputStringTokenizerTests: LineControllerStorageDelegate {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController) {
        lineController.constrainingWidth = 375
    }
}
