// Keep this research oracle and its differential fixtures self-contained for review.
// swiftlint:disable file_length

import CoreText
import Foundation
import QuartzCore
@testable import Runestone
import UIKit
import XCTest

/// Test-only hypothesis. A cluster break may differ from a word break at a
/// fractional width or interior offset, moving every following caret and pixel.
@MainActor
// Keep related experiment selectors together without changing XCTest discovery.
// swiftlint:disable:next type_body_length
final class UnbrokenLineBreakExperimentTests: XCTestCase {
    func testAdmittedParagraphsMatchProductionRangesGlyphsCaretsAndPixels() throws {
        for size in [CGFloat(13), CGFloat(19.5)] {
            let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: size)),
                         UIFont.monospacedSystemFont(ofSize: size, weight: .regular)]
            for font in fonts {
                for explicitLigature in [false, true] {
                    for body in [String(repeating: "a", count: 127),
                                 String(repeating: "officeAV09Zflffi123", count: 8)] {
                        for ending in ["", "\n", "\r\n"] {
                            let text = unbrokenText(body + ending, font: font, explicitLigature: explicitLigature)
                            let native = CTTypesetterCreateWithAttributedString(text)
                            let boundary = CGFloat(CTLineGetTypographicBounds(
                                CTTypesetterCreateLine(native, CFRange(location: 0, length: 7)), nil, nil, nil))
                            for width in [boundary - 1 / 1_024, boundary, boundary + 1 / 1_024, 320.25] {
                                let result = UnbrokenSnapshot(text).layout(width: width, heightMultiplier: 1.125)
                                XCTAssertTrue(result.usedClusterBreak, "\(font.fontName), width=\(width), ending=\(ending.debugDescription)")
                                XCTAssertNil(result.fallback)
                                try compare(result.fragments, with: unbrokenFresh(text, width: width, heightMultiplier: 1.125), text: text)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Arbitrary offsets expose rounding that sequential wrapping might miss.
    /// Compare post-truncation fragments; the whole-layout oracle above is the
    /// production LineTypesetter, independent of this experimental fragment helper.
    func testInteriorOffsetsAndFractionalWidthsMatchNativeTruncation() throws {
        let text = unbrokenText(String(repeating: "AVoffice09flZ123", count: 20))
        let native = CTTypesetterCreateWithAttributedString(text)
        var rawSuggestionDifferences = 0
        for offset in [0, 1, 2, 7, 17, 63, 127, 251] {
            for count in [3, 7, 19] {
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: offset, length: count)), nil, nil, nil))
                let deltas: [CGFloat] = [-0.25, -1 / 1_024, 0, 1 / 1_024, 0.25]
                for delta in deltas {
                    let width = boundary + delta
                    let word = independentNativeWordBreak(text, native: native, offset: offset, width: width)
                    let cluster = CTTypesetterSuggestClusterBreak(native, offset, Double(width))
                    rawSuggestionDifferences += word == cluster ? 0 : 1
                    let expected = try XCTUnwrap(unbrokenFragment(text, native: native, offset: offset,
                                                                  length: word, index: 0, y: 0, width: width, multiplier: 1))
                    let actual = try XCTUnwrap(unbrokenFragment(text, native: native, offset: offset,
                                                                length: cluster, index: 0, y: 0, width: width, multiplier: 1))
                    XCTAssertEqual(actual.visibleRange, expected.visibleRange,
                                   "offset=\(offset) width=\(width) word=\(word) cluster=\(cluster)")
                    try compareFragment(actual, expected, text: text, includePixels: true)
                }
            }
        }
        print("UNBROKEN_BREAK_OFFSETS cases=120 raw_suggestion_differences=\(rawSuggestionDifferences)")
    }

    /// A simple prefix must not admit later punctuation, whitespace, contextual
    /// shaping, font changes or attribute overrides that change the native break.
    func testUnsupportedParagraphsFallBackToProduction() throws {
        let body = String(repeating: "a", count: 100)
        let strings = ["", "\n", body + " ", body + "\tZ", body + "_Z", body + "-Z",
                       "{\"payload\":\"" + body + "\"}", body + "é", body + "e\u{301}",
                       body + "👩‍💻", body + "אבג", body + "مرحبا", body + "\u{200B}Z",
                       body + "\u{00A0}Z", body + "\r", body + "\nZ", body + "\r\nZ"]
        var fixtures = strings.map { unbrokenText($0) }
        for (key, value) in [(NSAttributedString.Key.kern, 0.25 as Any),
                             (.ligature, 1 as Any), (.baselineOffset, 2 as Any),
                             (.obliqueness, 0.1 as Any), (.writingDirection, [NSNumber(value: 1)] as Any),
                             (.backgroundColor, UIColor.yellow as Any),
                             (.font, UIFont.systemFont(ofSize: 17) as Any),
                             (.font, UIFont.monospacedSystemFont(ofSize: 17, weight: .bold) as Any)] {
            let text = unbrokenText(body)
            text.addAttribute(key, value: value, range: NSRange(location: 40, length: 3))
            fixtures.append(text)
        }
        let paragraph = unbrokenText(body)
        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = .rightToLeft
        paragraph.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: paragraph.length))
        fixtures.append(paragraph)
        let mixedFixedFonts = unbrokenText(body)
        mixedFixedFonts.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular),
                                     range: NSRange(location: 40, length: 3))
        fixtures.append(mixedFixedFonts)
        let paragraphChanges: [(NSMutableParagraphStyle) -> Void] = [
            { $0.firstLineHeadIndent = 3 }, { $0.hyphenationFactor = 1 },
            { $0.defaultTabInterval += 1 }, { $0.lineHeightMultiple = 1.1 },
            { $0.tabStops = [NSTextTab(textAlignment: .right, location: 40)] }
        ]
        for change in paragraphChanges {
            let text = unbrokenText(body)
            let current = try XCTUnwrap(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            let changed = try XCTUnwrap(current.mutableCopy() as? NSMutableParagraphStyle)
            change(changed)
            text.addAttribute(.paragraphStyle, value: changed.copy(),
                              range: NSRange(location: 0, length: text.length))
            fixtures.append(text)
        }
        for text in fixtures {
            let result = UnbrokenSnapshot(text).layout(width: 79.125)
            XCTAssertFalse(result.usedClusterBreak)
            XCTAssertNotNil(result.fallback, text.string.debugDescription)
            try compare(result.fragments, with: unbrokenFresh(text, width: 79.125), text: text)
        }
    }

    /// Supported text/attribute replacement must leave old snapshots and CTLines
    /// unchanged. Apple forbids mutating an attribute value after assignment:
    /// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AttributedStrings/Tasks/ChangingAttrStrings.html
    func testSnapshotOwnsTextAndParagraphAttributes() throws {
        let body = String(repeating: "office09", count: 24)
        let original = unbrokenText(body)
        let snapshot = UnbrokenSnapshot(original)
        let cached = snapshot.layout(width: 101.25)
        XCTAssertTrue(cached.usedClusterBreak)

        // Configure a new value completely before installing its immutable copy.
        let storedStyle = try XCTUnwrap(original.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let style = try XCTUnwrap(storedStyle.mutableCopy() as? NSMutableParagraphStyle)
        style.baseWritingDirection = .rightToLeft
        let replacementStyle = style.copy()
        original.addAttribute(.paragraphStyle, value: replacementStyle,
                              range: NSRange(location: 0, length: original.length))
        let restyled = UnbrokenSnapshot(original).layout(width: 101.25)
        XCTAssertFalse(restyled.usedClusterBreak)
        XCTAssertEqual(restyled.fallback, "unsupported whole paragraph")
        let independentStyled = unbrokenText(body)
        independentStyled.addAttribute(.paragraphStyle, value: replacementStyle,
                                       range: NSRange(location: 0, length: independentStyled.length))
        try compare(restyled.fragments, with: unbrokenFresh(independentStyled, width: 101.25), text: independentStyled)

        original.replaceCharacters(in: NSRange(location: 0, length: 1), with: " ")
        let result = snapshot.layout(width: 101.25)
        XCTAssertTrue(result.usedClusterBreak)
        let independent = unbrokenText(body)
        let expectedOld = unbrokenFresh(independent, width: 101.25)
        try compare(cached.fragments, with: expectedOld, text: independent)
        try compare(result.fragments, with: expectedOld, text: independent)
        // The already-created restyled runs must also survive later text edits.
        try compare(restyled.fragments, with: unbrokenFresh(independentStyled, width: 101.25), text: independentStyled)
        independentStyled.replaceCharacters(in: NSRange(location: 0, length: 1), with: " ")
        let changed = UnbrokenSnapshot(original).layout(width: 101.25)
        XCTAssertFalse(changed.usedClusterBreak)
        XCTAssertEqual(changed.fallback, "unsupported whole paragraph")
        try compare(changed.fragments, with: unbrokenFresh(independentStyled, width: 101.25), text: independentStyled)
    }

    /// The same unresolved dynamic color must survive snapshots created before
    /// either trait scope; matching only one resolved color would miss dark mode.
    func testDefaultThemeDynamicColorAndGeneratedTabsMatchInBothAppearances() throws {
        let theme = DefaultTheme.shared
        let color = theme.textColor
        let body = String(repeating: "officeAV09flffi", count: 12)
        for tabLength in [2, 4, 8] {
            let interval = TabWidthMeasurer.tabWidth(tabLength: tabLength, font: theme.font)
            for ending in ["", "\n", "\r\n"] {
                let text = unbrokenText(body + ending, font: theme.font, color: color, tabWidth: interval)
                let snapshot = UnbrokenSnapshot(text)
                var nativePixels: [Data] = []
                for style in [UIUserInterfaceStyle.light, .dark] {
                    try withTraits(style) {
                        for width in [CGFloat(79.125), 320.25] {
                            let result = snapshot.layout(width: width)
                            XCTAssertTrue(result.usedClusterBreak)
                            XCTAssertNil(result.fallback)
                            let expected = unbrokenFresh(text, width: width)
                            try compare(result.fragments, with: expected, text: text)
                            if width == 79.125 {
                                nativePixels.append(try pixels(XCTUnwrap(expected.first), text: text))
                            }
                        }
                    }
                }
                XCTAssertNotEqual(nativePixels[0], nativePixels[1], "The native control must exercise the dynamic color.")
            }
        }
    }

    // swiftlint:disable function_body_length
    /// Recoloring within ligature candidates and across a wrap creates new runs;
    /// appearance refresh must rebuild those runs without resetting continuation.
    /// This ordered lifecycle keeps every transition and its assertions together.
    func testPartialContinuationRechecksAppearanceAdmission() throws {
        let theme = DefaultTheme.shared
        let text = unbrokenText(String(repeating: "officeAV09flffi", count: 24) + "\r\n",
                                font: theme.font, color: theme.textColor,
                                tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: theme.font))
        for style in [UIUserInterfaceStyle.light, .dark] {
            try withTraits(style) {
                let session = UnbrokenContinuation(text, width: 79.125)
                let oracle = IndependentNativeLineOracle()
                oracle.constrainingWidth = 79.125
                oracle.prepareToTypeset(text)
                for target in [1, 25] {
                    let partial = session.typeset(toLocation: target)
                    oracle.typesetLineFragments(toLocation: target)
                    XCTAssertTrue(partial.usedClusterBreak)
                    try compare(partial.fragments, with: oracle.lineFragments, text: text, complete: false)
                }
                let colored = NSMutableAttributedString(attributedString: text)
                colored.addAttribute(.foregroundColor, value: UIColor.systemRed.withAlphaComponent(0.65),
                                     range: NSRange(location: 2, length: 2))
                let boundary = try XCTUnwrap(session.fragments.last).visibleRange.upperBound
                colored.addAttribute(.foregroundColor, value: UIColor.label,
                                     range: NSRange(location: boundary - 1, length: 4))
                colored.addAttribute(.foregroundColor, value: UIColor.systemBlue,
                                     range: NSRange(location: colored.length - 2, length: 2))
                XCTAssertTrue(session.refreshAppearance(colored))
                _ = oracle.refreshAppearance(colored)
                try compare(session.fragments, with: oracle.lineFragments, text: colored, complete: false)
                let recolored = session.typeset(toLocation: boundary + 20)
                oracle.typesetLineFragments(toLocation: boundary + 20)
                XCTAssertTrue(recolored.usedClusterBreak)
                try compare(recolored.fragments, with: oracle.lineFragments, text: colored, complete: false)

                let background = NSMutableAttributedString(attributedString: colored)
                background.addAttribute(.backgroundColor, value: UIColor.yellow,
                                        range: NSRange(location: 1, length: background.length - 1))
                XCTAssertTrue(session.refreshAppearance(background))
                _ = oracle.refreshAppearance(background)
                try compare(session.fragments, with: oracle.lineFragments, text: background, complete: false)
                let target = try XCTUnwrap(session.fragments.last).range.upperBound + 20
                let rejected = session.typeset(toLocation: target)
                oracle.typesetLineFragments(toLocation: target)
                XCTAssertFalse(rejected.usedClusterBreak)
                XCTAssertEqual(rejected.fallback, "unsupported whole paragraph")
                try compare(rejected.fragments, with: oracle.lineFragments, text: background, complete: false)

                // Returning to supported colors must recompute admission, rather
                // than permanently inheriting the previous rejection.
                XCTAssertTrue(session.refreshAppearance(colored))
                _ = oracle.refreshAppearance(colored)
                let finished = session.typeset(toLocation: colored.length)
                oracle.typesetLineFragments(toLocation: colored.length)
                XCTAssertTrue(finished.usedClusterBreak)
                try compare(finished.fragments, with: oracle.lineFragments, text: colored)
                try compare(finished.fragments, with: unbrokenFresh(colored, width: 79.125), text: colored)

                XCTAssertTrue(session.refreshAppearance(text))
                _ = oracle.refreshAppearance(text)
                try compare(session.fragments, with: oracle.lineFragments, text: text)
                try compare(session.fragments, with: unbrokenFresh(text, width: 79.125), text: text)
            }
        }
    }

    // swiftlint:enable function_body_length

    /// Even another supported fixed font must discard old measured geometry.
    func testFontAndGeometryChangesResetPartialLayoutToNative() throws {
        let text = unbrokenText(String(repeating: "officeAV09flffi", count: 16))
        for change in 0 ..< 4 {
            let session = UnbrokenContinuation(text, width: 79.125)
            XCTAssertTrue(session.typeset(toLocation: 1).usedClusterBreak)
            let changed = NSMutableAttributedString(attributedString: text)
            var width: CGFloat = 79.125
            var multiplier: CGFloat = 1
            switch change {
            case 0:
                width = 111.25
            case 1:
                changed.addAttribute(.font, value: UIFont(name: "Menlo-Regular", size: 19)!,
                                     range: NSRange(location: 0, length: changed.length))
            case 2:
                changed.addAttribute(.kern, value: 0.25,
                                     range: NSRange(location: 0, length: changed.length))
            default:
                multiplier = 1.25
            }
            XCTAssertFalse(session.refreshAppearance(changed, width: width, heightMultiplier: multiplier))
            XCTAssertTrue(session.fragments.isEmpty)
            let result = session.typeset(toLocation: changed.length)
            XCTAssertFalse(result.usedClusterBreak)
            XCTAssertEqual(result.fallback, "layout attributes or geometry changed")
            try compare(result.fragments, with: unbrokenFresh(changed, width: width, heightMultiplier: multiplier), text: changed)
        }
    }

    /// Production paragraphs above the provisional 4096-unit threshold must
    /// preserve the independent native result with real default attributes.
    func testProductionLongParagraphsMatchIndependentNativeOracle() throws {
        let theme = DefaultTheme.shared
        let dynamicColor = theme.textColor
        let body = String(repeating: "officeAV09flffi", count: 300)
        for style in [UIUserInterfaceStyle.light, .dark] {
            try withTraits(style) {
                for tabLength in [2, 8] {
                    for ending in ["", "\n", "\r\n"] {
                        let text = unbrokenText(body + ending, font: theme.font, color: dynamicColor,
                                                tabWidth: TabWidthMeasurer.tabWidth(tabLength: tabLength, font: theme.font))
                        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: text))
                        let native = CTTypesetterCreateWithAttributedString(text)
                        let boundary = CGFloat(CTLineGetTypographicBounds(
                            CTTypesetterCreateLine(native, CFRange(location: 0, length: 37)), nil, nil, nil))
                        for width in [boundary - 1 / 1_024, boundary + 1 / 1_024] {
                            try compare(unbrokenProduction(text, width: width), with: unbrokenFresh(text, width: width),
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
                let text = unbrokenText(body + "\r\n", font: font, color: dynamicColor,
                                        tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font))
                XCTAssertNotNil(UnbrokenLineBreakContext.make(for: text))
                let native = CTTypesetterCreateWithAttributedString(text)
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: 0, length: 23)), nil, nil, nil))
                for width in [boundary - 1 / 1_024, boundary + 1 / 1_024] {
                    try compare(unbrokenProduction(text, width: width), with: unbrokenFresh(text, width: width),
                                text: text, sparsePixels: true)
                }
            }
        }
    }

    /// Late unsupported characters and attribute changes must not be missed by a
    /// prefix-only gate; wrapper punctuation must retain native word breaking.
    func testProductionLongUnsupportedParagraphsMatchIndependentNativeOracle() throws {
        let body = String(repeating: "a", count: 4_200)
        var fixtures = [unbrokenText("{\"payload\":\"" + body + "\"}"), unbrokenText(body + "é"),
                        unbrokenText(body + " tail"), unbrokenText(body + "אבג"), unbrokenText(body + "👩‍💻")]
        let mixedFont = unbrokenText(body)
        mixedFont.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 4_100, length: 3))
        fixtures.append(mixedFont)
        let styled = unbrokenText(body)
        styled.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 4_100, length: 3))
        fixtures.append(styled)
        for (key, value) in [(NSAttributedString.Key.ligature, NSNumber(value: 1)), (.kern, NSNumber(value: 0.375))] {
            let text = unbrokenText(String(repeating: "officeAV09flffi", count: 280))
            text.addAttribute(key, value: value, range: NSRange(location: 4_100, length: 30))
            fixtures.append(text)
        }
        let paragraphChanges: [(NSMutableParagraphStyle) -> Void] = [
            { $0.baseWritingDirection = .rightToLeft }, { $0.firstLineHeadIndent = 3.5 }
        ]
        for change in paragraphChanges {
            let text = unbrokenText(body)
            let original = try XCTUnwrap(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            let paragraph = try XCTUnwrap(original.mutableCopy() as? NSMutableParagraphStyle)
            change(paragraph)
            text.addAttribute(.paragraphStyle, value: paragraph.copy(), range: NSRange(location: 0, length: text.length))
            fixtures.append(text)
        }
        for text in fixtures {
            XCTAssertNil(UnbrokenLineBreakContext.make(for: text))
            try compare(unbrokenProduction(text, width: 320.25), with: unbrokenFresh(text, width: 320.25),
                        text: text, sparsePixels: true)
        }
    }

    /// The real typesetter must replace its prepared eligibility during appearance
    /// refresh, retain only measured geometry, and discard it on a normal reset.
    func testProductionPartialAppearanceRefreshAndResetMatchNativeOracle() throws {
        let theme = DefaultTheme.shared
        let initial = unbrokenText(String(repeating: "officeAV09flffi", count: 300) + "\r\n",
                                   font: theme.font, color: theme.textColor,
                                   tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: theme.font))
        let production = LineTypesetter(lineID: "unbroken-experiment")
        production.constrainingWidth = 320.25
        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: initial))
        production.prepareToTypeset(initial)
        let oracle = IndependentNativeLineOracle()
        oracle.constrainingWidth = 320.25
        oracle.prepareToTypeset(initial)
        production.typesetLineFragments(toLocation: 100)
        oracle.typesetLineFragments(toLocation: 100)
        try compare(production.lineFragments, with: oracle.lineFragments, text: initial, complete: false)

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
            try compare(production.lineFragments, with: oracle.lineFragments, text: text, complete: false)
            production.typesetLineFragments(toLocation: previousLength + 100)
            oracle.typesetLineFragments(toLocation: previousLength + 100)
            XCTAssertEqual(production.typesetLength, oracle.typesetLength)
            try compare(production.lineFragments, with: oracle.lineFragments, text: text, complete: false)
        }
        production.typesetLineFragments(toLocation: colored.length)
        oracle.typesetLineFragments(toLocation: colored.length)
        try compare(production.lineFragments, with: oracle.lineFragments, text: colored, sparsePixels: true)
        _ = production.refreshAppearance(initial)
        try compare(production.lineFragments, with: unbrokenFresh(initial, width: 320.25), text: initial, sparsePixels: true)

        let newFont = unbrokenText(initial.string, font: UIFont(name: "Menlo-Regular", size: 19), color: theme.textColor)
        production.reset()
        production.constrainingWidth = 211.125
        production.lineFragmentHeightMultiplier = 1.25
        XCTAssertNotNil(UnbrokenLineBreakContext.make(for: newFont))
        production.prepareToTypeset(newFont)
        production.typesetLineFragments(toLocation: newFont.length)
        try compare(production.lineFragments, with: unbrokenFresh(newFont, width: 211.125, heightMultiplier: 1.25),
                    text: newFont, sparsePixels: true)
    }

    /// Preparation of an admitted paragraph must snapshot supported mutations;
    /// the caller's later addAttribute/replaceCharacters must not change its CTLines.
    func testProductionPreparedSnapshotSurvivesSupportedCallerEdits() throws {
        let body = String(repeating: "officeAV09flffi", count: 300)
        let input = unbrokenText(body)
        let production = LineTypesetter(lineID: "unbroken-experiment")
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
        let independent = unbrokenText(body)
        let expected = unbrokenFresh(independent, width: 320.25)
        try compare(production.lineFragments, with: expected, text: independent, sparsePixels: true)
        try compare(measuredPrefix, with: Array(expected.prefix(measuredPrefix.count)), text: independent, complete: false)
        production.reset()
        production.prepareToTypeset(input)
        production.typesetLineFragments(toLocation: input.length)
        try compare(production.lineFragments, with: unbrokenFresh(input, width: 320.25), text: input, sparsePixels: true)
    }

    /// Match LineController's extraction path, including mutable editor history.
    /// ASCII states must actually admit; silent fallback would invalidate this trial.
    func testEditorStringViewConstructionRetainsDirectASCIIAdmission() throws {
        let view = StringView(string: String(repeating: "a", count: 9_000))
        try checkEditorLine(view, range: NSRange(location: 0, length: 9_000), stage: "initial")
        view.replaceText(in: NSRange(location: 100, length: 1), with: "Z")
        try checkEditorLine(view, range: NSRange(location: 0, length: 9_000), stage: "character-edit")
        view.replaceText(in: NSRange(location: 4_500, length: 0), with: "\n")
        try checkEditorLine(view, range: NSRange(location: 0, length: 4_501), stage: "newline-first")
        try checkEditorLine(view, range: NSRange(location: 4_501, length: 4_500), stage: "newline-second")
        view.replaceText(in: NSRange(location: 4_500, length: 1), with: "")
        try checkEditorLine(view, range: NSRange(location: 0, length: 9_000), stage: "join")
        view.replaceText(in: NSRange(location: 9_000, length: 0), with: "é")
        let unicode = try editorAttributedLine(view, range: NSRange(location: 0, length: 9_001))
        try checkStorageParity(unicode, stage: "unicode-inserted", expectedAdmission: false, requiresMissingASCII: true)
        view.replaceText(in: NSRange(location: 9_000, length: 1), with: "")
        try checkEditorLine(view, range: NSRange(location: 0, length: 9_000), stage: "unicode-removed")
    }

    /// Absence of direct ASCII storage is independently observed, not inferred
    /// from an encoding enum. Embedded NUL also must not truncate byte validation.
    func testUnsupportedASCIIPointerContextFallsBackToNative() throws {
        let body = String(repeating: "a", count: 4_500)
        let unicode = unbrokenText(body + "é")
        try checkStorageParity(unicode, stage: "late-unicode-direct", expectedAdmission: false, requiresMissingASCII: true)
        let embeddedNUL = unbrokenText(body + "\0Z")
        try checkStorageParity(embeddedNUL, stage: "embedded-nul", expectedAdmission: false)
    }

    private func checkEditorLine(_ view: StringView, range: NSRange, stage: String) throws {
        let text = try editorAttributedLine(view, range: range)
        try checkStorageParity(text, stage: stage, expectedAdmission: true)
    }

    private func editorAttributedLine(_ view: StringView, range: NSRange) throws -> NSMutableAttributedString {
        let substring = try XCTUnwrap(view.substring(in: range))
        let text = NSMutableAttributedString(string: substring)
        let theme = DefaultTheme.shared
        DefaultStringAttributes(textColor: theme.textColor, font: theme.font, kern: 0,
                                tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: theme.font)).apply(to: text)
        return text
    }

    private func checkStorageParity(_ text: NSAttributedString, stage: String, expectedAdmission: Bool,
                                    requiresMissingASCII: Bool = false) throws {
        var record = pairedViewportStorage(text)
        let hasDirectASCII = CFStringGetCStringPtr(CFAttributedStringGetString(text), CFStringBuiltInEncodings.ASCII.rawValue) != nil
        let context = UnbrokenLineBreakContext.make(for: text)
        record["stage"] = stage
        record["inputClass"] = NSStringFromClass(type(of: text))
        record["inputIsMutable"] = text is NSMutableAttributedString
        record["utf16"] = text.length
        record["expectedAdmission"] = expectedAdmission
        record["contextAdmitted"] = context != nil
        record["bodyLength"] = context?.bodyLength ?? 0
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw UnbrokenMismatch.invalidJSONEncoding
        }
        print("UNBROKEN_EDITOR_STORAGE \(json)")
        XCTAssertEqual(context != nil, expectedAdmission, stage)
        if expectedAdmission { XCTAssertTrue(hasDirectASCII, stage) }
        if requiresMissingASCII { XCTAssertFalse(hasDirectASCII, stage) }
        if !hasDirectASCII { XCTAssertNil(context, stage) }
        try compare(unbrokenProduction(text, width: 320.25), with: unbrokenFresh(text, width: 320.25),
                    text: text, sparsePixels: true)
    }

    private func withTraits(_ style: UIUserInterfaceStyle, body: () throws -> Void) throws {
        var outcome: Result<Void, Error>?
        UITraitCollection(userInterfaceStyle: style).performAsCurrent {
            outcome = Result { try body() }
        }
        try XCTUnwrap(outcome).get()
    }

    /// A failed suggestion after partial progress must discard the partial result
    /// and return a complete native layout, rather than loop or omit the suffix.
    func testFailedClusterSuggestionFallsBackWithoutLosingText() throws {
        let text = unbrokenText(String(repeating: "office09", count: 24))
        let result = UnbrokenSnapshot(text).layout(width: 101.25) { native, offset, width in
            offset == 0 ? CTTypesetterSuggestClusterBreak(native, offset, width) : 0
        }
        XCTAssertFalse(result.usedClusterBreak)
        XCTAssertEqual(result.fallback, "cluster suggestion made no progress")
        try compare(result.fragments, with: unbrokenFresh(text, width: 101.25), text: text)
    }

    /// Paired order exposes cache/order effects that separate simulator runs hide.
    /// Both sides receive the same unmodified 1 MiB input and exact 700-point cutoff.
    func testPairedOneMiBFirstViewportPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 for paired first-viewport measurements.")
        for fixture in ["unsupported-font", "late-unicode", "json-wrapper", "words"] {
            let text = pairedViewportInput(fixture: fixture)
            for width in [CGFloat(320), 10_000] {
                for pair in 0 ..< 7 {
                    try autoreleasepool {
                        let storageBefore = pairedViewportStorage(text)
                        let productionFirst = pair.isMultiple(of: 2)
                        let first = timedViewport(text, width: width, production: productionFirst)
                        let storageAfterFirst = pairedViewportStorage(text)
                        let second = timedViewport(text, width: width, production: !productionFirst)
                        let production = productionFirst ? first : second
                        let native = productionFirst ? second : first
                        let record: [String: Any] = [
                            "fixture": fixture, "utf16": text.length, "width": Double(width), "viewportHeight": 700,
                            "pair": pair, "warmup": pair == 0,
                            "order": productionFirst ? ["production", "native"] : ["native", "production"],
                            "sameUnmodifiedInput": true, "inputIsMutable": text is NSMutableAttributedString,
                            "inputClass": NSStringFromClass(type(of: text)),
                            "inputStorageBeforePair": storageBefore, "inputStorageAfterFirst": storageAfterFirst,
                            "inputStorageAfterPair": pairedViewportStorage(text),
                            "production": production.record, "native": native.record
                        ]
                        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                        // Preserve raw paired evidence even when the first parity
                        // assertion fails. No speed assertion masks host contention.
                        guard let json = String(data: data, encoding: .utf8) else {
                            throw UnbrokenMismatch.invalidJSONEncoding
                        }
                        print("UNBROKEN_VIEWPORT_PAIR \(json)")
                        try withExtendedLifetime((first.engineOwner, second.engineOwner)) {
                            XCTAssertFalse(native.oracleInvalidSuggestion)
                            XCTAssertGreaterThan(production.consumedUTF16, 0)
                            XCTAssertLessThanOrEqual(production.consumedUTF16, text.length)
                            XCTAssertEqual(production.consumedUTF16, native.consumedUTF16)
                            XCTAssertGreaterThanOrEqual(production.lastBottomY, 700)
                            XCTAssertLessThan(production.lastY, 700)
                            XCTAssertEqual(production.lastBottomY, native.lastBottomY)
                            try compare(production.fragments, with: native.fragments, text: text, complete: false)
                        }
                    }
                }
            }
        }
    }

    /// Mirrors LongLinePreparationPerformanceTests fixture construction exactly;
    /// retain its original mutable storage but never mutate it during this test.
    private func pairedViewportInput(fixture: String) -> NSAttributedString {
        let length = 1_048_576
        let body = String(repeating: "a", count: length)
        let contents: String
        switch fixture {
        case "late-unicode":
            contents = body + "é"
        case "words":
            contents = String(String(repeating: "alpha beta ", count: length / 11 + 1).prefix(length))
        case "json-wrapper":
            contents = "{\"value\":\"" + body + "\"}"
        default:
            contents = body
        }
        let theme = DefaultTheme.shared
        let font = fixture == "unsupported-font" ? UIFont.systemFont(ofSize: 14) : theme.font
        let text = unbrokenText(contents, font: font, color: theme.textColor,
                                tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font))
        return text
    }

    private func pairedViewportStorage(_ text: NSAttributedString) -> [String: Any] {
        let string = CFAttributedStringGetString(text)
        // These accessors inspect existing storage; do not bridge via text.string,
        // copy UTF-16 units, or request an encoded buffer just for diagnostics.
        return [
            "fastestCFStringEncoding": CFStringGetFastestEncoding(string),
            "hasDirectUTF16Pointer": CFStringGetCharactersPtr(string) != nil,
            "hasDirectASCIIPointer": CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) != nil
        ]
    }

    private func timedViewport(_ text: NSAttributedString, width: CGFloat, production: Bool) -> PairedViewportSample {
        let viewport = CGRect(x: 0, y: 0, width: width, height: 700)
        if production {
            let typesetter = LineTypesetter(lineID: "unbroken-experiment")
            typesetter.constrainingWidth = width
            let start = CACurrentMediaTime()
            typesetter.prepareToTypeset(text)
            let prepared = CACurrentMediaTime()
            typesetter.typesetLineFragments(in: viewport)
            let finished = CACurrentMediaTime()
            return PairedViewportSample(prepareMs: (prepared - start) * 1_000, layoutMs: (finished - prepared) * 1_000,
                                        totalMs: (finished - start) * 1_000, consumedUTF16: typesetter.typesetLength,
                                        fragments: typesetter.lineFragments, oracleInvalidSuggestion: false, engineOwner: typesetter)
        } else {
            let typesetter = IndependentNativeLineOracle()
            typesetter.constrainingWidth = width
            let start = CACurrentMediaTime()
            typesetter.prepareToTypeset(text)
            let prepared = CACurrentMediaTime()
            typesetter.typesetLineFragments(in: viewport)
            let finished = CACurrentMediaTime()
            return PairedViewportSample(prepareMs: (prepared - start) * 1_000, layoutMs: (finished - prepared) * 1_000,
                                        totalMs: (finished - start) * 1_000, consumedUTF16: typesetter.typesetLength,
                                        fragments: typesetter.lineFragments, oracleInvalidSuggestion: typesetter.invalidSuggestion,
                                        engineOwner: typesetter)
        }
    }

    /// Includes eligibility, immutable snapshot, full paragraph shaping and layout.
    /// Exact glyph/geometry/caret checks are outside timing; pixels sample edges.
    func testSixtyThousandUnitPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 to run the 60k-unit experiment.")
        let body = String(repeating: "a", count: 60_000)
        let theme = DefaultTheme.shared
        let defaultText = unbrokenText(body, font: theme.font, color: theme.textColor,
                                       tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: theme.font))
        let fixtures = [("unbroken", unbrokenText(body), true),
                        ("unbrokenDefaultTheme", defaultText, true),
                        ("jsonWrapperFallback", unbrokenText("{\"payload\":\"" + body + "\"}"), false)]
        for (name, text, accepted) in fixtures {
            for width in [CGFloat(320), CGFloat(10_000)] {
                var baseline: [Double] = []
                var candidate: [Double] = []
                var fragments = 0
                for trial in 0 ..< 4 {
                    try autoreleasepool {
                        var expected: [LineFragment] = []
                        var result: [LineFragment]?
                        for isCandidate in (trial.isMultiple(of: 2) ? [false, true] : [true, false]) {
                            let start = ProcessInfo.processInfo.systemUptime
                            if isCandidate {
                                result = unbrokenProduction(text, width: width)
                            } else {
                                expected = unbrokenFresh(text, width: width)
                            }
                            let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                            if trial > 0 {
                                if isCandidate { candidate.append(elapsed) } else { baseline.append(elapsed) }
                            }
                        }
                        let actual = try XCTUnwrap(result)
                        // Eligibility diagnostics are outside timing and do not
                        // add a production-only switch or influence its result.
                        XCTAssertEqual(UnbrokenLineBreakContext.make(for: text) != nil, accepted)
                        try compare(actual, with: expected, text: text, sparsePixels: true)
                        fragments = actual.count
                    }
                }
                print("UNBROKEN_PRODUCTION_PERF fixture=\(name) utf16=\(text.length) width=\(width) fragments=\(fragments) "
                      + "native_median_ms=\(baseline.sorted()[1]) production_median_ms=\(candidate.sorted()[1]) "
                      + "native_ms=\(baseline) production_ms=\(candidate)")
            }
        }
    }
}

