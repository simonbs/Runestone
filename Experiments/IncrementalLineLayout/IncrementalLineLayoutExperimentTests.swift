// swiftlint:disable file_length
import CoreText
import Darwin
import Foundation
@testable import Runestone
import UIKit
import XCTest

/// Test-only hypothesis, not a supported CoreText incremental-layout API.
/// Never promote this gate based on passing examples alone. Only an unchanged
/// terminal LF/CRLF and standard Menlo/default-editor attributes are admitted.
/// Printable punctuation has a separate, unproven test policy; the default remains words-only.
@MainActor
final class IncrementalLineLayoutExperimentTests: XCTestCase {
    func testInsertDeleteReplaceFromSnapshots() throws {
        for size in [CGFloat(13), CGFloat(19)] {
            for width in [CGFloat(113), CGFloat(320)] {
                let original = text(String(repeating: "alpha beta  gamma delta ", count: 18), size: size)
                let configuration = LayoutConfiguration(width: width, heightMultiplier: 1.15)
                let cache = LayoutSnapshot(original, configuration: configuration)
                for (location, length, replacement) in [
                    (original.length - 15, 0, "Z"),
                    (original.length - 15, 1, ""),
                    (original.length / 2, 3, "XYZ"),
                    (original.length, 0, "omega"),
                    (0, 0, "start ")
                ] {
                    let edit = NSRange(location: location, length: length)
                    let changed = replacing(original, range: edit, with: text(replacement, size: size))
                    let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                    XCTAssertNil(result.fallback)
                    if location > original.length / 2 { XCTAssertGreaterThan(result.reusedPrefix, 0) }
                    try compare(result.fragments, with: fresh(changed, configuration), text: changed)
                }
            }
        }
    }

    func testHiddenSpacesAndWordJoiningInvalidateTheirOwner() throws {
        let original = text("intro words " + String(repeating: "a", count: 180) + "     "
                            + String(repeating: "b", count: 150) + " tail words end")
        let configuration = LayoutConfiguration(width: 101)
        let cache = LayoutSnapshot(original, configuration: configuration)
        XCTAssertTrue(cache.fragments.contains { $0.hiddenLength > 0 })
        let spaces = (original.string as NSString).range(of: "     ")
        let edits = [spaces, NSRange(location: spaces.location, length: 0),
                     NSRange(location: spaces.location + 2, length: 1),
                     NSRange(location: spaces.location + spaces.length, length: 0)]
        for edit in edits {
            for replacement in ["", "x", " "] {
                let changed = replacing(original, range: edit, with: text(replacement))
                let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(result.fallback)
                try compare(result.fragments, with: fresh(changed, configuration), text: changed)
            }
        }
    }

    func testPrefixOnlyReuseAndSequentialEdits() throws {
        let configuration = LayoutConfiguration(width: 153, heightMultiplier: 1.13)
        var original = text(String(repeating: "alpha beta gamma delta ", count: 24))
        var cache = LayoutSnapshot(original, configuration: configuration)
        for location in [162, 415, 94] {
            let edit = NSRange(location: location, length: 1)
            let changed = replacing(original, range: edit, with: text("Z"))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            XCTAssertTrue(result.fragments[0] === cache.fragments[0])
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
            cache = result.snapshot
            original = changed
        }
    }

    func testSnapshotOwnsImmutableTextAndSupportsColorRuns() throws {
        let original = NSMutableAttributedString(attributedString: text(String(repeating: "alpha beta gamma ", count: 25)))
        original.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 40, length: 170))
        let configuration = LayoutConfiguration(width: 181)
        let cache = LayoutSnapshot(original, configuration: configuration)
        let edit = NSRange(location: 350, length: 0)
        original.replaceCharacters(in: edit, with: text("Z"))
        let result = cache.layout(original, configuration: configuration, reusePermission: .textEdit)
        XCTAssertNil(result.fallback)
        XCTAssertGreaterThan(result.reusedPrefix, 0)
        try compare(result.fragments, with: fresh(original, configuration), text: original)
    }

    func testUnicodeBidiTabsPunctuationAndLineEndingsFallBack() throws {
        for token in ["café", "e\u{301}", "👩‍💻", "مرحبا", "אבג", "\u{202E}", "\u{2067}",
                      "\t", "\u{00A0}", "\u{200B}", "\u{2028}", ",", "/>", "\n", "\r\n"] {
            let original = text(String(repeating: "alpha beta ", count: 12) + token + " omega")
            let configuration = LayoutConfiguration(width: 151)
            let cache = LayoutSnapshot(original, configuration: configuration)
            let edit = NSRange(location: original.length - 2, length: 0)
            let changed = replacing(original, range: edit, with: text("Z"))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(result.fallback, "unsupported context")
            XCTAssertEqual(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
        // Newly introduced global bidi/shaping context must also invalidate the cache.
        let original = text(String(repeating: "alpha beta ", count: 20))
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration)
        let edit = NSRange(location: original.length - 5, length: 0)
        let changed = replacing(original, range: edit, with: text("אבג"))
        let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
        XCTAssertEqual(result.fallback, "unsupported context")
        try compare(result.fragments, with: fresh(changed, configuration), text: changed)
    }

    func testUnsupportedAttributesFallBackAndEarlierColorChangesInvalidatePrefix() throws {
        let original = text(String(repeating: "alpha beta gamma ", count: 20))
        let configuration = LayoutConfiguration(width: 151)
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.firstLineHeadIndent = 12
        let changes: [(NSAttributedString.Key, Any)] = [
            (.font, UIFont.systemFont(ofSize: 17)), (.font, UIFont(name: "Menlo-Bold", size: 17)!),
            (.kern, 1), (.ligature, 2), (.paragraphStyle, paragraph), (.paragraphStyle, NSParagraphStyle.default),
            (.baselineOffset, 3),
            (.writingDirection, [NSNumber(value: NSWritingDirection.rightToLeft.rawValue)]),
            (.backgroundColor, UIColor.yellow)
        ]
        for (key, value) in changes {
            let styled = NSMutableAttributedString(attributedString: original)
            styled.addAttribute(key, value: value, range: NSRange(location: 0, length: styled.length))
            let cache = LayoutSnapshot(styled, configuration: configuration)
            let edit = NSRange(location: styled.length - 5, length: 0)
            let changed = replacing(styled, range: edit, with: text("Z"))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(result.fallback, "unsupported context")
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
        let cache = LayoutSnapshot(original, configuration: configuration)
        let edit = NSRange(location: original.length - 5, length: 0)
        let changed = NSMutableAttributedString(attributedString: replacing(original, range: edit, with: text("Z")))
        changed.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: 5))
        let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
        XCTAssertNil(result.fallback)
        XCTAssertEqual(result.reusedPrefix, 0)
        try compare(result.fragments, with: fresh(changed, configuration), text: changed)
    }

    func testLayoutChangesFallBackAndSplitJoinUseSnapshotBoundaries() throws {
        let original = text(String(repeating: "alpha beta gamma ", count: 20))
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration)
        for changedConfiguration in [LayoutConfiguration(width: 152),
                                     LayoutConfiguration(width: 151, heightMultiplier: 1.2),
                                     LayoutConfiguration(width: 151, wordWrapping: false)] {
            let result = cache.layout(original, configuration: changedConfiguration, reusePermission: .textEdit)
            XCTAssertEqual(result.fallback, "layout changed")
            try compare(result.fragments, with: fresh(original, changedConfiguration), text: original)
        }
        // These are the resulting individual logical lines; do not pass a multi-line
        // string to a production LineTypesetter and pretend it models line-tree edits.
        let split = text(String(original.string.prefix(170)))
        let joined = text(original.string + "joined words")
        for changed in [split, joined] {
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
    }

    func testOptInPerformanceIncludingSnapshotAndCacheConstruction() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1; coordinator runs Release with coverage disabled.")
        let configuration = LayoutConfiguration(width: 320)
        let fixtures = [
            ("words-default-font-lf", String(repeating: "alpha beta gamma delta ", count: 2_728) + "\n"),
            ("unbroken", String(repeating: "a", count: 60_000)),
            ("json-fallback", "{\"value\":\"" + String(repeating: "alpha beta ", count: 5_455) + "\"}\n")
        ]
        for (name, contents) in fixtures {
            for trial in 0 ... 5 {
                try autoreleasepool {
                    let font = DefaultTheme.shared.font
                    let original = text(contents, font: font)
                    let (_, coldNativeMS) = timed { fresh(original, configuration) }
                    let edit = NSRange(location: original.length - 20, length: 0)
                    let changed = replacing(original, range: edit, with: text("Z", font: font))
                    let (expected, freshMS) = timed { fresh(changed, configuration) }
                    let modes = trial.isMultiple(of: 2) ? PrefixRunMode.allCases : Array(PrefixRunMode.allCases.reversed())
                    for (order, mode) in modes.enumerated() {
                        try autoreleasepool {
                            let (cache, coldCacheMS) = timed {
                                LayoutSnapshot(original, configuration: configuration, prefixRunMode: mode)
                            }
                            let (result, incrementalMS) = timed {
                                cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                            }
                            // Includes prefix reconstruction, change detection and
                            // next snapshot ownership. Oracles are outside timing.
                            try compare(result.fragments, with: expected, text: changed, sparsePixels: true)
                            if trial > 0 {
                                print("RUNESTONE_INCREMENTAL_LAYOUT fixture=\(name) mode=\(mode.rawValue) order=\(order) trial=\(trial) "
                                      + "font=\(font.fontName) size=\(font.pointSize) coldNativeMS=\(coldNativeMS) "
                                      + "coldLayoutAndCacheMS=\(coldCacheMS) editIncludingNextCacheMS=\(incrementalMS) freshMS=\(freshMS) "
                                      + "geometryPrefix=\(result.reusedPrefix) fallback=\(result.fallback ?? "none")")
                            }
                        }
                    }
                }
            }
        }
    }

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

    private func timed<T>(_ operation: () -> T) -> (T, Double) {
        let start = ProcessInfo.processInfo.systemUptime
        let result = operation()
        return (result, (ProcessInfo.processInfo.systemUptime - start) * 1_000)
    }

}

