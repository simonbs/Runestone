#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputContextConnectionTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testStaleCompositionDiscardsContextBeforeReconstructingNewestSnapshot() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        let oldDriver = try XCTUnwrap(drivers.first)
        let oldClient = try XCTUnwrap(oldDriver.client)
        let oldContext = oldDriver.context
        oldClient.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(oldClient.hasMarkedText())
        XCTAssertEqual(view.content.string, "にabc")
        owner.text = "newest"
        owner.revision = UUID()
        oldDriver.onDiscard = {
            XCTAssertFalse(oldClient.hasMarkedText())
            XCTAssertEqual(oldClient.markedRange().location, NSNotFound)
            oldClient.insertText("bad", replacementRange: self.unspecified)
            XCTAssertEqual(owner.text, "newest")
            XCTAssertEqual(view.content.string, "にabc")
        }
        oldDriver.onDeactivate = {
            oldClient.setMarkedText("bad", selectedRange: NSRange(location: 3, length: 0), replacementRange: self.unspecified)
        }
        oldClient.insertText("stale", replacementRange: unspecified)
        XCTAssertEqual(view.content.string, "にabc")
        queue.runAll()
        XCTAssertEqual(oldDriver.discards, 1)
        XCTAssertEqual(oldDriver.deactivations, 1)
        XCTAssertEqual(view.content.string, "newest")
        XCTAssertEqual(owner.text, "newest")
        XCTAssertEqual(owner.undoCount, 0)
        XCTAssertEqual(drivers.count, 2)
        XCTAssertEqual(oldClient.selectedRange().location, NSNotFound)
        oldClient.insertText("old", replacementRange: unspecified)
        XCTAssertEqual(owner.text, "newest")
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
        oldDriver.onDiscard = nil
        oldDriver.onDeactivate = nil
        withExtendedLifetime(oldContext) {}
    }

    func testNestedQueueDuringActivationWaitsForDriverReturn() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var first: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            if first == nil { first = driver }
            return driver
        }, schedule: queue.enqueue))
        first?.onActivate = {
            owner.text = "newer"
            owner.revision = UUID()
            first?.client?.insertText("stale", replacementRange: self.unspecified)
            queue.runAll() // Simulate a nested main event loop while activate is on the stack.
            XCTAssertEqual(first?.discards, 0)
            XCTAssertEqual(view.content.string, "abc")
        }
        XCTAssertFalse(connection.activate())
        XCTAssertEqual(first?.discards, 0)
        queue.runAll()
        XCTAssertEqual(first?.discards, 1)
        XCTAssertEqual(view.content.string, "newer")
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
        first?.onActivate = nil
    }

    func testBusyReconstructionRemainsInertUntilExplicitRetry() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        var blocked = 0
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue, blocked: { blocked += 1 }))
        let oldClient = try XCTUnwrap(drivers.first?.client)
        owner.text = "newer"
        owner.revision = UUID()
        owner.reconstructionBusy = true
        oldClient.insertText("stale", replacementRange: unspecified)
        queue.runAll()
        XCTAssertEqual(blocked, 1)
        XCTAssertEqual(drivers.count, 1)
        XCTAssertEqual(oldClient.selectedRange().location, NSNotFound)
        XCTAssertNil(view.claimInputMutation())
        owner.reconstructionBusy = false
        connection.resumeAfterQuiescing()
        XCTAssertEqual(drivers.count, 2)
        XCTAssertEqual(view.content.string, "newer")
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testBlockedCallbackCanSignalReadinessBeforeItReturns() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        weak var weakConnection: PreparedInputContextConnection?
        var blocked = 0
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue, blocked: {
            blocked += 1
            owner.reconstructionBusy = false
            weakConnection?.resumeAfterQuiescing()
        }))
        weakConnection = connection
        owner.reconstructionBusy = true
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(blocked, 1)
        XCTAssertEqual(drivers.count, 2)
        XCTAssertEqual(drivers[1].client?.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testRepeatedBlockedCallbackRetryDoesNotSpinAndPreservesClose() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        weak var weakConnection: PreparedInputContextConnection?
        var blocked = 0
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue, blocked: {
            blocked += 1
            _ = weakConnection?.disconnect()
        }))
        weakConnection = connection
        owner.reconstructionBusy = true
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(blocked, 1)
        XCTAssertFalse(connection.isDisconnected)
        XCTAssertEqual(drivers.count, 1)
        owner.reconstructionBusy = false
        connection.resumeAfterQuiescing()
        XCTAssertTrue(connection.isDisconnected)
        XCTAssertEqual(drivers.count, 1)
    }

    func testResumeDuringAdapterIdleCleanupRetriesAfterGuardUnwinds() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        var blocked = 0
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue, blocked: { blocked += 1 }))
        owner.reconstructionBusy = true
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(blocked, 1)
        owner.reconstructionBusy = false
        adapter.whenInputActivityIdle {
            connection.resumeAfterQuiescing()
            XCTAssertEqual(drivers.count, 1)
        }
        queue.runAll()
        XCTAssertEqual(drivers.count, 2)
        XCTAssertEqual(blocked, 1)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testCloseRequestedDuringDeactivationSurvivesBusyReconstruction() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        var connection: PreparedInputContextConnection?
        connection = PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            return driver
        }, schedule: queue.enqueue)
        let activeConnection = try XCTUnwrap(connection)
        XCTAssertTrue(activeConnection.activate())
        let driver = try XCTUnwrap(drivers.first)
        let client = try XCTUnwrap(driver.client)
        client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        owner.text = "newest"
        owner.revision = UUID()
        owner.reconstructionBusy = true
        driver.onDiscard = {
            XCTAssertFalse(client.hasMarkedText())
            XCTAssertNil(adapter.claimInputContext())
            XCTAssertEqual(adapter.reconstructWithoutInputContext(), .unavailable)
            XCTAssertFalse(adapter.disconnectAfterQuiescing())
        }
        driver.onDeactivate = {
            XCTAssertNil(adapter.claimInputContext())
            XCTAssertFalse(connection?.disconnect() ?? true)
            client.insertText("stale", replacementRange: self.unspecified)
        }
        client.insertText("trigger", replacementRange: unspecified)
        queue.runAll()
        XCTAssertFalse(activeConnection.isDisconnected)
        XCTAssertEqual(drivers.count, 1)
        XCTAssertEqual(owner.text, "newest")
        XCTAssertEqual(client.selectedRange().location, NSNotFound)
        owner.reconstructionBusy = false
        activeConnection.resumeAfterQuiescing()
        XCTAssertTrue(activeConnection.isDisconnected)
        XCTAssertEqual(drivers.count, 1)
        XCTAssertEqual(view.content.string, "newest")
        driver.onDiscard = nil
        driver.onDeactivate = nil
        connection = nil
    }

    func testRealContextAndResponderBecomeInertAfterDisconnect() throws {
        _ = NSApplication.shared
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        let host = PreparedContextTestResponder(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        var context: NSTextInputContext?
        weak var client: (AnyObject & NSTextInputClient)?
        var driver: PreparedRealDriver?
        var connection: PreparedInputContextConnection? = PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { input in
            let value = PreparedRealDriver(client: input)
            driver = value
            context = value.context
            client = input as AnyObject & NSTextInputClient
            return value
        }, schedule: queue.enqueue)
        host.testInputContext = context
        XCTAssertTrue(window.makeFirstResponder(host))
        XCTAssertTrue(window.firstResponder === host)
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        client?.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(client?.hasMarkedText() ?? false)
        XCTAssertTrue(window.makeFirstResponder(nil))
        XCTAssertFalse(try XCTUnwrap(connection).disconnect())
        queue.runAll()
        XCTAssertTrue(try XCTUnwrap(connection).isDisconnected)
        XCTAssertEqual(driver?.discards, 1)
        XCTAssertEqual(driver?.deactivations, 1)
        XCTAssertEqual(client?.markedRange().location, NSNotFound)
        client?.insertText("stale", replacementRange: unspecified)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(view.content.string, "abc")
        connection = nil
        driver = nil
        XCTAssertNotNil(context)
        XCTAssertEqual(client?.selectedRange().location, NSNotFound)
        host.testInputContext = nil
        context = nil
        window.close()
    }

    func testOffMainFinalReleaseQuarantinesProvisionalViewUntilIdleCleanup() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        owner.reconstructionBusy = true
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        let discarded = expectation(description: "driver discarded on main")
        let driverReleased = expectation(description: "driver released on main")
        weak var driver: ContextFakeDriver?
        var connection: PreparedInputContextConnection? = PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client)
            value.onDiscard = {
                XCTAssertTrue(Thread.isMainThread)
                discarded.fulfill()
            }
            value.onDeactivate = { XCTAssertTrue(Thread.isMainThread) }
            value.onDeinit = {
                XCTAssertTrue(Thread.isMainThread)
                driverReleased.fulfill()
            }
            driver = value
            return value
        }, schedule: queue.enqueue)
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        driver?.client?.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertEqual(view.content.string, "にabc")
        let holder = PreparedConnectionHolder(connection)
        connection = nil
        let released = expectation(description: "owner released off main")
        DispatchQueue.global().async {
            holder.connection = nil
            XCTAssertTrue(view.isRetired)
            XCTAssertEqual(view.content.string, "")
            DispatchQueue.main.async { released.fulfill() }
        }
        wait(for: [released], timeout: 1)
        XCTAssertTrue(view.isHidden)
        XCTAssertNil(view.claimInputMutation())
        queue.runAll()
        wait(for: [discarded, driverReleased], timeout: 1)
        XCTAssertNil(driver)
        XCTAssertTrue(view.isRetired)
        XCTAssertEqual(view.content.string, "")
    }

    func testCloseRequestedByReplacementDriverFactoryIsNotLost() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        var connection: PreparedInputContextConnection?
        connection = PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            if drivers.count == 2 { XCTAssertFalse(connection?.disconnect() ?? true) }
            return driver
        }, schedule: queue.enqueue)
        try XCTUnwrap(connection).requestReset()
        queue.runAll()
        XCTAssertTrue(try XCTUnwrap(connection).isDisconnected)
        XCTAssertEqual(drivers.count, 2)
        XCTAssertEqual(drivers[1].discards, 1)
        XCTAssertEqual(drivers[1].client?.selectedRange().location, NSNotFound)
        connection = nil
    }

    func testResetRequestedByReplacementDriverFactoryRetiresThatDriver() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var drivers: [ContextFakeDriver] = []
        var connection: PreparedInputContextConnection?
        connection = PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            drivers.append(driver)
            if drivers.count == 2 { connection?.requestReset() }
            return driver
        }, schedule: queue.enqueue)
        try XCTUnwrap(connection).requestReset()
        queue.runAll()
        XCTAssertEqual(drivers.count, 3)
        XCTAssertEqual(drivers[1].discards, 1)
        XCTAssertEqual(drivers[1].client?.selectedRange().location, NSNotFound)
        XCTAssertEqual(drivers[2].client?.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(try XCTUnwrap(connection).disconnect())
        queue.runAll()
        XCTAssertTrue(try XCTUnwrap(connection).isDisconnected)
        connection = nil
    }

    func testOldDisconnectedOwnerReleaseDoesNotDetachSuccessorInvalidation() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: owner.text), fallbackHeight: 16,
                                        inputInvalidation: InputInvalidationDelivery(schedule: queue.enqueue))
        let oldAdapter = try makeAdapter(owner, view, queue)
        var oldConnection: PreparedInputContextConnection? = PreparedInputContextConnection(
            adapter: oldAdapter, view: view, makeDriver: { ContextFakeDriver(client: $0) }, schedule: queue.enqueue)
        XCTAssertFalse(try XCTUnwrap(oldConnection).disconnect())
        queue.runAll()
        XCTAssertTrue(try XCTUnwrap(oldConnection).isDisconnected)
        let newAdapter = try makeAdapter(owner, view, queue)
        var newDriver: ContextFakeDriver?
        let newConnection = try XCTUnwrap(PreparedInputContextConnection(adapter: newAdapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            newDriver = driver
            return driver
        }, schedule: queue.enqueue))
        XCTAssertTrue(newConnection.activate())
        oldConnection = nil
        let oldCleanup = expectation(description: "old owner's main cleanup")
        DispatchQueue.main.async { oldCleanup.fulfill() }
        wait(for: [oldCleanup], timeout: 1)
        view.inputInvalidation.invalidate()
        queue.runAll()
        XCTAssertEqual(newDriver?.invalidations, 1)
        XCTAssertFalse(newConnection.disconnect())
        queue.runAll()
        XCTAssertTrue(newConnection.isDisconnected)
    }

    func testNestedQueueDuringGeometryQueryWaitsForCallbackAndAdapterQuery() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        weak var weakConnection: PreparedInputContextConnection?
        weak var weakAdapter: PreparedInputEventAdapter?
        var driver: ContextFakeDriver?
        var providerCalled = false
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(
            view: view, snapshot: view.content, initialRevision: owner.revision,
            documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.beginReconstruction() },
            requestReset: {}, rectProvider: { range, _ in
                providerCalled = true
                XCTAssertFalse(weakConnection?.disconnect() ?? true)
                queue.runAll() // The queued drain may run before this query unwinds.
                XCTAssertEqual(driver?.discards, 0)
                XCTAssertEqual(weakAdapter?.reconstructWithoutInputContext(), .resetRequired)
                XCTAssertFalse(weakAdapter?.disconnectAfterQuiescing() ?? true)
                return (NSRect(x: 1, y: 2, width: 3, height: 4), range)
            }, schedule: queue.enqueue))
        weakAdapter = adapter
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client)
            driver = value
            return value
        }, schedule: queue.enqueue))
        weakConnection = connection
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        var actual = NSRange(location: 0, length: 0)
        XCTAssertEqual(client.firstRect(forCharacterRange: actual, actualRange: &actual), .zero)
        XCTAssertTrue(providerCalled)
        XCTAssertEqual(actual.location, NSNotFound)
        XCTAssertEqual(driver?.discards, 0)
        queue.runAll()
        XCTAssertEqual(driver?.discards, 1)
        XCTAssertEqual(driver?.deactivations, 1)
        XCTAssertTrue(connection.isDisconnected)
        XCTAssertEqual(client.selectedRange().location, NSNotFound)
    }

    private func makeAdapter(_ owner: ContextOwner, _ view: ReadOnlyDocumentView,
                             _ queue: ContextQueue) throws -> PreparedInputEventAdapter {
        try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content, initialRevision: owner.revision,
                                               documentRevision: { owner.revision }, typingAttributes: { [:] },
                                               beginEvent: { owner.begin($0) },
                                               beginReconstruction: { owner.beginReconstruction() },
                                               requestReset: {}, schedule: queue.enqueue))
    }
}

