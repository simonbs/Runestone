import CoreText
import Foundation
@testable import Runestone
import UIKit
import XCTest

/// Compatibility contracts for the production alphanumeric-run fast path.
/// The expected layout uses a frozen native word-break oracle, never the fast path.
@MainActor
final class LineTypesetterNativeCompatibilityTests: XCTestCase {
    func testAlphanumericParagraphsMatchNativeLayout() throws {
        let theme = DefaultTheme.shared
        let dynamicColor = theme.textColor
        let body = String(repeating: "officeAV09flffi", count: 300)
        for style in [UIUserInterfaceStyle.light, .dark] {
            try withTraits(style) {
                for tabLength in [2, 8] {
                    for ending in ["", "\n", "\r\n"] {
                        let text = makeLayoutText(body + ending, font: theme.font, color: dynamicColor,
                                                  tabWidth: TabWidthMeasurer.tabWidth(tabLength: tabLength, font: theme.font))
                        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: text))
                        let native = CTTypesetterCreateWithAttributedString(text)
                        let boundary = CGFloat(CTLineGetTypographicBounds(
                            CTTypesetterCreateLine(native, CFRange(location: 0, length: 37)), nil, nil, nil))
                        for width in [boundary - 1 / 1_024, boundary + 1 / 1_024] {
                            try assertNativeLayout(productionLayout(text, width: width), with: nativeLayout(text, width: width),
                                                   text: text, sparsePixels: true)
                        }
                    }
                }
            }
        }
        // Exercise the admitted size limits in both families without repeating
        // the entire default-theme/appearance matrix above.
        for size in [CGFloat(10), CGFloat(22)] {
            let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: size)),
                         UIFont.monospacedSystemFont(ofSize: size, weight: .regular)]
            for font in fonts {
                let text = makeLayoutText(body + "\r\n", font: font, color: dynamicColor,
                                          tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font))
                XCTAssertNotNil(UnbrokenLineBreakContext.make(for: text))
                let native = CTTypesetterCreateWithAttributedString(text)
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: 0, length: 23)), nil, nil, nil))
                for width in [boundary - 1 / 1_024, boundary + 1 / 1_024] {
                    try assertNativeLayout(productionLayout(text, width: width), with: nativeLayout(text, width: width),
                                           text: text, sparsePixels: true)
                }
            }
        }
    }

    func testUnsupportedAlphanumericContentAndAttributesUseNativeLayout() throws {
        let body = String(repeating: "a", count: 4_200)
        var fixtures = [makeLayoutText("{\"payload\":\"" + body + "\"}"), makeLayoutText(body + "é"),
                        makeLayoutText(body + " tail"), makeLayoutText(body + "אבג"), makeLayoutText(body + "👩‍💻"),
                        makeLayoutText(body + "\0Z"), makeLayoutText(body + "\tZ"), makeLayoutText(body + "\u{007F}")]
        let mixedFont = makeLayoutText(body)
        mixedFont.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 4_100, length: 3))
        fixtures.append(mixedFont)
        let mixedFixedFonts = makeLayoutText(body)
        mixedFixedFonts.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular),
                                     range: NSRange(location: 4_100, length: 3))
        fixtures.append(mixedFixedFonts)
        let styled = makeLayoutText(body)
        styled.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 4_100, length: 3))
        fixtures.append(styled)
        for (key, value) in [(NSAttributedString.Key.ligature, NSNumber(value: 1)), (.kern, NSNumber(value: 0.375))] {
            let text = makeLayoutText(String(repeating: "officeAV09flffi", count: 280))
            text.addAttribute(key, value: value, range: NSRange(location: 4_100, length: 30))
            fixtures.append(text)
        }
        let paragraphChanges: [(NSMutableParagraphStyle) -> Void] = [
            { $0.baseWritingDirection = .rightToLeft }, { $0.firstLineHeadIndent = 3.5 }, { $0.hyphenationFactor = 1 }
        ]
        for change in paragraphChanges {
            let text = makeLayoutText(body)
            let original = try XCTUnwrap(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            let paragraph = try XCTUnwrap(original.mutableCopy() as? NSMutableParagraphStyle)
            change(paragraph)
            text.addAttribute(.paragraphStyle, value: paragraph.copy(), range: NSRange(location: 0, length: text.length))
            fixtures.append(text)
        }
        for text in fixtures {
            XCTAssertNil(UnbrokenLineBreakContext.make(for: text))
            try assertNativeLayout(productionLayout(text, width: 320.25), with: nativeLayout(text, width: 320.25),
                                   text: text, sparsePixels: true)
        }
    }

    func testAppearanceRefreshAndResetKeepNativeLayout() throws {
        let theme = DefaultTheme.shared
        let initial = makeLayoutText(String(repeating: "officeAV09flffi", count: 300) + "\r\n",
                                     font: theme.font, color: theme.textColor,
                                     tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: theme.font))
        let production = LineTypesetter(lineID: "native-compatibility")
        production.constrainingWidth = 320.25
        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: initial))
        production.prepareToTypeset(initial)
        let oracle = NativeLayoutOracle()
        oracle.constrainingWidth = 320.25
        oracle.prepareToTypeset(initial)
        production.typesetLineFragments(toLocation: 100)
        oracle.typesetLineFragments(toLocation: 100)
        try assertNativeLayout(production.lineFragments, with: oracle.lineFragments, text: initial, complete: false)

        let colored = NSMutableAttributedString(attributedString: initial)
        colored.addAttribute(.foregroundColor, value: UIColor.systemRed.withAlphaComponent(0.65),
                             range: NSRange(location: 2, length: 2))
        colored.addAttribute(.foregroundColor, value: UIColor.systemBlue,
                             range: NSRange(location: production.typesetLength - 1, length: 4))
        let rejected = NSMutableAttributedString(attributedString: colored)
        rejected.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 0, length: rejected.length))
        for text in [colored, rejected, colored] {
            XCTAssertEqual(UnbrokenLineBreakContext.make(for: text) != nil, text !== rejected)
            let previousLength = production.typesetLength
            _ = production.refreshAppearance(text)
            _ = oracle.refreshAppearance(text)
            XCTAssertEqual(production.typesetLength, previousLength)
            try assertNativeLayout(production.lineFragments, with: oracle.lineFragments, text: text, complete: false)
            production.typesetLineFragments(toLocation: previousLength + 100)
            oracle.typesetLineFragments(toLocation: previousLength + 100)
            XCTAssertEqual(production.typesetLength, oracle.typesetLength)
            try assertNativeLayout(production.lineFragments, with: oracle.lineFragments, text: text, complete: false)
        }
        production.typesetLineFragments(toLocation: colored.length)
        oracle.typesetLineFragments(toLocation: colored.length)
        try assertNativeLayout(production.lineFragments, with: oracle.lineFragments, text: colored, sparsePixels: true)
        _ = production.refreshAppearance(initial)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(initial, width: 320.25), text: initial, sparsePixels: true)

        let newFont = makeLayoutText(initial.string, font: UIFont(name: "Menlo-Regular", size: 19), color: theme.textColor)
        production.reset()
        production.constrainingWidth = 211.125
        production.lineFragmentHeightMultiplier = 1.25
        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: newFont))
        production.prepareToTypeset(newFont)
        production.typesetLineFragments(toLocation: newFont.length)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(newFont, width: 211.125, heightMultiplier: 1.25),
                               text: newFont, sparsePixels: true)
    }

    func testPreparedLayoutSurvivesSupportedCallerEdits() throws {
        let body = String(repeating: "officeAV09flffi", count: 300)
        let input = makeLayoutText(body)
        let production = LineTypesetter(lineID: "native-compatibility")
        production.constrainingWidth = 320.25
        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: input))
        production.prepareToTypeset(input)
        production.typesetLineFragments(toLocation: 100)
        let measuredPrefix = production.lineFragments
        let changedStyle = NSMutableParagraphStyle()
        changedStyle.baseWritingDirection = .rightToLeft
        input.addAttribute(.paragraphStyle, value: changedStyle.copy(),
                           range: NSRange(location: 0, length: input.length))
        input.replaceCharacters(in: NSRange(location: 0, length: 1), with: " ")
        production.typesetLineFragments(toLocation: body.utf16.count)
        let independent = makeLayoutText(body)
        let expected = nativeLayout(independent, width: 320.25)
        try assertNativeLayout(production.lineFragments, with: expected, text: independent, sparsePixels: true)
        try assertNativeLayout(measuredPrefix, with: Array(expected.prefix(measuredPrefix.count)), text: independent, complete: false)
        production.reset()
        production.prepareToTypeset(input)
        production.typesetLineFragments(toLocation: input.length)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(input, width: 320.25), text: input, sparsePixels: true)
    }
}