extension IncrementalLineLayoutExperimentTests {
    func testUnchangedTerminalLineEndingsAndWhitespaceBoundaries() throws {
        let bodies = ["", "    ", String(repeating: "a", count: 220) + "    ",
                      String(repeating: "alpha beta gamma delta ", count: 14) + "omega    "]
        for ending in ["\n", "\r\n"] {
            for body in bodies {
                for width in [CGFloat(101), CGFloat(320)] {
                    let original = text(body + ending)
                    let configuration = LayoutConfiguration(width: width, heightMultiplier: 1.15)
                    let cache = LayoutSnapshot(original, configuration: configuration)
                    let end = body.utf16.count
                    var edits = [(NSRange(location: end, length: 0), "Z")]
                    if end > 0 { edits.append((NSRange(location: end - 1, length: 1), "")) }
                    let spaces = body.utf16.reversed().prefix { $0 == 32 }.count
                    if spaces > 0 {
                        edits.append((NSRange(location: end - spaces, length: spaces), ""))
                        edits.append((NSRange(location: end - spaces, length: spaces), "X"))
                        edits.append((NSRange(location: end - spaces, length: 0), "  "))
                    }
                    for (edit, replacement) in edits {
                        let changed = replacing(original, range: edit, with: text(replacement))
                        let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                        XCTAssertNil(result.fallback)
                        if body.hasPrefix("alpha") { XCTAssertGreaterThan(result.reusedPrefix, 0) }
                        try compare(result.fragments, with: fresh(changed, configuration), text: changed)
                    }
                }
            }
        }
    }

    func testTerminalLineEndingChangesAndSnapshotDerivedSplitJoin() throws {
        let body = String(repeating: "alpha beta gamma delta ", count: 14) + "omega    "
        let configuration = LayoutConfiguration(width: 101)
        for ending in ["\n", "\r\n"] {
            let original = text(body + ending)
            let cache = LayoutSnapshot(original, configuration: configuration)
            let delimiter = NSRange(location: body.utf16.count, length: ending.utf16.count)
            // Snapshot comparison sees identical text as a no-op; changing the
            // delimiter kind still forces full native layout.
            for replacement in ["", "\n", "\r\n"] {
                let changed = replacing(original, range: delimiter, with: text(replacement))
                let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                if replacement == ending {
                    XCTAssertNil(result.fallback)
                    XCTAssertEqual(result.reusedPrefix, cache.fragments.count)
                } else {
                    XCTAssertEqual(result.fallback, "line ending changed")
                    XCTAssertEqual(result.reusedPrefix, 0)
                }
                try compare(result.fragments, with: fresh(changed, configuration), text: changed)
            }
            if ending == "\r\n" {
                let edit = NSRange(location: delimiter.location, length: 1)
                let changed = replacing(original, range: edit, with: text(""))
                let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                XCTAssertEqual(result.fallback, "line ending changed")
                try compare(result.fragments, with: fresh(changed, configuration), text: changed)
            }
            // Supply each resulting logical line, including its own terminator.
            // No structural flag or global edit range is supplied to the cache.
            for changed in [text(String(body.prefix(170)) + ending), text(body + "joined words" + ending)] {
                let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(result.fallback)
                XCTAssertGreaterThan(result.reusedPrefix, 0)
                try compare(result.fragments, with: fresh(changed, configuration), text: changed)
            }
        }
    }
}

