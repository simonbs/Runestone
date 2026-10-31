#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Foreground-window checks of the public attachment and AppKit's public
/// accessibility and input-client entry points. Direct client calls are not
/// evidence of a third-party input method or VoiceOver interaction.
final class PublicAttachmentLiveAccessibilityTests: XCTestCase {
    func testAccessibilityTextAndGeometryInKeyWindow() throws {
        let fixture = try LivePublicFixture(text: "A😀B\r\nsecond")
        defer { fixture.close() }
        try fixture.activate()
        let view = fixture.attachment.view
        let emoji = NSRange(location: 1, length: 2)
        XCTAssertTrue(fixture.window.isKeyWindow)
        XCTAssertTrue(fixture.window.firstResponder === view)
        XCTAssertTrue(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityRole(), .textArea)
        XCTAssertEqual(view.accessibilityValue() as? String, "A😀B\r\nsecond")
        XCTAssertEqual(view.accessibilityNumberOfCharacters(), ("A😀B\r\nsecond" as NSString).length)
        XCTAssertEqual(view.accessibilityString(for: emoji), "😀")
        XCTAssertEqual(view.accessibilityRange(for: 2), emoji)
        XCTAssertEqual(view.accessibilityRange(forLine: 0), NSRange(location: 0, length: 6))
        XCTAssertNotEqual(view.accessibilityVisibleCharacterRange().location, NSNotFound)

        let frame = view.accessibilityFrame(for: emoji)
        XCTAssertFalse(frame.isEmpty, "A visible emoji must have an on-screen accessibility frame")
        XCTAssertEqual(view.accessibilityRange(for: NSPoint(x: frame.midX, y: frame.midY)), emoji)
        XCTAssertTrue(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedTextRange:")))
        view.setAccessibilitySelectedTextRange(emoji)
        XCTAssertEqual(fixture.attachment.inputState?.selection, emoji)
        XCTAssertEqual(view.accessibilitySelectedTextRange(), emoji)
        XCTAssertEqual(view.accessibilitySelectedText(), "😀")
        view.setAccessibilitySelectedText("文")
        XCTAssertEqual(fixture.host.text, "A文B\r\nsecond")
        XCTAssertEqual(view.accessibilityValue() as? String, "A文B\r\nsecond")
        XCTAssertEqual(view.accessibilitySelectedTextRange(), NSRange(location: 2, length: 0))
    }

    func testMarkedUpdatesAndBothCommitPathsUsePublicClient() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        let view = fixture.attachment.view
        let context = try XCTUnwrap(view.inputContext)
        let client = context.client
        let unspecified = NSRange(location: NSNotFound, length: 0)
        let initialPublications = fixture.host.publications

        client.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(client.hasMarkedText())
        XCTAssertEqual(fixture.attachment.inputState?.markedRange, NSRange(location: 0, length: 1))
        XCTAssertEqual(fixture.attachment.inputState?.hasComposition, true)
        XCTAssertEqual(view.accessibilityValue() as? String, "にabc")
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.publications, initialPublications)
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedText:")))

        client.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0), replacementRange: unspecified)
        XCTAssertEqual(fixture.attachment.inputState?.markedRange, NSRange(location: 0, length: 2))
        XCTAssertEqual(view.accessibilityValue() as? String, "日本abc")
        XCTAssertEqual(fixture.host.text, "abc")
        client.insertText("日本語", replacementRange: unspecified)
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(fixture.attachment.inputState?.hasComposition, false)
        XCTAssertEqual(fixture.host.text, "日本語abc")
        XCTAssertEqual(fixture.host.publications, initialPublications + 1)

        client.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(client.hasMarkedText())
        XCTAssertEqual(fixture.host.text, "日本語abc")
        client.unmarkText()
        XCTAssertFalse(client.hasMarkedText())
        XCTAssertEqual(fixture.attachment.inputState?.hasComposition, false)
        XCTAssertEqual(fixture.host.text, "日本語仮abc")
        XCTAssertEqual(fixture.host.publications, initialPublications + 2)
        withExtendedLifetime(context) {}
    }

    func testBlurDiscardsProvisionalCompositionAndInvalidatesOldClient() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        let oldContext = try XCTUnwrap(fixture.attachment.view.inputContext)
        let oldClient = oldContext.client
        let unspecified = NSRange(location: NSNotFound, length: 0)
        let initialPublications = fixture.host.publications
        oldClient.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified)
        XCTAssertTrue(oldClient.hasMarkedText())
        XCTAssertEqual(fixture.attachment.inputState?.hasComposition, true)
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.other))
        XCTAssertTrue(fixture.window.firstResponder === fixture.other)
        XCTAssertFalse(oldClient.hasMarkedText())
        oldClient.insertText("stale", replacementRange: unspecified)
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.publications, initialPublications)

        try fixture.focus()
        XCTAssertTrue(fixture.window.firstResponder === fixture.attachment.view)
        XCTAssertEqual(fixture.attachment.inputState?.hasComposition, false)
        XCTAssertEqual(fixture.attachment.view.content.string, "abc")
        XCTAssertEqual(fixture.attachment.view.accessibilityRole(), .textArea)
        XCTAssertEqual(oldClient.selectedRange().location, NSNotFound)
        withExtendedLifetime(oldContext) {}
    }
}
#endif
