@testable import Runestone
import XCTest

#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
final class WritingToolsActiveSessionTests: XCTestCase {
    func testOrdinaryEditDuringApprovalCannotApplyToSwitchedDocument() throws {
        let view = TextView()
        view.text = "Original text"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveStreaming)
        let context = try requestContext(from: interaction)
        let recorder = WritingToolsLifecycleRecorder()
        recorder.onApproval = { $0.text = "New" }
        view.editorDelegate = recorder
        view.selectedRange = NSRange(location: 5, length: 8)

        view.insertText("pending edit")

        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "New")
        XCTAssertNil(replace(NSRange(location: 0, length: 3), in: context, with: "late suggestion", using: interaction))
    }

    func testTypingAndOverlappingSuggestionKeepSessionAndSeparateUndoSteps() throws {
        let view = TextView()
        view.text = "A😀 bad sentence."
        let interaction = try makeInteraction(in: view)
        let coordinator = RecordingWritingToolsCoordinator(delegate: interaction)
        interaction.coordinator = coordinator
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 4, length: 3), in: context, with: "good", using: interaction))
        view.selectedRange = NSRange(location: 0, length: 0)
        view.insertText("New ")
        XCTAssertTrue(view.isWritingToolsActive)
        XCTAssertEqual(coordinator.updates.last?.range, NSRange(location: 0, length: 0))
        XCTAssertEqual(coordinator.updates.last?.text, "New ")
        XCTAssertEqual(coordinator.updates.last?.reason, .typing)
        XCTAssertNotNil(replace(NSRange(location: 8, length: 4), in: context, with: "great", using: interaction))
        XCTAssertEqual(view.text, "New A😀 great sentence.")

        let undo = try XCTUnwrap(view.undoManager)
        undo.undo()
        XCTAssertTrue(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "New A😀 good sentence.")
        XCTAssertEqual(coordinator.updates.last?.reason, .undoRedo)
        undo.undo()
        XCTAssertEqual(view.text, "A😀 good sentence.")
        undo.undo()
        XCTAssertEqual(view.text, "A😀 bad sentence.")
        undo.redo()
        undo.redo()
        undo.redo()
        XCTAssertEqual(view.text, "New A😀 great sentence.")
        XCTAssertTrue(view.isWritingToolsActive)
        transition(interaction, to: .inactive)
        undo.undo()
        XCTAssertEqual(view.text, "New A😀 good sentence.")
    }

    func testUpdatedExclusionsAreReportedBeyondTheTypedDelimiter() throws {
        let view = TextView()
        view.text = "code"
        view.writingToolsExcludedRangesProvider = { text in
            text.hasSuffix("`") ? [NSRange(location: 0, length: text.utf16.count)] : []
        }
        let interaction = try makeInteraction(in: view)
        let coordinator = RecordingWritingToolsCoordinator(delegate: interaction)
        interaction.coordinator = coordinator
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)
        view.selectedRange = NSRange(location: 4, length: 0)

        view.insertText("`")

        XCTAssertTrue(view.isWritingToolsActive)
        let update = try XCTUnwrap(coordinator.updates.last)
        XCTAssertEqual(update.range, NSRange(location: 0, length: 4))
        XCTAssertEqual(update.text, "code`")
        XCTAssertEqual(update.attributedText.attribute(.writingToolsExclusionAttributeName, at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertNil(replace(NSRange(location: 0, length: 4), in: context, with: "prose", using: interaction))
        view.undoManager?.undo()
        XCTAssertTrue(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "code")
        XCTAssertNil(coordinator.updates.last?.attributedText.attribute(.writingToolsExclusionAttributeName, at: 0, effectiveRange: nil))
    }

    func testSuggestionChangingProtectionOutsideReplacementRetiresContext() throws {
        let view = TextView()
        view.text = "code"
        view.writingToolsExcludedRangesProvider = { text in
            text.hasSuffix("`") ? [NSRange(location: 0, length: text.utf16.count)] : []
        }
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)

        XCTAssertNotNil(replace(NSRange(location: 4, length: 0), in: context, with: "`", using: interaction))

        XCTAssertEqual(view.text, "code`")
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertNil(replace(NSRange(location: 0, length: 4), in: context, with: "prose", using: interaction))
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "code")
    }

    func testCoordinatorEndingSessionDuringTypingCanSwitchDocuments() throws {
        let view = TextView()
        view.text = "Original"
        let recorder = WritingToolsLifecycleRecorder()
        recorder.onEnd = { $0.text = "New file" }
        view.editorDelegate = recorder
        let interaction = try makeInteraction(in: view)
        let coordinator = RecordingWritingToolsCoordinator(delegate: interaction)
        coordinator.onUpdate = { view.stopWritingTools() }
        interaction.coordinator = coordinator
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)
        view.selectedRange = NSRange(location: 0, length: 8)

        view.insertText("Typed")

        XCTAssertEqual(view.text, "New file")
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertNil(replace(NSRange(location: 0, length: 3), in: context, with: "Late", using: interaction))
    }

    func testIndentationCannotMoveSelectionIntoReentrantlyLoadedDocument() throws {
        let view = TextView()
        view.text = "Original long text"
        let selection = NSRange(location: 1, length: 0)
        let recorder = WritingToolsLifecycleRecorder()
        recorder.onEnd = { $0.text = "New"; $0.selectedRange = selection }
        view.editorDelegate = recorder
        let interaction = try makeInteraction(in: view)
        let coordinator = RecordingWritingToolsCoordinator(delegate: interaction)
        coordinator.onUpdate = { view.stopWritingTools() }
        interaction.coordinator = coordinator
        transition(interaction, to: .interactiveResting)
        _ = try requestContext(from: interaction)
        view.selectedRange = NSRange(location: 8, length: 0)

        view.shiftRight()

        XCTAssertEqual(view.text, "New")
        XCTAssertEqual(view.selectedRange, selection)
        XCTAssertFalse(view.isWritingToolsActive)
    }

    func testRejectingSuggestionAfterTypingPreservesUserEditAndUndo() throws {
        let view = TextView()
        view.text = "Bad 😀"
        let interaction = try makeInteraction(in: view)
        transition(interaction, to: .interactiveResting)
        let context = try requestContext(from: interaction)
        XCTAssertNotNil(replace(NSRange(location: 0, length: 3), in: context, with: "Good", using: interaction))
        view.selectedRange = NSRange(location: 7, length: 0)
        view.insertText(" added")
        // UIKit's rejection incorporates the typed suffix using the reported updated context.
        XCTAssertNotNil(replace(NSRange(location: 0, length: 4), in: context, with: "Bad", using: interaction))
        transition(interaction, to: .inactive)
        XCTAssertEqual(view.text, "Bad 😀 added")
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "Good 😀 added")
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "Good 😀")
        view.undoManager?.redo()
        XCTAssertEqual(view.text, "Good 😀 added")
    }

}
#endif