extension IncrementalLineLayoutExperimentTests {
    func testRealDefaultAttributesAndLigatureWordEdits() throws {
        let fonts = [UIFont(name: "Menlo-Regular", size: 14)!, UIFont(name: "Menlo-Regular", size: 17)!, DefaultTheme.shared.font]
        for font in fonts {
            let original = text(String(repeating: "office affine waffle filling flight ", count: 12) + "office waffle\n", font: font)
            XCTAssertNil(original.attribute(.ligature, at: 0, effectiveRange: nil))
            XCTAssertNotNil(original.attribute(.paragraphStyle, at: 0, effectiveRange: nil))
            for width in [CGFloat(101), CGFloat(237)] {
                let configuration = LayoutConfiguration(width: width)
                let cache = LayoutSnapshot(original, configuration: configuration)
                let office = (original.string as NSString).range(of: "office", options: .backwards)
                let edits = [(NSRange(location: office.location + 2, length: 1), ""),
                             (NSRange(location: office.location + 2, length: 0), " "),
                             (NSRange(location: office.location + 1, length: 4), "f"),
                             (NSRange(location: office.location + 6, length: 1), "")]
                for (edit, replacement) in edits {
                    let changed = replacing(original, range: edit, with: text(replacement, font: font))
                    let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
                    XCTAssertNil(result.fallback)
                    XCTAssertGreaterThan(result.reusedPrefix, 0)
                    try compare(result.fragments, with: fresh(changed, configuration), text: changed)
                }
                let explicitDefault = NSMutableAttributedString(attributedString: original)
                explicitDefault.addAttribute(.ligature, value: 1, range: NSRange(location: 0, length: original.length))
                let result = cache.layout(explicitDefault, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(result.fallback)
                try compare(result.fragments, with: fresh(explicitDefault, configuration), text: explicitDefault)
            }
        }
    }

    func testReplacingParagraphAttributesPreservesSnapshotAndNativeLines() throws {
        // Foundation requires replacing installed attribute values, not mutating
        // them in place: attribute caching/uniquing can share them between strings.
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AttributedStrings/Tasks/ChangingAttrStrings.html
        for useSetAttributes in [false, true] {
            let original = NSMutableAttributedString(attributedString: text(String(repeating: "alpha beta gamma ", count: 30) + "\n"))
            let control = text(original.string)
            let configuration = LayoutConfiguration(width: 151)
            let cache = LayoutSnapshot(original, configuration: configuration)
            let installed = try XCTUnwrap(original.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            let replacement = try XCTUnwrap(installed.mutableCopy() as? NSMutableParagraphStyle)
            replacement.firstLineHeadIndent = 24
            replacement.defaultTabInterval = 99
            replacement.tabStops = []
            let immutableReplacement = try XCTUnwrap(replacement.copy() as? NSParagraphStyle)
            let fullRange = NSRange(location: 0, length: original.length)
            if useSetAttributes {
                var attributes = original.attributes(at: 0, effectiveRange: nil)
                attributes[.paragraphStyle] = immutableReplacement
                original.setAttributes(attributes, range: fullRange)
            } else {
                original.addAttribute(.paragraphStyle, value: immutableReplacement, range: fullRange)
            }
            original.replaceCharacters(in: NSRange(location: original.length - 8, length: 1), with: "Z")
            XCTAssertTrue(cache.text.isEqual(to: control), "Replacing source text and attributes must preserve the old snapshot.")
            try compare(cache.fragments, with: fresh(control, configuration), text: control)
            let reflowed = cache.layout(original, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(reflowed.fallback, "unsupported context")
            XCTAssertEqual(reflowed.reusedPrefix, 0)
            try compare(reflowed.fragments, with: fresh(original, configuration), text: original)
            // The original cache still admits a normal edit with its original style.
            let changed = replacing(control, range: NSRange(location: control.length - 8, length: 1), with: text("Z"))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
    }

    func testAttributeDifferenceBeforeTextEditSetsRestartBoundary() throws {
        let original = text(String(repeating: "alpha beta gamma delta ", count: 28) + "\n")
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration)
        let changed = NSMutableAttributedString(attributedString: replacing(
            original, range: NSRange(location: original.length - 12, length: 1), with: text("Z")))
        changed.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 100, length: 17))
        let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
        XCTAssertNil(result.fallback)
        XCTAssertGreaterThan(result.reusedPrefix, 0)
        XCTAssertLessThanOrEqual(result.fragments[result.reusedPrefix - 1].range.upperBound, 100)
        try compare(result.fragments, with: fresh(changed, configuration), text: changed)
    }

    func testChangedFontKernAndParagraphMetricsInvalidateCache() throws {
        let original = text(String(repeating: "alpha beta gamma ", count: 30) + "\n")
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration)
        let tabStyle = NSMutableParagraphStyle()
        tabStyle.defaultTabInterval = 50
        tabStyle.tabStops = (0 ..< 20).map { NSTextTab(textAlignment: .natural, location: CGFloat($0) * 50) }
        let originalStyle = try XCTUnwrap(original.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let indentStyle = try XCTUnwrap(originalStyle.mutableCopy() as? NSMutableParagraphStyle)
        indentStyle.firstLineHeadIndent = 10
        let changes: [(NSAttributedString.Key, Any)] = [
            (.font, UIFont(name: "Menlo-Regular", size: 19)!), (.kern, 0.5),
            (.paragraphStyle, tabStyle), (.paragraphStyle, indentStyle), (.ligature, 0)
        ]
        for (key, value) in changes {
            let changed = NSMutableAttributedString(attributedString: original)
            changed.addAttribute(key, value: value, range: NSRange(location: 0, length: changed.length))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNotNil(result.fallback)
            XCTAssertEqual(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
    }
}

extension IncrementalLineLayoutExperimentTests {
    func testPartialLayoutEditsAndContinuationPreserveNativeGeometry() throws {
        let font = DefaultTheme.shared.font
        let pattern = "office beta gamma" + String(repeating: " ", count: 30)
        let original = text(String(repeating: pattern, count: 24) + "\r\n", font: font)
        let configuration = LayoutConfiguration(width: 151, heightMultiplier: 1.15)
        let cache = LayoutSnapshot(original, configuration: configuration, toLocation: 180)
        let knownEnd = try XCTUnwrap(cache.fragments.last).range.upperBound
        XCTAssertLessThan(knownEnd, original.length)
        let hiddenOwner = try XCTUnwrap(cache.fragments.last { $0.hiddenLength > 0 })
        for edit in [NSRange(location: original.length - 12, length: 1),
                     NSRange(location: hiddenOwner.visibleRange.upperBound, length: 1)] {
            let changed = replacing(original, range: edit, with: text("Z", font: font))
            let result = cache.layout(changed, configuration: configuration, toLocation: 35, reusePermission: .textEdit)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            XCTAssertEqual(result.fragments.count, result.reusedPrefix, "The request is already inside the retained prefix.")
            let resultEnd = result.fragments.last?.range.upperBound ?? 0
            XCTAssertGreaterThanOrEqual(resultEnd, 35)
            try compare(result.fragments, with: fresh(changed, configuration, toLocation: resultEnd), text: changed, complete: false)
            let continued = result.snapshot.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(continued.reusedPrefix, result.fragments.count)
            try compare(continued.fragments, with: fresh(changed, configuration), text: changed)
            let next = replacing(changed, range: NSRange(location: changed.length - 8, length: 1), with: text("Q", font: font))
            let repeated = continued.snapshot.layout(next, configuration: configuration, reusePermission: .textEdit)
            XCTAssertGreaterThan(repeated.reusedPrefix, 0)
            try compare(repeated.fragments, with: fresh(next, configuration), text: next)
        }
    }

    func testAppearanceRefreshUpdatesSnapshotBeforeContinuationAndEdit() throws {
        let font = DefaultTheme.shared.font
        let original = text(String(repeating: "office affine waffle gamma ", count: 24) + "\n", font: font)
        let configuration = LayoutConfiguration(width: 151)
        for partial in [true, false] {
            let cache = LayoutSnapshot(original, configuration: configuration, toLocation: partial ? 180 : nil)
            let changed = NSMutableAttributedString(attributedString: original)
            changed.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: changed.length))
            changed.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 51, length: 2))
            let refreshed = cache.refreshingAppearance(changed, revision: 0)
            let knownEnd = try XCTUnwrap(cache.fragments.last).range.upperBound
            XCTAssertEqual(refreshed.fragments.count, cache.fragments.count)
            XCTAssertNotEqual(try pixels(refreshed.fragments[0], text: changed), try pixels(cache.fragments[0], text: original))
            try compare(refreshed.fragments, with: fresh(changed, configuration, toLocation: knownEnd),
                        text: changed, complete: !partial)
            let continued = refreshed.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(continued.reusedPrefix, refreshed.fragments.count)
            try compare(continued.fragments, with: fresh(changed, configuration), text: changed)
            let edited = replacing(changed, range: NSRange(location: changed.length - 10, length: 1), with: text("Z", font: font))
            let result = continued.snapshot.layout(edited, configuration: configuration, reusePermission: .textEdit)
            XCTAssertGreaterThan(result.reusedPrefix, 0, "Stale pre-refresh attributes would force an incorrect restart at zero.")
            try compare(result.fragments, with: fresh(edited, configuration), text: edited)
        }
    }

    func testSplitInsideLongWordOrHiddenSpacesAndJoinWithoutSeparator() throws {
        let configuration = LayoutConfiguration(width: 101)
        let body = "alpha beta " + String(repeating: "a", count: 190) + "         omega"
        for ending in ["\n", "\r\n"] {
            let original = text(body + ending)
            let cache = LayoutSnapshot(original, configuration: configuration)
            let spaces = (body as NSString).range(of: "         ")
            for split in [97, spaces.location + 3] {
                let left = text(String(body.prefix(split)) + ending)
                let right = text(String(body.dropFirst(split)) + ending)
                let result = cache.layout(left, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(result.fallback)
                try compare(result.fragments, with: fresh(left, configuration), text: left)
                // The new right logical line has its own fresh, zero-based cache.
                try compare(LayoutSnapshot(right, configuration: configuration).fragments,
                            with: fresh(right, configuration), text: right)
                let joined = text(body + ending)
                let joinResult = result.snapshot.layout(joined, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(joinResult.fallback)
                try compare(joinResult.fragments, with: fresh(joined, configuration), text: joined)
            }
        }
    }
}

extension IncrementalLineLayoutExperimentTests {
    func testPendingAppearanceOverridesTextEditReuseUntilCurrentRefresh() throws {
        let original = text(String(repeating: "alpha beta gamma delta ", count: 24) + "\n")
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration, toLocation: 180)
        let pending = cache.invalidatingAppearance(to: 1).invalidatingAppearance(to: 2)
        let stale = pending.refreshingAppearance(original, revision: 1)
        XCTAssertEqual(stale.pendingAppearanceRevision, 2)
        XCTAssertEqual(stale.appearanceRevision, 0)
        let firstEdit = replacing(original, range: NSRange(location: original.length - 12, length: 1), with: text("Z"))
        let blocked = stale.layout(firstEdit, configuration: configuration, reusePermission: .textEdit, appearanceRevision: 2)
        XCTAssertEqual(blocked.fallback, "appearance pending")
        XCTAssertEqual(blocked.reusedPrefix, 0)
        XCTAssertEqual(blocked.snapshot.pendingAppearanceRevision, 2)
        try compare(blocked.fragments, with: fresh(firstEdit, configuration), text: firstEdit)
        let resetWhilePending = blocked.snapshot.layout(firstEdit, configuration: configuration, reusePermission: .fullReset, appearanceRevision: 3)
        XCTAssertEqual(resetWhilePending.reusedPrefix, 0)
        XCTAssertEqual(resetWhilePending.snapshot.pendingAppearanceRevision, 3)
        XCTAssertEqual(resetWhilePending.snapshot.appearanceRevision, 3)
        let staleAfterEdit = resetWhilePending.snapshot.refreshingAppearance(original, revision: 2)
        XCTAssertTrue(staleAfterEdit.text.isEqual(to: firstEdit), "Stale refresh must not restore pre-edit content.")
        let secondEdit = replacing(firstEdit, range: NSRange(location: firstEdit.length - 8, length: 1), with: text("Q"))
        let stillBlocked = staleAfterEdit.layout(secondEdit, configuration: configuration, reusePermission: .textEdit, appearanceRevision: 3)
        XCTAssertEqual(stillBlocked.fallback, "appearance pending")
        XCTAssertEqual(stillBlocked.reusedPrefix, 0)
        XCTAssertEqual(stillBlocked.snapshot.pendingAppearanceRevision, 3)
        try compare(stillBlocked.fragments, with: fresh(secondEdit, configuration), text: secondEdit)
        let refreshed = stillBlocked.snapshot.refreshingAppearance(secondEdit, revision: 3)
        XCTAssertNil(refreshed.pendingAppearanceRevision)
        XCTAssertEqual(refreshed.appearanceRevision, 3)
        let ready = refreshed.layout(secondEdit, configuration: configuration, reusePermission: .textEdit, appearanceRevision: 3)
        XCTAssertEqual(ready.reusedPrefix, refreshed.fragments.count)
        try compare(ready.fragments, with: fresh(secondEdit, configuration), text: secondEdit)
    }

    func testExplicitResetAndAppearanceRevisionChangeDiscardEqualPrefix() throws {
        let original = text(String(repeating: "alpha beta gamma delta ", count: 24) + "\n")
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration)
        let reset = cache.layout(original, configuration: configuration, reusePermission: .fullReset)
        XCTAssertEqual(reset.fallback, "prefix reuse disallowed")
        XCTAssertEqual(reset.reusedPrefix, 0)
        try compare(reset.fragments, with: fresh(original, configuration), text: original)
        let changedRevision = cache.layout(original, configuration: configuration, reusePermission: .textEdit, appearanceRevision: 1)
        XCTAssertEqual(changedRevision.fallback, "appearance revision changed")
        XCTAssertEqual(changedRevision.reusedPrefix, 0)
        XCTAssertEqual(changedRevision.snapshot.appearanceRevision, 1)
        try compare(changedRevision.fragments, with: fresh(original, configuration), text: original)
    }

    func testSameDynamicColorRefreshAndEditMatchesFreshTraitPixels() throws {
        for mode in PrefixRunMode.allCases { try checkDynamicColor(prefixRunMode: mode) }
    }

    private func checkDynamicColor(prefixRunMode: PrefixRunMode) throws {
        let color = UIColor { traits in traits.userInterfaceStyle == .dark ? .blue : .red }
        let contents = String(repeating: "office affine gamma delta ", count: 20) + "\n"
        let original = coloredText(contents, color: color)
        let configuration = LayoutConfiguration(width: 151)
        let (lightCache, lightPixels) = try withTraits(.light) {
            let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: prefixRunMode)
            try compare(cache.fragments, with: fresh(original, configuration), text: original)
            let bitmap = try pixels(cache.fragments[0], text: original)
            let staticLight = coloredText(contents, color: .red)
            XCTAssertEqual(bitmap, try pixels(fresh(staticLight, configuration)[0], text: staticLight))
            return (cache, bitmap)
        }
        try withTraits(.dark) {
            let pending = lightCache.invalidatingAppearance(to: 1)
            XCTAssertTrue(pending.text.isEqual(to: original), "Equal attribute values do not acknowledge an appearance change.")
            XCTAssertTrue((pending.text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor) === color)
            let refreshed = pending.refreshingAppearance(original, revision: 1)
            XCTAssertNil(refreshed.pendingAppearanceRevision)
            XCTAssertEqual(refreshed.appearanceRevision, 1)
            try compare(refreshed.fragments, with: fresh(original, configuration), text: original)
            let darkPixels = try pixels(refreshed.fragments[0], text: original)
            let staticDark = coloredText(contents, color: .blue)
            XCTAssertEqual(darkPixels, try pixels(fresh(staticDark, configuration)[0], text: staticDark))
            XCTAssertNotEqual(lightPixels, darkPixels)
            let edited = NSMutableAttributedString(attributedString: original)
            edited.replaceCharacters(in: NSRange(location: original.length - 10, length: 1), with: "Z")
            XCTAssertTrue((edited.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor) === color)
            let result = refreshed.layout(edited, configuration: configuration, reusePermission: .textEdit, appearanceRevision: 1)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(edited, configuration), text: edited)
            let staticEdited = coloredText(edited.string, color: .blue)
            XCTAssertEqual(try pixels(result.fragments[0], text: edited),
                           try pixels(fresh(staticEdited, configuration)[0], text: staticEdited))
        }
    }

    private func coloredText(_ contents: String, color: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text(contents, font: DefaultTheme.shared.font))
        result.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: result.length))
        return result
    }

    private func withTraits<T>(_ style: UIUserInterfaceStyle, operation: () throws -> T) throws -> T {
        var outcome: Result<T, Error>?
        UITraitCollection(userInterfaceStyle: style).performAsCurrent {
            outcome = Result { try operation() }
        }
        return try XCTUnwrap(outcome).get()
    }
}