extension LineTypesetterNativeCompatibilityTests {
    func testUnsupportedQuotedContentAndAttributesUseNativeLayout() throws {
        let payload = String(repeating: "a", count: 4_200)
        var fixtures = ["  \"" + payload + " ", "  \"" + payload + "\r",
                        payload + "\",\t", payload + "\", more", payload + "\\",
                        "  \"" + payload + "\\", " " + payload + "\"",
                        "let value_09 = " + payload + "; next_word 09",
                        "short words " + payload + " tail words", "_" + payload + "_",
                        String(repeating: "short words ", count: 450),
                        "  \"" + payload + "é\"",
                        "  \"" + payload + "e\u{301}\"",
                        "  \"" + payload + "👩‍💻\"",
                        "  \"" + payload + "\t\"",
                        "  \"" + payload + "\nmore\"",
                        "  \"" + payload + "\u{0000}\"",
                        "  \"" + payload + "\r\"",
                        "  \"" + payload + String(repeating: " words", count: 800) + "\""]
            .map { makeLayoutText($0) }
        let shifted = makeLayoutText("  \"" + payload + "\",")
        shifted.addAttribute(.baselineOffset, value: 2, range: NSRange(location: shifted.length - 4, length: 1))
        fixtures.append(shifted)
        for text in fixtures {
            XCTAssertNil(UnbrokenLineBreakContext.make(for: text))
            let expected = nativeLayout(text, width: 97.25)
            let production = preparedTypesetter(text, width: 97.25)
            production.typesetLineFragments(toLocation: text.length)
            try assertNativeLayout(production.lineFragments, with: expected, text: text, sparsePixels: true)
        }
    }

