#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputViewSynchronizerTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testBusyComposingViewAdoptsNewestCanonicalRevisionWithoutRestoringOldBaseline() throws {
        _ = NSApplication.shared
        let queue = SyncQueue()
        let synchronizer = PreparedInputViewSynchronizer(schedule: queue.enqueue)
        let document = SyncDocument(text: "abc", synchronizer: synchronizer)
        let first = try SyncView(document: document, synchronizer: synchronizer, queue: queue)
        let second = try SyncView(document: document, synchronizer: synchronizer, queue: queue)
        XCTAssertTrue(first.connection.activate())
        XCTAssertTrue(second.connection.activate())
        let oldFirst = try XCTUnwrap(first.drivers.first?.client)
        let oldSecond = try XCTUnwrap(second.drivers.first?.client)
        let retainedContext = try XCTUnwrap(second.drivers.first?.context)
        oldSecond.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(second.view.content.string, "にabc")
        XCTAssertEqual(document.text, "abc")

        document.onFinish = {
            XCTAssertTrue(document.busy)
            XCTAssertFalse(oldSecond.hasMarkedText())
            oldSecond.insertText("bad", replacementRange: self.unspecified)
            XCTAssertEqual(document.text, "oneabc")
            queue.runAll() // Real teardown may run in a nested loop while the document gate is held.
            XCTAssertEqual(second.drivers.count, 1)
            XCTAssertEqual(second.drivers[0].discards, 1)
            XCTAssertEqual(second.view.content.string, "にabc")
            XCTAssertEqual(document.undoCount, 1)
        }
        oldFirst.insertText("one", replacementRange: unspecified)
        document.onFinish = nil
        XCTAssertEqual(document.text, "oneabc")
        XCTAssertEqual(first.drivers.count, 1) // The current accepted origin was excluded.
        XCTAssertEqual(oldFirst.selectedRange(), NSRange(location: 3, length: 0))

        // Another document operation starts before the queued release signal is
        // delivered. Every view must converge to the latest of its revisions.
        document.beginExternalChange()
        document.replaceExternally("newer")
        document.replaceExternally("newest")
        queue.runAll()
        XCTAssertEqual(second.drivers.count, 1)
        XCTAssertEqual(document.text, "newest")
        XCTAssertEqual(document.undoCount, 1)
        document.endExternalChange()
        queue.runAll()
        XCTAssertEqual(first.view.content.string, "newest")
        XCTAssertEqual(second.view.content.string, "newest")
        XCTAssertEqual(first.drivers.count, 2)
        XCTAssertEqual(second.drivers.count, 2)
        XCTAssertEqual(oldSecond.selectedRange().location, NSNotFound)
        oldSecond.insertText("old", replacementRange: unspecified)
        XCTAssertEqual(document.text, "newest")
        XCTAssertEqual(document.undoCount, 1)
        withExtendedLifetime(retainedContext) {}
        XCTAssertFalse(first.connection.disconnect())
        XCTAssertFalse(second.connection.disconnect())
        queue.runAll()
        XCTAssertTrue(first.connection.isDisconnected)
        XCTAssertTrue(second.connection.isDisconnected)
    }

    func testRegistrationDoesNotOwnConnectionAndUnregistrationInvalidatesQueuedWake() throws {
        _ = NSApplication.shared
        let queue = SyncQueue()
        let synchronizer = PreparedInputViewSynchronizer(schedule: queue.enqueue)
        let document = SyncDocument(text: "abc", synchronizer: synchronizer)
        var host: SyncView? = try SyncView(document: document, synchronizer: synchronizer, queue: queue)
        let hostValue = try XCTUnwrap(host)
        XCTAssertTrue(synchronizer.register(hostValue.connection) === hostValue.registration)
        document.beginExternalChange()
        document.replaceExternally("next")
        queue.runAll()
        XCTAssertEqual(hostValue.drivers.count, 1)
        document.endExternalChange() // A wake is queued, then the registration is removed.
        synchronizer.unregister(hostValue.registration)
        queue.runAll()
        XCTAssertEqual(hostValue.drivers.count, 1)
        XCTAssertEqual(hostValue.view.content.string, "abc")
        hostValue.connection.resumeAfterQuiescing()
        XCTAssertEqual(hostValue.view.content.string, "next")
        XCTAssertFalse(hostValue.connection.disconnect())
        queue.runAll()
        XCTAssertTrue(hostValue.connection.isDisconnected)
        // There is no strong coordinator-to-connection reference, even if a
        // registration is left behind by an owner that disappears.
        var other: SyncView? = try SyncView(document: document, synchronizer: synchronizer, queue: queue)
        weak var oldConnection = other?.connection
        XCTAssertFalse(try XCTUnwrap(other).connection.disconnect())
        queue.runAll()
        other = nil
        XCTAssertNil(oldConnection)
        synchronizer.canonicalDidChange()
        host = nil
    }
}