extension IncrementalLineLayoutExperimentTests {
    func testPrefixRunModesMatchFreshEditsContinuationAndColorChanges() throws {
        let original = text(String(repeating: "office beta gamma" + String(repeating: " ", count: 30), count: 14)
                            + "tail words\r\n", font: DefaultTheme.shared.font)
        let configuration = LayoutConfiguration(width: 151, heightMultiplier: 1.15)
        let spaces = (original.string as NSString).range(of: String(repeating: " ", count: 30))
        let edits = [(NSRange(location: original.length - 12, length: 0), "Z"),
                     (NSRange(location: original.length / 2, length: 2), ""), (spaces, ""), (NSRange(location: 0, length: 0), "start ")]
        for mode in PrefixRunMode.allCases {
            for partial in [true, false] {
                let cache = LayoutSnapshot(original, configuration: configuration, toLocation: partial ? 180 : nil, prefixRunMode: mode)
                for (edit, replacement) in edits {
                    let changed = replacing(original, range: edit, with: text(replacement, font: DefaultTheme.shared.font))
                    let result = cache.layout(changed, configuration: configuration, toLocation: partial ? 35 : nil, reusePermission: .textEdit)
                    XCTAssertNil(result.fallback)
                    XCTAssertEqual(result.snapshot.prefixRunMode, mode)
                    if edit.location > original.length / 2 { XCTAssertGreaterThan(result.reusedPrefix, 0) }
                    let knownEnd = result.fragments.last?.range.upperBound ?? 0
                    try compare(result.fragments, with: fresh(changed, configuration, toLocation: knownEnd), text: changed, complete: !partial)
                    let continued = result.snapshot.layout(changed, configuration: configuration, reusePermission: .textEdit)
                    XCTAssertEqual(continued.reusedPrefix, result.fragments.count)
                    try compare(continued.fragments, with: fresh(changed, configuration), text: changed)
                    let recolored = NSMutableAttributedString(attributedString: changed)
                    recolored.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 100, length: 17))
                    let editedAgain = continued.snapshot.layout(recolored, configuration: configuration, reusePermission: .textEdit)
                    XCTAssertNil(editedAgain.fallback)
                    try compare(editedAgain.fragments, with: fresh(recolored, configuration), text: recolored)
                }
            }
        }
    }

    func testRebuiltPrefixUsesNewNonlocalColorsAndBackgrounds() throws {
        let original = text(String(repeating: "alpha beta gamma delta ", count: 20), font: DefaultTheme.shared.font)
        let configuration = LayoutConfiguration(width: 151)
        for key in [NSAttributedString.Key.foregroundColor, .backgroundColor] {
            let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines)
            let changed = NSMutableAttributedString(attributedString: replacing(
                original, range: NSRange(location: original.length - 12, length: 1), with: text("Z", font: DefaultTheme.shared.font)
            ))
            changed.addAttribute(key, value: UIColor.red, range: NSRange(location: 0, length: changed.length))
            changed.addAttribute(key, value: UIColor.blue, range: NSRange(location: 37, length: 79))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(result.fallback)
            XCTAssertGreaterThan(result.reusedPrefix, 0)
            XCTAssertNotEqual(try pixels(cache.fragments[0], text: original), try pixels(result.fragments[0], text: changed))
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)

            // Color-only updates, including removal of a token background, may
            // preserve every measured range but must still rebuild every run.
            let restored = text(changed.string, font: DefaultTheme.shared.font)
            let restoredResult = result.snapshot.layout(restored, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(restoredResult.fallback)
            XCTAssertEqual(restoredResult.reusedPrefix, result.fragments.count)
            try compare(restoredResult.fragments, with: fresh(restored, configuration), text: restored)
        }
    }

    func testRebuiltPrefixQuoteSplitJoinRecoloringMatchesFreshPixels() throws {
        let body = #"{"text":""# + String(repeating: "alpha beta gamma delta ", count: 20) + #""}"#
        let original = NSMutableAttributedString(attributedString: text(body + "\r\n", font: DefaultTheme.shared.font))
        original.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: original.length))
        original.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 0, length: original.length))
        let configuration = LayoutConfiguration(width: 151, heightMultiplier: 1.15)
        for partial in [false, true] {
            let cache = LayoutSnapshot(original, configuration: configuration, toLocation: partial ? 150 : nil,
                                       prefixRunMode: .rebuildLines, characterPolicy: .printableASCII)
            let splitLocation = original.length * 3 / 4
            let split = NSMutableAttributedString(attributedString: replacing(
                original, range: NSRange(location: splitLocation, length: 0), with: text("\"", font: DefaultTheme.shared.font)
            ))
            split.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: split.length))
            split.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: split.length))
            split.addAttribute(.backgroundColor, value: UIColor.cyan, range: NSRange(location: 31, length: 91))
            let splitResult = cache.layout(split, configuration: configuration, toLocation: partial ? 100 : nil, reusePermission: .textEdit)
            XCTAssertNil(splitResult.fallback)
            XCTAssertGreaterThan(splitResult.reusedPrefix, 0)
            XCTAssertNotEqual(try pixels(cache.fragments[0], text: original), try pixels(splitResult.fragments[0], text: split))
            let knownEnd = try XCTUnwrap(splitResult.fragments.last).range.upperBound
            try compare(splitResult.fragments, with: fresh(split, configuration, toLocation: knownEnd),
                        text: split, complete: knownEnd == split.length)
            let completed = splitResult.snapshot.layout(split, configuration: configuration, reusePermission: .textEdit)
            try compare(completed.fragments, with: fresh(split, configuration), text: split)

            // Join the quote back out and restore earlier token colors. This
            // models nonlocal highlighting; it does not test parser semantics.
            let joined = NSMutableAttributedString(attributedString: original)
            let joinedResult = completed.snapshot.layout(joined, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNil(joinedResult.fallback)
            XCTAssertGreaterThan(joinedResult.reusedPrefix, 0)
            try compare(joinedResult.fragments, with: fresh(joined, configuration), text: joined)
        }
    }

    func testRebuiltPrefixStillRejectsChangedShapingAndUnknownAttributes() throws {
        let original = text(String(repeating: "alpha beta gamma delta ", count: 20), font: DefaultTheme.shared.font)
        let configuration = LayoutConfiguration(width: 151)
        let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines)
        let changes: [(NSAttributedString.Key, Any)] = [
            (.font, UIFont(name: "Menlo-Regular", size: 18)!), (.kern, 0.5), (.ligature, 2),
            (.baselineOffset, 3)
        ]
        for (key, value) in changes {
            let changed = NSMutableAttributedString(attributedString: original)
            changed.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: changed.length))
            changed.addAttribute(key, value: value, range: NSRange(location: 0, length: changed.length))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertNotNil(result.fallback)
            XCTAssertEqual(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
    }

    func testOptInRepeatedEditMemoryObservation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_INCREMENTAL_MEMORY"] == "1",
                          "Set RUNESTONE_INCREMENTAL_MEMORY=1 for a bounded whole-process memory observation.")
        // Counterbalance policy order; neither order removes allocator/test history.
        // These are observations, not leak detection or proof of native ownership.
        for order in 0 ..< 2 {
            let modes = order == 0 ? PrefixRunMode.allCases : Array(PrefixRunMode.allCases.reversed())
            for mode in modes { try observeRepeatedEdits(mode: mode, order: order) }
        }
    }

    private func observeRepeatedEdits(mode: PrefixRunMode, order: Int) throws {
        let configuration = LayoutConfiguration(width: 320)
        let contents = String(repeating: "alpha beta gamma delta ", count: 2_728) + "\n"
        reportMemory(mode: mode, order: order, phase: "beforeCache", step: 0)
        var cache: LayoutSnapshot? = autoreleasepool {
            LayoutSnapshot(text(contents, font: DefaultTheme.shared.font), configuration: configuration, prefixRunMode: mode)
        }
        reportMemory(mode: mode, order: order, phase: "afterInitialCache", step: 0)
        for step in 1 ... 24 {
            try autoreleasepool {
                let previous = try XCTUnwrap(cache)
                let changed = NSMutableAttributedString(attributedString: previous.text)
                // Advance edits through the last quarter so retained-line mode may
                // accumulate prefix fragments made in multiple paragraph generations.
                let location = changed.length * 3 / 4 + step * (changed.length / 5) / 24
                changed.replaceCharacters(in: NSRange(location: location, length: 1), with: step.isMultiple(of: 2) ? "Q" : "Z")
                let result = previous.layout(changed, configuration: configuration, reusePermission: .textEdit)
                XCTAssertNil(result.fallback)
                XCTAssertGreaterThan(result.reusedPrefix, 0)
                XCTAssertTrue(result.snapshot.text.isEqual(to: changed))
                cache = result.snapshot
            }
            if step.isMultiple(of: 6) { reportMemory(mode: mode, order: order, phase: "afterEditPool", step: step) }
        }
        // Run the full final oracle after edit memory samples so its allocations
        // do not contaminate the preceding checkpoints within this sequence.
        try autoreleasepool {
            let final = try XCTUnwrap(cache)
            try compare(final.fragments, with: fresh(final.text, configuration), text: final.text)
        }
        autoreleasepool { cache = nil }
        reportMemory(mode: mode, order: order, phase: "afterReleaseIncludesOracleHistory", step: 24)
    }

    private func reportMemory(mode: PrefixRunMode, order: Int, phase: String, step: Int) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawInfo in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawInfo, &count)
            }
        }
        let tag = "RUNESTONE_PREFIX_MEMORY mode=\(mode.rawValue) order=\(order) phase=\(phase) step=\(step)"
        guard status == KERN_SUCCESS else {
            print("\(tag) status=\(status)")
            return
        }
        let mebibyte = 1_024.0 * 1_024.0
        print("\(tag) status=ok residentMiB=\(Double(info.resident_size) / mebibyte) footprintMiB=\(Double(info.phys_footprint) / mebibyte)")
    }
}

