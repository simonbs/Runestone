#if canImport(AppKit)
import AppKit
import ObjectiveC
@testable import RunestoneAppKit
import XCTest

final class RunestoneInputDocumentLifetimeTests: XCTestCase {
    func testInvalidationQuarantinesImmediatelyAndDefersAppKitCleanup() throws {
        let lifetime = RunestoneInputDocumentLifetime()
        let parent = NSView()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "sensitive"))
        parent.addSubview(view)
        let registration = try XCTUnwrap(lifetime.register(view))
        lifetime.invalidate()
        XCTAssertTrue(view.isRetired)
        XCTAssertEqual(view.content.string, "")
        XCTAssertTrue(view.superview === parent) // No synchronous AppKit removal.
        XCTAssertNil(lifetime.register(view))
        lifetime.unregister(registration)
        let cleanup = expectation(description: "main-thread retirement cleanup")
        DispatchQueue.main.async {
            XCTAssertNil(view.superview)
            XCTAssertTrue(view.isHidden)
            cleanup.fulfill()
        }
        wait(for: [cleanup], timeout: 1)
    }

    func testCleanUnregistrationAndWeakTracking() throws {
        let lifetime = RunestoneInputDocumentLifetime()
        let detached = ReadOnlyDocumentView(content: NSAttributedString(string: "retained"))
        let registration = try XCTUnwrap(lifetime.register(detached))
        lifetime.unregister(registration)
        var ephemeral: ReadOnlyDocumentView? = ReadOnlyDocumentView(content: NSAttributedString(string: "ephemeral"))
        weak let weakEphemeral = ephemeral
        _ = try XCTUnwrap(lifetime.register(try XCTUnwrap(ephemeral)))
        ephemeral = nil
        XCTAssertNil(weakEphemeral)
        lifetime.invalidate()
        XCTAssertFalse(detached.isRetired)
        XCTAssertEqual(detached.content.string, "retained")
    }

    func testConcurrentRegistrationCannotEscapeInvalidation() {
        let lifetime = RunestoneInputDocumentLifetime()
        let views = (0..<24).map { _ in ReadOnlyDocumentView(content: NSAttributedString(string: "text")) }
        let resultLock = NSLock()
        var registered = Array(repeating: false, count: views.count)
        DispatchQueue.concurrentPerform(iterations: views.count + 1) { index in
            if index == views.count { lifetime.invalidate(); return }
            let succeeded = lifetime.register(views[index]) != nil
            resultLock.lock()
            registered[index] = succeeded
            resultLock.unlock()
        }
        for (index, view) in views.enumerated() {
            if registered[index] { XCTAssertTrue(view.isRetired) }
            XCTAssertNil(lifetime.register(view))
        }
    }

    func testOffMainOwnerDeinitQuarantinesAndReleasesViewOnMain() throws {
        let released = expectation(description: "view's AppKit-owned sentinel released on main")
        var lifetime: RunestoneInputDocumentLifetime? = RunestoneInputDocumentLifetime()
        var view: ReadOnlyDocumentView? = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        weak let weakView = view
        objc_setAssociatedObject(try XCTUnwrap(view), &lifetimeProbeKey, LifetimeDeinitProbe {
            XCTAssertTrue(Thread.isMainThread)
            released.fulfill()
        }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        _ = try XCTUnwrap(try XCTUnwrap(lifetime).register(try XCTUnwrap(view)))
        let holder = LifetimeTestHolder(lifetime: lifetime, view: view)
        lifetime = nil
        view = nil
        // Keep the main queue from draining until the background thread has
        // dropped both last external references.
        DispatchQueue.global().sync {
            holder.lifetime = nil
            XCTAssertTrue(holder.view?.isRetired ?? false)
            holder.view = nil
        }
        wait(for: [released], timeout: 1)
        XCTAssertNil(weakView)
    }
}

private var lifetimeProbeKey: UInt8 = 0
private final class LifetimeDeinitProbe {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    deinit { callback() }
}
private final class LifetimeTestHolder {
    var lifetime: RunestoneInputDocumentLifetime?
    var view: ReadOnlyDocumentView?
    init(lifetime: RunestoneInputDocumentLifetime?, view: ReadOnlyDocumentView?) {
        self.lifetime = lifetime
        self.view = view
    }
}
#endif
