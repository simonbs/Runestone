// swiftlint:disable file_length
import CoreText
import Foundation
@testable import Runestone
import UIKit
import XCTest

/// Compare prefix reuse with fresh production layout, including drawing and hit testing.
@MainActor
final class LinePrefixReuseTests: XCTestCase {
    private func text(_ contents: String, size: CGFloat = 17, font: UIFont? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString(string: contents)
        DefaultStringAttributes(textColor: .black, font: font ?? UIFont(name: "Menlo-Regular", size: size)!,
                                kern: 0, tabWidth: 40).apply(to: result)
        return result
    }

    private func replacing(_ original: NSAttributedString, range: NSRange, with replacement: NSAttributedString) -> NSAttributedString {
        let changed = NSMutableAttributedString(attributedString: original)
        changed.replaceCharacters(in: range, with: replacement)
        return changed
    }

}

extension LinePrefixReuseTests {
    func testProductionPrefixRebuildsColorsAndContinuesMeasuredRanges() throws {
        let original = text(String(repeating: "alpha / beta gamma delta ", count: 300) + "\r\n", font: DefaultTheme.shared.font)
        let configuration = LayoutConfiguration(width: 151, heightMultiplier: 1.15)
        let typesetter = LineTypesetter(lineID: "production-prefix")
        typesetter.constrainingWidth = configuration.width
        typesetter.lineFragmentHeightMultiplier = configuration.heightMultiplier
        typesetter.prepareToTypeset(original)
        typesetter.typesetLineFragments(toLocation: 5_500)
        let oldCount = typesetter.lineFragments.count
        let changed = NSMutableAttributedString(attributedString: replacing(
            original, range: NSRange(location: original.length - 20, length: 0), with: text("\"", font: DefaultTheme.shared.font)
        ))
        changed.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: changed.length))
        changed.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 100, length: 200))
        for location in stride(from: 0, to: changed.length, by: 7) {
            changed.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: location, length: min(3, changed.length - location)))
        }
        let prefix = typesetter.reprepareToTypeset(changed, previous: original, prefixLimit: oldCount - 2)
        XCTAssertEqual(prefix.count, oldCount - 2)
        let end = try XCTUnwrap(prefix.last).range.upperBound
        try compare(prefix, with: fresh(changed, configuration, toLocation: end), text: changed, complete: false)
        XCTAssertEqual(typesetter.typesetLength, end)
        XCTAssertEqual(typesetter.maximumLineWidth, prefix.map(\.scaledSize.width).max() ?? 0)
        typesetter.typesetLineFragments(toLocation: changed.length)
        XCTAssertTrue(typesetter.isFinishedTypesetting)
        try compare(typesetter.lineFragments, with: fresh(changed, configuration), text: changed)
    }

    func testProductionPrefixRejectsChangedConfigurationAndEarlyRequests() throws {
        let original = text(String(repeating: "alpha / beta gamma delta ", count: 300), font: DefaultTheme.shared.font)
        let changed = replacing(original, range: NSRange(location: original.length - 20, length: 1), with: text("X", font: DefaultTheme.shared.font))
        for configuration in [LayoutConfiguration(width: 152), LayoutConfiguration(width: 151, heightMultiplier: 1.2),
                              LayoutConfiguration(width: 151, wordWrapping: false), LayoutConfiguration(width: 151)] {
            let typesetter = LineTypesetter(lineID: "production-prefix-fallback")
            typesetter.constrainingWidth = 151
            typesetter.prepareToTypeset(original)
            typesetter.typesetLineFragments(toLocation: original.length)
            typesetter.constrainingWidth = configuration.width
            typesetter.lineFragmentHeightMultiplier = configuration.heightMultiplier
            typesetter.lineBreakMode = configuration.wordWrapping ? .byWordWrapping : .byCharWrapping
            let limit = configuration == LayoutConfiguration(width: 151) ? 2 : typesetter.lineFragments.count
            XCTAssertTrue(typesetter.reprepareToTypeset(changed, previous: original, prefixLimit: limit).isEmpty)
            typesetter.typesetLineFragments(toLocation: changed.length)
            try compare(typesetter.lineFragments, with: fresh(changed, configuration), text: changed)
        }
    }

    func testProductionPrefixRejectsLateControlsAndMixedASCIIUnicodeInputs() throws {
        let ascii = text(String(repeating: "alpha / beta gamma delta ", count: 300) + "\r\n", font: DefaultTheme.shared.font)
        let configuration = LayoutConfiguration(width: 151)
        // The unsupported unit lies beyond the measured prefix, so validation
        // must inspect the whole paragraph rather than just retained fragments.
        // Unicode/ASCII pairs exercise both input directions without depending
        // on Foundation's choice of internal storage or pointer availability.
        for token in ["\u{0}", "\t", "\u{1F}", "\u{7F}", "é", "👩‍💻"] {
            let unsupported = replacing(ascii, range: NSRange(location: 6_500, length: 1),
                                        with: text(token, font: DefaultTheme.shared.font))
            for (old, changed) in [(ascii, unsupported), (unsupported, ascii)] {
                let typesetter = LineTypesetter(lineID: "prefix-storage-fallback")
                typesetter.constrainingWidth = configuration.width
                typesetter.prepareToTypeset(old)
                typesetter.typesetLineFragments(toLocation: 5_500)
                let limit = typesetter.lineFragments.count
                XCTAssertTrue(typesetter.reprepareToTypeset(changed, previous: old, prefixLimit: limit).isEmpty)
                typesetter.typesetLineFragments(toLocation: 5_500)
                try compare(typesetter.lineFragments, with: fresh(changed, configuration, toLocation: 5_500),
                            text: changed, sparsePixels: true, complete: false)
            }
        }

    }

    /// A pending highlight or a real metric change must supersede edit reuse.
    func testProductionControllerInvalidationsAndStaleHighlightCompletionMatchFresh() throws {
        let contents = String(repeating: "alpha / beta gamma delta ", count: 300)
        for pendingHighlight in [false, true] {
            let fixture = PrefixControllerFixture(contents: contents)
            fixture.controller.prepareToDisplayString(toLocation: contents.utf16.count,
                                                      syntaxHighlightAsynchronously: pendingHighlight)
            let originalWidth = try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: 0).data.lineFragment).baseSize.width
            if !pendingHighlight { fixture.controller.kern = 0.75 }
            fixture.string.replaceText(in: NSRange(location: contents.utf16.count - 12, length: 1), with: "X")
            fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            if pendingHighlight {
                XCTAssertEqual(fixture.highlighter.pending.count, 1)
                XCTAssertFalse(try XCTUnwrap(fixture.highlighter.pending.first).input.isValid())
            }
            fixture.controller.prepareToDisplayString(toLocation: 5_000, syntaxHighlightAsynchronously: false)
            fixture.highlighter.completePending()
            let current = try XCTUnwrap(fixture.controller.attributedString)
            XCTAssertEqual(current.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
            let expected = LineTypesetter(lineID: "fresh-controller-invalidation")
            expected.constrainingWidth = 151
            expected.prepareToTypeset(current)
            expected.typesetLineFragments(toLocation: 5_000, additionalLineFragmentCount: 1)
            let actual = try (0 ..< fixture.controller.numberOfLineFragments).map { index in
                try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: index).data.lineFragment)
            }
            if !pendingHighlight {
                XCTAssertNotEqual(try XCTUnwrap(actual.first).baseSize.width, originalWidth,
                                  "The invalidation must exercise a real shaping change.")
            }
            try compare(actual, with: expected.lineFragments, text: current, complete: false)
        }
    }

    func testProductionControllerReseedsBoundedPrefixAndContinuesLikeFresh() throws {
        let contents = String(repeating: "alpha / beta gamma delta ", count: 300)
        for request in 0 ..< 3 {
            let fixture = PrefixControllerFixture(contents: contents)
            fixture.controller.prepareToDisplayString(toLocation: contents.utf16.count, syntaxHighlightAsynchronously: false)
            fixture.string.replaceText(in: NSRange(location: contents.utf16.count - 12, length: 1), with: "X")
            fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            let expected = LineTypesetter(lineID: "fresh-controller-prefix")
            expected.constrainingWidth = 151
            let current = NSMutableAttributedString(string: fixture.string.string as String)
            DefaultStringAttributes(textColor: .blue, font: DefaultTheme.shared.font, kern: 0, tabWidth: 10).apply(to: current)
            expected.prepareToTypeset(current)
            switch request {
            case 0:
                fixture.controller.prepareToDisplayString(toLocation: 5_000, syntaxHighlightAsynchronously: false)
                expected.typesetLineFragments(toLocation: 5_000, additionalLineFragmentCount: 1)
            case 1:
                let rect = CGRect(x: 0, y: 0, width: 151, height: 6_000)
                fixture.controller.prepareToDisplayString(in: rect, syntaxHighlightAsynchronously: false)
                expected.typesetLineFragments(in: rect)
            default:
                fixture.controller.prepareToDisplayString(toLineFragmentIndex: 350, syntaxHighlightAsynchronously: false)
                expected.typesetLineFragments(toLocation: 0, additionalLineFragmentCount: 351)
            }
            let bounded = try (0 ..< fixture.controller.numberOfLineFragments).map { index in
                try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: index).data.lineFragment)
            }
            XCTAssertLessThan(bounded.count, fresh(current, LayoutConfiguration(width: 151)).count)
            try compare(bounded, with: expected.lineFragments, text: current, complete: false)
            XCTAssertEqual(fixture.controller.lineWidth, ceil(expected.maximumLineWidth))
            fixture.controller.prepareToDisplayString(toLocation: current.length, syntaxHighlightAsynchronously: false)
            expected.typesetLineFragments(toLocation: current.length, additionalLineFragmentCount: 1)
            let completed = try (0 ..< fixture.controller.numberOfLineFragments).map { index in
                try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: index).data.lineFragment)
            }
            try compare(completed, with: expected.lineFragments, text: current)
        }
    }
}

