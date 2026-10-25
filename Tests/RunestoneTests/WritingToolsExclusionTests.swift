@testable import Runestone
import XCTest

final class WritingToolsExclusionTests: XCTestCase {
    func testUpdateRangeRemainsLocalWhenExclusionsOnlyShiftWithTheEdit() {
        let ranges = WritingToolsExclusions.updateRanges(replacing: NSRange(location: 2, length: 1), withLength: 3,
                                                         oldLength: 30, oldExcludedRanges: [NSRange(location: 10, length: 5)],
                                                         newExcludedRanges: [NSRange(location: 12, length: 5)])
        XCTAssertEqual(ranges.old, NSRange(location: 2, length: 1))
        XCTAssertEqual(ranges.new, NSRange(location: 2, length: 3))
    }

    func testOpeningFenceUpdatesNewExclusionsAfterInsertion() {
        let ranges = WritingToolsExclusions.updateRanges(replacing: NSRange(location: 5, length: 0), withLength: 3,
                                                         oldLength: 30, oldExcludedRanges: [],
                                                         newExcludedRanges: [NSRange(location: 5, length: 20)])
        XCTAssertEqual(ranges.old, NSRange(location: 5, length: 17))
        XCTAssertEqual(ranges.new, NSRange(location: 5, length: 20))
    }

    func testClosingFenceUpdatesExclusionBeforeInsertion() {
        let ranges = WritingToolsExclusions.updateRanges(replacing: NSRange(location: 20, length: 0), withLength: 3,
                                                         oldLength: 30, oldExcludedRanges: [],
                                                         newExcludedRanges: [NSRange(location: 5, length: 18)])
        XCTAssertEqual(ranges.old, NSRange(location: 5, length: 15))
        XCTAssertEqual(ranges.new, NSRange(location: 5, length: 18))
    }

    func testRemovingFenceUpdatesExclusionsOnBothSidesOfDeletion() {
        let ranges = WritingToolsExclusions.updateRanges(replacing: NSRange(location: 10, length: 3), withLength: 0,
                                                         oldLength: 30, oldExcludedRanges: [NSRange(location: 5, length: 20)],
                                                         newExcludedRanges: [])
        XCTAssertEqual(ranges.old, NSRange(location: 5, length: 20))
        XCTAssertEqual(ranges.new, NSRange(location: 5, length: 17))
    }

    func testInsertionInsideExclusionDoesNotBroadenUpdateWhenAttributeIsUnchanged() {
        let ranges = WritingToolsExclusions.updateRanges(replacing: NSRange(location: 10, length: 0), withLength: 2,
                                                         oldLength: 30, oldExcludedRanges: [NSRange(location: 5, length: 20)],
                                                         newExcludedRanges: [NSRange(location: 5, length: 22)])
        XCTAssertEqual(ranges.old, NSRange(location: 10, length: 0))
        XCTAssertEqual(ranges.new, NSRange(location: 10, length: 2))
    }

    func testInvalidRangesAreIgnoredAndOverlappingRangesAreMerged() {
        let text = "A😀 code end" as NSString
        let ranges = [NSRange(location: 4, length: 3), NSRange(location: 6, length: 2),
                      NSRange(location: 8, length: 1), NSRange(location: 1, length: 2),
                      NSRange(location: 2, length: 1), NSRange(location: -1, length: 2),
                      NSRange(location: NSNotFound, length: 1), NSRange(location: 4, length: Int.max),
                      NSRange(location: 3, length: 0)]
        XCTAssertEqual(WritingToolsExclusions.normalizedRanges(ranges, in: text),
                       [NSRange(location: 1, length: 2), NSRange(location: 4, length: 5)])
    }

    func testProtectedTextCannotBeReplacedDeletedOrInsertedInto() throws {
        let view = TextView()
        view.text = "A `code` sentence"
        view.writingToolsExcludedRangesProvider = { [($0 as NSString).range(of: "`code`")] }
        let input = try textInput(in: view)
        let selection = NSRange(location: 2, length: 6)
        view.selectedRange = selection

        for (range, text) in [(selection, "other"), (selection, ""),
                              (NSRange(location: 4, length: 0), "changed"),
                              (NSRange(location: 0, length: 7), "Partial overlap")] {
            XCTAssertNil(input.replaceTextForWritingTools(in: range, with: text))
            XCTAssertEqual(view.text, "A `code` sentence")
            XCTAssertEqual(view.selectedRange, selection)
            XCTAssertFalse(view.undoManager?.canUndo == true)
        }
    }