private struct PairedViewportSample {
    let prepareMs: Double
    let layoutMs: Double
    let totalMs: Double
    let consumedUTF16: Int
    let fragments: [LineFragment]
    let oracleInvalidSuggestion: Bool
    let engineOwner: AnyObject
    var lastY: CGFloat { fragments.last?.yPosition ?? 0 }
    var lastBottomY: CGFloat { fragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0 }
    var record: [String: Any] {
        ["prepareMs": prepareMs, "layoutMs": layoutMs, "totalMs": totalMs,
         "fragmentCount": fragments.count, "consumedUTF16": consumedUTF16,
         "lastY": Double(lastY), "lastBottomY": Double(lastBottomY), "oracleInvalidSuggestion": oracleInvalidSuggestion]
    }
}

private struct UnbrokenResult {
    var fragments: [LineFragment]
    var usedClusterBreak: Bool
    var fallback: String?
}

/// Whole-paragraph admission only: no tokenizer cache or substring shaping.
private final class UnbrokenSnapshot {
    let text: NSAttributedString
    let bodyLength: Int?

    init(_ input: NSAttributedString) {
        // Populate fresh storage with copied paragraph values. Isolation covers
        // attributed-string API edits, not unsupported mutation of assigned values.
        let copy = NSMutableAttributedString(string: input.string)
        input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, range, _ in
            var ownedAttributes = attributes
            if let style = attributes[.paragraphStyle] as? NSParagraphStyle {
                ownedAttributes[.paragraphStyle] = style.copy()
            }
            copy.setAttributes(ownedAttributes, range: range)
        }
        text = NSAttributedString(attributedString: copy)
        bodyLength = Self.admittedBodyLength(text)
    }

    func layout(width: CGFloat, heightMultiplier: CGFloat = 1,
                clusterSuggestion: ((CTTypesetter, Int, Double) -> Int)? = nil) -> UnbrokenResult {
        func fallback(_ reason: String) -> UnbrokenResult {
            UnbrokenResult(fragments: unbrokenFresh(text, width: width, heightMultiplier: heightMultiplier),
                           usedClusterBreak: false, fallback: reason)
        }
        guard let bodyLength else {
            return fallback("unsupported whole paragraph")
        }
        // Exclude sub-glyph widths from the legacy differential oracle. Production
        // progress has separate whole-grapheme tests. Admitted sizes are <=22.
        guard width.isFinite, width >= 32, heightMultiplier.isFinite, heightMultiplier > 0 else {
            return fallback("unsupported geometry")
        }
        let native = CTTypesetterCreateWithAttributedString(text)
        var fragments: [LineFragment] = []
        var offset = 0
        var y: CGFloat = 0
        var usedClusterBreak = false
        while offset < text.length {
            var length = clusterSuggestion?(native, offset, Double(width))
                ?? CTTypesetterSuggestClusterBreak(native, offset, Double(width))
            // The final body fragment and terminal LF/CRLF retain native behavior.
            // This remaining suffix is bounded by one fragment, not 60k units.
            if offset + length >= bodyLength {
                length = LineBreakSuggester(lineBreakMode: .byWordWrapping, typesetter: native,
                                            attributedString: text, constrainingWidth: width)
                    .suggestLineBreak(startingAt: offset)
            } else {
                usedClusterBreak = true
            }
            guard let fragment = unbrokenFragment(text, native: native, offset: offset, length: length,
                                                  index: fragments.count, y: y, width: width, multiplier: heightMultiplier),
                  fragment.range.length > 0 else { return fallback("cluster suggestion made no progress") }
            fragments.append(fragment)
            offset = fragment.range.upperBound
            y += fragment.scaledSize.height
        }
        return UnbrokenResult(fragments: fragments, usedClusterBreak: usedClusterBreak, fallback: nil)
    }

    private static func admittedBodyLength(_ text: NSAttributedString) -> Int? {
        let units = Array(text.string.utf16)
        let terminalLength = units.last == 10 ? (units.count > 1 && units[units.count - 2] == 13 ? 2 : 1) : 0
        let body = units.dropLast(terminalLength)
        guard !body.isEmpty, body.allSatisfy({ (48 ... 57).contains($0) || (65 ... 90).contains($0) || (97 ... 122).contains($0) }),
              let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
              (10 ... 22).contains(font.pointSize),
              font == UIFont(name: "Menlo-Regular", size: font.pointSize)
                || font == UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular) else { return nil }
        guard let paragraph = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
              paragraph.defaultTabInterval.isFinite, paragraph.defaultTabInterval > 0 else { return nil }
        // Validate every paragraph property, including the generated tab stops.
        // Colors may vary between runs, but the standard paragraph and font may not.
        var expected = unbrokenText("a", font: font, tabWidth: paragraph.defaultTabInterval)
            .attributes(at: 0, effectiveRange: nil)
        expected.removeValue(forKey: .foregroundColor)
        var supported = true
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, stop in
            var actual = attributes
            guard actual.removeValue(forKey: .foregroundColor) is UIColor else {
                supported = false
                stop.pointee = true
                return
            }
            if let ligature = actual.removeValue(forKey: .ligature) {
                guard let value = ligature as? NSNumber, value.doubleValue == 0 else {
                    supported = false
                    stop.pointee = true
                    return
                }
            }
            if !(actual as NSDictionary).isEqual(to: expected) {
                supported = false
                stop.pointee = true
            }
        }
        return supported ? body.count : nil
    }
}