extension LinePrefixReuseTests {
    /// Edits inside hidden whitespace or a word must reflow their owner. Splits
    /// and joins use individual logical-line results, never multiline paragraphs.
    func testBoundaryEditsReflowAffectedWordsAndPreservePrefix() throws {
        let font = DefaultTheme.shared.font
        let stable = String(repeating: "anchor / stable words ", count: 240)
        let body = stable + "\"" + String(repeating: "a", count: 180)
            + String(repeating: " ", count: 129) + "(" + String(repeating: "b", count: 120) + " tail words"
        let original = text(body + "\r\n", font: font)
        let configuration = LayoutConfiguration(width: 101.5, heightMultiplier: 1.15)
        let spaces = (body as NSString).range(of: String(repeating: " ", count: 129))
        let split = stable.utf16.count + 81
        let edits = [
            PrefixEdit(range: NSRange(location: spaces.location + 17, length: 1), replacement: "X"),
            PrefixEdit(range: spaces, replacement: ""),
            PrefixEdit(range: NSRange(location: split, length: original.length - split), replacement: "\r\n"),
            PrefixEdit(range: NSRange(location: spaces.location - 1, length: 0), replacement: "\"/>"),
            PrefixEdit(range: NSRange(location: original.length - 2, length: 2), replacement: "\n", expectsReuse: false)
        ]
        for edit in edits {
            let typesetter = LineTypesetter(lineID: "prefix-boundary")
            typesetter.constrainingWidth = configuration.width
            typesetter.lineFragmentHeightMultiplier = configuration.heightMultiplier
            typesetter.prepareToTypeset(original)
            typesetter.typesetLineFragments(toLocation: original.length)
            XCTAssertTrue(typesetter.lineFragments.contains { $0.hiddenLength > 0 })
            let changed = replacing(original, range: edit.range, with: text(edit.replacement, font: font))
            var previous = original
            // Restore through the same typesetter too: this includes joining the
            // split word back without a separator and continuing a reused layout.
            for next in [changed, original] {
                let prefix = typesetter.reprepareToTypeset(next, previous: previous, prefixLimit: typesetter.lineFragments.count)
                XCTAssertEqual(!prefix.isEmpty, edit.expectsReuse)
                typesetter.typesetLineFragments(toLocation: next.length)
                try compare(typesetter.lineFragments, with: fresh(next, configuration), text: next)
                previous = next
            }
        }
    }

