@testable import Runestone
import XCTest

#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
extension XCTestCase {
    func makeInteraction(in textView: TextView) throws -> WritingToolsInteraction {
        let input = try XCTUnwrap(textView.subviews.compactMap { $0 as? TextInputView }.first)
        let interaction = WritingToolsInteraction(textInputView: input)
        input.writingToolsController = interaction
        return interaction
    }

    func requestContext(from interaction: WritingToolsInteraction,
                        scope: UIWritingToolsCoordinator.ContextScope = .fullDocument) throws -> UIWritingToolsCoordinator.Context {
        let completion = expectation(description: "Context request completes")
        var contexts: [UIWritingToolsCoordinator.Context] = []
        interaction.writingToolsCoordinator(interaction.coordinator, requestsContextsFor: scope) { requestedContexts in
            contexts = requestedContexts
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
        return try XCTUnwrap(contexts.first)
    }

    func replace(_ range: NSRange,
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
                                            animationParameters: nil) { replacement in
            result = replacement
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
        return result
    }

    func transition(_ interaction: WritingToolsInteraction, to state: UIWritingToolsCoordinator.State) {
        let completion = expectation(description: "State change completes")
        interaction.writingToolsCoordinator(interaction.coordinator, willChangeTo: state) {
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
    }
}

@available(iOS 18.2, visionOS 2.4, *)
final class RecordingWritingToolsCoordinator: UIWritingToolsCoordinator {
    struct Update {
        let range: NSRange
        let text: String
        let reason: UIWritingToolsCoordinator.TextUpdateReason
        let attributedText: NSAttributedString
    }
    var updates: [Update] = []
    var onUpdate: (() -> Void)?

    override func updateRange(_ range: NSRange, with replacementText: NSAttributedString,
                              reason: UIWritingToolsCoordinator.TextUpdateReason,
                              forContextWithIdentifier contextID: UUID) {
        updates.append(Update(range: range, text: replacementText.string, reason: reason, attributedText: replacementText))
        onUpdate?()
    }
}

final class WritingToolsLifecycleRecorder: TextViewDelegate {
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
