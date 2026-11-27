#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import RunestoneSyntax
import TestTreeSitterLanguages
import XCTest

@MainActor
final class AppKitFoldingAnimationTests: XCTestCase {
    private struct Fixture {
        let window: NSWindow
        let scroll: NSScrollView
        let view: ReadOnlyDocumentView
        let text: String
    }

    func testFoldIndicatorUsesSelectedLineNumberColor() {
        let fixture = makeFixture(NSAttributedString(string: "header\nbody\n"))
        var configuration = fixture.view.displayConfiguration
        configuration.lineNumberColor = .blue
        configuration.selectedLineNumberColor = .red
        configuration.showsSelectedLines = true
        fixture.view.displayConfiguration = configuration
        fixture.view.updateDisplaySelection(NSRange(location: 0, length: 0))
        XCTAssertEqual(fixture.view.gutterForegroundColor(for: fixture.view.manager.firstLine), .red)
        XCTAssertEqual(fixture.view.gutterForegroundColor(for: fixture.view.manager.line(atRow: 1)), .blue)
        configuration.showsSelectedLines = false
        fixture.view.displayConfiguration = configuration
        XCTAssertEqual(fixture.view.gutterForegroundColor(for: fixture.view.manager.firstLine), .blue)
    }

    func testFirstCollapseSurvivesDestinationSyntaxHighlighting() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduce Motion is enabled") }
        let fixture = try makeAnimatedFoldFixture()
        defer { fixture.window.orderOut(nil) }
        XCTAssertTrue(fixture.view.toggleSyntaxFold(atRow: 0))
        let transition = try XCTUnwrap(fixture.view.foldingTransition)
        let running = expectation(description: "Animation remains visible while new tail lines acquire syntax colors")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            XCTAssertTrue(fixture.view.foldingTransition === transition)
            XCTAssertGreaterThan(transition.progress, 0)
            XCTAssertLessThan(transition.progress, 1)
            running.fulfill()
        }
        XCTAssertEqual(XCTWaiter().wait(for: [running], timeout: 2), .completed)
        let lastLine = try XCTUnwrap(fixture.view.visibleLayout?.lines.last?.line)
        let number = (fixture.text as NSString).range(of: "42", range: NSRange(
            location: lastLine.location, length: lastLine.data.length))
        XCTAssertNotEqual(number.location, NSNotFound)
        let colored = expectation(for: NSPredicate { _, _ in
            fixture.view.foldingTransition == nil &&
                fixture.view.presentationAttributedSubstring(from: number)
                    .attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [colored], timeout: 2), .completed)
    }

    func testFirstCollapseSnapshotMatchesRepeatedCollapse() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduce Motion is enabled") }
        let fixture = try makeAnimatedFoldFixture()
        defer { fixture.window.orderOut(nil) }
        let view = fixture.view
        var images: [Data] = []
        for _ in 0..<2 {
            XCTAssertTrue(view.toggleSyntaxFold(atRow: 0))
            let transition = try XCTUnwrap(view.foldingTransition)
            transition.progress = 0
            let bitmap = try XCTUnwrap(transition.bitmapImageRepForCachingDisplay(in: transition.bounds))
            transition.cacheDisplay(in: transition.bounds, to: bitmap)
            images.append(try XCTUnwrap(bitmap.representation(using: .png, properties: [:])))
            view.unfoldAllSyntax()
        }
        XCTAssertEqual(images[0], images[1], "A cold first collapse must capture the same text as later collapses")
    }

    func testFoldingAnimationFinishesAndRapidReversalKeepsDocumentIntact() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduce Motion is enabled") }
        let fixture = try makeAnimatedFoldFixture()
        defer { fixture.window.orderOut(nil) }
        let view = fixture.view
        XCTAssertNotNil(SyntaxFoldIndicator.image(color: .lightGray))
        XCTAssertTrue(view.toggleSyntaxFold(atRow: 0))
        let collapse = try XCTUnwrap(view.foldingTransition)
        XCTAssertEqual(collapse.frame.size, fixture.scroll.contentView.bounds.size)
        XCTAssertTrue(view.manager.isLineHidden(1))
        XCTAssertNil(collapse.hitTest(.zero))
        XCTAssertTrue(view.toggleSyntaxFold(atRow: 0))
        XCTAssertNil(collapse.superview)
        XCTAssertNotNil(view.foldingTransition)
        XCTAssertFalse(view.manager.isLineHidden(1))
        let finished = expectation(for: NSPredicate { _, _ in view.foldingTransition == nil }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [finished], timeout: 2), .completed)
        XCTAssertEqual(view.content.string, fixture.text)
    }

    func testFirstCollapseKeepsViewportUntilAnimationFinishes() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduce Motion is enabled") }
        let fixture = try makeAnimatedFoldFixture(tailCount: 0, bodyCount: 40)
        defer { fixture.window.orderOut(nil) }
        fixture.scroll.contentView.scroll(to: CGPoint(x: 0, y: 5))
        fixture.view.updateViewport()
        let viewport = fixture.scroll.contentView.bounds
        XCTAssertTrue(fixture.view.toggleSyntaxFold(atRow: 0))
        XCTAssertNotNil(fixture.view.foldingTransition)
        XCTAssertEqual(fixture.scroll.contentView.bounds, viewport)
        let finished = expectation(for: NSPredicate { _, _ in fixture.view.foldingTransition == nil }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [finished], timeout: 2), .completed)
        XCTAssertEqual(fixture.scroll.contentView.bounds.minY, 0)
        XCTAssertEqual(fixture.view.content.string, fixture.text)
    }

    func testFoldingAnimationCancelsWhenScrollingOrEditing() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduce Motion is enabled") }
        let fixture = try makeAnimatedFoldFixture()
        defer { fixture.window.orderOut(nil) }
        let view = fixture.view
        XCTAssertTrue(view.toggleSyntaxFold(atRow: 0))
        XCTAssertNotNil(view.foldingTransition)
        fixture.scroll.contentView.scroll(to: CGPoint(x: 0, y: 10))
        view.updateViewport()
        XCTAssertNil(view.foldingTransition)
        fixture.scroll.contentView.scroll(to: .zero)
        view.updateViewport()
        XCTAssertTrue(view.toggleSyntaxFold(atRow: 0))
        XCTAssertNotNil(view.foldingTransition)
        XCTAssertTrue(view.replaceContent(in: NSRange(location: 0, length: 0), with: NSAttributedString(string: " ")))
        XCTAssertNil(view.foldingTransition)
        XCTAssertEqual(view.content.string, " " + fixture.text)
    }

    private func makeAnimatedFoldFixture(tailCount: Int = 40, bodyCount: Int = 1) throws -> Fixture {
        _ = NSApplication.shared
        let text = "{\n" + String(repeating: "\n", count: bodyCount) + "  \"value\": 1\n}\n"
            + String(repeating: "{\"tail\": 42}\n", count: tailCount)
        let fixture = makeFixture(NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]), height: 240)
        let window = NSWindow(contentRect: fixture.scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = fixture.scroll
        window.orderFront(nil)
        var configuration = fixture.view.displayConfiguration
        configuration.isCodeFoldingEnabled = true
        fixture.view.displayConfiguration = configuration
        let highlighter = try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(), highlightsQuery: "(number) @number", foldsQuery: "(object) @fold"))
        fixture.view.applySyntaxConfiguration(.init(highlighter: highlighter, styles: [
            "number": RunestoneAppKitSyntaxStyle(foregroundColor: .systemBlue)
        ]))
        let parsed = expectation(for: NSPredicate { _, _ in fixture.view.syntaxFoldRows == [0] }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [parsed], timeout: 3), .completed)
        return Fixture(window: window, scroll: fixture.scroll, view: fixture.view, text: text)
    }

    private func makeFixture(_ content: NSAttributedString, height: CGFloat = 120)
        -> (scroll: NSScrollView, view: ReadOnlyDocumentView) {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: height))
        let view = ReadOnlyDocumentView(content: content)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (scroll, view)
    }
}
#endif