private final class SyncView {
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter
    let connection: PreparedInputContextConnection
    let registration: PreparedInputViewSynchronizer.Registration
    private let storage: SyncDrivers
    var drivers: [SyncDriver] { storage.values }

    init(document: SyncDocument, synchronizer: PreparedInputViewSynchronizer, queue: SyncQueue) throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: document.text))
        let token = SyncRegistrationBox()
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: document.revision, documentRevision: { document.revision }, typingAttributes: { [:] },
            beginEvent: { document.begin($0, origin: token.registration) },
            beginReconstruction: { document.beginReconstruction() }, requestReset: {}, schedule: queue.enqueue))
        let storage = SyncDrivers()
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = SyncDriver(client: client)
            storage.values.append(driver)
            return driver
        }, schedule: queue.enqueue))
        let registration = synchronizer.register(connection)
        token.registration = registration
        self.view = view
        self.adapter = adapter
        self.connection = connection
        self.registration = registration
        self.storage = storage
    }
}

private final class SyncRegistrationBox {
    var registration: PreparedInputViewSynchronizer.Registration?
}
private final class SyncDrivers { var values: [SyncDriver] = [] }

private final class SyncDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let context: NSTextInputContext
    var discards = 0
    init(client: NSTextInputClient) { self.client = client; context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    func activate() { context.activate() }
    func handle(_ event: NSEvent) -> Bool { context.handleEvent(event) }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func discardMarkedText() { discards += 1; context.discardMarkedText() }
    func deactivate() { context.deactivate() }
}

private final class SyncDocument {
    var text: String
    var revision = UUID()
    private(set) var busy = false
    private(set) var undoCount = 0
    var onFinish: (() -> Void)?
    private let synchronizer: PreparedInputViewSynchronizer
    init(text: String, synchronizer: PreparedInputViewSynchronizer) {
        self.text = text
        self.synchronizer = synchronizer
    }
    func begin(_ expected: UUID, origin: PreparedInputViewSynchronizer.Registration?) -> PreparedInputEventAdapter.ReservationResult {
        guard !busy else { return .busy }
        guard expected == revision else { return .stale }
        busy = true
        return .reserved(.init(prepare: { [self] candidate in
            let accepted = candidate.string
            return .init(publish: { [self] in text = accepted; revision = UUID() },
                         finish: { [self] in
                             undoCount += 1
                             synchronizer.canonicalDidChange(excluding: origin)
                             onFinish?()
                         }, reconcile: { _ in XCTFail("Unexpected conflict") })
        }, close: { [self] in
            busy = false
            synchronizer.documentGateDidBecomeAvailable()
        }))
    }
    func beginReconstruction() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision, close: { [self] in
            busy = false
            synchronizer.documentGateDidBecomeAvailable()
        }))
    }
    func beginExternalChange() { precondition(!busy); busy = true }
    func replaceExternally(_ text: String) {
        precondition(busy)
        self.text = text
        revision = UUID()
        synchronizer.canonicalDidChange()
    }
    func endExternalChange() {
        precondition(busy)
        busy = false
        synchronizer.documentGateDidBecomeAvailable()
    }
}

private final class SyncQueue {
    private var pending: [() -> Void] = []
    func enqueue(_ block: @escaping () -> Void) { pending.append(block) }
    func runAll() {
        var limit = 200
        while !pending.isEmpty {
            guard limit > 0 else { XCTFail("Queue failed to settle"); return }
            limit -= 1
            pending.removeFirst()()
        }
    }
}
#endif