/// Lifecycle experiment only. Snapshot/gate and native shaping are replaced on
/// refresh, while already measured ranges survive verified appearance-only edits.
private final class UnbrokenContinuation {
    private var snapshot: UnbrokenSnapshot
    private var native: CTTypesetter
    private var width: CGFloat
    private var heightMultiplier: CGFloat
    private var nativeReset: LineTypesetter?
    private var resetReason: String?
    private(set) var fragments: [LineFragment] = []

    init(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) {
        let snapshot = UnbrokenSnapshot(text)
        self.snapshot = snapshot
        self.width = width
        self.heightMultiplier = heightMultiplier
        native = CTTypesetterCreateWithAttributedString(unbrokenDrawingText(snapshot.text))
    }

    func typeset(toLocation target: Int) -> UnbrokenResult {
        if let nativeReset {
            nativeReset.typesetLineFragments(toLocation: target)
            fragments = nativeReset.lineFragments
            return UnbrokenResult(fragments: fragments, usedClusterBreak: false, fallback: resetReason)
        }
        guard width.isFinite, width > 0 else {
            resetToNative(reason: "unsupported geometry")
            return typeset(toLocation: target)
        }
        let supportedGeometry = width >= 32 && heightMultiplier.isFinite && heightMultiplier > 0
        let canUseCluster = snapshot.bodyLength != nil && supportedGeometry
        var usedCluster = false
        var offset = fragments.last?.range.upperBound ?? 0
        var y = fragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        while offset < min(target, snapshot.text.length) {
            var length: Int
            if canUseCluster, let bodyLength = snapshot.bodyLength {
                length = CTTypesetterSuggestClusterBreak(native, offset, Double(width))
                if offset + length < bodyLength {
                    usedCluster = true
                } else {
                    length = nativeSuggestion(at: offset)
                }
            } else {
                length = nativeSuggestion(at: offset)
            }
            guard let fragment = unbrokenFragment(snapshot.text, native: native, offset: offset, length: length,
                                                  index: fragments.count, y: y, width: width, multiplier: heightMultiplier) else {
                resetToNative(reason: "suggestion made no progress")
                return typeset(toLocation: target)
            }
            fragments.append(fragment)
            offset = fragment.range.upperBound
            y += fragment.scaledSize.height
        }
        let fallback = canUseCluster ? nil : (supportedGeometry ? "unsupported whole paragraph" : "unsupported geometry")
        return UnbrokenResult(fragments: fragments, usedClusterBreak: usedCluster, fallback: fallback)
    }