private final class ContextFakeDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let context = NSObject()
    var onActivate: (() -> Void)?
    var onDiscard: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var onDeinit: (() -> Void)?
    var invalidations = 0
    var discards = 0
    var deactivations = 0
    init(client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { context }
    func activate() { onActivate?() }
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() { invalidations += 1 }
    func discardMarkedText() { discards += 1; onDiscard?() }
    func deactivate() { deactivations += 1; onDeactivate?() }
    deinit { onDeinit?() }
}

private final class PreparedContextTestResponder: NSView {
    var testInputContext: NSTextInputContext?
    override var acceptsFirstResponder: Bool { true }
    override var inputContext: NSTextInputContext? { testInputContext }
}

private final class PreparedRealDriver: PreparedInputContextConnection.Driver {
    let context: NSTextInputContext
    var discards = 0
    var deactivations = 0
    init(client: NSTextInputClient) { context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    func activate() { context.activate() }
    func handle(_ event: NSEvent) -> Bool { context.handleEvent(event) }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func discardMarkedText() { discards += 1; context.discardMarkedText() }
    func deactivate() { deactivations += 1; context.deactivate() }
}

private final class PreparedConnectionHolder {
    var connection: PreparedInputContextConnection?
    init(_ connection: PreparedInputContextConnection?) { self.connection = connection }
}

private final class ContextOwner {
    var text: String
    var revision = UUID()
    var active = false
    var reconstructionBusy = false
    var undoCount = 0
    init(text: String) { self.text = text }
    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard expected == revision else { return .stale }
        guard !active else { return .busy }
        active = true
        return .reserved(.init(prepare: { [self] candidate in
            let text = candidate.string
            return .init(publish: { [self] in self.text = text; revision = UUID() },
                         finish: { [self] in undoCount += 1 }, reconcile: { _ in })
        }, close: { [self] in active = false }))
    }
    func beginReconstruction() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !active, !reconstructionBusy else { return .busy }
        active = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision,
                               close: { [self] in active = false }))
    }
}

private final class ContextQueue {
    private var pending: [() -> Void] = []
    func enqueue(_ block: @escaping () -> Void) { pending.append(block) }
    func runAll() {
        var limit = 100
        while !pending.isEmpty {
            guard limit > 0 else { XCTFail("Queue failed to settle"); return }
            limit -= 1
            pending.removeFirst()()
        }
    }
}
#endif
