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
#endif