    /// True means measured ranges were retained. Geometry/text changes force an
    /// actual production reset, even when the new snapshot could pass admission.
    func refreshAppearance(_ input: NSAttributedString, width newWidth: CGFloat? = nil,
                           heightMultiplier newMultiplier: CGFloat? = nil) -> Bool {
        let next = UnbrokenSnapshot(input)
        let retained = (newWidth ?? width) == width && (newMultiplier ?? heightMultiplier) == heightMultiplier
            && Self.layoutAttributes(next.text).isEqual(to: Self.layoutAttributes(snapshot.text))
        snapshot = next
        width = newWidth ?? width
        heightMultiplier = newMultiplier ?? heightMultiplier
        native = CTTypesetterCreateWithAttributedString(unbrokenDrawingText(snapshot.text))
        guard retained else {
            resetToNative(reason: "layout attributes or geometry changed")
            return false
        }
        if let nativeReset {
            fragments = nativeReset.refreshAppearance(snapshot.text)
        } else {
            fragments = fragments.map { fragment in
                let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
                return fragment.withLine(CTTypesetterCreateLine(native, range))
            }
        }
        return true
    }

    private func nativeSuggestion(at offset: Int) -> Int {
        LineBreakSuggester(lineBreakMode: .byWordWrapping, typesetter: native,
                           attributedString: snapshot.text, constrainingWidth: width).suggestLineBreak(startingAt: offset)
    }

