@testable import Runestone
import XCTest

final class LineMovementControllerTests: XCTestCase {
    func testMovingDownDoesNotTypesetEntireLongLine() throws {
        let stringView = StringView(string: String(repeating: "a", count: 100_000))
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let factory = LineControllerFactory(stringView: stringView,
                                            highlightService: HighlightService(lineManager: lineManager),
                                            invisibleCharacterConfiguration: InvisibleCharacterConfiguration())
        let storage = LineControllerStorage(stringView: stringView, lineControllerFactory: factory)
        let lineController = storage.getOrCreateLineController(for: lineManager.firstLine)
        lineController.constrainingWidth = 365
        let movement = LineMovementController(lineManager: lineManager, stringView: stringView, lineControllerStorage: storage)

        let destination = try XCTUnwrap(movement.location(from: 0, in: .down, offset: 1))

        XCTAssertGreaterThan(destination, 0)
        XCTAssertFalse(lineController.isFinishedTypesetting, "One Down key must not lay out the entire long logical line")
        lineController.prepareToDisplayString(toLocation: stringView.string.length, syntaxHighlightAsynchronously: false)
        XCTAssertEqual(destination, movement.location(from: 0, in: .down, offset: 1))
    }

    func testMovingUpFromEndOfPartiallyTypesetLine() throws {
        let input = makeInput(String(repeating: "a", count: 10_000))
        input.layoutLines(toLocation: 0)
        let position = IndexedPosition(index: input.string.length)

        let beforeLayout = try movement(in: input, from: position, direction: .up)

        input.layoutLines(toLocation: input.string.length)
        XCTAssertEqual(beforeLayout, try movement(in: input, from: position, direction: .up))
        XCTAssertLessThan(beforeLayout, input.string.length)
    }

    func testMovingUpIntoUnpreparedWrappedLine() throws {
        let input = makeInput(String(repeating: "a", count: 10_000) + "\nxyz")
        let position = IndexedPosition(index: 10_002)
        // Prepare only the source line, leaving the previous line's fragments unavailable.
        _ = input.caretRect(at: position.index)

        let beforeLayout = try movement(in: input, from: position, direction: .up)

        input.layoutLines(toLocation: input.string.length)
        XCTAssertEqual(beforeLayout, try movement(in: input, from: position, direction: .up))
        XCTAssertTrue((1..<10_000).contains(beforeLayout))
    }

    func testMovingDownIntoUnpreparedWrappedLine() throws {
        let input = makeInput("xyz\n" + String(repeating: "a", count: 10_000))
        let position = IndexedPosition(index: 1)

        let beforeLayout = try movement(in: input, from: position, direction: .down, offset: 2)

        input.layoutLines(toLocation: input.string.length)
        XCTAssertEqual(beforeLayout, try movement(in: input, from: position, direction: .down, offset: 2))
        XCTAssertTrue((5..<input.string.length).contains(beforeLayout))
    }

    private func makeInput(_ text: String) -> TextInputView {
        let input = TextInputView(theme: DefaultTheme())
        input.scrollViewWidth = 365
        input.string = text as NSString
        return input
    }

    private func movement(in input: TextInputView,
                          from position: IndexedPosition,
                          direction: UITextLayoutDirection,
                          offset: Int = 1) throws -> Int {
        try XCTUnwrap(input.position(from: position, in: direction, offset: offset) as? IndexedPosition).index
    }
}
