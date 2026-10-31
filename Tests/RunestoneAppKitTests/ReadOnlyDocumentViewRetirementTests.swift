#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class ReadOnlyDocumentViewRetirementTests: XCTestCase {
    func testRetiredViewCannotRevealOrAdoptContentAfterPermitReleaseOrReattachment() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        let permit = try XCTUnwrap(view.claimInputMutation())
        view.setAccessibilityElement(true)
        view.retireInputView()
        XCTAssertTrue(view.isRetired)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.content.string, "")
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertFalse(view.isAccessibilityElement())
        view.setAccessibilityElement(true)
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertNil(view.hitTest(.zero))
        XCTAssertTrue(view.releaseInputMutation(permit))
        XCTAssertNil(view.claimInputMutation())
        view.setContent(NSAttributedString(string: "new"))
        XCTAssertFalse(view.replaceContent(in: NSRange(location: 0, length: 0), with: NSAttributedString(string: "new")))
        XCTAssertEqual(view.content.string, "")
        view.isHidden = false
        XCTAssertTrue(view.isHidden)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        scroll.documentView = view
        view.isHidden = false
        XCTAssertTrue(view.isHidden)
        XCTAssertNil(view.hitTest(.zero))
        view.retireInputView() // idempotent
        XCTAssertTrue(view.isRetired)
    }

    func testRetirementDetachesAccessibleSubtreeAndFirstResponderFromWindow() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let parent = NSView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        let button = NSButton(title: "child", target: nil, action: nil)
        parent.addSubview(view)
        view.addSubview(button)
        window.contentView = parent
        XCTAssertTrue(window.makeFirstResponder(button))
        XCTAssertTrue(window.firstResponder === button)
        view.retireInputView()
        XCTAssertNil(view.superview)
        XCTAssertFalse(window.firstResponder === button)
        XCTAssertTrue(view.accessibilityChildren()?.isEmpty ?? true)
        parent.addSubview(view)
        view.isHidden = false
        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertTrue(view.accessibilityChildren()?.isEmpty ?? true)
        window.close()
    }

    func testRetirementRemovesDescendantThatRefusesToResign() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let parent = NSView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        let child = RefusingRetirementResponder(frame: .zero)
        parent.addSubview(view)
        view.addSubview(child)
        window.contentView = parent
        XCTAssertTrue(window.makeFirstResponder(child))
        view.retireInputView()
        XCTAssertNil(view.superview)
        XCTAssertFalse(window.firstResponder === child)
        XCTAssertTrue(view.isHidden)
        window.close()
    }

    func testOffMainRetirementImmediatelySuppressesSnapshotUntilMainCleanup() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        let finished = expectation(description: "background retirement")
        DispatchQueue.global().async {
            view.retireInputView()
            XCTAssertTrue(view.isRetired)
            XCTAssertEqual(view.content.string, "")
            DispatchQueue.main.async { finished.fulfill() }
        }
        wait(for: [finished], timeout: 1)
        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
    }

    func testUnexpectedAdapterReleasePermanentlyQuarantinesProvisionalView() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let revision = UUID()
        var adapter: PreparedInputEventAdapter? = PreparedInputEventAdapter(
            view: view, snapshot: view.content, initialRevision: revision,
            documentRevision: { revision }, typingAttributes: { [:] },
            beginEvent: { _ in .reserved(.init(prepare: { _ in nil }, close: {})) },
            beginReconstruction: { .busy }, requestReset: {})
        XCTAssertEqual(try XCTUnwrap(adapter).setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                                           replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        XCTAssertEqual(view.content.string, "にabc")
        adapter = nil
        XCTAssertTrue(view.isRetired)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.content.string, "")
        view.setContent(NSAttributedString(string: "untrusted"))
        XCTAssertEqual(view.content.string, "")
        XCTAssertNil(view.claimInputMutation())
    }

    func testOffMainAdapterReleaseImmediatelyQuarantinesProvisionalView() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let revision = UUID()
        var adapter: PreparedInputEventAdapter? = PreparedInputEventAdapter(
            view: view, snapshot: view.content, initialRevision: revision,
            documentRevision: { revision }, typingAttributes: { [:] },
            beginEvent: { _ in .reserved(.init(prepare: { _ in nil }, close: {})) },
            beginReconstruction: { .busy }, requestReset: {})
        XCTAssertEqual(try XCTUnwrap(adapter).setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                                           replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        let holder = AdapterHolder(adapter)
        adapter = nil
        let finished = expectation(description: "off-main adapter release")
        DispatchQueue.global().async {
            holder.adapter = nil
            XCTAssertTrue(view.isRetired)
            XCTAssertEqual(view.content.string, "")
            DispatchQueue.main.async { finished.fulfill() }
        }
        wait(for: [finished], timeout: 1)
        XCTAssertTrue(view.isHidden)
        XCTAssertNil(view.claimInputMutation())
    }

    func testRetirementDuringMutationKeepsPermitUntilTransactionUnwinds() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "provisional"))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let authority = try XCTUnwrap(view.bindInputSession(to: permit))
        let transaction = try XCTUnwrap(view.beginInputMutation(with: permit, authority: authority))
        view.retireInputView()
        XCTAssertTrue(view.inputMutationInFlight)
        XCTAssertFalse(view.releaseInputMutation(permit))
        XCTAssertNil(view.setContentReturningRevision(NSAttributedString(string: "foreign"), permit: permit, transaction: transaction))
        view.releaseInputMutationWhenIdle(permit)
        view.endInputMutation(transaction)
        XCTAssertFalse(view.inputMutationInFlight)
        XCTAssertNil(view.claimInputMutation())
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.content.string, "")
    }
}

private final class RefusingRetirementResponder: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func resignFirstResponder() -> Bool { false }
}

private final class AdapterHolder {
    var adapter: PreparedInputEventAdapter?
    init(_ adapter: PreparedInputEventAdapter?) { self.adapter = adapter }
}
#endif
