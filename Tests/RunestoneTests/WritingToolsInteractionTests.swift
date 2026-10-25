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

    func testEndingSessionCanReplaceDocumentWithoutApplyingPendingUserEditToNewFile() throws {
        let view = TextView()
        view.text = "Original text"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 13), in: context, with: "Long rewritten text", using: interaction))
        view.selectedRange = NSRange(location: 5, length: 9)
        let recorder = WritingToolsLifecycleRecorder()
        recorder.onEnd = { $0.text = "New" }
        view.editorDelegate = recorder

        view.insertText("pending edit")

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "New")
        XCTAssertEqual(recorder.activeStates, [false])
        XCTAssertNil(replace(NSRange(location: 0, length: 3), in: context, with: "late suggestion", using: interaction))
        XCTAssertEqual(view.text, "New")
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

    func testUndoDuringStreamingEndsSessionAndRejectsLateSuggestions() throws {
        let view = TextView()
        view.text = "Draft text"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 10), in: context, with: "Improved text", using: interaction))

        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "Draft text")
        XCTAssertNil(replace(NSRange(location: 0, length: 10), in: context, with: "Late text", using: interaction))
        undoManager.redo()
        XCTAssertEqual(view.text, "Improved text")
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

        view.insertText("new file")

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
        interaction.writingToolsCoordinator(interaction.coordinator, select: [NSValue(range: NSRange(location: 0, length: 0))], in: unrelatedContext) {
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

    private func assertCancellationDuringApprovalRejectsSuggestion(_ cancellation: @escaping (TextView) -> Void) throws {
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

    private func assertSessionEndDocumentReplacementCancelsCommand(_ command: (TextView) -> Void) throws {
        let view = TextView()
        view.text = "First\nSecond\nThird"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 5), in: context, with: "Rewritten", using: interaction))
        view.selectedRange = NSRange(location: 10, length: 6)
        let recorder = WritingToolsLifecycleRecorder()
        let newSelection = NSRange(location: 1, length: 0)
        recorder.onEnd = {
            $0.text = "New"
            $0.selectedRange = newSelection
        }
        view.editorDelegate = recorder

        command(view)

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "New")
        XCTAssertEqual(view.selectedRange, newSelection)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertEqual(recorder.activeStates, [false])
    }

    private func makeInteraction(in textView: TextView) throws -> WritingToolsInteraction {
        let input = try XCTUnwrap(textView.subviews.compactMap { $0 as? TextInputView }.first)
        let interaction = WritingToolsInteraction(textInputView: input)
        input.writingToolsController = interaction
        return interaction
    }

    private func requestContext(from interaction: WritingToolsInteraction,
                                scope: UIWritingToolsCoordinator.ContextScope = .fullDocument) throws -> UIWritingToolsCoordinator.Context {
        let completion = expectation(description: "Context request completes")
        var contexts: [UIWritingToolsCoordinator.Context] = []
        interaction.writingToolsCoordinator(interaction.coordinator, requestsContextsFor: scope) {
            contexts = $0
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
        return try XCTUnwrap(contexts.first)
    }

    private func replace(_ range: NSRange,
                         in context: UIWritingToolsCoordinator.Context,
                         with text: String,
                         using interaction: WritingToolsInteraction) -> NSAttributedString? {
        let completion = expectation(description: "Replacement request completes")
        var result: NSAttributedString?
        interaction.writingToolsCoordinator(interaction.coordinator,
                                            replace: range,
                                            in: context,
                                            proposedText: NSAttributedString(string: text),
                                            reason: .noninteractive,
                                            animationParameters: nil) {
            result = $0
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
        return result
    }

    private func transition(_ interaction: WritingToolsInteraction, to state: UIWritingToolsCoordinator.State) {
        let completion = expectation(description: "State change completes")
        interaction.writingToolsCoordinator(interaction.coordinator, willChangeTo: state) {
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
    }
}

private final class WritingToolsLifecycleRecorder: TextViewDelegate {
    var activeStates: [Bool] = []
    var changedTexts: [String] = []
    var onEnd: ((TextView) -> Void)?
    var onApproval: ((TextView) -> Void)?

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        onApproval?(textView)
        return true
    }

    func textViewDidChange(_ textView: TextView) {
        changedTexts.append(textView.text)
    }

    func textViewWritingToolsWillBegin(_ textView: TextView) {
        activeStates.append(textView.isWritingToolsActive)
    }

    func textViewWritingToolsDidEnd(_ textView: TextView) {
        activeStates.append(textView.isWritingToolsActive)
        onEnd?(textView)
    }
}
#endif