    func testProtectedUnchangedSuffixPermitsProseReplacementAndUndoRedo() throws {
        let view = TextView()
        view.text = "Bad `code`"
        view.writingToolsExcludedRangesProvider = { [($0 as NSString).range(of: "`code`")] }
        let input = try textInput(in: view)
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 10), with: "Better `code`"), "Better `code`")
        XCTAssertEqual(view.text, "Better `code`")
        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.text, "Bad `code`")
        undoManager.redo()
        XCTAssertEqual(view.text, "Better `code`")
    }

    func testExclusionsAreRecomputedAfterUTF16LengthChangingEdit() throws {
        let view = TextView()
        view.text = "A 😀 code"
        view.writingToolsExcludedRangesProvider = { [($0 as NSString).range(of: "code")] }
        let input = try textInput(in: view)
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 1), with: "Prose"), "Prose")
        let movedRange = (view.text as NSString).range(of: "code")
        XCTAssertEqual(input.writingToolsExcludedRanges(), [movedRange])
        XCTAssertNil(input.replaceTextForWritingTools(in: movedRange, with: "broken"))
        XCTAssertEqual(view.text, "Prose 😀 code")
    }

    func testOrdinaryUserEditsRemainAllowedInsideExclusions() throws {
        let view = TextView()
        view.text = "code"
        view.writingToolsExcludedRangesProvider = { [NSRange(location: 0, length: $0.utf16.count)] }
        view.selectedRange = NSRange(location: 1, length: 2)
        view.insertText("hang")
        XCTAssertEqual(view.text, "change")
    }

    func testExclusionsChangedDuringDelegateApprovalRejectReplacement() throws {
        let view = TextView()
        view.text = "Protected"
        var protectsText = false
        view.writingToolsExcludedRangesProvider = { text in
            protectsText ? [NSRange(location: 0, length: text.utf16.count)] : []
        }
        let recorder = ExclusionApprovalRecorder { protectsText = true }
        view.editorDelegate = recorder
        let input = try textInput(in: view)
        XCTAssertNil(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 9), with: "Changed"))
        XCTAssertEqual(view.text, "Protected")
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func testMatchingHalfOfSurrogatePairDoesNotPermitChangingProtectedEmoji() {
        let text = "😀!" as NSString
        XCTAssertFalse(WritingToolsExclusions.allowsReplacement(in: NSRange(location: 0, length: 3),
                                                                with: "😁!", in: text,
                                                                excluding: [NSRange(location: 0, length: 2)]))
    }

    func testInsertionAtExclusionEdgesIsAllowed() throws {
        let view = TextView()
        view.text = "code"
        view.writingToolsExcludedRangesProvider = { [($0 as NSString).range(of: "code")] }
        let input = try textInput(in: view)
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 0), with: "Before "), "Before ")
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 11, length: 0), with: " after"), " after")
        XCTAssertEqual(view.text, "Before code after")
    }

    private func textInput(in view: TextView) throws -> TextInputView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
    }
}

#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
extension WritingToolsExclusionTests {
    func testExplicitSelectionRetainsNativeExclusionAttributes() throws {
        let view = TextView()
        view.text = "Prose `code` here"
        view.selectedRange = NSRange(location: 0, length: view.text.utf16.count)
        view.writingToolsExcludedRangesProvider = { [($0 as NSString).range(of: "`code`")] }
        let input = try textInput(in: view)
        let interaction = try XCTUnwrap(input.writingToolsController as? WritingToolsInteraction)
        var context: UIWritingToolsCoordinator.Context?
        interaction.writingToolsCoordinator(interaction.coordinator, requestsContextsFor: .userSelection) { context = $0.first }
        let received = try XCTUnwrap(context)
        XCTAssertEqual(received.range, view.selectedRange)
        let excluded = received.attributedString.attribute(.writingToolsExclusionAttributeName, at: 6, effectiveRange: nil) as? NSNumber
        XCTAssertEqual(excluded?.boolValue, true)
        XCTAssertNil(received.attributedString.attribute(.writingToolsExclusionAttributeName, at: 0, effectiveRange: nil))
    }
}
#endif

private final class ExclusionApprovalRecorder: TextViewDelegate {
    let onApproval: () -> Void
    init(onApproval: @escaping () -> Void) { self.onApproval = onApproval }
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        onApproval()
        return true
    }
}