extension IncrementalLineLayoutExperimentTests {
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
        XCTAssertGreaterThan(prefix.count, 0)
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
        let measured = fresh(ascii, configuration, toLocation: 5_500)
        XCTAssertGreaterThan(try XCTUnwrap(measured.last).range.upperBound, 4_096)
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
        // A shared embedded NUL must not terminate first-difference scanning;
        // later changed bytes still cannot make this paragraph admissible.
        let withNUL = replacing(ascii, range: NSRange(location: 6_000, length: 1), with: text("\u{0}", font: DefaultTheme.shared.font))
        let afterNUL = replacing(withNUL, range: NSRange(location: 6_500, length: 1), with: text("X", font: DefaultTheme.shared.font))
        XCTAssertEqual(LinePrefixReuse.count(from: withNUL, to: afterNUL, fragments: measured, limit: measured.count), 0)
    }

    func testProductionControllerInvalidationsAndStaleHighlightCompletionMatchFresh() throws {
        let contents = String(repeating: "alpha / beta gamma delta ", count: 300)
        for invalidation in 0 ..< 6 {
            let fixture = PrefixControllerFixture(contents: contents)
            fixture.controller.prepareToDisplayString(toLocation: contents.utf16.count, syntaxHighlightAsynchronously: invalidation == 3)
            fixture.string.replaceText(in: NSRange(location: contents.utf16.count - 12, length: 1), with: "X")
            switch invalidation {
            case 0:
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            case 1:
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
                fixture.controller.invalidateEverything()
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            case 2:
                fixture.controller.theme = DefaultTheme()
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            case 3:
                XCTAssertEqual(fixture.highlighter.pending.count, 1)
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
                XCTAssertFalse(try XCTUnwrap(fixture.highlighter.pending.first).input.isValid())
            case 4:
                fixture.controller.invalidateSyntaxHighlighter()
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
            default:
                fixture.controller.constrainingWidth = 152
                fixture.controller.constrainingWidth = 151
                fixture.controller.invalidateEverything(allowingPrefixReuse: true)
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

extension IncrementalLineLayoutExperimentTests {
    func testPrintableASCIICodeAndOperatorsMatchFreshNativeWraps() throws {
        let records = Array(repeating: #"{"text":"alpha beta gamma delta","items":[12,345.67,-1e-10],"ok":true}"#, count: 4)
        let samples = [
            "[" + records.joined(separator: ",") + "]",
            String(repeating: #"const s = "alpha \" beta"; const x = obj?.item ?? fallback; a !== b && c <= d; "#, count: 3),
            String(repeating: #"<tag attr="alpha beta" /> // path/to/file.swift / > /> />> /* one two */ "#, count: 3),
            String(repeating: #"!@#$%^&*()_+-=[]{}|;:',.<>/?~`\" 0123456789 office affine ffi ffl "#, count: 3),
            String(repeating: "total = $+12 + 12,345.67 - 1e-10; foo::bar -> baz => qux; a/b//c///d ", count: 3)
        ]
        var reusedCases = 0
        for font in [DefaultTheme.shared.font, UIFont(name: "Menlo-Regular", size: 17)!] {
            for width in [CGFloat(80.5), CGFloat(151.25)] {
                for (sample, body) in samples.enumerated() {
                    let original = text(body + "\r\n", font: font)
                    let configuration = LayoutConfiguration(width: width)
                    let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines,
                                               characterPolicy: .printableASCII)
                    let boundary = cache.fragments[cache.fragments.count * 2 / 3]
                    let visibleEnd = min(boundary.visibleRange.upperBound, body.utf16.count)
                    let rangeEnd = min(boundary.range.upperBound, body.utf16.count)
                    let edits = [(NSRange(location: visibleEnd, length: 0), "\""),
                                 (NSRange(location: max(0, visibleEnd - 1), length: 1), ""),
                                 (NSRange(location: min(visibleEnd + 1, body.utf16.count), length: 0), "/>"),
                                 (NSRange(location: max(0, rangeEnd - 1), length: 1), "/"),
                                 (NSRange(location: rangeEnd, length: 0), " "),
                                 (NSRange(location: min(rangeEnd + 1, body.utf16.count), length: 0), "'")]
                    for (edit, replacement) in edits {
                        guard let result = try checkPunctuationEdit(
                            cache, edit: edit, replacement: replacement, label: "code sample=\(sample)"
                        ) else { return }
                        reusedCases += result.reused > 0 ? 1 : 0
                    }
                }
            }
        }
        XCTAssertGreaterThan(reusedCases, 0, "The matrix must exercise cached prefix geometry, not only full reflow.")
    }

    func testPrintableASCIIQuotesAcrossLongSpacesMatchFreshNativeWraps() throws {
        let contexts = [("\"", "("), ("'", "["), ("(", "a"), ("[", "\""), (")", "%")]
        var reusedCases = 0
        for (before, after) in contexts {
            for spaceCount in [1, 2, 30, 129] {
                let prefix = String(repeating: "anchor / stable words ", count: 6) + before
                let body = prefix + String(repeating: " ", count: spaceCount) + after + "alphabetagamma / tail words"
                let original = text(body + "\n", font: DefaultTheme.shared.font)
                let configuration = LayoutConfiguration(width: 101.5)
                let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines,
                                           characterPolicy: .printableASCII)
                let token = prefix.utf16.count + spaceCount
                let edits = [(NSRange(location: token, length: 1), "\""),
                             (NSRange(location: token + 1, length: 1), ""),
                             (NSRange(location: token + 2, length: 8), "x"),
                             (NSRange(location: prefix.utf16.count, length: spaceCount), ""),
                             (NSRange(location: prefix.utf16.count - 1, length: 1), "/>")]
                for (edit, replacement) in edits {
                    guard let result = try checkPunctuationEdit(
                        cache, edit: edit, replacement: replacement, label: "spaces=\(spaceCount) before=\(before) after=\(after)"
                    ) else { return }
                    reusedCases += result.reused > 0 ? 1 : 0
                }
            }
        }
        XCTAssertGreaterThan(reusedCases, 0)
    }

    func testPrintableASCIIPolicyPreservesUnsupportedContextFallbacks() throws {
        let configuration = LayoutConfiguration(width: 151)
        let bodies = ["café", "e\u{301}", "👩‍💻", "אבג", "مرحبا", "\t", "\u{202E}", "\u{00A0}", "\u{200B}", "\u{7F}"]
        for body in bodies {
            let original = text("anchor / alpha beta " + body + " tail words\n", font: DefaultTheme.shared.font)
            let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines,
                                       characterPolicy: .printableASCII)
            let changed = replacing(original, range: NSRange(location: 10, length: 1), with: text("Z", font: DefaultTheme.shared.font))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(result.fallback, "unsupported context")
            XCTAssertEqual(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
        let original = text("anchor / alpha beta gamma delta / tail words\n", font: DefaultTheme.shared.font)
        let cache = LayoutSnapshot(original, configuration: configuration, prefixRunMode: .rebuildLines,
                                   characterPolicy: .printableASCII)
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        let attributes: [(NSAttributedString.Key, Any)] = [
            (.font, UIFont.systemFont(ofSize: 17)), (.font, UIFont(name: "Menlo-Bold", size: 17)!),
            (.kern, 0.5), (.ligature, 2), (.paragraphStyle, paragraph.copy()),
            (NSAttributedString.Key(kCTLanguageAttributeName as String), "th")
        ]
        for (key, value) in attributes {
            let changed = NSMutableAttributedString(attributedString: original)
            changed.addAttribute(key, value: value, range: NSRange(location: 0, length: changed.length))
            let result = cache.layout(changed, configuration: configuration, reusePermission: .textEdit)
            XCTAssertEqual(result.fallback, "unsupported context")
            XCTAssertEqual(result.reusedPrefix, 0)
            try compare(result.fragments, with: fresh(changed, configuration), text: changed)
        }
    }
}

extension IncrementalLineLayoutExperimentTests {
    func testOptInSeededPrintableASCIIPrefixSearch() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["RUNESTONE_PREFIX_PUNCTUATION_SEARCH"] == "1",
                          "Set RUNESTONE_PREFIX_PUNCTUATION_SEARCH=1 for the seeded counterexample search.")
        let seedText = environment["RUNESTONE_PREFIX_SEARCH_SEED"] ?? "505245464958504e"
        let seed = try XCTUnwrap(UInt64(seedText.replacingOccurrences(of: "0x", with: ""), radix: 16))
        var random = PrefixSearchRandom(state: seed)
        let caseCount = min(2_048, max(1, Int(environment["RUNESTONE_PREFIX_SEARCH_CASES"] ?? "256") ?? 256))
        var checks = 0
        var reusedCases = 0
        for index in 0 ..< caseCount {
            let font = random.pick(2) == 0 ? DefaultTheme.shared.font : UIFont(name: "Menlo-Regular", size: 17)!
            let body = random.punctuationBody()
            let ending = ["", "\n", "\r\n"][random.pick(3)]
            let original = text(body + ending, font: font)
            let advance = ("M" as NSString).size(withAttributes: [.font: font]).width
            let width = advance * CGFloat([8, 13, 24][random.pick(3)]) + [-0.01, 0, 0.01][random.pick(3)]
            let configuration = LayoutConfiguration(width: width, heightMultiplier: 1.15)
            var cache = LayoutSnapshot(original, configuration: configuration, toLocation: index.isMultiple(of: 3) ? body.utf16.count / 3 : nil,
                                       prefixRunMode: .rebuildLines, characterPolicy: .printableASCII)
            for step in 0 ..< 4 {
                let bodyLength = cache.text.length - ending.utf16.count
                let native = fresh(cache.text, configuration)
                let boundary = native[min(native.count - 1, 1 + random.pick(max(1, native.count - 1)))]
                let edge = random.pick(2) == 0 ? boundary.visibleRange.upperBound : boundary.range.upperBound
                // Never remove the stable initial '/' marker, keeping both inputs
                // outside the separate unbroken-ASCII production fast path.
                let location = min(bodyLength, max(30, edge + random.pick(3) - 1))
                let length = min(bodyLength - location, [0, 1, 2, 9][random.pick(4)])
                let replacement = ["", " ", "\"", "'", "/>", "/", "//", "/*", "*/", "(", "]", "=>", "..", "12,3"][random.pick(14)]
                guard let result = try checkPunctuationEdit(
                    cache, edit: NSRange(location: location, length: length), replacement: replacement,
                    label: "seed=\(seedText) case=\(index) step=\(step)",
                    toLocation: index.isMultiple(of: 3) ? bodyLength / 6 : nil
                ) else { return }
                checks += 1
                reusedCases += result.reused > 0 ? 1 : 0
                cache = result.snapshot
            }
        }
        XCTAssertGreaterThan(reusedCases, 0, "A fallback-only or restart-at-zero-only search is not useful reuse evidence.")
        print("RUNESTONE_PREFIX_PUNCTUATION_SEARCH seed=\(seedText) cases=\(caseCount) checks=\(checks) withReusedPrefix=\(reusedCases)")
    }

    private func checkPunctuationEdit(_ cache: LayoutSnapshot, edit: NSRange, replacement: String,
                                      label: String, toLocation: Int? = nil) throws -> (snapshot: LayoutSnapshot, reused: Int)? {
        let run = try XCTUnwrap(testRun)
        let failuresBefore = run.failureCount
        let attributes = cache.text.attributes(at: min(edit.location, cache.text.length - 1), effectiveRange: nil)
        let changed = replacing(cache.text, range: edit, with: NSAttributedString(string: replacement, attributes: attributes))
        let result = cache.layout(changed, configuration: cache.configuration, toLocation: toLocation, reusePermission: .textEdit)
        XCTAssertNil(result.fallback)
        let expected = fresh(changed, cache.configuration)
        let knownEnd = result.fragments.last?.range.upperBound ?? 0
        XCTAssertGreaterThanOrEqual(knownEnd, min(toLocation ?? changed.length, changed.length))
        let expectedPrefix = Array(expected.prefix { $0.range.location < knownEnd })
        try compare(result.fragments, with: expectedPrefix, text: changed, complete: knownEnd == changed.length)
        let completed = knownEnd < changed.length
            ? result.snapshot.layout(changed, configuration: cache.configuration, reusePermission: .textEdit) : result
        if knownEnd < changed.length { try compare(completed.fragments, with: expected, text: changed) }
        guard run.failureCount == failuresBefore else {
            let font = cache.text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            let diagnostic: [String: Any] = [
                "case": label, "width": Double(cache.configuration.width), "font": font?.fontName ?? "unknown",
                "size": Double(font?.pointSize ?? 0), "old": cache.text.string, "new": changed.string,
                "location": edit.location, "length": edit.length, "replacement": replacement, "retained": result.reusedPrefix,
                "actualRanges": completed.fragments.map { [$0.visibleRange.location, $0.visibleRange.length, $0.hiddenLength] },
                "freshRanges": expected.map { [$0.visibleRange.location, $0.visibleRange.length, $0.hiddenLength] }
            ]
            let data = try JSONSerialization.data(withJSONObject: diagnostic, options: [.sortedKeys])
            let payload = try XCTUnwrap(String(data: data, encoding: .utf8))
            print("RUNESTONE_PREFIX_PUNCTUATION_COUNTEREXAMPLE \(payload)")
            XCTContext.runActivity(named: "Reproduce printable-ASCII prefix counterexample") { activity in
                let attachment = XCTAttachment(string: payload)
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
            return nil
        }
        return (completed.snapshot, result.reusedPrefix)
    }
}

private struct PrefixSearchRandom {
    var state: UInt64

    mutating func pick(_ count: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 32) % UInt64(count))
    }

    mutating func punctuationBody() -> String {
        let tokens = ["\"", "'", "(", ")", "[", "]", "{", "}", "/>", "/ >", "/>>", "//", "/*", "*/", "\\\"",
                      "!=", "?.", "??", "::", "12,345.67", "1e-10", "$+12", "office", "affine", "alphabetagamma"]
        var body = "anchor / stable prefix words "
        for _ in 0 ..< 20 + pick(30) {
            switch pick(4) {
            case 0:
                body += String(repeating: " ", count: [1, 2, 30, 129][pick(4)])
            case 1:
                body += String(UnicodeScalar(33 + pick(94))!)
            default:
                body += tokens[pick(tokens.count)]
            }
        }
        return body + " / tail words"
    }
}

extension IncrementalLineLayoutExperimentTests {
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

private enum PrefixCharacterPolicy {
    case wordsOnly
    case printableASCII
}

private enum PrefixRunMode: String, CaseIterable {
    case retainLines
    case rebuildLines
}

private enum PrefixReusePermission {
    case textEdit
    case fullReset
}

private struct LayoutResult {
    let snapshot: LayoutSnapshot
    let reusedPrefix: Int
    var fallback: String?
    var fragments: [LineFragment] { snapshot.fragments }
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

/// Immutable snapshots own both text and the measured prefix. Every layout result
/// owns the replacement cache, so edit timing includes cache maintenance. This does
/// not model controller trees, asynchronous delivery, view recycling, or cache eviction.
private final class LayoutSnapshot {
    let text: NSAttributedString
    let fragments: [LineFragment]
    let configuration: LayoutConfiguration
    let appearanceRevision: Int
    let pendingAppearanceRevision: Int?
    let prefixRunMode: PrefixRunMode
    let characterPolicy: PrefixCharacterPolicy
    private let signature: ShapingSignature?

    init(_ text: NSAttributedString, configuration: LayoutConfiguration, toLocation: Int? = nil,
         appearanceRevision: Int = 0, prefixRunMode: PrefixRunMode = .retainLines,
         characterPolicy: PrefixCharacterPolicy = .wordsOnly) {
        precondition(characterPolicy == .wordsOnly || prefixRunMode == .rebuildLines,
                     "Printable-ASCII admission is experimental and requires rebuilding all retained drawing runs.")
        let frozen = Self.freeze(text)
        self.text = frozen
        self.configuration = configuration
        self.appearanceRevision = appearanceRevision
        self.prefixRunMode = prefixRunMode
        self.characterPolicy = characterPolicy
        pendingAppearanceRevision = nil
        signature = Self.shapingSignature(frozen, characterPolicy: characterPolicy, prefixRunMode: prefixRunMode)
        fragments = fresh(frozen, configuration, toLocation: toLocation)
    }

    private init(frozen: NSAttributedString, configuration: LayoutConfiguration,
                 signature: ShapingSignature?, fragments: [LineFragment],
                 appearanceRevision: Int, pendingAppearanceRevision: Int? = nil, prefixRunMode: PrefixRunMode,
                 characterPolicy: PrefixCharacterPolicy) {
        text = frozen
        self.configuration = configuration
        self.signature = signature
        self.fragments = fragments
        self.appearanceRevision = appearanceRevision
        self.pendingAppearanceRevision = pendingAppearanceRevision
        self.prefixRunMode = prefixRunMode
        self.characterPolicy = characterPolicy
    }

    func invalidatingAppearance(to revision: Int) -> LayoutSnapshot {
        precondition(revision >= (pendingAppearanceRevision ?? appearanceRevision), "Appearance revisions must not move backward.")
        return LayoutSnapshot(frozen: text, configuration: configuration, signature: signature, fragments: fragments,
                              appearanceRevision: appearanceRevision, pendingAppearanceRevision: revision,
                              prefixRunMode: prefixRunMode, characterPolicy: characterPolicy)
    }

    func layout(_ changed: NSAttributedString, configuration: LayoutConfiguration, toLocation: Int? = nil,
                reusePermission: PrefixReusePermission, appearanceRevision: Int? = nil) -> LayoutResult {
        let requiredRevision = max(self.appearanceRevision, pendingAppearanceRevision ?? self.appearanceRevision)
        let requestedRevision = appearanceRevision ?? requiredRevision
        precondition(requestedRevision >= requiredRevision, "Layout must not rewind the appearance revision.")
        let updatedPendingRevision = pendingAppearanceRevision.map { max($0, requestedRevision) }
        let frozen = Self.freeze(changed)
        let newSignature = Self.shapingSignature(frozen, characterPolicy: characterPolicy, prefixRunMode: prefixRunMode)
        func finish(_ fragments: [LineFragment], reused: Int, fallback: String? = nil) -> LayoutResult {
            // Rebuilding drawing runs during a text edit does not acknowledge
            // pending theme/highlight work. Only explicit refresh clears it.
            let snapshot = LayoutSnapshot(frozen: frozen, configuration: configuration, signature: newSignature, fragments: fragments,
                                          appearanceRevision: requestedRevision, pendingAppearanceRevision: updatedPendingRevision,
                                          prefixRunMode: prefixRunMode, characterPolicy: characterPolicy)
            return LayoutResult(snapshot: snapshot, reusedPrefix: reused, fallback: fallback)
        }
        func fallback(_ reason: String) -> LayoutResult {
            finish(fresh(frozen, configuration, toLocation: toLocation), reused: 0, fallback: reason)
        }
        if let reason = reuseInvalidationReason(reusePermission, revision: requestedRevision) {
            return fallback(reason)
        }
        guard configuration == self.configuration, configuration.wordWrapping,
              configuration.width > 0, configuration.width.isFinite else {
            return fallback("layout changed")
        }
        guard Self.terminalLength(text) == Self.terminalLength(frozen) else {
            return fallback("line ending changed")
        }
        guard let signature, let newSignature else {
            return fallback("unsupported context")
        }
        guard signature == newSignature else {
            return fallback("shaping attributes changed")
        }
        let prefixCount = retainedPrefixCount(comparedWith: frozen)
        // Retain the entire immutable attributed paragraph for shaping, including
        // its real paragraph settings, default ligatures, and terminal delimiter.
        let native = drawingTypesetter(frozen)
        var result = prefixFragments(count: prefixCount, typesetter: native)
        var offset = result.last?.range.upperBound ?? 0
        var yPosition = result.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        let target = min(toLocation ?? frozen.length, frozen.length)
        while offset < target {
            let next = nativeFragment(frozen, typesetter: native, configuration: configuration,
                                      offset: offset, index: result.count, yPosition: yPosition)
            result.append(next)
            offset = next.range.upperBound
            yPosition += next.scaledSize.height
        }
        return finish(result, reused: prefixCount)
    }

    private func prefixFragments(count: Int, typesetter: CTTypesetter) -> [LineFragment] {
        let prefix = fragments.prefix(count)
        guard prefixRunMode == .rebuildLines else {
            return Array(prefix)
        }
        // Reuse only measured ranges/geometry. Every drawing run comes from the
        // current full paragraph; old prefix CTLines are not copied into the result.
        return prefix.map { fragment in
            let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
            return fragment.withLine(CTTypesetterCreateLine(typesetter, range))
        }
    }

    private func retainedPrefixCount(comparedWith changed: NSAttributedString) -> Int {
        guard let start = Self.firstChange(text, changed, compareAttributes: prefixRunMode == .retainLines) else {
            return fragments.count
        }
        let restart = min(Self.restart(in: text, at: start), Self.restart(in: changed, at: start))
        let eligible = fragments.prefix { $0.range.upperBound <= restart }.count
        return max(0, eligible - 1)
    }

    private func reuseInvalidationReason(_ permission: PrefixReusePermission, revision: Int) -> String? {
        guard permission == .textEdit else {
            return "prefix reuse disallowed"
        }
        guard pendingAppearanceRevision == nil else {
            return "appearance pending"
        }
        guard revision == appearanceRevision else {
            return "appearance revision changed"
        }
        return nil
    }

    /// Mirror the production appearance-only path: refresh full-context CTLines
    /// over measured ranges and advance the immutable snapshot to that same revision.
    /// Invalid content/metrics use normal reprepare instead of claiming appearance-only.
    func refreshingAppearance(_ changed: NSAttributedString, revision: Int) -> LayoutSnapshot {
        // A stale async completion must never acknowledge a newer invalidation.
        guard revision == (pendingAppearanceRevision ?? appearanceRevision) else {
            return self
        }
        let frozen = Self.freeze(changed)
        let newSignature = Self.shapingSignature(frozen, characterPolicy: characterPolicy, prefixRunMode: prefixRunMode)
        let refreshed: [LineFragment]
        if frozen.string == text.string, let signature, signature == newSignature {
            let native = drawingTypesetter(frozen)
            refreshed = fragments.map { fragment in
                let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
                return fragment.withLine(CTTypesetterCreateLine(native, range))
            }
        } else {
            // A refresh with changed content or metrics requires native remeasurement.
            refreshed = fresh(frozen, configuration, toLocation: fragments.last?.range.upperBound ?? 0)
        }
        return LayoutSnapshot(frozen: frozen, configuration: configuration, signature: newSignature, fragments: refreshed,
                              appearanceRevision: revision, prefixRunMode: prefixRunMode, characterPolicy: characterPolicy)
    }

    private static func freeze(_ source: NSAttributedString) -> NSAttributedString {
        // Copy paragraph values and the run table. Foundation may intern equal
        // attributes globally, so callers must still replace installed values via
        // attributed-string APIs rather than mutate those values in place.
        let copy = NSMutableAttributedString(string: source.string)
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length)) { attributes, range, _ in
            var frozen = attributes
            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
                frozen[.paragraphStyle] = paragraph.copy()
            }
            copy.setAttributes(frozen, range: range)
        }
        return NSAttributedString(attributedString: copy)
    }

    private static func firstChange(_ old: NSAttributedString, _ new: NSAttributedString, compareAttributes: Bool) -> Int? {
        let oldString = CFAttributedStringGetString(old)
        let newString = CFAttributedStringGetString(new)
        let commonLength = min(old.length, new.length)
        var character = 0
        while character < commonLength && CFStringGetCharacterAtIndex(oldString, character) == CFStringGetCharacterAtIndex(newString, character) {
            character += 1
        }
        // Both full paragraphs already passed the uniform shaping-signature gate.
        // Rebuilt drawing runs use the new colors everywhere, even before the edit.
        guard compareAttributes else {
            return character == old.length && character == new.length ? nil : character
        }
        var position = 0
        while position < character {
            var oldRange = NSRange()
            var newRange = NSRange()
            let oldAttributes = old.attributes(at: position, effectiveRange: &oldRange)
            let newAttributes = new.attributes(at: position, effectiveRange: &newRange)
            if (oldAttributes as NSDictionary) != (newAttributes as NSDictionary) {
                return position
            }
            position = min(character, oldRange.upperBound, newRange.upperBound)
        }
        return character == old.length && character == new.length ? nil : character
    }

    private static func restart(in text: NSAttributedString, at location: Int) -> Int {
        let string = CFAttributedStringGetString(text)
        var start = min(location, text.length - terminalLength(text))
        while start > 0 && CFStringGetCharacterAtIndex(string, start - 1) == 32 { start -= 1 }
        while start > 0 && CFStringGetCharacterAtIndex(string, start - 1) != 32 { start -= 1 }
        return start
    }

    private static func terminalLength(_ text: NSAttributedString) -> Int {
        let string = CFAttributedStringGetString(text)
        guard text.length > 0, CFStringGetCharacterAtIndex(string, text.length - 1) == 10 else {
            return 0
        }
        return text.length > 1 && CFStringGetCharacterAtIndex(string, text.length - 2) == 13 ? 2 : 1
    }

    private static func shapingSignature(_ text: NSAttributedString, characterPolicy: PrefixCharacterPolicy,
                                         prefixRunMode: PrefixRunMode) -> ShapingSignature? {
        guard text.length > 0 else {
            return nil
        }
        let string = CFAttributedStringGetString(text)
        for index in 0 ..< text.length - terminalLength(text) {
            let unit = CFStringGetCharacterAtIndex(string, index)
            let admitted = characterPolicy == .printableASCII ? (32 ... 126).contains(unit)
                : unit == 32 || (48 ... 57).contains(unit) || (65 ... 90).contains(unit) || (97 ... 122).contains(unit)
            guard admitted else {
                return nil
            }
        }
        var allowed: Set<NSAttributedString.Key> = [.font, .foregroundColor, .kern, .ligature, .paragraphStyle]
        if prefixRunMode == .rebuildLines { allowed.insert(.backgroundColor) }
        var signature: ShapingSignature?
        var supported = true
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, stop in
            guard Set(attributes.keys).isSubset(of: allowed),
                  (attributes[.foregroundColor] as? UIColor) != nil,
                  attributes[.backgroundColor] == nil || attributes[.backgroundColor] is UIColor,
                  let font = attributes[.font] as? UIFont,
                  let ordinary = UIFont(name: "Menlo-Regular", size: font.pointSize),
                  font == ordinary || font == DefaultTheme.shared.font,
                  attributes[.ligature] == nil || (attributes[.ligature] as? NSNumber)?.doubleValue == 1,
                  (attributes[.kern] as? NSNumber)?.doubleValue == 0,
                  let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
                  Self.isStandardParagraph(paragraph) else {
                supported = false
                stop.pointee = true
                return
            }
            let current = ShapingSignature(font: font, paragraph: paragraph)
            if let signature, signature != current {
                supported = false
                stop.pointee = true
            } else {
                signature = current
            }
        }
        return supported ? signature : nil
    }

    private static func isStandardParagraph(_ paragraph: NSParagraphStyle) -> Bool {
        let interval = paragraph.defaultTabInterval
        guard interval.isFinite, interval > 0 else {
            return false
        }
        let expected = NSMutableParagraphStyle()
        expected.defaultTabInterval = interval
        expected.tabStops = (0 ..< 20).map { NSTextTab(textAlignment: .natural, location: CGFloat($0) * interval) }
        return paragraph == expected
    }
}

private func drawingTypesetter(_ source: NSAttributedString) -> CTTypesetter {
    // Match production's rendering adapter: token backgrounds are painted by
    // LineFragmentRenderer before overlays, not by CTLineDraw over overlays.
    var drawing: NSMutableAttributedString?
    source.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: source.length)) { value, range, _ in
        guard let value else {
            return
        }
        if drawing == nil { drawing = NSMutableAttributedString(attributedString: source) }
        drawing?.removeAttribute(.backgroundColor, range: range)
        drawing?.addAttribute(.tokenBackgroundColor, value: value, range: range)
    }
    return CTTypesetterCreateWithAttributedString(drawing ?? source)
}

