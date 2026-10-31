#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputDispatchIntegrationTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testOneDispatchKeepsGateAcrossTypedReplacementCompositionAndSelection() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let connection = fixture.attachment.connection
        let client = try XCTUnwrap(fixture.driver.client)
        let view = try XCTUnwrap(fixture.attachment.view as? PreparedInputResponderView)
        let initial = host.inputRevision
        var forwarded = false

        XCTAssertTrue(connection.performCoordinatedInput {
            XCTAssertTrue(host.parentOpen)
            if case .busy = host.beginInputReconstruction() {} else { XCTFail("The entire dispatch must hold the gate") }
            XCTAssertEqual(fixture.attachment.adapter.setSelection(NSRange(location: 1, length: 2)), .processed)
            client.insertText("X", replacementRange: self.unspecified)
            let afterReplacement = host.inputRevision
            XCTAssertNotEqual(afterReplacement, initial)
            XCTAssertEqual(host.text, "aX")
            client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: self.unspecified)
            client.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0), replacementRange: self.unspecified)
            XCTAssertEqual(host.inputRevision, afterReplacement)
            XCTAssertEqual(fixture.attachment.view.content.string, "aX日本")
            client.insertText("日本", replacementRange: self.unspecified)
            XCTAssertEqual(host.text, "aX日本")
            XCTAssertNotEqual(host.inputRevision, afterReplacement)
            view.routeCommand(NSSelectorFromString("moveBackward:"), on: connection) { _ in forwarded = true; return true }
            XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), NSRange(location: 3, length: 0))
            XCTAssertTrue(host.parentOpen)
        })
        fixture.queue.runAll()
        XCTAssertFalse(forwarded)
        XCTAssertEqual(host.text, "aX日本")
        XCTAssertEqual(host.undoCount, 2)
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.childStarts, host.childCloses)
        XCTAssertEqual(host.childStarts, 6)
        XCTAssertEqual(host.completions.count, 1)
        let completion = try XCTUnwrap(host.completions.first)
        XCTAssertEqual(completion.expectedRevision, initial)
        XCTAssertEqual(completion.finalRevision, host.inputRevision)
        if case .completed = completion.outcome {} else { XCTFail("Expected successful dispatch") }
        XCTAssertFalse(host.parentOpen)
        try fixture.disconnect()
    }

    func testMarkedUpdateAndCancelStayWithinDispatchAndDoNotPublish() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let client = try XCTUnwrap(fixture.driver.client)
        let initial = host.inputRevision
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: self.unspecified)
            client.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0), replacementRange: self.unspecified)
            XCTAssertEqual(fixture.attachment.view.content.string, "日本abc")
            // The input context must discard its conversion session before
            // restoring the provisional overlay and accepting further input.
            fixture.driver.discardMarkedText()
            XCTAssertEqual(fixture.attachment.adapter.cancelCompositionAfterQuiescing(), .processed)
            XCTAssertEqual(fixture.attachment.view.content.string, "abc")
            XCTAssertTrue(host.parentOpen)
        })
        fixture.queue.runAll()
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertEqual(host.inputRevision, initial)
        XCTAssertEqual(host.childStarts, 3)
        XCTAssertEqual(host.childStarts, host.childCloses)
        XCTAssertEqual(host.completions.count, 1)
        XCTAssertEqual(host.completions.first?.expectedRevision, initial)
        XCTAssertEqual(host.completions.first?.finalRevision, initial)
        if case .completed = try XCTUnwrap(host.completions.first).outcome {} else { XCTFail("Expected successful dispatch") }
        try fixture.disconnect()
    }

    func testBusyAndStaleAdmissionsDoNotRunInputOrReplayAgainstNewerRevision() throws {
        for stale in [false, true] {
            let fixture = try DispatchFixture()
            let host = fixture.host
            let client = try XCTUnwrap(fixture.driver.client)
            let expected = host.inputRevision
            if stale {
                host.text = "newer"
                host.inputRevision = UUID()
            } else {
                host.externallyBusy = true
            }
            var entered = false
            XCTAssertFalse(fixture.attachment.connection.performCoordinatedInput {
                entered = true
                client.insertText("stale", replacementRange: self.unspecified)
            })
            fixture.queue.runAll()
            XCTAssertFalse(entered)
            XCTAssertEqual(host.text, stale ? "newer" : "abc")
            XCTAssertEqual(host.undoCount, 0)
            XCTAssertEqual(host.childStarts, 0)
            XCTAssertEqual(host.parentCloses, 0)
            XCTAssertEqual(host.completions.count, 1)
            let completion = try XCTUnwrap(host.completions.first)
            XCTAssertEqual(completion.expectedRevision, expected)
            switch completion.outcome {
            case .rejectedBeforeAdmission(.stale) where stale: break
            case .rejectedBeforeAdmission(.busy) where !stale: break
            default: XCTFail("Incorrect rejection outcome")
            }
            host.externallyBusy = false
            fixture.queue.runAll()
            XCTAssertEqual(host.text, stale ? "newer" : "abc")
            XCTAssertEqual(host.undoCount, 0)
            try fixture.disconnect()
        }
    }

    func testLaterClientCallbackGetsSeparateAdmissionAndRevisionIdentity() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let client = try XCTUnwrap(fixture.driver.client)
        let firstRevision = host.inputRevision
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: self.unspecified)
        })
        XCTAssertEqual(host.completions.count, 1)
        XCTAssertEqual(host.completions[0].expectedRevision, firstRevision)
        XCTAssertEqual(host.completions[0].finalRevision, firstRevision)
        // A later NSTextInputClient callback is not silently attached to the
        // previous synchronous event; it must acquire a fresh parent lease.
        client.insertText("日", replacementRange: unspecified)
        fixture.queue.runAll()
        XCTAssertEqual(host.completions.count, 2)
        XCTAssertNotEqual(host.completions[0].id, host.completions[1].id)
        XCTAssertEqual(host.completions[1].expectedRevision, firstRevision)
        XCTAssertEqual(host.completions[1].finalRevision, host.inputRevision)
        if case .completed = host.completions[1].outcome {} else { XCTFail("Expected separate successful dispatch") }
        XCTAssertEqual(host.parentStarts, 2)
        XCTAssertEqual(host.parentCloses, 2)
        XCTAssertEqual(host.text, "日abc")
        XCTAssertEqual(host.undoCount, 1)
        try fixture.disconnect()
    }

    func testDeclinedDriverQueryAndKeyBindingFallbackShareDispatchGate() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let connection = fixture.attachment.connection
        let view = try XCTUnwrap(fixture.attachment.view as? PreparedInputResponderView)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "x",
                                                   charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 0))
        var driverCalls = 0
        fixture.driver.onHandle = {
            driverCalls += 1
            XCTAssertTrue(host.parentOpen)
            XCTAssertEqual(fixture.driver.client?.selectedRange(), NSRange(location: 0, length: 0))
            return false
        }
        var fallbackCalls = 0
        XCTAssertTrue(connection.performCoordinatedInput {
            XCTAssertEqual(connection.dispatchKey(event), .declined)
            XCTAssertTrue(host.parentOpen)
            XCTAssertTrue(connection.performKeyBindingFallback {
                fallbackCalls += 1
                XCTAssertTrue(host.parentOpen)
                view.routeCommand(NSSelectorFromString("moveForward:"), on: connection) { _ in
                    XCTFail("A recognized command must not be forwarded")
                    return true
                }
            })
        })
        fixture.queue.runAll()
        fixture.driver.onHandle = nil
        XCTAssertEqual(driverCalls, 1)
        XCTAssertEqual(fallbackCalls, 1)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), NSRange(location: 1, length: 0))
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.childStarts, 1)
        XCTAssertEqual(host.childStarts, host.childCloses)
        XCTAssertEqual(host.completions.count, 1)
        if case .completed = try XCTUnwrap(host.completions.first).outcome {} else { XCTFail("Expected completed dispatch") }
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        try fixture.disconnect()
    }

    func testEmptyMarkedCompositionResetReportsSeparateDiscardOnce() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let client = try XCTUnwrap(fixture.driver.client)
        let revision = host.inputRevision
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            client.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                 replacementRange: NSRange(location: 1, length: 1))
            XCTAssertEqual(fixture.attachment.view.content.string, "ac")
            XCTAssertFalse(client.hasMarkedText())
        })
        XCTAssertEqual(host.completions.count, 1)
        if case .completed = host.completions[0].outcome {} else { XCTFail("Expected completed marking dispatch") }
        fixture.attachment.connection.requestReset()
        fixture.queue.runAll()
        XCTAssertEqual(host.completions.count, 2)
        let notice = host.completions[1]
        XCTAssertEqual(notice.kind, .compositionDiscarded)
        XCTAssertEqual(notice.outcome, .mayHaveApplied)
        XCTAssertNotEqual(notice.id, host.completions[0].id)
        XCTAssertNil(notice.expectedRevision)
        XCTAssertNil(notice.finalRevision)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.inputRevision, revision)
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertEqual(fixture.attachment.view.content.string, "abc")
        client.insertText("old", replacementRange: unspecified)
        fixture.queue.runAll()
        XCTAssertEqual(host.completions.count, 2)
        XCTAssertEqual(host.text, "abc")
        try fixture.disconnect()
    }

    func testNestedDispatchIsRejectedBeforeAdmissionAndReportedInCompletionOrder() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let connection = fixture.attachment.connection
        var nestedEntered = false
        XCTAssertTrue(connection.performCoordinatedInput {
            XCTAssertTrue(host.parentOpen)
            XCTAssertFalse(connection.performCoordinatedInput { nestedEntered = true })
            XCTAssertFalse(nestedEntered)
            XCTAssertEqual(host.completions.count, 1)
            XCTAssertEqual(host.completions[0].outcome, .rejectedBeforeAdmission(.busy))
            XCTAssertTrue(host.completionWhileParentOpen[0])
        })
        fixture.queue.runAll()
        XCTAssertEqual(host.completions.count, 2)
        XCTAssertEqual(host.completions[1].outcome, .completed)
        XCTAssertFalse(host.completionWhileParentOpen[1])
        XCTAssertNotEqual(host.completions[0].id, host.completions[1].id)
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        try fixture.disconnect()
    }

    func testResetAfterPublicationReportsUncertainOutcomeAndNeverReplays() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let client = try XCTUnwrap(fixture.driver.client)
        let initial = host.inputRevision
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            client.insertText("X", replacementRange: self.unspecified)
            fixture.attachment.connection.requestReset()
            fixture.queue.runAll() // Nested loop must not close a live dispatch or retire the driver.
            XCTAssertTrue(host.parentOpen)
            XCTAssertEqual(fixture.driver.discards, 0)
        })
        fixture.queue.runAll()
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.completions.count, 1)
        let completion = try XCTUnwrap(host.completions.first)
        XCTAssertEqual(completion.expectedRevision, initial)
        XCTAssertEqual(completion.finalRevision, host.inputRevision)
        if case .mayHaveApplied = completion.outcome {} else { XCTFail("Expected interrupted outcome") }
        client.insertText("old", replacementRange: unspecified)
        fixture.queue.runAll()
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
        try fixture.disconnect()
    }

    func testResetDuringParentCloseReportsUncertainOutcomeWithUnderGateRevision() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let connection = fixture.attachment.connection
        let client = try XCTUnwrap(fixture.driver.client)
        let initialRevision = host.inputRevision
        var publishedRevision: UUID?
        host.onParentClose = {
            XCTAssertFalse(host.parentOpen)
            connection.requestReset()
        }
        XCTAssertTrue(connection.performCoordinatedInput {
            client.insertText("X", replacementRange: self.unspecified)
            publishedRevision = host.inputRevision
            XCTAssertNotEqual(publishedRevision, initialRevision)
        })
        host.onParentClose = nil
        fixture.queue.runAll()
        XCTAssertEqual(host.completions.count, 1)
        let completion = try XCTUnwrap(host.completions.first)
        XCTAssertEqual(completion.expectedRevision, initialRevision)
        XCTAssertEqual(completion.finalRevision, publishedRevision)
        XCTAssertEqual(completion.outcome, .mayHaveApplied)
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
        client.insertText("old", replacementRange: unspecified)
        fixture.queue.runAll()
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
        try fixture.disconnect()
    }

    func testTeardownDuringDispatchWaitsForUnwindAndReportsUncertainOutcome() throws {
        let fixture = try DispatchFixture()
        let host = fixture.host
        let client = try XCTUnwrap(fixture.driver.client)
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            client.insertText("X", replacementRange: self.unspecified)
            host.lifetime.invalidate()
            fixture.queue.runAll()
            XCTAssertTrue(host.parentOpen)
            XCTAssertEqual(fixture.driver.discards, 0)
        })
        fixture.queue.runAll()
        XCTAssertEqual(host.parentStarts, 1)
        XCTAssertEqual(host.parentCloses, 1)
        XCTAssertEqual(host.completions.count, 1)
        if case .mayHaveApplied = try XCTUnwrap(host.completions.first).outcome {} else { XCTFail("Expected interrupted outcome") }
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
        client.insertText("old", replacementRange: unspecified)
        fixture.queue.runAll()
        XCTAssertEqual(host.text, "Xabc")
        XCTAssertEqual(host.undoCount, 1)
    }
}

