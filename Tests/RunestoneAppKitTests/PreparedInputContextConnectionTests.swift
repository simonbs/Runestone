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

    func testBlurDuringActivationSuppressesClientUntilReadyAndRefocused() throws {
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
        let first = try XCTUnwrap(drivers.first)
        let client = try XCTUnwrap(first.client)
        var focused = true
        var focusGeneration = 0
        let observer = ContextReadyObserver()
        observer.onReady = { connection in
            let generation = focusGeneration
            // A real responder must also verify its window's current first responder.
            if focused && generation == focusGeneration { XCTAssertTrue(connection.resumeForFocus()) }
        }
        connection.readyObserver = observer
        weak let weakConnection = connection
        first.onActivate = {
            client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: self.unspecified)
            XCTAssertTrue(client.hasMarkedText())
            focused = false
            focusGeneration += 1
            weakConnection?.suspendForFocusLoss()
            XCTAssertFalse(client.hasMarkedText())
            client.insertText("stale", replacementRange: self.unspecified)
            XCTAssertFalse(weakConnection?.resumeForFocus() ?? true)
            queue.runAll() // Nested loop cannot discard while activate is on stack.
            XCTAssertEqual(first.discards, 0)
            XCTAssertEqual(owner.text, "abc")
        }
        XCTAssertFalse(connection.activate())
        XCTAssertEqual(first.discards, 0)
        queue.runAll()
        XCTAssertEqual(first.discards, 1)
        XCTAssertEqual(first.deactivations, 1)
        XCTAssertEqual(observer.notifications, 1)
        XCTAssertEqual(drivers.count, 2)
        let second = try XCTUnwrap(drivers.last)
        XCTAssertEqual(second.activations, 0)
        let secondClient = try XCTUnwrap(second.client)
        XCTAssertEqual(secondClient.selectedRange().location, NSNotFound)
        XCTAssertEqual(view.content.string, "abc")
        focused = true
        focusGeneration += 1
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertEqual(second.activations, 1)
        secondClient.insertText("x", replacementRange: unspecified)
        XCTAssertEqual(owner.text, "xabc")
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
        first.onActivate = nil
    }

    func testDelayedFocusRequestChecksGenerationAfterBlur() throws {
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
        var focusGeneration = 0
        var focused = true
        var staleRequests = 0
        let observer = ContextReadyObserver()
        observer.onReady = { connection in
            guard focusGeneration == 0 else { return }
            let requestedGeneration = focusGeneration
            queue.enqueue { [weak connection] in
                guard focused, focusGeneration == requestedGeneration else { staleRequests += 1; return }
                _ = connection?.resumeForFocus()
            }
            // Focus changes after readiness but before the queued host action.
            focused = false
            focusGeneration += 1
            connection.suspendForFocusLoss()
        }
        connection.readyObserver = observer
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(staleRequests, 1)
        XCTAssertEqual(observer.notifications, 2)
        XCTAssertTrue(drivers.allSatisfy { $0.activations == 0 })
        XCTAssertEqual(drivers.last?.client?.selectedRange().location, NSNotFound)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testReadyObserverCanCloseReentrantlyAndIsNotRetained() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view,
            makeDriver: { ContextFakeDriver(client: $0) }, schedule: queue.enqueue))
        var observer: ContextReadyObserver? = ContextReadyObserver()
        weak let weakObserver = observer
        observer?.onReady = { connection in XCTAssertFalse(connection.disconnect()) }
        connection.readyObserver = observer
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(observer?.notifications, 1)
        XCTAssertTrue(connection.isDisconnected)
        observer = nil
        XCTAssertNil(weakObserver)
    }

    func testCommandIsForwardedAndBlurDuringHandlerWaitsForCallback() throws {
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
        let driver = try XCTUnwrap(first)
        let client = try XCTUnwrap(driver.client)
        let selector = NSSelectorFromString("moveLeft:")
        var handler: ContextCommandHandler? = ContextCommandHandler()
        weak let weakHandler = handler
        handler?.onCommand = { connection, received in
            XCTAssertEqual(received, selector)
            connection.suspendForFocusLoss()
            client.doCommand(by: selector)
            queue.runAll()
            XCTAssertEqual(driver.discards, 0)
        }
        connection.commandHandler = handler
        XCTAssertTrue(connection.activate())
        client.doCommand(by: selector)
        XCTAssertEqual(handler?.selectors, [selector])
        queue.runAll()
        XCTAssertEqual(driver.discards, 1)
        client.doCommand(by: selector)
        XCTAssertEqual(handler?.selectors, [selector])
        handler = nil
        XCTAssertNil(weakHandler)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testKeyBindingFallbackRemainsActiveAcrossNestedBlur() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var first: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view,
            initiallyFocusSuspended: true, makeDriver: { client in
                let driver = ContextFakeDriver(client: client)
                if first == nil { first = driver }
                return driver
            }, schedule: queue.enqueue))
        let driver = try XCTUnwrap(first)
        let client = try XCTUnwrap(driver.client)
        client.insertText("ignored", replacementRange: unspecified)
        XCTAssertFalse(connection.activate())
        XCTAssertEqual(owner.text, "abc")
        XCTAssertTrue(connection.resumeForFocus())
        let handler = ContextCommandHandler()
        connection.commandHandler = handler
        XCTAssertTrue(connection.performKeyBindingFallback {
            connection.insertTextFromKeyBinding("x", replacementRange: self.unspecified)
            connection.doCommandFromKeyBinding(NSSelectorFromString("moveLeft:"))
            XCTAssertEqual(owner.text, "xabc")
            XCTAssertEqual(handler.selectors.count, 1)
            connection.suspendForFocusLoss()
            connection.insertTextFromKeyBinding("ignored", replacementRange: self.unspecified)
            connection.doCommandFromKeyBinding(NSSelectorFromString("moveRight:"))
            queue.runAll()
            XCTAssertEqual(driver.discards, 0)
            XCTAssertEqual(owner.text, "xabc")
            XCTAssertEqual(handler.selectors.count, 1)
        })
        queue.runAll()
        XCTAssertEqual(driver.discards, 1)
        XCTAssertFalse(connection.performKeyBindingFallback { XCTFail("Blurred context must be inert") })
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testHandledInputCallbackPreventsDuplicateKeyFallbackButQueryDoesNot() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var first: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let driver = ContextFakeDriver(client: client)
            first = driver
            return driver
        }, schedule: queue.enqueue))
        let driver = try XCTUnwrap(first)
        let client = try XCTUnwrap(driver.client)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "x", charactersIgnoringModifiers: "x",
            isARepeat: false, keyCode: 7))
        XCTAssertTrue(connection.activate())
        driver.onHandle = {
            client.insertText("x", replacementRange: self.unspecified)
            return false
        }
        XCTAssertTrue(connection.handle(event))
        XCTAssertEqual(owner.text, "xabc")
        driver.onHandle = { _ = client.selectedRange(); return false }
        XCTAssertFalse(connection.handle(event))
        driver.onHandle = nil
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testResponderActivityRejectsSuspensionAndDefersTeardownThroughNestedLoop() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var first: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view,
            initiallyFocusSuspended: true, makeDriver: { client in
                let driver = ContextFakeDriver(client: client)
                if first == nil { first = driver }
                return driver
            }, schedule: queue.enqueue))
        let driver = try XCTUnwrap(first)
        XCTAssertFalse(connection.performResponderActivity { _, _ in XCTFail("Inactive responder must be inert") })
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertTrue(connection.performResponderActivity { adapter, isCurrent in
            XCTAssertTrue(isCurrent())
            XCTAssertEqual(adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        })
        XCTAssertEqual(adapter.selectedRangeForInput(), NSRange(location: 1, length: 0))
        var changedAfterBlur = false
        XCTAssertFalse(connection.performResponderActivity { adapter, isCurrent in
            XCTAssertTrue(isCurrent())
            XCTAssertFalse(connection.performResponderActivity { _, _ in XCTFail("Nested responder activity must be inert") })
            connection.suspendForFocusLoss()
            queue.runAll() // Teardown cannot run while hit testing or drawing is on stack.
            XCTAssertEqual(driver.discards, 0)
            if isCurrent() {
                changedAfterBlur = true
                _ = adapter.setSelection(NSRange(location: 2, length: 0))
            }
        })
        XCTAssertFalse(changedAfterBlur)
        XCTAssertFalse(connection.performResponderActivity { _, _ in XCTFail("Blurred responder must be inert") })
        queue.runAll()
        XCTAssertEqual(driver.discards, 1)
        XCTAssertFalse(connection.performResponderActivity { _, _ in XCTFail("Rebuilt context stays suspended") })
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
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
        XCTAssertTrue(try XCTUnwrap(connection).currentInputContext === context)
        XCTAssertTrue(window.makeFirstResponder(host))
        XCTAssertTrue(window.firstResponder === host)
        XCTAssertTrue(try XCTUnwrap(connection).activate())
        client?.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(client?.hasMarkedText() ?? false)
        XCTAssertTrue(window.makeFirstResponder(nil))
        XCTAssertFalse(try XCTUnwrap(connection).disconnect())
        XCTAssertNil(try XCTUnwrap(connection).currentInputContext)
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

    func testBusyCallbacksAreReportedInOrderAndNeverReplayed() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        let observer = ContextInputFailureObserver()
        connection.inputFailureObserver = observer
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        owner.active = true
        client.insertText("x", replacementRange: unspecified)
        client.setMarkedText("y", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        client.unmarkText()
        XCTAssertEqual(observer.notifications, 0)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.undoCount, 0)
        owner.active = false
        queue.runAll()
        XCTAssertEqual(observer.notifications, 1)
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.insertText, .setMarkedText, .unmarkText])
        XCTAssertEqual(batch.records.map(\.failure.reason), [.busy, .unavailable, .unavailable])
        XCTAssertTrue(batch.records.allSatisfy { $0.failure.effect == .notApplied })
        XCTAssertEqual(batch.overflowCount, 0)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.undoCount, 0)
        // A retained client is detached after cleanup and cannot create reports.
        client.insertText("old", replacementRange: unspecified)
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testFailureMailboxIsBoundedAndExplicitlyAcknowledged() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        owner.active = true
        client.insertText("x", replacementRange: unspecified)
        for _ in 0..<20 { client.unmarkText() }
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.count, 16)
        XCTAssertEqual(batch.records.first?.operation, .insertText)
        XCTAssertTrue(batch.records.dropFirst().allSatisfy { $0.operation == .unmarkText })
        XCTAssertEqual(batch.overflowCount, 5)
        let cleared = connection.takeInputFailures()
        XCTAssertTrue(cleared.records.isEmpty)
        XCTAssertEqual(cleared.overflowCount, 0)
        owner.active = false
        queue.runAll()
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
        XCTAssertTrue(connection.isDisconnected)
    }

    func testFailureObserverWaitsForNestedDriverAndAdapterActivity() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        let observer = ContextInputFailureObserver()
        var insideDriver = false
        observer.onNotify = { _ in
            XCTAssertFalse(insideDriver)
            XCTAssertFalse(adapter.inputActivityIsBusy)
        }
        connection.inputFailureObserver = observer
        owner.active = true
        driver?.onActivate = {
            insideDriver = true
            driver?.client?.insertText("x", replacementRange: self.unspecified)
            queue.runAll() // nested event loop while the driver remains active
            XCTAssertEqual(observer.notifications, 0)
            insideDriver = false
        }
        XCTAssertFalse(connection.activate())
        owner.active = false
        queue.runAll()
        XCTAssertEqual(observer.notifications, 1)
        XCTAssertEqual(connection.takeInputFailures().records.first?.failure.reason, .busy)
        driver?.onActivate = nil
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testObserverIsWeakAndPendingBatchCanBeObservedLater() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view,
            makeDriver: { ContextFakeDriver(client: $0) }, schedule: queue.enqueue))
        var observer: ContextInputFailureObserver? = ContextInputFailureObserver()
        weak let weakObserver = observer
        connection.inputFailureObserver = observer
        observer = nil
        XCTAssertNil(weakObserver)
        connection.recordInputFailure(operation: .command, failure: .init(reason: .busy, effect: .notApplied))
        queue.runAll()
        let next = ContextInputFailureObserver()
        connection.inputFailureObserver = next
        queue.runAll()
        XCTAssertEqual(next.notifications, 1)
        XCTAssertEqual(connection.takeInputFailures().records.map(\.operation), [.command])
        queue.runAll()
        XCTAssertEqual(next.notifications, 1)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testEmptyCompositionDiscardIsReportedOnlyOnceAndOldClientIsInert() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); if driver == nil { driver = value }; return value
        }, schedule: queue.enqueue))
        let observer = ContextInputFailureObserver()
        connection.inputFailureObserver = observer
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        client.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: 1, length: 1))
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(view.content.string, "ac")
        driver?.onDiscard = { XCTAssertEqual(observer.notifications, 0) }
        connection.requestReset()
        queue.runAll()
        XCTAssertEqual(observer.notifications, 1)
        let failures = connection.takeInputFailures().records
        XCTAssertEqual(failures.map(\.operation), [.compositionDiscarded])
        XCTAssertEqual(failures.map(\.failure.reason), [.compositionDiscarded])
        XCTAssertEqual(failures.map(\.failure.effect), [.mayHaveApplied])
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertEqual(owner.text, "abc")
        client.insertText("old", replacementRange: unspecified)
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        driver?.onDiscard = nil
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testMissingCommandHandlerReportsFailureWithoutMutation() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        try XCTUnwrap(driver?.client).doCommand(by: NSSelectorFromString("deleteBackward:"))
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.command])
        XCTAssertEqual(batch.records.map(\.failure.reason), [.unavailable])
        XCTAssertEqual(batch.records.map(\.failure.effect), [.notApplied])
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.undoCount, 0)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testUndispatchedKeyAndFallbackFailureHaveDistinctEffects() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view,
            makeDriver: { ContextFakeDriver(client: $0) }, schedule: queue.enqueue))
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "a",
                                                   charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        XCTAssertEqual(connection.dispatchKey(event), .unavailable)
        XCTAssertFalse(connection.performKeyBindingFallback { XCTFail("Fallback must not run") })
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.undispatchedKey, .keyBindingFallback])
        XCTAssertEqual(batch.records.map(\.failure.effect), [.notApplied, .mayHaveApplied])
        XCTAssertEqual(owner.text, "abc")
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testFocusLossDuringDriverDispatchReportsInterruptionWithoutReplaying() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "a",
                                                   charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        driver?.onHandle = {
            connection.suspendForFocusLoss()
            queue.runAll() // A nested event loop cannot retire the active driver.
            XCTAssertEqual(driver?.discards, 0)
            return false
        }
        XCTAssertEqual(connection.dispatchKey(event), .handled)
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.inputDispatchInterrupted])
        XCTAssertEqual(batch.records.map(\.failure.reason), [.unavailable])
        XCTAssertEqual(batch.records.map(\.failure.effect), [.mayHaveApplied])
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.undoCount, 0)
        driver?.onHandle = nil
        queue.runAll()
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testFocusLossAfterPublishedCallbackReportsInterruptionWithoutReplaying() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "x",
                                                   charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 0))
        driver?.onHandle = {
            client.insertText("x", replacementRange: self.unspecified)
            connection.suspendForFocusLoss()
            return false
        }
        XCTAssertEqual(connection.dispatchKey(event), .handled)
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.inputDispatchInterrupted])
        XCTAssertEqual(batch.records.map(\.failure.reason), [.unavailable])
        XCTAssertEqual(batch.records.map(\.failure.effect), [.mayHaveApplied])
        XCTAssertEqual(owner.text, "xabc")
        XCTAssertEqual(owner.undoCount, 1)
        driver?.onHandle = nil
        queue.runAll()
        XCTAssertEqual(owner.text, "xabc")
        XCTAssertEqual(owner.undoCount, 1)
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
    }

    func testFocusLossAfterRejectedCallbackReportsBothOutcomes() throws {
        let queue = ContextQueue()
        let owner = ContextOwner(text: "abc")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(owner, view, queue)
        var driver: ContextFakeDriver?
        let connection = try XCTUnwrap(PreparedInputContextConnection(adapter: adapter, view: view, makeDriver: { client in
            let value = ContextFakeDriver(client: client); driver = value; return value
        }, schedule: queue.enqueue))
        XCTAssertTrue(connection.activate())
        let client = try XCTUnwrap(driver?.client)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "a",
                                                   charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        owner.active = true
        driver?.onHandle = {
            client.insertText("x", replacementRange: self.unspecified)
            connection.suspendForFocusLoss()
            return false
        }
        XCTAssertEqual(connection.dispatchKey(event), .handled)
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records.map(\.operation), [.insertText, .inputDispatchInterrupted])
        XCTAssertEqual(batch.records.map(\.failure.reason), [.busy, .unavailable])
        XCTAssertEqual(batch.records.map(\.failure.effect), [.notApplied, .mayHaveApplied])
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.undoCount, 0)
        driver?.onHandle = nil
        owner.active = false
        queue.runAll()
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertFalse(connection.disconnect())
        queue.runAll()
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

