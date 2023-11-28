// swiftlint:disable force_cast
@testable import Runestone
import XCTest

final class TextInputStringTokenizerTests: XCTestCase {}

// MARK: - Movement in Lines
extension TextInputStringTokenizerTests {
    // This is equivalent to doing Cmd+Right at the very beginning of the document.
    func testMovingToEndOfFirstLineFragmentFromBeginningOfDocument() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 0)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 39)
    }

    // This is equivalent to doing Cmd+Right within the first line fragment.
    func testMovingToEndOfFirstLineFragmentFromWithinFirstLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 10)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 39)
    }

    // This is equivalent to doing Cmd+Right within the second line fragment.
    func testMovingToEndOfSecondLineFragmentFromWithinSecondLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 45)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 77)
    }

    // This is equivalent to doing Cmd+Right within the last line fragment of a line.
    func testMovingToEndOfLineFromWithinLastLineFragmentInLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 274)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 289)
    }

    // This is equivalent to doing Cmd+Left at the very beginning of the document.
    func testMovingToBeginningOfFirstLineFragmentFromBeginningOfDocument() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 0)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Cmd+Left within the first line fragment.
    func testMovingToBeginningOfFirstLineFragmentFromWithinFirstLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 10)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Cmd+Left within the second line fragment.
    func testMovingToBeginningOfSecondLineFragmentFromWithinSecondLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 45)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 40)
    }

    // This is equivalent to doing Cmd+Left within the last line fragment of a line.
    func testMovingToBeginningOfLineFromWithinLastLineFragmentInLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 274)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 267)
    }

    // This is equivalent to doing Cmd+Right in an empty line.
    func testMovingToEndOfLineFineFragmentFromEmptyLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 290)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 290)
    }

    // This is equivalent to doing Cmd+Left in an empty line.
    func testMovingToBeginningOfLineFineFragmentFromEmptyLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 290)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .line, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 290)
    }

    func testBeginningOfDocumentIsAtBoundary() {
        let tokenizer = makeTokenizer()
        let position = IndexedPosition(index: 0)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let isAtBoundary = tokenizer.isPosition(position, atBoundary: .line, inDirection: textDirection)
        XCTAssertTrue(isAtBoundary)
    }

    func testEndOfDocumentIsAtBoundary() {
        let tokenizer = makeTokenizer()
        let position = IndexedPosition(index: 457)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let isAtBoundary = tokenizer.isPosition(position, atBoundary: .line, inDirection: textDirection)
        XCTAssertTrue(isAtBoundary)
    }

    func testBeginningOfLineFragmentIsAtBoundary() {
        let tokenizer = makeTokenizer()
        let position = IndexedPosition(index: 35)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let isAtBoundary = tokenizer.isPosition(position, atBoundary: .line, inDirection: textDirection)
        XCTAssertFalse(isAtBoundary)
    }

    func testEndOfLineFragmentIsAtBoundary() {
        let tokenizer = makeTokenizer()
        let position = IndexedPosition(index: 87)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let isAtBoundary = tokenizer.isPosition(position, atBoundary: .line, inDirection: textDirection)
        XCTAssertFalse(isAtBoundary)
    }

    func testMiddleOfLineFragmentIsNotAtBoundary() {
        let tokenizer = makeTokenizer()
        let position = IndexedPosition(index: 35)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let isAtBoundary = tokenizer.isPosition(position, atBoundary: .line, inDirection: textDirection)
        XCTAssertFalse(isAtBoundary)
    }
}

// MARK: - Movement in Paragraphs
extension TextInputStringTokenizerTests {
    // This is equivalent to doing Ctrl+E at the very beginning of the document.
    func testMovingToEndOfParagraphFromBeginningOfDocument() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 0)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 289)
    }

    // This is equivalent to doing Ctrl+E in the middle of the first line fragment.
    func testMovingToEndOfParagraphFromMiddleOfFirstLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 10)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 289)
    }

    // This is equivalent to doing Ctrl+E in the middle of the second line fragment.
    func testMovingToEndOfParagraphFromMiddleOfSecondLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 50)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 289)
    }

    // This is equivalent to doing Ctrl+E in the middle of the last line fragment in the line.
    func testMovingToEndOfParagraphFromMiddleOfLastLineFragmentInLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 274)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 289)
    }

    // This is equivalent to doing Ctrl+A at the very beginning of the document.
    func testMovingToBeginningOfParagraphFromBeginningOfDocument() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 0)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Ctrl+A in the middle of the first line fragment.
    func testMovingToBeginningOfParagraphFromMiddleOfFirstLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 10)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Ctrl+A in the middle of the second line fragment.
    func testMovingToBeginningOfParagraphFromMiddleOfSecondLineFragment() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 50)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Ctrl+A in the middle of the last line fragment in the line.
    func testMovingToBeginningOfParagraphFromMiddleOfLastLineFragmentInLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 274)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 0)
    }

    // This is equivalent to doing Ctrl+E in an empty line.
    func testMovingToEndOfLineFromEmptyLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 290)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 290)
    }

    // This is equivalent to doing Ctrl+A in an empty line.
    func testMovingToBeginningOfLineFromEmptyLine() {
        let tokenizer = makeTokenizer()
        let fromPosition = IndexedPosition(index: 290)
        let textDirection = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
        let position = tokenizer.position(from: fromPosition, toBoundary: .paragraph, inDirection: textDirection)
        let indexedPosition = position as! IndexedPosition
        XCTAssertEqual(indexedPosition.index, 290)
    }
}

private extension TextInputStringTokenizerTests {
    private var sampleText: String {
        // swiftlint:disable line_length
        """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras commodo pretium lorem et scelerisque. Sed urna massa, eleifend vel suscipit et, finibus ut nisi. Praesent ullamcorper justo ut lectus faucibus venenatis. Suspendisse lobortis libero sed odio iaculis, quis blandit ante accumsan.

Quisque sed hendrerit diam. Quisque ut enim ligula.
Donec laoreet, massa sed commodo tincidunt, dui neque ullamcorper sapien, laoreet efficitur nisi est semper velit.
"""
        // swiftlint:enable line_length
    }

    private func makeTokenizer() -> UITextInputTokenizer {
        let textInputView = TextInputView(theme: DefaultTheme())
        let stringLength = textInputView.stringView.string.length
        textInputView.layoutLines(toLocation: stringLength)
        let stringView = StringView(string: sampleText)
        let invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let highlightService = HighlightService(lineManager: lineManager)
        let lineControllerFactory = LineControllerFactory(stringView: stringView,
                                                          highlightService: highlightService,
                                                          invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        let lineControllerStorage = LineControllerStorage(stringView: stringView, lineControllerFactory: lineControllerFactory)
        lineControllerStorage.delegate = self
        for row in 0 ..< lineManager.lineCount {
            let line = lineManager.line(atRow: row)
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            lineController.prepareToDisplayString(toLocation: line.data.totalLength, syntaxHighlightAsynchronously: false)
        }
        return TextInputStringTokenizer(textInput: textInputView,
                                        stringView: stringView,
                                        lineManager: lineManager,
                                        lineControllerStorage: lineControllerStorage)
    }
}

extension TextInputStringTokenizerTests: LineControllerStorageDelegate {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController) {
        // Configured with the same values as running the example project in the iPhone 8 simulator.
        lineController.delegate = self
        lineController.constrainingWidth = 365
        lineController.kern = 0.3
    }
}

extension TextInputStringTokenizerTests: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        PlainTextSyntaxHighlighter()
    }

    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {}
}
// swiftlint:enable force_cast
