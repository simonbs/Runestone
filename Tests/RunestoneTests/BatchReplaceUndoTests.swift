@testable import Runestone
import XCTest

final class BatchReplaceUndoTests: XCTestCase {
    func testReplaceAllUndoAndRedoPreserveTextAndHistory() {
        let view = TextInputView(theme: DefaultTheme())
        view.string = "one two one"
        view.replaceText(in: BatchReplaceSet(replacements: [
            .init(range: NSRange(location: 0, length: 3), text: "three"),
            .init(range: NSRange(location: 8, length: 3), text: "three")
        ]))
        XCTAssertEqual(view.string, "three two three")
        XCTAssertTrue(view.undoManager?.canUndo == true)
        view.undoManager?.undo()
        XCTAssertEqual(view.string, "one two one")
        XCTAssertFalse(view.undoManager?.canUndo == true)
        XCTAssertTrue(view.undoManager?.canRedo == true)
        view.undoManager?.redo()
        XCTAssertEqual(view.string, "three two three")
        view.undoManager?.undo()
        XCTAssertEqual(view.string, "one two one")
    }
}