    private func resetToNative(reason: String) {
        let reset = LineTypesetter(lineID: "unbroken-experiment")
        reset.constrainingWidth = width
        reset.lineFragmentHeightMultiplier = heightMultiplier
        reset.prepareToTypeset(snapshot.text)
        fragments = []
        nativeReset = reset
        resetReason = reason
    }

    private static func layoutAttributes(_ text: NSAttributedString) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: text)
        for key in [NSAttributedString.Key.foregroundColor, .backgroundColor, .shadow] {
            copy.removeAttribute(key, range: NSRange(location: 0, length: copy.length))
        }
        return copy
    }
}

/// Match production background extraction. The baseline independently shapes and
/// breaks these drawing attributes without entering production LineTypesetter.
private func unbrokenDrawingText(_ text: NSAttributedString) -> NSAttributedString {
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

private func unbrokenText(_ string: String, font: UIFont? = nil, explicitLigature: Bool = false,
                          color: UIColor = .black, tabWidth: CGFloat = 40) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(string: string)
    DefaultStringAttributes(textColor: color, font: font ?? UIFont(name: "Menlo-Regular", size: 17)!,
                            kern: 0, tabWidth: tabWidth).apply(to: result)
    if explicitLigature {
        result.addAttribute(.ligature, value: 0, range: NSRange(location: 0, length: result.length))
    }
    return result
}