private final class ContextInputFailureObserver: PreparedInputContextConnection.InputFailureObserver {
    var notifications = 0
    var onNotify: ((PreparedInputContextConnection) -> Void)?
    func preparedInputContextConnectionHasInputFailures(_ connection: PreparedInputContextConnection) {
        notifications += 1
        onNotify?(connection)
    }
}

private final class ContextReadyObserver: PreparedInputContextConnection.ReadyObserver {
    var notifications = 0
    var onReady: ((PreparedInputContextConnection) -> Void)?
    func preparedInputContextConnectionDidBecomeReady(_ connection: PreparedInputContextConnection) {
        notifications += 1
        onReady?(connection)
    }
}

private final class ContextCommandHandler: PreparedInputContextConnection.CommandHandler {
    var selectors: [Selector] = []
    var onCommand: ((PreparedInputContextConnection, Selector) -> Void)?
    func preparedInputContextConnection(_ connection: PreparedInputContextConnection, doCommand selector: Selector) {
        selectors.append(selector)
        onCommand?(connection, selector)
    }
}

private final class ContextFakeDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    let context = NSObject()
    var onActivate: (() -> Void)?
    var onHandle: (() -> Bool)?
    var onDiscard: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var onDeinit: (() -> Void)?
    var invalidations = 0
    var activations = 0
    var discards = 0
    var deactivations = 0
    init(client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { context }
    func activate() { activations += 1; onActivate?() }
    func handle(_ event: NSEvent) -> Bool { onHandle?() ?? false }
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
    var inputContext: NSTextInputContext? { context }
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