private final class DispatchFixture {
    let host: DispatchTestHost
    let queue: DispatchTestQueue
    let attachment: PreparedInputDocumentAttachment
    let driver: DispatchTestDriver

    init() throws {
        let host = DispatchTestHost()
        let queue = DispatchTestQueue()
        var made: DispatchTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { client in let result = DispatchTestDriver(client); made = result; return result },
            schedule: queue.enqueue))
        self.host = host
        self.queue = queue
        self.attachment = attachment
        self.driver = try XCTUnwrap(made)
        XCTAssertTrue(attachment.connection.resumeForFocus())
    }

    func disconnect() throws {
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }
}

private final class DispatchTestHost: RunestoneInputDocumentHost, RunestoneInputDispatchHost {
    var text = "abc"
    var inputRevision = UUID()
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    var externallyBusy = false
    var parentOpen = false
    var childOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var onParentClose: (() -> Void)?
    var childStarts = 0
    var childCloses = 0
    var undoCount = 0
    var completions: [RunestoneInputDispatchCompletion] = []
    var completionWhileParentOpen: [Bool] = []

    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !externallyBusy, !parentOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true
        parentStarts += 1
        return .reserved(DispatchParentReservation(self))
    }

    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        if parentOpen {
            XCTAssertEqual(completion.outcome, .rejectedBeforeAdmission(.busy))
        }
        XCTAssertFalse(childOpen)
        completionWhileParentOpen.append(parentOpen)
        completions.append(completion)
    }

    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !externallyBusy, !parentOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        externallyBusy = true
        return .reserved(DispatchChildReservation(self, standalone: true))
    }

    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !externallyBusy, !parentOpen else { return .busy }
        externallyBusy = true
        return .reserved(DispatchSnapshotReservation(self))
    }

    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class DispatchParentReservation: RunestoneInputDispatchReservation {
    let host: DispatchTestHost
    init(_ host: DispatchTestHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        XCTAssertTrue(host.parentOpen)
        guard !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true
        host.childStarts += 1
        return .reserved(DispatchChildReservation(host, standalone: false))
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertFalse(host.childOpen)
        host.parentOpen = false
        host.parentCloses += 1
        host.onParentClose?()
    }
}

