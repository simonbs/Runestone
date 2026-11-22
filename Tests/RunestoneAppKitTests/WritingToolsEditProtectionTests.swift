#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// These tests create no windows, application, input contexts, or system UI.
final class WritingToolsEditProtectionTests: XCTestCase {
    func testOrdinaryTypingPasteAndMarkedTextCannotChangeProtectedContent() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Before protected after"))
        let session = DocumentInputSession(view: view)
        view.writingToolsProtectedRangeProvider = { NSRange(location: 7, length: 9) }
        view.isWritingToolsActive = true
        XCTAssertTrue(session.setSelection(NSRange(location: 9, length: 0)))
        XCTAssertFalse(session.insertText(NSAttributedString(string: "typing"), replacementRange: NSRange(location: NSNotFound, length: 0)))
        XCTAssertFalse(session.insertText(NSAttributedString(string: "paste"), replacementRange: NSRange(location: 6, length: 11)))
        XCTAssertFalse(session.setMarkedText("IME", selectedRange: NSRange(location: 3, length: 0),
                                            replacementRange: NSRange(location: 8, length: 2), attributes: [:]))
        XCTAssertEqual(view.content.string, "Before protected after")
        XCTAssertEqual(session.selectedRange, NSRange(location: 9, length: 0))
        XCTAssertNil(session.markedRange)
    }

    func testEditsOutsideProtectedRangeRemainEditableAndShiftProtectionImmediately() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Before protected after"))
        let session = DocumentInputSession(view: view)
        view.writingToolsProtectedRangeProvider = { NSRange(location: 7, length: 9) }
        view.isWritingToolsActive = true
        XCTAssertTrue(session.insertText(NSAttributedString(string: "Extra "), replacementRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 14, length: 1)))
        XCTAssertTrue(session.insertText(NSAttributedString(string: "!"), replacementRange: NSRange(location: view.content.length, length: 0)))
        XCTAssertEqual(view.content.string, "Extra Before protected after!")
    }

    func testSystemRevisionsUseExplicitRouteAndOrdinaryEditsStayProtected() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Before protected after"))
        let session = DocumentInputSession(view: view)
        view.writingToolsProtectedRangeProvider = { NSRange(location: 7, length: 9) }
        view.isWritingToolsActive = true
        XCTAssertTrue(session.insertText(NSAttributedString(string: "much better prose"), replacementRange: NSRange(location: 7, length: 9),
                                         isWritingToolsReplacement: true))
        XCTAssertFalse(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 20, length: 1)))
        XCTAssertEqual(view.content.string, "Before much better prose after")
        view.isWritingToolsActive = false
        XCTAssertTrue(session.insertText(NSAttributedString(string: "X"), replacementRange: NSRange(location: 7, length: 1)))
    }

    func testShrinkingAndBoundarySystemInsertionsKeepGeneratedTextProtected() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Before protected after"))
        let session = DocumentInputSession(view: view)
        view.writingToolsProtectedRangeProvider = { NSRange(location: 7, length: 9) }
        view.isWritingToolsActive = true
        XCTAssertTrue(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 7, length: 9),
                                         isWritingToolsReplacement: true))
        XCTAssertTrue(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: view.content.length, length: 0)))
        XCTAssertFalse(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 7, length: 1)))
        XCTAssertTrue(session.insertText(NSAttributedString(string: "new"), replacementRange: NSRange(location: 7, length: 0),
                                         isWritingToolsReplacement: true))
        XCTAssertFalse(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 9, length: 1)))
        XCTAssertTrue(session.insertText(NSAttributedString(string: "tail"), replacementRange: NSRange(location: 11, length: 0),
                                         isWritingToolsReplacement: true))
        XCTAssertFalse(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 14, length: 1)))
    }

    func testPendingAndExpandedSystemRangesFailClosedAndRefresh() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Before protected after"))
        let session = DocumentInputSession(view: view)
        var resolved: NSRange?
        view.writingToolsProtectedRangeProvider = { resolved }
        view.isWritingToolsActive = true
        XCTAssertFalse(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 0, length: 0)))
        resolved = NSRange(location: 7, length: 9)
        XCTAssertTrue(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 1, length: 1)))
        resolved = NSRange(location: 0, length: view.content.length)
        XCTAssertFalse(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 1, length: 1)))
        resolved = NSRange(location: NSNotFound, length: 0)
        XCTAssertFalse(view.allowsOrdinaryWritingToolsEdit(in: NSRange(location: 1, length: 1)))
    }

    func testBoundaryInsertionsAndZeroLengthResolvedRangesAreProtected() {
        XCTAssertFalse(WritingToolsEditProtection.allows(NSRange(location: 7, length: 0), protecting: NSRange(location: 7, length: 9)))
        XCTAssertFalse(WritingToolsEditProtection.allows(NSRange(location: 16, length: 0), protecting: NSRange(location: 7, length: 9)))
        XCTAssertFalse(WritingToolsEditProtection.allows(NSRange(location: 4, length: 0), protecting: NSRange(location: 4, length: 0)))
        XCTAssertFalse(WritingToolsEditProtection.allows(NSRange(location: 3, length: 2), protecting: NSRange(location: 4, length: 0)))
    }

    func testUnicodeProtectionUsesUTF16AndCannotBypassSessionValidation() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "A😀B prose"))
        let session = DocumentInputSession(view: view)
        view.writingToolsProtectedRangeProvider = { NSRange(location: 1, length: 2) }
        view.isWritingToolsActive = true
        XCTAssertFalse(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 1, length: 1),
                                          isWritingToolsReplacement: true))
        XCTAssertFalse(session.insertText(NSAttributedString(string: "x"), replacementRange: NSRange(location: 1, length: 2)))
        XCTAssertTrue(session.insertText(NSAttributedString(string: "你好"), replacementRange: NSRange(location: 1, length: 2),
                                         isWritingToolsReplacement: true))
        XCTAssertEqual(view.content.string, "A你好B prose")
    }
}
#endif
