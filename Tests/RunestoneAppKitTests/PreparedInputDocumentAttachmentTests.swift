#if canImport(AppKit)
import AppKit
import ObjectiveC
@testable import RunestoneAppKit
import XCTest

final class PreparedInputDocumentAttachmentTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testPublicGateWiringSynchronizesComposingViewAndClosesLeases() throws {
        _ = NSApplication.shared
        let host = AttachmentTestHost(text: "abc")
        var firstDrivers: [AttachmentTestDriver] = []
        var secondDrivers: [AttachmentTestDriver] = []
        let rebuilt = expectation(description: "second view adopts the committed revision")
        let first = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge, makeDriver: { client in
            let driver = AttachmentTestDriver(client)
            firstDrivers.append(driver)
            return driver
        }))
        let second = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge, makeDriver: { client in
            let driver = AttachmentTestDriver(client)
            secondDrivers.append(driver)
            if secondDrivers.count == 2 { rebuilt.fulfill() }
            return driver
        }))
        let oldSecond = try XCTUnwrap(secondDrivers.first?.client)
        oldSecond.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(second.view.content.string, "にabc")
        XCTAssertEqual(host.text, "abc")
        try XCTUnwrap(firstDrivers.first?.client).insertText("new", replacementRange: unspecified)
        XCTAssertEqual(host.text, "newabc")
        XCTAssertEqual(host.undoCount, 1)
        XCTAssertEqual(oldSecond.markedRange().location, NSNotFound)
        wait(for: [rebuilt], timeout: 2)
        XCTAssertEqual(firstDrivers.count, 1)
        XCTAssertEqual(second.view.content.string, "newabc")
        oldSecond.insertText("stale", replacementRange: unspecified)
        XCTAssertEqual(host.text, "newabc")
        XCTAssertEqual(host.undoCount, 1)
        XCTAssertEqual(host.eventStarts, host.eventCloses)
        XCTAssertEqual(host.reconstructionStarts, host.reconstructionCloses)
        XCTAssertFalse(first.disconnect())
        XCTAssertFalse(second.disconnect())
        let disconnected = expectation(description: "both contexts disconnected")
        var attempts = 0
        func finishDisconnect() {
            if first.disconnect() && second.disconnect() { disconnected.fulfill() }
            else if attempts < 100 {
                attempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: finishDisconnect)
            } else {
                XCTFail("Connections did not disconnect")
                disconnected.fulfill()
            }
        }
        DispatchQueue.main.async(execute: finishDisconnect)
        wait(for: [disconnected], timeout: 2)
        XCTAssertEqual(host.reconstructionStarts, host.reconstructionCloses)
    }

    func testRejectedInitialSnapshotClosesLeaseAndDoesNotCreateContext() {
        let host = AttachmentTestHost(text: "abc")
        host.onCapture = { host.inputRevision = UUID() }
        var contexts = 0
        XCTAssertNil(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { input in contexts += 1; return AttachmentTestDriver(input) }))
        XCTAssertEqual(contexts, 0)
        XCTAssertEqual(host.reconstructionStarts, 1)
        XCTAssertEqual(host.reconstructionCloses, 1)
        XCTAssertFalse(host.busy)
        host.onCapture = nil
    }

    func testLifetimeInvalidationDuringDriverCreationFailsAttachmentAndDiscards() {
        _ = NSApplication.shared
        let host = AttachmentTestHost(text: "abc")
        let discarded = expectation(description: "unexposed context discarded")
        let attachment = PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { input in
                let driver = AttachmentTestDriver(input)
                driver.onDiscard = { discarded.fulfill() }
                host.lifetime.invalidate()
                return driver
            })
        XCTAssertNil(attachment)
        XCTAssertFalse(host.busy)
        wait(for: [discarded], timeout: 2)
        XCTAssertEqual(host.reconstructionStarts, host.reconstructionCloses)
    }

    func testInvalidatedLifetimeDiscardsActiveContextWithoutDocumentGate() throws {
        _ = NSApplication.shared
        let host = AttachmentTestHost(text: "abc")
        let discarded = expectation(description: "old context discarded")
        let deactivated = expectation(description: "old context deactivated")
        var driver: AttachmentTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { input in
                let value = AttachmentTestDriver(input)
                value.onDiscard = {
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertFalse(value.client?.hasMarkedText() ?? true)
                    value.client?.insertText("stale", replacementRange: self.unspecified)
                    XCTAssertEqual(host.text, "abc")
                    discarded.fulfill()
                }
                value.onDeactivate = {
                    XCTAssertTrue(Thread.isMainThread)
                    deactivated.fulfill()
                }
                driver = value
                return value
            }))
        XCTAssertTrue(attachment.connection.activate())
        driver?.client?.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(attachment.view.content.string, "にabc")
        host.busy = true // Abandonment must not try to reacquire the document gate.
        host.lifetime.invalidate()
        XCTAssertTrue(attachment.view.isRetired)
        XCTAssertEqual(attachment.view.content.string, "")
        wait(for: [discarded, deactivated], timeout: 2)
        let disconnected = expectation(for: NSPredicate { _, _ in attachment.connection.isDisconnected }, evaluatedWith: nil)
        wait(for: [disconnected], timeout: 2)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertEqual(driver?.discards, 1)
        XCTAssertEqual(driver?.deactivations, 1)
        driver?.onDiscard = nil
        driver?.onDeactivate = nil
    }

    func testBridgeRejectsASecondDocumentHost() throws {
        let firstHost = AttachmentTestHost(text: "one")
        let secondHost = AttachmentTestHost(text: "two")
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: firstHost, lifetime: firstHost.lifetime,
                                                                              bridge: firstHost.bridge,
                                                                              makeDriver: { AttachmentTestDriver($0) }))
        XCTAssertNil(PreparedInputDocumentAttachment.attach(host: secondHost, lifetime: firstHost.lifetime,
                                                            bridge: firstHost.bridge))
        XCTAssertEqual(secondHost.reconstructionStarts, 0)
        XCTAssertFalse(attachment.disconnect())
        let disconnected = expectation(for: NSPredicate { _, _ in attachment.connection.isDisconnected }, evaluatedWith: nil)
        wait(for: [disconnected], timeout: 2)
        XCTAssertTrue(attachment.disconnect())
    }

    func testLosingBridgeAbandonsRetainedAttachment() throws {
        let host = AttachmentTestHost(text: "abc")
        var bridge: RunestoneInputDocumentBridge? = RunestoneInputDocumentBridge()
        let discarded = expectation(description: "context discarded after bridge loss")
        var driver: AttachmentTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime,
            bridge: try XCTUnwrap(bridge), makeDriver: { input in
                let value = AttachmentTestDriver(input)
                value.onDiscard = { discarded.fulfill() }
                driver = value
                return value
            }))
        XCTAssertTrue(attachment.connection.activate())
        driver?.client?.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        bridge = nil
        XCTAssertTrue(attachment.view.isRetired)
        wait(for: [discarded], timeout: 2)
        let disconnected = expectation(for: NSPredicate { _, _ in attachment.connection.isDisconnected }, evaluatedWith: nil)
        wait(for: [disconnected], timeout: 2)
        XCTAssertEqual(host.text, "abc")
        driver?.onDiscard = nil
    }

    func testInvalidationDuringActivationWaitsForDriverReturn() throws {
        _ = NSApplication.shared
        let host = AttachmentTestHost(text: "abc")
        let teardownScheduled = expectation(description: "lifetime invalidation delivered on main")
        let deactivated = expectation(description: "context deactivated")
        var driver: AttachmentTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { input in
                let value = AttachmentTestDriver(input)
                value.onActivate = {
                    host.lifetime.invalidate()
                    DispatchQueue.main.async { teardownScheduled.fulfill() }
                    self.wait(for: [teardownScheduled], timeout: 2) // Nested event loop while activate is on stack.
                    XCTAssertEqual(value.discards, 0)
                    XCTAssertEqual(value.deactivations, 0)
                }
                value.onDeactivate = { deactivated.fulfill() }
                driver = value
                return value
            }))
        XCTAssertFalse(attachment.connection.activate())
        XCTAssertTrue(attachment.view.isRetired)
        wait(for: [deactivated], timeout: 2)
        XCTAssertEqual(driver?.discards, 1)
        XCTAssertEqual(driver?.deactivations, 1)
        let disconnected = expectation(for: NSPredicate { _, _ in attachment.connection.isDisconnected }, evaluatedWith: nil)
        wait(for: [disconnected], timeout: 2)
        driver?.onActivate = nil
        driver?.onDeactivate = nil
    }

    func testOffMainAttachmentReleaseDestroysDriverAndViewOnMain() throws {
        _ = NSApplication.shared
        let host = AttachmentTestHost(text: "abc")
        let driverReleased = expectation(description: "driver released on main")
        let viewReleased = expectation(description: "view released on main")
        var attachment: PreparedInputDocumentAttachment? = PreparedInputDocumentAttachment.attach(
            host: host, lifetime: host.lifetime, bridge: host.bridge, makeDriver: { input in
                let driver = AttachmentTestDriver(input)
                driver.onDeinit = {
                    XCTAssertTrue(Thread.isMainThread)
                    driverReleased.fulfill()
                }
                return driver
            })
        do {
            let view = try XCTUnwrap(attachment?.view)
            objc_setAssociatedObject(view, &attachmentProbeKey, AttachmentDeinitProbe {
                XCTAssertTrue(Thread.isMainThread)
                viewReleased.fulfill()
            }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let holder = AttachmentHolder(attachment)
        attachment = nil
        let released = expectation(description: "attachment released off main")
        DispatchQueue.global().async {
            holder.attachment = nil
            released.fulfill()
        }
        wait(for: [released, driverReleased, viewReleased], timeout: 2)
    }

    func testHostLifetimeQuarantinesRetainedAttachmentWithoutCycle() throws {
        var host: AttachmentTestHost? = AttachmentTestHost(text: "abc")
        weak let weakHost = host
        var driver: AttachmentTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attach(host: try XCTUnwrap(host),
            lifetime: try XCTUnwrap(host).lifetime, bridge: try XCTUnwrap(host).bridge,
            makeDriver: { input in let value = AttachmentTestDriver(input); driver = value; return value }))
        driver?.client?.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(attachment.view.content.string, "Xabc")
        host = nil
        XCTAssertNil(weakHost)
        XCTAssertTrue(attachment.view.isRetired)
        XCTAssertEqual(attachment.view.content.string, "")
        driver?.client?.insertText("stale", replacementRange: unspecified)
        XCTAssertEqual(attachment.view.content.string, "")
    }
}

