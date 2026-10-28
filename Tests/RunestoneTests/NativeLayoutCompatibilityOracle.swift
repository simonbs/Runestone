import CoreText
import Foundation
@testable import Runestone
import UIKit
import XCTest

// One frozen native baseline and renderer assertion shared by the production
// compatibility contracts. No experimental gate or cluster typesetter lives here.
private func nativeDrawingText(_ text: NSAttributedString) -> NSAttributedString {
    var copy: NSMutableAttributedString?
    text.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
        guard let value else {
            return
        }
        if copy == nil { copy = NSMutableAttributedString(attributedString: text) }
        copy?.removeAttribute(.backgroundColor, range: range)
        copy?.addAttribute(.tokenBackgroundColor, value: value, range: range)
    }
    return copy ?? text
}

func makeLayoutText(_ string: String, font: UIFont? = nil,
                    color: UIColor = .black, tabWidth: CGFloat = 40) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(string: string)
    DefaultStringAttributes(textColor: color, font: font ?? UIFont(name: "Menlo-Regular", size: 17)!,
                            kern: 0, tabWidth: tabWidth).apply(to: result)
    return result
}

func preparedTypesetter(_ text: NSAttributedString, width: CGFloat, multiplier: CGFloat = 1) -> LineTypesetter {
    let production = LineTypesetter(lineID: "native-compatibility")
    production.constrainingWidth = width
    production.lineFragmentHeightMultiplier = multiplier
    production.prepareToTypeset(text)
    return production
}

func nativeLayout(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) -> [LineFragment] {
    let native = NativeLayoutOracle()
    native.constrainingWidth = width
    native.lineFragmentHeightMultiplier = heightMultiplier
    native.prepareToTypeset(text)
    native.typesetLineFragments(toLocation: text.length)
    return native.lineFragments
}

/// Frozen native baseline: no production LineTypesetter/LineBreakSuggester and no
/// cluster fast path. Only ordinary-width cases use this legacy truncation oracle;
/// pathological progress behavior has separate contract tests, never a hanging baseline.
final class NativeLayoutOracle {
    var constrainingWidth: CGFloat = 0
    var lineFragmentHeightMultiplier: CGFloat = 1
    private(set) var lineFragments: [LineFragment] = []
    private var text = NSAttributedString(string: "")
    private var native: CTTypesetter?
    var typesetLength: Int { lineFragments.last?.range.upperBound ?? 0 }

    func prepareToTypeset(_ text: NSAttributedString) {
        self.text = text
        native = CTTypesetterCreateWithAttributedString(nativeDrawingText(text))
    }

    func typesetLineFragments(toLocation target: Int) {
        guard constrainingWidth > 0, let native else {
            return
        }
        var offset = typesetLength
        var y = lineFragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        while offset < text.length && offset < target {
            let length = nativeWordBreak(text, native: native, offset: offset, width: constrainingWidth)
            guard let fragment = nativeFragment(text, native: native, offset: offset, length: length,
                                                index: lineFragments.count, y: y, width: constrainingWidth,
                                                multiplier: lineFragmentHeightMultiplier) else {
                XCTFail("Independent native oracle encountered a sub-glyph width; no invalid range was executed.")
                return
            }
            lineFragments.append(fragment)
            offset = fragment.range.upperBound
            y += fragment.scaledSize.height
        }
    }

    func refreshAppearance(_ text: NSAttributedString) -> [LineFragment] {
        prepareToTypeset(text)
        guard let native else {
            return lineFragments
        }
        lineFragments = lineFragments.map { fragment in
            let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
            return fragment.withLine(CTTypesetterCreateLine(native, range))
        }
        return lineFragments
    }
}

/// Preserve the original word-lookback rule independently, including inspection
/// of the character immediately after CoreText's suggested range.
private func nativeWordBreak(_ text: NSAttributedString, native: CTTypesetter,
                             offset: Int, width: CGFloat) -> Int {
    let length = CTTypesetterSuggestLineBreak(native, offset, Double(width))
    guard length > 0, offset + length < text.length else {
        return length
    }
    let string = CFAttributedStringGetString(text)
    func prefersBreak(at location: Int) -> Bool {
        guard let scalar = UnicodeScalar(CFStringGetCharacterAtIndex(string, location)) else {
            return false
        }
        return CharacterSet.whitespaces.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar)
    }
    guard !prefersBreak(at: offset + length - 1) else {
        return length
    }
    for lookback in 0 ..< min(length, 100) where prefersBreak(at: offset + length - lookback) {
        return length - lookback + 1
    }
    return length
}

// swiftlint:disable function_parameter_count
/// Frozen legacy truncation and hidden-space conventions for ordinary widths.
/// Invalid native ranges return nil instead of hanging the test runner.
/// Keep the frozen native fragment inputs explicit and independent of production state.
private func nativeFragment(_ text: NSAttributedString, native: CTTypesetter, offset: Int, length: Int,
                            index: Int, y: CGFloat, width: CGFloat, multiplier: CGFloat) -> LineFragment? {
    var length = length
    guard length > 0, offset + length <= text.length else {
        return nil
    }
    while length > 0 {
        let line = CTTypesetterCreateLine(native, CFRange(location: offset, length: length))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let measured = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        if measured <= width {
            let fragment = LineFragment(id: LineFragmentID(lineId: "native-compatibility", lineFragmentIndex: index),
                                        index: index, visibleRange: NSRange(location: offset, length: length), line: line,
                                        descent: descent, baseSize: CGSize(width: measured, height: height),
                                        scaledSize: CGSize(width: measured, height: height * multiplier), yPosition: y)
            var next = offset + length
            var hidden = 0
            while text.isWhitespaceCharacter(at: next) { hidden += 1; next += 1 }
            return fragment.withHiddenLength(hidden)
        }
        length -= 1
    }
    return nil
}