    /// Geometry reuse must reject changes that can alter shaping, even when the
    /// text edit is late and a large unchanged textual prefix is available.
    func testShapingAndUnknownAttributesRejectPrefixReuse() throws {
        let font = DefaultTheme.shared.font
        let original = text(String(repeating: "anchor / stable words ", count: 260) + "\n", font: font)
        let configuration = LayoutConfiguration(width: 151)
        let paragraph = try XCTUnwrap(original.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let indented = try XCTUnwrap(paragraph.mutableCopy() as? NSMutableParagraphStyle)
        indented.firstLineHeadIndent = 10
        let changes: [(NSAttributedString.Key, Any)] = [
            (.font, UIFont(name: "Menlo-Regular", size: 19)!), (.kern, 0.5), (.ligature, 0),
            (.paragraphStyle, indented.copy()), (.baselineOffset, 3),
            (NSAttributedString.Key(kCTLanguageAttributeName as String), "th")
        ]
        for (key, value) in changes {
            let typesetter = LineTypesetter(lineID: "prefix-shaping")
            typesetter.constrainingWidth = configuration.width
            typesetter.prepareToTypeset(original)
            typesetter.typesetLineFragments(toLocation: original.length)
            let changed = NSMutableAttributedString(attributedString: replacing(
                original, range: NSRange(location: original.length - 12, length: 1), with: text("X", font: font)
            ))
            changed.addAttribute(key, value: value, range: NSRange(location: 0, length: changed.length))
            let prefix = typesetter.reprepareToTypeset(changed, previous: original, prefixLimit: typesetter.lineFragments.count)
            XCTAssertTrue(prefix.isEmpty, "Changed shaping attribute: \(key.rawValue)")
            typesetter.typesetLineFragments(toLocation: changed.length)
            try compare(typesetter.lineFragments, with: fresh(changed, configuration), text: changed)
        }
    }
}

private struct PrefixEdit {
    let range: NSRange
    let replacement: String
    var expectsReuse = true
}

private final class PrefixControllerFixture: LineControllerDelegate {
    let string: StringView
    let controller: LineController
    let highlighter = PrefixColorHighlighter()

