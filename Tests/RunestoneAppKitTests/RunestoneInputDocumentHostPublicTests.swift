#if canImport(AppKit)
import AppKit
import RunestoneAppKit
import XCTest

// Intentionally use the public module interface: an app target must be able to
// supply the gate without importing framework internals.
final class RunestoneInputDocumentHostPublicTests: XCTestCase {
    func testHostCanSupplyEventAndReconstructionReservations() {
        let host = PublicTestHost()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "old"))
        let revision = host.inputRevision
        guard case let .reserved(event) = host.beginInputEvent(expectedRevision: revision, source: view) else {
            return XCTFail("Expected an event reservation")
        }
        let change = event.prepare(candidate: NSAttributedString(string: "new"))
        XCTAssertNotNil(change)
        change?.publish()
        change?.finish()
        event.close()
        XCTAssertEqual(host.text, "new")
        XCTAssertNotEqual(host.inputRevision, revision)
        guard case let .reserved(reconstruction) = host.beginInputReconstruction() else {
            return XCTFail("Expected a reconstruction reservation")
        }
        XCTAssertEqual(reconstruction.snapshot.string, "new")
        XCTAssertEqual(reconstruction.revision, host.inputRevision)
        reconstruction.close()
        let bridge = RunestoneInputDocumentBridge()
        bridge.canonicalDocumentDidChange()
        bridge.documentGateDidBecomeAvailable()
    }

    func testHostCanCoordinateSequentialOperationsAndAcknowledgeDispatch() {
        let host = PublicDispatchHost()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "old"))
        let initial = host.inputRevision
        guard case let .reserved(dispatch) = host.beginInputDispatch(expectedRevision: initial, source: view) else {
            return XCTFail("Expected a dispatch reservation")
        }
        guard case .busy = host.beginInputReconstruction() else { return XCTFail("Outer gate must remain held") }
        guard case let .reserved(first) = dispatch.beginInputOperation(expectedRevision: initial) else {
            return XCTFail("Expected the first operation")
        }
        let firstChange = first.prepare(candidate: NSAttributedString(string: "one"))
        firstChange?.publish()
        firstChange?.finish()
        first.close()
        let next = host.inputRevision
        XCTAssertNotEqual(initial, next)
        guard case .stale = dispatch.beginInputOperation(expectedRevision: initial) else {
            return XCTFail("A child must reject the old revision")
        }
        guard case let .reserved(second) = dispatch.beginInputOperation(expectedRevision: next) else {
            return XCTFail("Expected a second operation under the same outer gate")
        }
        let secondChange = second.prepare(candidate: NSAttributedString(string: "two"))
        secondChange?.publish()
        secondChange?.finish()
        second.close()
        let final = host.inputRevision
        dispatch.close()
        let completion = RunestoneInputDispatchCompletion(kind: .inputDispatch, id: UUID(),
            expectedRevision: initial, finalRevision: final, outcome: .completed)
        host.inputDispatchDidComplete(completion, source: view)
        XCTAssertEqual(host.completion, completion)
        XCTAssertTrue(host.source === view)
        XCTAssertEqual(host.text, "two")
        XCTAssertFalse(host.busy)
    }

}

private final class PublicTestHost: RunestoneInputDocumentHost {
    var inputRevision = UUID()
    var text = "old"
    var busy = false
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        return .reserved(PublicTestEvent(host: self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(PublicTestReconstruction(host: self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class PublicTestEvent: RunestoneInputEventReservation {
    private let host: PublicTestHost
    init(host: PublicTestHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> (RunestoneInputPreparedPublication)? {
        PublicTestPublication(host: host, text: candidate.string)
    }
    func close() { host.busy = false }
}

private final class PublicTestPublication: RunestoneInputPreparedPublication {
    private let host: PublicTestHost
    private let text: String
    init(host: PublicTestHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() {}
    func reconcile(_ phase: RunestoneInputReconciliationPhase) {
        switch phase {
        case .beforeFinish, .afterFinish, .afterNotification: break
        }
    }
}

private final class PublicTestReconstruction: RunestoneInputReconstructionReservation {
    private let host: PublicTestHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(host: PublicTestHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text)
        revision = host.inputRevision
    }
    func close() { host.busy = false }
}

private final class PublicDispatchHost: RunestoneInputDispatchHost {
    var inputRevision = UUID()
    var text = "old"
    var busy = false
    var childActive = false
    var completion: RunestoneInputDispatchCompletion?
    weak var source: ReadOnlyDocumentView?

    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        return .reserved(PublicDispatchReservation(host: self))
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        self.completion = completion
        self.source = source
    }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        .busy
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart { .busy }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class PublicDispatchReservation: RunestoneInputDispatchReservation {
    private let host: PublicDispatchHost
    init(host: PublicDispatchHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        guard host.busy, !host.childActive else { return .busy }
        guard host.inputRevision == expectedRevision else { return .stale }
        host.childActive = true
        return .reserved(PublicDispatchOperation(host: host))
    }
    func close() { host.busy = false }
}

private final class PublicDispatchOperation: RunestoneInputEventReservation {
    private let host: PublicDispatchHost
    init(host: PublicDispatchHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        PublicDispatchPublication(host: host, text: candidate.string)
    }
    func close() { host.childActive = false }
}

private final class PublicDispatchPublication: RunestoneInputPreparedPublication {
    private let host: PublicDispatchHost
    private let text: String
    init(host: PublicDispatchHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() {}
    func reconcile(_ phase: RunestoneInputReconciliationPhase) {}
}

#endif
