#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class InputContextConnectionTests: XCTestCase {
    func testDeactivationQueriesAreValidButRetainedContextBecomesInertAndReleasesOwnership() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let context = NSObject()
        var driver: FakeDriver?
        let connection = try XCTUnwrap(InputContextConnection(view: view) { client in
            let value = FakeDriver(client: client, context: context)
            driver = value
            return value
        })
        let client = try XCTUnwrap(driver?.client)
        driver?.onDeactivate = { [weak connection, weak view] in
            XCTAssertEqual(client.selectedRange(), NSRange(location: 0, length: 0))
            XCTAssertEqual(client.attributedSubstring(forProposedRange: NSRange(location: 0, length: 1), actualRange: nil)?.string, "a")
            client.insertText("bad", replacementRange: NSRange(location: NSNotFound, length: 0))
            XCTAssertEqual(view?.content.string, "abc")
            XCTAssertFalse(connection?.disconnect() ?? true)
        }
        XCTAssertTrue(connection.activate())
        XCTAssertTrue(connection.activate())
        XCTAssertEqual(driver?.activations, 1)
        XCTAssertTrue(connection.disconnect())
        XCTAssertEqual(driver?.deactivations, 1)
        var actual = NSRange(location: 0, length: 0)
        XCTAssertNil(client.attributedSubstring(forProposedRange: NSRange(location: 0, length: 1), actualRange: &actual))
        XCTAssertEqual(actual.location, NSNotFound)
        actual = NSRange(location: 0, length: 0)
        XCTAssertEqual(client.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: &actual), .zero)
        XCTAssertEqual(actual.location, NSNotFound)
        XCTAssertEqual(client.selectedRange().location, NSNotFound)
        XCTAssertEqual(client.markedRange().location, NSNotFound)
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(client.characterIndex(for: .zero), NSNotFound)
        view.setContent(NSAttributedString(string: "new"))
        XCTAssertEqual(view.content.string, "new")
        let permit = try XCTUnwrap(view.claimInputMutation())
        XCTAssertTrue(view.releaseInputMutation(permit))
        withExtendedLifetime(context) {}
    }

    func testReusingAssociationTargetDoesNotReplaceExistingClient() throws {
        let firstView = ReadOnlyDocumentView(content: NSAttributedString(string: "one"))
        let secondView = ReadOnlyDocumentView(content: NSAttributedString(string: "two"))
        let context = NSObject()
        var firstClient: NSTextInputClient?
        let first = try XCTUnwrap(InputContextConnection(view: firstView) { client in
            firstClient = client
            return FakeDriver(client: client, context: context)
        })
        XCTAssertNil(InputContextConnection(view: secondView) { FakeDriver(client: $0, context: context) })
        XCTAssertEqual(firstClient?.attributedSubstring(forProposedRange: NSRange(location: 0, length: 3), actualRange: nil)?.string, "one")
        let permit = try XCTUnwrap(secondView.claimInputMutation())
        XCTAssertTrue(secondView.releaseInputMutation(permit))
        XCTAssertTrue(first.disconnect())
    }

    func testUnexpectedReleaseDeactivatesAndReleasesPermitOnMainQueue() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let context = NSObject()
        var driver: FakeDriver?
        var connection: InputContextConnection? = InputContextConnection(view: view) { client in
            let value = FakeDriver(client: client, context: context)
            driver = value
            return value
        }
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        connection = nil
        XCTAssertNil(view.claimInputMutation())
        let completed = expectation(description: "deferred cleanup")
        DispatchQueue.main.async { completed.fulfill() }
        wait(for: [completed], timeout: 1)
        XCTAssertEqual(driver?.deactivations, 1)
        XCTAssertEqual(driver?.client?.selectedRange().location, NSNotFound)
        let permit = try XCTUnwrap(view.claimInputMutation())
        XCTAssertTrue(view.releaseInputMutation(permit))
    }

    func testActivationDefersInvalidationAndRejectsReentrantDisconnect() throws {
        let scheduler = ManualScheduler()
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: "abc"), fallbackHeight: 16,
                                        inputInvalidation: InputInvalidationDelivery(schedule: scheduler.enqueue))
        var driver: FakeDriver?
        var connection: InputContextConnection?
        connection = InputContextConnection(view: view) { client in
            let value = FakeDriver(client: client)
            driver = value
            return value
        }
        driver?.onActivate = { [weak connection, weak view] in
            view?.noteInputCoordinatesChanged()
            scheduler.runAll()
            XCTAssertEqual(driver?.invalidations, 0)
            XCTAssertFalse(connection?.disconnect() ?? true)
        }
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        scheduler.runAll()
        XCTAssertEqual(driver?.invalidations, 1)
        XCTAssertTrue(try XCTUnwrap(connection).disconnect())
        view.noteInputCoordinatesChanged()
        scheduler.runAll()
        XCTAssertEqual(driver?.invalidations, 1)
        driver?.onActivate = nil
        connection = nil
    }

    func testCleanupRequestedDuringQueryRunsAfterCallbackReturns() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var proxy: QueryOnlyClient!
        var events: [String] = []
        let client = DocumentInputClient(view: view, mutationPermit: permit,
                                         typingAttributes: { [:] }, commandHandler: { _ in },
                                         rectProvider: { _ in
                                             proxy.whenIdle { events.append("cleanup") }
                                             events.append("query")
                                             return nil
                                         }, indexProvider: { _ in nil })
        proxy = QueryOnlyClient(client)
        _ = proxy.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        events.append("returned")
        XCTAssertEqual(events, ["query", "returned"])
        let finished = expectation(description: "deferred cleanup")
        DispatchQueue.main.async { finished.fulfill() }
        wait(for: [finished], timeout: 1)
        XCTAssertEqual(events, ["query", "returned", "cleanup"])
        proxy.detach()
        XCTAssertTrue(view.releaseInputMutation(permit))
    }

    func testRetainedContextDoesNotKeepDetachedViewAlive() throws {
        let context = NSObject()
        var view: ReadOnlyDocumentView? = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        weak let weakView = view
        var connection: InputContextConnection? = InputContextConnection(view: try XCTUnwrap(view)) {
            FakeDriver(client: $0, context: context)
        }
        XCTAssertTrue(try XCTUnwrap(connection).disconnect())
        connection = nil
        view = nil
        XCTAssertNil(weakView)
        withExtendedLifetime(context) {}
    }

    func testDeferredPermitReleaseWaitsForTransactionAndDoesNotReleaseNewOwner() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let oldPermit = try XCTUnwrap(view.claimInputMutation())
        let authority = try XCTUnwrap(view.bindInputSession(to: oldPermit))
        let transaction = try XCTUnwrap(view.beginInputMutation(with: oldPermit, authority: authority))
        view.releaseInputMutationWhenIdle(oldPermit)
        XCTAssertNil(view.claimInputMutation())
        view.endInputMutation(transaction)
        let newPermit = try XCTUnwrap(view.claimInputMutation())
        view.releaseInputMutationWhenIdle(oldPermit)
        XCTAssertNil(view.claimInputMutation())
        XCTAssertTrue(view.releaseInputMutation(newPermit))
    }

    func testActivatedAppKitContextRetainedAfterDisconnectHasInertClient() throws {
        _ = NSApplication.shared
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        var context: NSTextInputContext?
        weak var client: (AnyObject & NSTextInputClient)?
        var connection: InputContextConnection? = InputContextConnection(view: view) { input in
            let driver = RealDriver(client: input)
            context = driver.context
            client = input as AnyObject & NSTextInputClient
            return driver
        }
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        XCTAssertTrue(try XCTUnwrap(connection).disconnect())
        connection = nil
        XCTAssertNotNil(context)
        XCTAssertEqual(client?.selectedRange().location, NSNotFound)
        view.setContent(NSAttributedString(string: "new"))
        XCTAssertEqual(view.content.string, "new")
        context = nil
    }

    func testUnactivatedDisconnectDoesNotDeactivate() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        var driver: FakeDriver?
        let connection = try XCTUnwrap(InputContextConnection(view: view) { client in
            let value = FakeDriver(client: client)
            driver = value
            return value
        })
        XCTAssertTrue(connection.disconnect())
        XCTAssertEqual(driver?.deactivations, 0)
    }
}

private final class FakeDriver: InputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let context: NSObject
    var onActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var activations = 0
    var invalidations = 0
    var deactivations = 0
    init(client: NSTextInputClient, context: NSObject = NSObject()) { self.client = client; self.context = context }
    var associationTarget: NSObject { context }
    func activate() { activations += 1; onActivate?() }
    func invalidateCoordinates() { invalidations += 1 }
    func deactivate() { deactivations += 1; onDeactivate?() }
}

private final class RealDriver: InputContextConnection.Driver {
    let context: NSTextInputContext
    init(client: NSTextInputClient) { context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    func activate() { context.activate() }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func deactivate() { context.deactivate() }
}

private final class ManualScheduler {
    private var pending: [() -> Void] = []
    func enqueue(_ work: @escaping () -> Void) { pending.append(work) }
    func runAll() {
        var remaining = 20
        while !pending.isEmpty {
            guard remaining > 0 else { XCTFail("Invalidation queue did not settle"); return }
            remaining -= 1
            pending.removeFirst()()
        }
    }
}
#endif