    init(contents: String) {
        string = StringView(string: contents)
        let lines = LineManager(stringView: string)
        lines.rebuild()
        controller = LineController(line: lines.firstLine, stringView: string,
                                    invisibleCharacterConfiguration: InvisibleCharacterConfiguration(),
                                    highlightService: HighlightService(lineManager: lines))
        controller.constrainingWidth = 151
        controller.delegate = self
    }

    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? { highlighter }
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {}
}

private final class PrefixColorHighlighter: LineSyntaxHighlighter {
    var pending: [(input: LineSyntaxHighlighterInput, completion: AsyncCallback)] = []
    var theme: Theme = DefaultTheme.shared
    var canHighlight: Bool { true }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        let color = input.attributedString.string.contains("X") ? UIColor.blue : UIColor.red
        input.attributedString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: input.attributedString.length))
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        pending.append((input, completion))
    }

    func completePending() {
        let requests = pending
        pending.removeAll()
        for request in requests {
            if request.input.isValid() { syntaxHighlight(request.input) }
            request.completion(.success(LineSyntaxHiglighterSetAttributesResult(isSizingInvalid: false)))
        }
    }

    func cancel() {}
}

extension LinePrefixReuseTests {
    private func compare(_ actual: [LineFragment], with expected: [LineFragment], text: NSAttributedString,
                         sparsePixels: Bool = false, complete: Bool = true) throws {
        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual.last?.range.upperBound ?? 0, complete ? text.length : expected.last?.range.upperBound ?? 0)
        for (index, pair) in zip(actual, expected).enumerated() {
            let (lhs, rhs) = pair
            XCTAssertEqual(lhs.index, rhs.index)
            XCTAssertEqual(lhs.visibleRange, rhs.visibleRange)
            XCTAssertEqual(lhs.hiddenLength, rhs.hiddenLength)
            XCTAssertEqual(lhs.baseSize, rhs.baseSize)
            XCTAssertEqual(lhs.scaledSize, rhs.scaledSize)
            XCTAssertEqual(lhs.descent, rhs.descent)
            XCTAssertEqual(lhs.yPosition, rhs.yPosition)
            if index > 0 {
                XCTAssertEqual(lhs.range.location, actual[index - 1].range.upperBound)
                XCTAssertEqual(lhs.yPosition, actual[index - 1].yPosition + actual[index - 1].scaledSize.height)
            }
            compareRuns(lhs.line, rhs.line)
            for location in lhs.range.location ... lhs.range.upperBound {
                let leftCaret = lhs.caretLocation(forLineLocalLocation: location)
                let rightCaret = rhs.caretLocation(forLineLocalLocation: location)
                XCTAssertEqual(leftCaret, rightCaret)
                guard let leftCaret, let rightCaret else { continue }
                var leftSecondary: CGFloat = 0
                var rightSecondary: CGFloat = 0
                let leftX = CTLineGetOffsetForStringIndex(lhs.line, leftCaret, &leftSecondary)
                let rightX = CTLineGetOffsetForStringIndex(rhs.line, rightCaret, &rightSecondary)
                XCTAssertEqual(leftX, rightX)
                XCTAssertEqual(leftSecondary, rightSecondary)
                XCTAssertEqual(CTLineGetStringIndexForPosition(lhs.line, CGPoint(x: leftX + 0.25, y: 0)),
                               CTLineGetStringIndexForPosition(rhs.line, CGPoint(x: rightX + 0.25, y: 0)))
            }
            if !sparsePixels || index == 0 || index >= actual.count - 2 {
                XCTAssertEqual(try pixels(lhs, text: text), try pixels(rhs, text: text))
            }
        }
    }

    private func compareRuns(_ actual: CTLine, _ expected: CTLine) {
        let actualRuns = CTLineGetGlyphRuns(actual) as? [CTRun] ?? []
        let expectedRuns = CTLineGetGlyphRuns(expected) as? [CTRun] ?? []
        XCTAssertEqual(actualRuns.count, expectedRuns.count)
        for (lhs, rhs) in zip(actualRuns, expectedRuns) {
            XCTAssertEqual(CTRunGetAttributes(lhs) as NSDictionary, CTRunGetAttributes(rhs) as NSDictionary)
            XCTAssertEqual(CTRunGetStatus(lhs), CTRunGetStatus(rhs))
            XCTAssertEqual(CTRunGetStringRange(lhs).location, CTRunGetStringRange(rhs).location)
            XCTAssertEqual(CTRunGetStringRange(lhs).length, CTRunGetStringRange(rhs).length)
            let count = CTRunGetGlyphCount(lhs)
            XCTAssertEqual(count, CTRunGetGlyphCount(rhs))
            guard count == CTRunGetGlyphCount(rhs) else { continue }
            var leftGlyphs = [CGGlyph](repeating: 0, count: count)
            var rightGlyphs = leftGlyphs
            var leftPositions = [CGPoint](repeating: .zero, count: count)
            var rightPositions = leftPositions
            var leftAdvances = [CGSize](repeating: .zero, count: count)
            var rightAdvances = leftAdvances
            var leftIndices = [CFIndex](repeating: 0, count: count)
            var rightIndices = leftIndices
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(lhs, all, &leftGlyphs)
            CTRunGetGlyphs(rhs, all, &rightGlyphs)
            CTRunGetPositions(lhs, all, &leftPositions)
            CTRunGetPositions(rhs, all, &rightPositions)
            CTRunGetAdvances(lhs, all, &leftAdvances)
            CTRunGetAdvances(rhs, all, &rightAdvances)
            CTRunGetStringIndices(lhs, all, &leftIndices)
            CTRunGetStringIndices(rhs, all, &rightIndices)
            XCTAssertEqual(leftGlyphs, rightGlyphs)
            XCTAssertEqual(leftPositions, rightPositions)
            XCTAssertEqual(leftAdvances, rightAdvances)
            XCTAssertEqual(leftIndices, rightIndices)
        }
    }

    private func pixels(_ fragment: LineFragment, text: NSAttributedString) throws -> Data {
        let configuration = InvisibleCharacterConfiguration()
        configuration.showSpaces = true
        let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: configuration)
        let delegate = FragmentText(text.attributedSubstring(from: fragment.visibleRange).string)
        renderer.delegate = delegate
        let size = CGSize(width: max(1, ceil(fragment.scaledSize.width) + 4), height: max(1, ceil(fragment.scaledSize.height)))
        let width = Int(size.width)
        let height = Int(size.height)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        // Match the UIKit canvas orientation without initializing a screen-backed
        // image renderer. The production renderer applies its own CoreText flip.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        // Invisible-space symbols use NSString drawing and need the current UIKit
        // context as well as the explicit context passed to the production renderer.
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        renderer.draw(to: context, inCanvasOfSize: size)
        withExtendedLifetime(delegate) {}
        return Data(bytes: try XCTUnwrap(context.data), count: width * height * 4)
    }
}

private final class FragmentText: LineFragmentRendererDelegate {
    let contents: String
    init(_ contents: String) { self.contents = contents }
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? { contents }
}

private struct LayoutConfiguration: Equatable {
    var width: CGFloat
    var heightMultiplier: CGFloat = 1
    var wordWrapping = true
}

private func fresh(_ text: NSAttributedString, _ configuration: LayoutConfiguration, toLocation: Int? = nil) -> [LineFragment] {
    let typesetter = LineTypesetter(lineID: "incremental-experiment")
    typesetter.constrainingWidth = configuration.width
    typesetter.lineFragmentHeightMultiplier = configuration.heightMultiplier
    typesetter.lineBreakMode = configuration.wordWrapping ? .byWordWrapping : .byCharWrapping
    typesetter.prepareToTypeset(text)
    typesetter.typesetLineFragments(toLocation: toLocation ?? text.length)
    return typesetter.lineFragments
}