private struct ShapingSignature: Equatable {
    let font: UIFont
    let paragraph: NSParagraphStyle
}

// Mirrors the production single-fragment operation, including its decrement and
// hidden-space conventions. Differential tests use fresh LineTypesetter, not this
// helper, as the oracle. No tokenizer or replacement line-break heuristic is used.
// swiftlint:disable:next function_parameter_count
private func nativeFragment(_ text: NSAttributedString, typesetter: CTTypesetter, configuration: LayoutConfiguration,
                            offset: Int, index: Int, yPosition: CGFloat) -> LineFragment {
    let suggester = LineBreakSuggester(
        lineBreakMode: .byWordWrapping, typesetter: typesetter, attributedString: text, constrainingWidth: configuration.width
    )
    var length = suggester.suggestLineBreak(startingAt: offset)
    var fragment: LineFragment
    repeat {
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: offset, length: length))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        fragment = LineFragment(id: LineFragmentID(lineId: "incremental-experiment", lineFragmentIndex: index),
                                index: index, visibleRange: NSRange(location: offset, length: length), line: line,
                                descent: descent, baseSize: CGSize(width: width, height: height),
                                scaledSize: CGSize(width: width, height: height * configuration.heightMultiplier), yPosition: yPosition)
        length -= 1
    } while fragment.scaledSize.width > configuration.width
    var next = offset + length + 1
    var hidden = 0
    while text.isWhitespaceCharacter(at: next) {
        hidden += 1
        next += 1
    }
    return fragment.withHiddenLength(hidden)
}
