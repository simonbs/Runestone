#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputResponderAccessibilityTests: XCTestCase {
    private let unavailable = NSRange(location: NSNotFound, length: 0)

    func testSuspendedResponderDoesNotExposeUnownedTextOrSelection() throws {
        let fixture = try AccessibilityResponderFixture("a😀b")
        let view = fixture.view
        // The connection is created suspended; no real key window is required.
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityRole(), .staticText)
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilityValue:")))
        XCTAssertNil(view.accessibilityValue())
        XCTAssertEqual(view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertNil(view.accessibilitySelectedText())
        XCTAssertNil(view.accessibilityString(for: NSRange(location: 0, length: 1)))
        XCTAssertEqual(view.accessibilityVisibleCharacterRange(), unavailable)
    }

    func testActiveConnectionExposesOneCurrentSelectionSnapshot() throws {
        let fixture = try AccessibilityResponderFixture("a😀b")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        XCTAssertEqual(fixture.setSelection(NSRange(location: 1, length: 2)), .processed)
        let view = fixture.view
        XCTAssertTrue(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityValue() as? String, "a😀b")
        XCTAssertEqual(view.accessibilityNumberOfCharacters(), 4)
        XCTAssertEqual(view.accessibilitySelectedTextRange(), NSRange(location: 1, length: 2))
        XCTAssertEqual(view.accessibilitySelectedText(), "😀")
        XCTAssertEqual(view.accessibilityString(for: NSRange(location: 1, length: 2)), "😀")
        XCTAssertEqual(view.accessibilityRole(), .textArea)
        XCTAssertTrue(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilityValue:")))
        XCTAssertTrue(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedTextRange:")))
        XCTAssertTrue(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedText:")))
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedTextRanges:")))
        // This checks mapping on an active connection, not real focus or VoiceOver.
    }

    func testAccessibilityMutationsUseTheDocumentGateAndPreserveText() throws {
        let fixture = try AccessibilityResponderFixture("a😀b")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        let view = fixture.view
        view.setAccessibilitySelectedTextRange(NSRange(location: 1, length: 2))
        XCTAssertEqual(view.accessibilitySelectedText(), "😀")
        XCTAssertEqual(fixture.host.text, "a😀b")
        view.setAccessibilitySelectedText("x\r\ny")
        XCTAssertEqual(fixture.host.text, "ax\r\nyb")
        XCTAssertEqual(view.accessibilityValue() as? String, "ax\r\nyb")
        XCTAssertEqual(fixture.host.publications, 1)
        view.setAccessibilityValue("one\ntwo\rthree")
        XCTAssertEqual(fixture.host.text, "one\ntwo\rthree")
        XCTAssertEqual(fixture.host.publications, 2)
        XCTAssertEqual(fixture.host.completions.count, 3)
        XCTAssertTrue(fixture.host.completions.allSatisfy { $0.outcome == .completed })
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }

    func testAccessibilityMutationWhileBusyIsReportedWithoutReplay() throws {
        let fixture = try AccessibilityResponderFixture("abc")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        fixture.host.busy = true
        fixture.view.setAccessibilityValue("new")
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        fixture.host.busy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.publications, 0)
    }

    func testMarkedTextBlocksAccessibilityMutation() throws {
        let fixture = try AccessibilityResponderFixture("abc")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        _ = fixture.attachment.connection.performCoordinatedInput {
            XCTAssertEqual(fixture.attachment.adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        }
        XCTAssertEqual(fixture.view.accessibilityRole(), .textArea)
        XCTAssertFalse(fixture.view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedText:")))
        fixture.view.setAccessibilitySelectedText("changed")
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.view.accessibilityValue() as? String, "にabc")
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.host.publications, 0)
    }

    func testInvalidAccessibilitySelectionAndStaleRevisionCannotChangeDocument() throws {
        let fixture = try AccessibilityResponderFixture("a😀b")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        fixture.view.setAccessibilitySelectedTextRange(NSRange(location: 2, length: 0))
        XCTAssertEqual(fixture.host.text, "a😀b")
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        fixture.queue.runAll()
        fixture.host.text = "newer"
        fixture.host.inputRevision = UUID()
        fixture.view.setAccessibilityValue("stale")
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.text, "newer")
        XCTAssertEqual(fixture.host.publications, 0)
    }

    func testExplicitFocusEligibilityAndDisarmSuppressAccessibilityImmediately() throws {
        let fixture = try AccessibilityResponderFixture("abc")
        let view = fixture.view
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertTrue(view.requestFocusEligibility())
        XCTAssertTrue(view.acceptsFirstResponder)
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        XCTAssertEqual(view.accessibilityRole(), .textArea)
        view.disarmForDetachment()
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertFalse(view.requestFocusEligibility())
        XCTAssertEqual(view.accessibilityRole(), .staticText)
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilityValue:")))
        view.setAccessibilityValue("stale")
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertFalse(fixture.attachment.disconnect())
        fixture.queue.runAll()
        XCTAssertTrue(fixture.attachment.disconnect())
        XCTAssertEqual(fixture.host.text, "abc")
    }

    func testNotificationsDeferredWhileSuppressedReplayAfterReactivation() throws {
        let fixture = try AccessibilityResponderFixture("old")
        let view = fixture.view
        var posted: [NSAccessibility.Notification] = []
        var onNotification: ((NSAccessibility.Notification) -> Void)?
        view.accessibilityNotificationPoster = { _, notification in
            XCTAssertTrue(Thread.isMainThread)
            posted.append(notification)
            onNotification?(notification)
        }
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        // Flush initial availability notifications before exercising replay.
        let initialTurn = expectation(description: "initial accessibility notifications")
        DispatchQueue.main.async { initialTurn.fulfill() }
        wait(for: [initialTurn], timeout: 1)
        posted.removeAll()

        XCTAssertEqual(fixture.setSelection(NSRange(location: 1, length: 1)), .processed)
        fixture.host.text = "newer"
        fixture.host.inputRevision = UUID()
        fixture.attachment.connection.suspendForFocusLoss()
        fixture.queue.runAll()
        let suppressedTurn = expectation(description: "suppressed notifications attempted")
        DispatchQueue.main.async { suppressedTurn.fulfill() }
        wait(for: [suppressedTurn], timeout: 1)
        XCTAssertNil(view.accessibilityValue())
        XCTAssertEqual(view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertTrue(posted.isEmpty)

        let value = expectation(description: "current accessibility value notification")
        let selection = expectation(description: "current accessibility selection notification")
        onNotification = { notification in
            if notification == .valueChanged { value.fulfill() }
            if notification == .selectedTextChanged { selection.fulfill() }
        }
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        wait(for: [value, selection], timeout: 1)
        onNotification = nil
        XCTAssertEqual(view.accessibilityValue() as? String, "newer")
        XCTAssertEqual(view.accessibilitySelectedTextRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(posted.filter { $0 == .valueChanged }.count, 1)
        XCTAssertEqual(posted.filter { $0 == .selectedTextChanged }.count, 1)
    }

    func testSelectionNotificationWaitsForAdapterIdleGuardToUnwind() throws {
        let fixture = try AccessibilityResponderFixture("abc")
        let view = fixture.view
        var observing = false
        var insideIdleWork = false
        var deliveredDuringIdleWork = false
        let delivered = expectation(description: "selection notification after idle work")
        view.accessibilityNotificationPoster = { _, notification in
            guard observing, notification == .selectedTextChanged else { return }
            if insideIdleWork { deliveredDuringIdleWork = true }
            else { delivered.fulfill() }
        }
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        let initialTurn = expectation(description: "initial accessibility notifications")
        DispatchQueue.main.async { initialTurn.fulfill() }
        wait(for: [initialTurn], timeout: 1)
        observing = true

        XCTAssertEqual(fixture.setSelection(NSRange(location: 1, length: 1)), .processed)
        fixture.attachment.adapter.whenInputActivityIdle {
            insideIdleWork = true
            let nestedTurn = self.expectation(description: "nested main turn during adapter idle work")
            DispatchQueue.main.async { nestedTurn.fulfill() }
            self.wait(for: [nestedTurn], timeout: 1)
            XCTAssertFalse(deliveredDuringIdleWork)
            insideIdleWork = false
        }
        fixture.queue.runAll()
        wait(for: [delivered], timeout: 1)
        XCTAssertFalse(deliveredDuringIdleWork)
        XCTAssertEqual(view.accessibilitySelectedTextRange(), NSRange(location: 1, length: 1))
    }

    func testStaleResetAndRetirementSuppressTextAndSelection() throws {
        let fixture = try AccessibilityResponderFixture("old")
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        XCTAssertEqual(fixture.setSelection(NSRange(location: 1, length: 1)), .processed)
        XCTAssertEqual(fixture.view.accessibilitySelectedText(), "l")

        fixture.host.text = "newer"
        fixture.host.inputRevision = UUID()
        XCTAssertNil(fixture.view.accessibilityValue())
        XCTAssertEqual(fixture.view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertNil(fixture.view.accessibilitySelectedText())
        XCTAssertFalse(fixture.view.isAccessibilityElement())
        fixture.queue.runAll()
        // Reconstructed input is inactive until its host re-establishes focus.
        XCTAssertNil(fixture.view.accessibilityValue())
        XCTAssertTrue(fixture.attachment.connection.resumeForFocus())
        XCTAssertEqual(fixture.view.accessibilityValue() as? String, "newer")
        XCTAssertEqual(fixture.view.accessibilitySelectedTextRange(), NSRange(location: 0, length: 0))

        fixture.view.retireInputView()
        XCTAssertFalse(fixture.view.isAccessibilityElement())
        XCTAssertNil(fixture.view.accessibilityValue())
        XCTAssertEqual(fixture.view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertNil(fixture.view.accessibilitySelectedText())
    }
}

private final class AccessibilityResponderFixture {
    let host: AccessibilityResponderHost
    let queue = AccessibilityResponderQueue()
    let attachment: PreparedInputDocumentAttachment
    var view: PreparedInputResponderView { attachment.view as! PreparedInputResponderView }

    init(_ text: String) throws {
        let host = AccessibilityResponderHost(text)
        let queue = self.queue
        self.host = host
        self.attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { AccessibilityResponderDriver($0) }, schedule: queue.enqueue))
    }

    func setSelection(_ range: NSRange) -> PreparedInputEventAdapter.Outcome {
        var outcome: PreparedInputEventAdapter.Outcome = .unavailable
        _ = attachment.connection.performCoordinatedInput { outcome = self.attachment.adapter.setSelection(range) }
        return outcome
    }
}

private final class AccessibilityResponderDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let object = NSObject()
    init(_ client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class AccessibilityResponderHost: RunestoneInputDispatchHost {
    var text: String
    var inputRevision = UUID()
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    var busy = false
    var parentOpen = false
    var childOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var childStarts = 0
    var childCloses = 0
    var publications = 0
    var completions: [RunestoneInputDispatchCompletion] = []
    init(_ text: String) { self.text = text }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        parentOpen = true
        parentStarts += 1
        return .reserved(AccessibilityResponderDispatch(self))
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        completions.append(completion)
    }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        return .reserved(AccessibilityResponderEvent(self, child: false))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(AccessibilityResponderSnapshot(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class AccessibilityResponderDispatch: RunestoneInputDispatchReservation {
    let host: AccessibilityResponderHost
    init(_ host: AccessibilityResponderHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        guard host.parentOpen, !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true
        host.childStarts += 1
        return .reserved(AccessibilityResponderEvent(host, child: true))
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertFalse(host.childOpen)
        host.parentOpen = false
        host.busy = false
        host.parentCloses += 1
    }
}

private final class AccessibilityResponderEvent: RunestoneInputEventReservation {
    let host: AccessibilityResponderHost
    let child: Bool
    init(_ host: AccessibilityResponderHost, child: Bool) { self.host = host; self.child = child }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        AccessibilityResponderPublication(host, text: candidate.string)
    }
    func close() {
        if child {
            XCTAssertTrue(host.parentOpen)
            host.childOpen = false
            host.childCloses += 1
        } else { host.busy = false }
    }
}

private final class AccessibilityResponderPublication: RunestoneInputPreparedPublication {
    let host: AccessibilityResponderHost
    let text: String
    init(_ host: AccessibilityResponderHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.publications += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected publication reconciliation") }
}

private final class AccessibilityResponderSnapshot: RunestoneInputReconstructionReservation {
    let host: AccessibilityResponderHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: AccessibilityResponderHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text)
        revision = host.inputRevision
    }
    func close() { host.busy = false }
}

private final class AccessibilityResponderQueue {
    private var work: [() -> Void] = []
    func enqueue(_ block: @escaping () -> Void) { work.append(block) }
    func runAll() {
        var limit = 100
        while !work.isEmpty, limit > 0 {
            limit -= 1
            work.removeFirst()()
        }
        if !work.isEmpty { XCTFail("Input queue did not settle") }
    }
}
#endif