private func unbrokenFresh(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) -> [LineFragment] {
    let native = IndependentNativeLineOracle()
    native.constrainingWidth = width
    native.lineFragmentHeightMultiplier = heightMultiplier
    native.prepareToTypeset(text)
    native.typesetLineFragments(toLocation: text.length)
    return native.lineFragments
}

private func unbrokenProduction(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) -> [LineFragment] {
    let production = LineTypesetter(lineID: "unbroken-experiment")
    production.constrainingWidth = width
    production.lineFragmentHeightMultiplier = heightMultiplier
    production.prepareToTypeset(text)
    production.typesetLineFragments(toLocation: text.length)
    return production.lineFragments
}

/// Frozen native baseline: no production LineTypesetter/LineBreakSuggester and no
/// cluster fast path. Only ordinary-width cases use this legacy truncation oracle;
/// pathological progress behavior has separate contract tests, never a hanging baseline.
private final class IndependentNativeLineOracle {
    private enum EndCondition {
        case character(Int)
        case yPosition(CGFloat)

        func shouldContinue(offset: Int, yPosition: CGFloat) -> Bool {
            switch self {
            case .character(let target):
                return offset < target
            case .yPosition(let target):
                return yPosition < target
            }
        }
    }

    var constrainingWidth: CGFloat = 0
    var lineFragmentHeightMultiplier: CGFloat = 1
    private(set) var lineFragments: [LineFragment] = []
    private(set) var invalidSuggestion = false
    private var text = NSAttributedString(string: "")
    private var native: CTTypesetter?
    var typesetLength: Int { lineFragments.last?.range.upperBound ?? 0 }