// swiftlint:enable function_parameter_count

func productionLayout(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) -> [LineFragment] {
    let production = preparedTypesetter(text, width: width, multiplier: heightMultiplier)
    production.typesetLineFragments(toLocation: text.length)
    return production.lineFragments
}

@MainActor
func assertNativeLayout(_ actual: [LineFragment], with expected: [LineFragment], text: NSAttributedString,
                        sparsePixels: Bool = false, complete: Bool = true) throws {
    XCTAssertEqual(actual.count, expected.count)
    guard actual.count == expected.count else { throw NativeCompatibilityMismatch.fragmentCount }
    if complete {
        XCTAssertEqual(actual.last?.range.upperBound ?? 0, text.length)
    } else {
        XCTAssertLessThanOrEqual(actual.last?.range.upperBound ?? 0, text.length)
    }
    for (index, pair) in zip(actual, expected).enumerated() {
        try assertNativeFragment(pair.0, pair.1, text: text,
                                 includePixels: !sparsePixels || index <= 1 || index == actual.count / 2 || index >= actual.count - 2)
        if index > 0 {
            XCTAssertEqual(pair.0.range.location, actual[index - 1].range.upperBound)
            XCTAssertEqual(pair.0.yPosition, actual[index - 1].yPosition + actual[index - 1].scaledSize.height)
        }
    }
}

@MainActor
private func assertNativeFragment(_ lhs: LineFragment, _ rhs: LineFragment, text: NSAttributedString,
                                  includePixels: Bool) throws {
    XCTAssertEqual(lhs.index, rhs.index)
    XCTAssertEqual(lhs.id, rhs.id)
    XCTAssertEqual(lhs.visibleRange, rhs.visibleRange)
    XCTAssertEqual(lhs.hiddenLength, rhs.hiddenLength)
    guard lhs.visibleRange == rhs.visibleRange, lhs.hiddenLength == rhs.hiddenLength else {
        throw NativeCompatibilityMismatch.fragmentRange
    }
    XCTAssertEqual(lhs.baseSize, rhs.baseSize)
    XCTAssertEqual(lhs.scaledSize, rhs.scaledSize)
    XCTAssertEqual(lhs.descent, rhs.descent)
    XCTAssertEqual(lhs.yPosition, rhs.yPosition)
    assertNativeRuns(lhs.line, rhs.line)
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
        for delta in [CGFloat(-0.25), 0, 0.25] {
            XCTAssertEqual(CTLineGetStringIndexForPosition(lhs.line, CGPoint(x: leftX + delta, y: 0)),
                           CTLineGetStringIndexForPosition(rhs.line, CGPoint(x: leftX + delta, y: 0)))
        }
    }
    if includePixels { XCTAssertEqual(try nativeLayoutPixels(lhs, text: text), try nativeLayoutPixels(rhs, text: text)) }
}

@MainActor
private func assertNativeRuns(_ actual: CTLine, _ expected: CTLine) {
    let actualRuns = CTLineGetGlyphRuns(actual) as? [CTRun] ?? []
    let expectedRuns = CTLineGetGlyphRuns(expected) as? [CTRun] ?? []
    XCTAssertEqual(actualRuns.count, expectedRuns.count)
    for (lhs, rhs) in zip(actualRuns, expectedRuns) {
        XCTAssertEqual(CTRunGetAttributes(lhs) as NSDictionary, CTRunGetAttributes(rhs) as NSDictionary)
        XCTAssertEqual(CTRunGetStatus(lhs), CTRunGetStatus(rhs))
        XCTAssertEqual(CTRunGetTextMatrix(lhs), CTRunGetTextMatrix(rhs))
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

@MainActor
private func nativeLayoutPixels(_ fragment: LineFragment, text: NSAttributedString) throws -> Data {
    let configuration = InvisibleCharacterConfiguration()
    configuration.showSpaces = true
    configuration.showTabs = true
    configuration.showLineBreaks = true
    let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: configuration)
    let delegate = NativeCompatibilityFragmentText(text.attributedSubstring(from: fragment.visibleRange).string)
    renderer.delegate = delegate
    let symbolWidth = [configuration.spaceSymbol, configuration.tabSymbol, configuration.lineBreakSymbol]
        .map { $0.size(withAttributes: [.font: configuration.font]).width }.max() ?? 0
    let size = CGSize(width: max(1, ceil(fragment.scaledSize.width + symbolWidth) + 4),
                      height: max(1, ceil(fragment.scaledSize.height)))
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

private final class NativeCompatibilityFragmentText: LineFragmentRendererDelegate {
    let contents: String
    init(_ contents: String) { self.contents = contents }
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? { contents }
}

private enum NativeCompatibilityMismatch: Error {
    case fragmentCount
    case fragmentRange
}