private final class DispatchChildReservation: RunestoneInputEventReservation {
    let host: DispatchTestHost
    let standalone: Bool
    init(_ host: DispatchTestHost, standalone: Bool) { self.host = host; self.standalone = standalone }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        DispatchPublication(host, text: candidate.string)
    }
    func close() {
        if standalone { host.externallyBusy = false }
        else {
            XCTAssertTrue(host.parentOpen)
            XCTAssertTrue(host.childOpen)
            host.childOpen = false
            host.childCloses += 1
        }
    }
}

private final class DispatchPublication: RunestoneInputPreparedPublication {
    let host: DispatchTestHost
    let text: String
    init(_ host: DispatchTestHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.undoCount += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected reconciliation") }
}

private final class DispatchSnapshotReservation: RunestoneInputReconstructionReservation {
    let host: DispatchTestHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: DispatchTestHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text)
        revision = host.inputRevision
    }
    func close() { host.externallyBusy = false }
}

private final class DispatchTestDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let object = NSObject()
    var discards = 0
    var onHandle: (() -> Bool)?
    init(_ client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { onHandle?() ?? false }
    func invalidateCoordinates() {}
    func discardMarkedText() { discards += 1 }
    func deactivate() {}
}

private final class DispatchTestQueue {
    var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var count = 0
        while !work.isEmpty && count < 200 {
            count += 1
            work.removeFirst()()
        }
        XCTAssertTrue(work.isEmpty, "The queue should settle without polling indefinitely")
    }
}
#endif