    func testQuotedParagraphsMatchNativeLayout() throws {
        let payload = String(repeating: "AVoffice09Zflffi123", count: 250)
        let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 10)),
                     try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 22)),
                     UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular), DefaultTheme.shared.font]
        let wrappers = [("  \"", "\","), ("\"", "\""), ("    \"", "\",   "), ("  \"", "\",")]
        for (index, font) in fonts.enumerated() {
            let wrapper = wrappers[index]
            for ending in ["", "\n", "\r\n"] {
                let text = makeLayoutText(wrapper.0 + payload + wrapper.1 + ending, font: font,
                                          tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font))
                let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: text))
                let start = wrapper.0.utf16.count
                XCTAssertEqual(context.runRange, start ..< start + payload.utf16.count)
                let native = CTTypesetterCreateWithAttributedString(text)
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: start + 1, length: 17)), nil, nil, nil))
                let widths: [CGFloat] = [boundary - 1 / 1_024, boundary + 1 / 1_024, 320.25]
                for width in widths {
                    let production = preparedTypesetter(text, width: width, multiplier: 1.125)
                    production.typesetLineFragments(toLocation: text.length)
                    try assertNativeLayout(production.lineFragments, with: nativeLayout(text, width: width, heightMultiplier: 1.125),
                                           text: text, sparsePixels: true)
                }
            }
        }
        let whole = makeLayoutText(payload + "\r\n")
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: whole)).runRange, 0 ..< payload.utf16.count)
    }

    func testQuotedAppearanceRefreshAndResetMatchNativeLayout() throws {
        let body = "  \"" + String(repeating: "officeAV09", count: 500) + "\",   \r\n"
        for style in [UIUserInterfaceStyle.light, .dark] {
            var result: Result<Void, Error> = .success(())
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                result = Result {
                    let initial = makeLayoutText(body, color: .label)
                    XCTAssertNotNil(UnbrokenLineBreakContext.make(for: initial))
                    let production = preparedTypesetter(initial, width: 101.25)
                    production.typesetLineFragments(toLocation: 700)
                    let native = NativeLayoutOracle()
                    native.constrainingWidth = 101.25
                    native.prepareToTypeset(initial)
                    native.typesetLineFragments(toLocation: 700)
                    try assertNativeLayout(production.lineFragments, with: native.lineFragments, text: initial,
                                           sparsePixels: true, complete: false)
                    let recolored = makeLayoutText(body, color: .label)
                    recolored.addAttribute(.foregroundColor, value: UIColor.systemRed, range: NSRange(location: 150, length: 70))
                    XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: recolored)).runRange,
                                   3 ..< 3 + 5_000)
                    let retainedRanges = production.lineFragments.map(\.visibleRange)
                    _ = production.refreshAppearance(recolored)
                    XCTAssertEqual(production.lineFragments.map(\.visibleRange), retainedRanges)
                    production.typesetLineFragments(toLocation: 1_400)
                    native.prepareToTypeset(recolored)
                    native.typesetLineFragments(toLocation: 1_400)
                    let recoloredPrefix = native.refreshAppearance(recolored)
                    try assertNativeLayout(production.lineFragments, with: recoloredPrefix, text: recolored, sparsePixels: true, complete: false)
                    let background = NSMutableAttributedString(attributedString: recolored)
                    background.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 4_500, length: 20))
                    XCTAssertNil(UnbrokenLineBreakContext.make(for: background))
                    let prefix = production.lineFragments.map(\.visibleRange)
                    _ = production.refreshAppearance(background)
                    XCTAssertEqual(production.lineFragments.map(\.visibleRange), prefix)
                    production.typesetLineFragments(toLocation: background.length)
                    try assertNativeLayout(production.lineFragments, with: nativeLayout(background, width: 101.25),
                                           text: background, sparsePixels: true)
                    production.reset()
                    production.constrainingWidth = 149.125
                    production.lineFragmentHeightMultiplier = 1.2
                    let newFont = makeLayoutText(body, font: UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular))
                    XCTAssertNotNil(UnbrokenLineBreakContext.make(for: newFont))
                    production.prepareToTypeset(newFont)
                    production.typesetLineFragments(toLocation: newFont.length)
                    try assertNativeLayout(production.lineFragments, with: nativeLayout(newFont, width: 149.125, heightMultiplier: 1.2),
                                           text: newFont, sparsePixels: true)
                }
            }
            try result.get()
        }
    }

    func testEditsReplaceCachedRunScope() throws {
        let body = "  \"" + String(repeating: "officeAV09", count: 500) + "\",\n"
        let source = makeLayoutText(body)
        let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: source))
        let production = preparedTypesetter(source, width: 101.25)
        production.typesetLineFragments(toLocation: 600)
        source.replaceCharacters(in: NSRange(location: 10, length: 1), with: "é")
        production.typesetLineFragments(toLocation: context.text.length)
        XCTAssertEqual(context.text.string, body)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(context.text, width: 101.25),
                               text: context.text, sparsePixels: true)
        XCTAssertNil(UnbrokenLineBreakContext.make(for: source))
        production.reset()
        production.prepareToTypeset(source)
        production.typesetLineFragments(toLocation: source.length)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(source, width: 101.25), text: source, sparsePixels: true)

        let rescope = makeLayoutText("      " + body)
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: rescope)).runRange, 9 ..< 5_009)
        _ = production.reprepareToTypeset(rescope, previous: source, prefixLimit: 0)
        production.typesetLineFragments(toLocation: rescope.length)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(rescope, width: 101.25), text: rescope, sparsePixels: true)
        let tailEdit = NSMutableAttributedString(attributedString: rescope)
        tailEdit.replaceCharacters(in: NSRange(location: tailEdit.length - 4, length: 1), with: "Z9")
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: tailEdit)).runRange, 9 ..< 5_010)
        _ = production.reprepareToTypeset(tailEdit, previous: rescope, prefixLimit: tailEdit.length - 4)
        production.typesetLineFragments(toLocation: tailEdit.length)
        try assertNativeLayout(production.lineFragments, with: nativeLayout(tailEdit, width: 101.25), text: tailEdit, sparsePixels: true)
    }

    func testSplitDerivedParagraphsMatchNativeLayout() throws {
        let payload = String(repeating: "AVoffice09Zflffi123", count: 250)
        let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 13)),
                     UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular)]
        for font in fonts {
            for wrapper in [("  \"", ""), ("", "\",   ")] {
                for ending in ["", "\n", "\r\n"] {
                    let text = makeLayoutText(wrapper.0 + payload + wrapper.1 + ending, font: font)
                    let run = NSRange(location: wrapper.0.utf16.count, length: payload.utf16.count)
                    let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: text))
                    XCTAssertEqual(context.runRange, run.location ..< run.upperBound)
                    XCTAssertFalse(context.run.allowsInitialOffset)
                    let native = CTTypesetterCreateWithAttributedString(text)
                    let boundary = CGFloat(CTLineGetTypographicBounds(
                        CTTypesetterCreateLine(native, CFRange(location: run.location + 1, length: 17)), nil, nil, nil))
                    let widths: [CGFloat] = [boundary - 1 / 1_024, boundary + 1 / 1_024, 320.25]
                    for width in widths {
                        let expected = nativeLayout(text, width: width)
                        let production = preparedTypesetter(text, width: width)
                        production.typesetLineFragments(toLocation: text.length)
                        try assertNativeLayout(production.lineFragments, with: expected, text: text, sparsePixels: true)
                    }
                }
            }
        }
        let whole = makeLayoutText(payload + "\r\n")
        XCTAssertTrue(try XCTUnwrap(UnbrokenLineBreakContext.make(for: whole)).run.allowsInitialOffset)
    }
}

extension LineTypesetterNativeCompatibilityTests {
    private func withTraits(_ style: UIUserInterfaceStyle, body: () throws -> Void) throws {
        var outcome: Result<Void, Error>?
        UITraitCollection(userInterfaceStyle: style).performAsCurrent {
            outcome = Result { try body() }
        }
        try XCTUnwrap(outcome).get()
    }
}
