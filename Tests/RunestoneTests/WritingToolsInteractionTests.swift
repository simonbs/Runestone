@testable import Runestone
import XCTest

#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
final class WritingToolsInteractionTests: XCTestCase {
    func testDelegateMakingEditorReadOnlyDuringApprovalRejectsSuggestion() throws {
        try assertCancellationDuringApprovalRejectsSuggestion { $0.isEditable = false }
    }

    func testDelegateStoppingWritingToolsDuringApprovalRejectsSuggestion() throws {
        try assertCancellationDuringApprovalRejectsSuggestion { $0.stopWritingTools() }
    }

    func testSessionEndDocumentReplacementCancelsPendingBatchReplace() throws {
        try assertSessionEndDocumentReplacementCancelsCommand { view in
            view.replaceText(in: BatchReplaceSet(replacements: [
                .init(range: NSRange(location: 10, length: 6), text: "Replace second"),
                .init(range: NSRange(location: 17, length: 5), text: "Replace third")
            ]))
        }
    }

    func testSessionEndDocumentReplacementCancelsPendingMoveLines() throws {
        try assertSessionEndDocumentReplacementCancelsCommand { $0.moveSelectedLinesUp() }
        try assertSessionEndDocumentReplacementCancelsCommand { $0.moveSelectedLinesDown() }
    }

    func testAcceptedSessionIsOneUndoStepAndPreservesEarlierHistory() throws {
        let view = TextView()
        view.text = "Draft"
        view.selectedRange = NSRange(location: 5, length: 0)
        view.insertText(" text")
        let originalSelection = NSRange(location: 0, length: 10)
        view.selectedRange = originalSelection
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 5), in: context, with: "Better", using: interaction))
        XCTAssertNotNil(replace(NSRange(location: 7, length: 4), in: context, with: "prose", using: interaction))
        transition(interaction, to: .inactive)
        XCTAssertEqual(view.text, "Better prose")

        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.text, "Draft text")
        XCTAssertEqual(view.selectedRange, originalSelection)
        undoManager.undo()
        XCTAssertEqual(view.text, "Draft")
        undoManager.redo()
        XCTAssertEqual(view.text, "Draft text")
        undoManager.redo()
        XCTAssertEqual(view.text, "Better prose")
    }

    func testRejectedSessionLeavesEarlierUndoHistoryWithoutTemporarySuggestions() throws {
        let view = TextView()
        view.text = "Draft"
        view.selectedRange = NSRange(location: 5, length: 0)
        view.insertText(" text")
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 10), in: context, with: "Rewritten text", using: interaction))
        XCTAssertNotNil(replace(NSRange(location: 0, length: 14), in: context, with: "Draft text", using: interaction))
        transition(interaction, to: .inactive)

        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.text, "Draft")
        XCTAssertFalse(undoManager.canUndo)
        undoManager.redo()
        XCTAssertEqual(view.text, "Draft text")
        XCTAssertFalse(undoManager.canRedo)
    }

    func testUndoDuringStreamingReportsUpdatedContextAndKeepsSession() throws {
        let view = TextView()
        view.text = "Draft text"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 10), in: context, with: "Improved text", using: interaction))

        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()

        XCTAssertTrue(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "Draft text")
        undoManager.redo()
        XCTAssertEqual(view.text, "Improved text")
        XCTAssertNotNil(replace(NSRange(location: 0, length: 8), in: context, with: "Better", using: interaction))
        XCTAssertEqual(view.text, "Better text")
    }

    func testSelectedContextAndSuccessiveSuggestionsUseDocumentUTF16Offsets() throws {
        let view = TextView()
        let originalText = "Intro 🥳\nThis are text.\nEnd"
        let selectedRange = (originalText as NSString).range(of: "This are text.")
        view.text = originalText
        view.selectedRange = selectedRange
        let interaction = try makeInteraction(in: view)
        let context = try requestContext(from: interaction, scope: .userSelection)
        XCTAssertEqual(context.attributedString.string, originalText)
        XCTAssertEqual(context.range, selectedRange)

        let firstRange = (view.text as NSString).range(of: "are")
        XCTAssertEqual(replace(firstRange, in: context, with: "is", using: interaction)?.string, "is")
        let secondRange = (view.text as NSString).range(of: "text")
        XCTAssertEqual(replace(secondRange, in: context, with: "a sentence", using: interaction)?.string, "a sentence")
        XCTAssertEqual(view.text, "Intro 🥳\nThis is a sentence.\nEnd")

        // Choosing the original revision must restore the original text using the updated range.
        let rewrittenRange = (view.text as NSString).range(of: "This is a sentence.")
        XCTAssertEqual(replace(rewrittenRange, in: context, with: "This are text.", using: interaction)?.string, "This are text.")
        XCTAssertEqual(view.text, originalText)
    }

    func testExternalEditsInvalidateSuggestionsEvenWhenDocumentTextIsRestored() throws {
        let view = TextView()
        view.text = "original"
        view.selectedRange = NSRange(location: 0, length: 8)
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)

        view.text = "new file"

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertNil(replace(NSRange(location: 0, length: 8), in: context, with: "late suggestion", using: interaction))
        XCTAssertEqual(view.text, "new file")

        view.text = "original"
        XCTAssertNil(replace(NSRange(location: 0, length: 8), in: context, with: "late suggestion", using: interaction))
        XCTAssertEqual(view.text, "original")
    }

    func testUnrecognizedContextCannotReplaceOrSelectText() throws {
        let view = TextView()
        view.text = "Keep this"
        let selection = NSRange(location: 5, length: 4)
        view.selectedRange = selection
        let interaction = try makeInteraction(in: view)
        let context = try requestContext(from: interaction)
        let unrelatedContext = UIWritingToolsCoordinator.Context(
            attributedString: context.attributedString,
            range: context.range
        )

        XCTAssertNil(replace(NSRange(location: 0, length: 4), in: unrelatedContext, with: "Lose", using: interaction))
        let completion = expectation(description: "Selection request completes")
        interaction.writingToolsCoordinator(interaction.coordinator,
                                            select: [NSValue(range: NSRange(location: 0, length: 0))],
                                            in: unrelatedContext) {
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)

        XCTAssertEqual(view.text, "Keep this")
        XCTAssertEqual(view.selectedRange, selection)
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func testLifecycleReportsOneBeginAndEndAcrossStreamingAndRestingStates() throws {
        let view = TextView()
        view.text = "Sample text"
        let recorder = WritingToolsLifecycleRecorder()
        view.editorDelegate = recorder
        let interaction = try makeInteraction(in: view)

        transition(interaction, to: .interactiveResting)
        transition(interaction, to: .interactiveStreaming)
        transition(interaction, to: .interactiveResting)
        XCTAssertTrue(view.isWritingToolsActive)
        XCTAssertEqual(recorder.activeStates, [true])
        transition(interaction, to: .inactive)
        transition(interaction, to: .inactive)
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(recorder.activeStates, [true, false])

        transition(interaction, to: .noninteractive)
        view.stopWritingTools()
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(recorder.activeStates, [true, false, true, false])
    }

}

