#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class DocumentInputClientTests: XCTestCase {
    private var attributes: [NSAttributedString.Key: Any] { [.font: NSFont.systemFont(ofSize: 14)] }
    private var unspecified: NSRange { NSRange(location: NSNotFound, length: 0) }

    func testProtocolMarkedCycleAndExplicitReplacement() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "start", attributes: attributes))
        let bridge = makeClient(view)
        let client: NSTextInputClient = bridge
        var changes: [String] = []
        bridge.session.contentDidChange = { changes.append($0.string) }
        XCTAssertTrue(bridge.session.setSelection(NSRange(location: 5, length: 0)))
        client.setMarkedText("🐢a", selectedRange: NSRange(location: 2, length: 1), replacementRange: unspecified)
        XCTAssertTrue(client.hasMarkedText())
        XCTAssertEqual(client.markedRange(), NSRange(location: 5, length: 3))
        XCTAssertEqual(client.selectedRange(), NSRange(location: 7, length: 1))
        client.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0), replacementRange: unspecified)
        client.insertText("日本", replacementRange: unspecified)
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(client.markedRange().location, NSNotFound)
        XCTAssertEqual(client.selectedRange(), NSRange(location: 7, length: 0))
        XCTAssertEqual(changes, ["start🐢a", "start日本"])
        client.insertText("X", replacementRange: NSRange(location: 0, length: 5))
        XCTAssertEqual(view.content.string, "X日本")
        XCTAssertEqual(client.selectedRange(), NSRange(location: 1, length: 0))
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 14)
    }

    func testAttributedInputsPreserveDistinctRuns() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: ""))
        let bridge = makeClient(view)
        let client: NSTextInputClient = bridge
        let text = NSMutableAttributedString(string: "ab", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        text.addAttribute(.font, value: NSFont.systemFont(ofSize: 24), range: NSRange(location: 1, length: 1))
        client.setMarkedText(text, selectedRange: NSRange(location: 2, length: 0), replacementRange: unspecified)
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 12)
        XCTAssertEqual((view.content.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)?.pointSize, 24)
        client.unmarkText()
        XCTAssertFalse(client.hasMarkedText())
        client.insertText(text, replacementRange: NSRange(location: 0, length: 2))
        XCTAssertEqual((view.content.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)?.pointSize, 24)
    }

    func testQueriesReturnValidatedAttributedSubstring() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "😀text", attributes: attributes))
        let bridge = makeClient(view, markedAttributes: [.underlineStyle])
        let client: NSTextInputClient = bridge
        var actual = NSRange(location: NSNotFound, length: 0)
        let content = try XCTUnwrap(client.attributedSubstring(forProposedRange: NSRange(location: 2, length: 4), actualRange: &actual))
        XCTAssertEqual(content.string, "text")
        XCTAssertEqual(actual, NSRange(location: 2, length: 4))
        XCTAssertEqual(client.validAttributesForMarkedText(), [.underlineStyle])
        XCTAssertNil(client.attributedSubstring(forProposedRange: NSRange(location: 1, length: 1), actualRange: &actual))
        XCTAssertEqual(actual.location, NSNotFound)
        XCTAssertNil(client.attributedSubstring(forProposedRange: NSRange(location: 0, length: Int.max), actualRange: &actual))
        XCTAssertEqual(actual.location, NSNotFound)
    }

    func testInvalidInputAndMarkedSelectionDoNotMutateState() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "😀"))
        let bridge = makeClient(view)
        let client: NSTextInputClient = bridge
        var changes = 0
        bridge.session.contentDidChange = { _ in changes += 1 }
        client.insertText(123, replacementRange: unspecified)
        client.insertText("x", replacementRange: NSRange(location: 0, length: 1))
        client.setMarkedText("🐢", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(view.content.string, "😀")
        XCTAssertEqual(client.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(changes, 0)
    }

    func testGeometryAndCommandsAreForwardedAndInvalidResultsAreRejected() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "😀abc"))
        var command: Selector?
        var queried: NSRange?
        var point: NSPoint?
        let bridge = DocumentInputClient(view: view, typingAttributes: { [:] }, commandHandler: { command = $0 },
                                         rectProvider: { range in
                                             queried = range
                                             return (NSRect(x: 100, y: 200, width: 1, height: 20), range)
                                         }, indexProvider: { location in point = location; return 2 })
        let client: NSTextInputClient = bridge
        var actual = NSRange(location: NSNotFound, length: 0)
        XCTAssertEqual(client.firstRect(forCharacterRange: NSRange(location: 2, length: 1), actualRange: &actual),
                       NSRect(x: 100, y: 200, width: 1, height: 20))
        XCTAssertEqual(queried, NSRange(location: 2, length: 1))
        XCTAssertEqual(actual, NSRange(location: 2, length: 1))
        XCTAssertEqual(client.characterIndex(for: NSPoint(x: 4, y: 5)), 2)
        XCTAssertEqual(point, NSPoint(x: 4, y: 5))
        let selector = NSSelectorFromString("deleteBackward:")
        client.doCommand(by: selector)
        XCTAssertEqual(command, selector)
        XCTAssertEqual(client.firstRect(forCharacterRange: NSRange(location: 1, length: 0), actualRange: &actual), .zero)
        XCTAssertEqual(actual.location, NSNotFound)
        view.setContent(view.content)
        XCTAssertEqual(client.characterIndex(for: .zero), NSNotFound)
        XCTAssertEqual(client.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: &actual), .zero)
        XCTAssertEqual(actual.location, NSNotFound)
    }

    private func makeClient(_ view: ReadOnlyDocumentView,
                            markedAttributes: [NSAttributedString.Key] = []) -> DocumentInputClient {
        DocumentInputClient(view: view, typingAttributes: { self.attributes }, commandHandler: { _ in },
                            rectProvider: { _ in nil }, indexProvider: { _ in nil }, markedAttributes: markedAttributes)
    }
}
#endif