    func prepareToTypeset(_ text: NSAttributedString) {
        self.text = text
        invalidSuggestion = false
        native = CTTypesetterCreateWithAttributedString(unbrokenDrawingText(text))
    }

    func typesetLineFragments(toLocation target: Int) {
        typesetLineFragments(until: .character(target))
        if invalidSuggestion {
            XCTFail("Independent native oracle encountered a sub-glyph width; no invalid range was executed.")
        }
    }

    func typesetLineFragments(in rect: CGRect) {
        typesetLineFragments(until: .yPosition(rect.maxY))
    }

    private func typesetLineFragments(until condition: EndCondition) {
        guard constrainingWidth > 0, let native else {
            return
        }
        var offset = typesetLength
        var y = lineFragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        while offset < text.length && condition.shouldContinue(offset: offset, yPosition: y) {
            let length = independentNativeWordBreak(text, native: native, offset: offset, width: constrainingWidth)
            guard let fragment = unbrokenFragment(text, native: native, offset: offset, length: length,
                                                  index: lineFragments.count, y: y, width: constrainingWidth,
                                                  multiplier: lineFragmentHeightMultiplier) else {
                invalidSuggestion = true
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
private func independentNativeWordBreak(_ text: NSAttributedString, native: CTTypesetter,
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
/// A bad experimental suggestion returns nil instead of hanging the test runner.
/// Keep the frozen native fragment inputs explicit and independent of production state.
private func unbrokenFragment(_ text: NSAttributedString, native: CTTypesetter, offset: Int, length: Int,
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
            let fragment = LineFragment(id: LineFragmentID(lineId: "unbroken-experiment", lineFragmentIndex: index),
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

extension UnbrokenLineBreakExperimentTests {
    private func compare(_ actual: [LineFragment], with expected: [LineFragment], text: NSAttributedString,
                         sparsePixels: Bool = false, complete: Bool = true) throws {
        XCTAssertEqual(actual.count, expected.count)
        guard actual.count == expected.count else { throw UnbrokenMismatch.fragmentCount }
        if complete {
            XCTAssertEqual(actual.last?.range.upperBound ?? 0, text.length)
        } else {
            XCTAssertLessThanOrEqual(actual.last?.range.upperBound ?? 0, text.length)
        }
        for (index, pair) in zip(actual, expected).enumerated() {
            try compareFragment(pair.0, pair.1, text: text,
                                includePixels: !sparsePixels || index == 0 || index >= actual.count - 2)
            if index > 0 {
                XCTAssertEqual(pair.0.range.location, actual[index - 1].range.upperBound)
                XCTAssertEqual(pair.0.yPosition, actual[index - 1].yPosition + actual[index - 1].scaledSize.height)
            }
        }
    }

    private func compareFragment(_ lhs: LineFragment, _ rhs: LineFragment, text: NSAttributedString,
                                 includePixels: Bool) throws {
        XCTAssertEqual(lhs.index, rhs.index)
        XCTAssertEqual(lhs.id, rhs.id)
        XCTAssertEqual(lhs.visibleRange, rhs.visibleRange)
        XCTAssertEqual(lhs.hiddenLength, rhs.hiddenLength)
        guard lhs.visibleRange == rhs.visibleRange, lhs.hiddenLength == rhs.hiddenLength else {
            throw UnbrokenMismatch.fragmentRange
        }
        XCTAssertEqual(lhs.baseSize, rhs.baseSize)
        XCTAssertEqual(lhs.scaledSize, rhs.scaledSize)
        XCTAssertEqual(lhs.descent, rhs.descent)
        XCTAssertEqual(lhs.yPosition, rhs.yPosition)
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
            for delta in [CGFloat(-0.25), 0, 0.25] {
                XCTAssertEqual(CTLineGetStringIndexForPosition(lhs.line, CGPoint(x: leftX + delta, y: 0)),
                               CTLineGetStringIndexForPosition(rhs.line, CGPoint(x: leftX + delta, y: 0)))
            }
        }
        if includePixels { XCTAssertEqual(try pixels(lhs, text: text), try pixels(rhs, text: text)) }
    }
    private func compareRuns(_ actual: CTLine, _ expected: CTLine) {
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

    private func pixels(_ fragment: LineFragment, text: NSAttributedString) throws -> Data {
        let configuration = InvisibleCharacterConfiguration()
        configuration.showSpaces = true
        configuration.showTabs = true
        configuration.showLineBreaks = true
        let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: configuration)
        let delegate = UnbrokenFragmentText(text.attributedSubstring(from: fragment.visibleRange).string)
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
}

private final class UnbrokenFragmentText: LineFragmentRendererDelegate {
    let contents: String
    init(_ contents: String) { self.contents = contents }
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? { contents }
}

private enum UnbrokenMismatch: Error {
    case invalidJSONEncoding
    case fragmentCount
    case fragmentRange
}