@available(iOS 18.2, visionOS 2.4, *)
private extension WritingToolsInteractionTests {
    func assertCancellationDuringApprovalRejectsSuggestion(_ cancellation: @escaping (TextView) -> Void) throws {
        let view = TextView()
        view.text = "Original text"
        let selection = NSRange(location: 0, length: 13)
        view.selectedRange = selection
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        let recorder = WritingToolsLifecycleRecorder()
        recorder.onApproval = cancellation
        view.editorDelegate = recorder

        XCTAssertNil(replace(selection, in: context, with: "Suggestion", using: interaction))

        XCTAssertEqual(view.text, "Original text")
        XCTAssertEqual(view.selectedRange, selection)
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func assertSessionEndDocumentReplacementCancelsCommand(_ command: (TextView) -> Void) throws {
        let view = TextView()
        view.text = "First\nSecond\nThird"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 5), in: context, with: "Rewritten", using: interaction))
        view.selectedRange = NSRange(location: 10, length: 6)
        let recorder = WritingToolsLifecycleRecorder()
        let newSelection = NSRange(location: 1, length: 0)
        recorder.onEnd = { textView in
            textView.text = "New"
            textView.selectedRange = newSelection
        }
        view.editorDelegate = recorder

        command(view)

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "New")
        XCTAssertEqual(view.selectedRange, newSelection)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertEqual(recorder.activeStates, [false])
    }

}
#endif