private final class AttachmentTestHost: RunestoneInputDocumentHost {
    var text: String
    var inputRevision = UUID()
    let bridge = RunestoneInputDocumentBridge()
    let lifetime = RunestoneInputDocumentLifetime()
    var busy = false
    var eventStarts = 0
    var eventCloses = 0
    var reconstructionStarts = 0
    var reconstructionCloses = 0
    var undoCount = 0
    var onCapture: (() -> Void)?
    init(text: String) { self.text = text }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        eventStarts += 1
        return .reserved(AttachmentEventLease(host: self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        reconstructionStarts += 1
        let lease = AttachmentSnapshotLease(host: self, snapshot: NSAttributedString(string: text), revision: inputRevision)
        onCapture?()
        return .reserved(lease)
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class AttachmentEventLease: RunestoneInputEventReservation {
    let host: AttachmentTestHost
    init(host: AttachmentTestHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        AttachmentPublication(host: host, text: candidate.string)
    }
    func close() {
        XCTAssertTrue(host.busy)
        host.busy = false
        host.eventCloses += 1
    }
}

private final class AttachmentPublication: RunestoneInputPreparedPublication {
    let host: AttachmentTestHost
    let text: String
    init(host: AttachmentTestHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.undoCount += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected reconciliation") }
}

private final class AttachmentSnapshotLease: RunestoneInputReconstructionReservation {
    let host: AttachmentTestHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(host: AttachmentTestHost, snapshot: NSAttributedString, revision: UUID) {
        self.host = host
        self.snapshot = snapshot
        self.revision = revision
    }
    func close() {
        XCTAssertTrue(host.busy)
        host.busy = false
        host.reconstructionCloses += 1
    }
}

private final class AttachmentTestDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let object = NSObject()
    var onActivate: (() -> Void)?
    var onDiscard: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var onDeinit: (() -> Void)?
    var discards = 0
    var deactivations = 0
    init(_ client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { object }
    func activate() { onActivate?() }
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() { discards += 1; onDiscard?() }
    func deactivate() { deactivations += 1; onDeactivate?() }
    deinit { onDeinit?() }
}

private var attachmentProbeKey: UInt8 = 0
private final class AttachmentDeinitProbe {
    private let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    deinit { callback() }
}
private final class AttachmentHolder {
    var attachment: PreparedInputDocumentAttachment?
    init(_ attachment: PreparedInputDocumentAttachment?) { self.attachment = attachment }
}
#endif
