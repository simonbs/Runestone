// Independent native oracle for the isolated prototype and real production typesetter.
// swiftlint:disable file_length

import CoreText
import Foundation
import QuartzCore
@testable import Runestone
import UIKit
import XCTest

@MainActor
// Keep prototype and real-production selectors beside their independent oracle.
// swiftlint:disable:next type_body_length
final class InteriorASCIIRunExperimentTests: XCTestCase {
    func testRunBoundariesAndFractionalWidthsMatchIndependentNative() throws {
        let payload = String(repeating: "AVoffice09Zflffi123", count: 250)
        for size in [CGFloat(13), 19.5] {
            for font in [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: size)),
                         UIFont.monospacedSystemFont(ofSize: size, weight: .regular)] {
                for wrapper in [("  \"", "\","), ("\"", "\""), ("    \"", "\",   ")] {
                    for ending in ["", "\n", "\r\n"] {
                        let text = interiorText(wrapper.0 + payload + wrapper.1 + ending, font: font)
                        let run = try XCTUnwrap(InteriorRunGate.range(in: text))
                        XCTAssertEqual(run, NSRange(location: wrapper.0.utf16.count, length: payload.utf16.count))
                        let native = CTTypesetterCreateWithAttributedString(text)
                        let boundary = CGFloat(CTLineGetTypographicBounds(
                            CTTypesetterCreateLine(native, CFRange(location: run.location + 1, length: 17)), nil, nil, nil))
                        for width in [boundary - 1 / 1_024, boundary, boundary + 1 / 1_024, 320.25] {
                            let layout = InteriorRunLayout(text, width: width, multiplier: 1.125)
                            layout.typeset(to: text.length)
                            XCTAssertGreaterThan(layout.clusterCount, 0)
                            XCTAssertGreaterThan(layout.nativeCount, 0)
                            XCTAssertTrue(layout.clusterRanges.allSatisfy { range in
                                range.location > run.location && range.upperBound < run.upperBound
                            })
                            try compare(layout.fragments, with: interiorFresh(text, width: width, heightMultiplier: 1.125),
                                        text: text, sparsePixels: true)
                        }
                    }
                }
            }
        }
    }

    /// Sequential wrapping does not visit every position next to either run boundary.
    func testArbitraryInteriorAndBoundaryOffsetsMatchNative() throws {
        let text = interiorText("  \"" + String(repeating: "officeAV09", count: 500) + "\",  ")
        let run = try XCTUnwrap(InteriorRunGate.range(in: text))
        let native = CTTypesetterCreateWithAttributedString(text)
        for offset in [0, run.location - 1, run.location, run.location + 1, run.location + 99,
                       run.upperBound - 33, run.upperBound - 2, run.upperBound, text.length - 3] {
            for count in [2, 7, 31] {
                let fitting = min(count, text.length - offset)
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: offset, length: fitting)), nil, nil, nil))
                let deltas: [CGFloat] = [-1 / 1_024, 0, 1 / 1_024]
                for delta in deltas {
                    let width = max(32, boundary + delta)
                    let layout = InteriorRunLayout(text, width: width)
                    let suggested = layout.suggestion(at: offset)
                    let expected = interiorNativeWordBreak(text, native: native, offset: offset, width: width)
                    let lhs = try XCTUnwrap(interiorFragment(text, native: native, offset: offset, length: suggested,
                                                             index: 0, y: 0, width: width, multiplier: 1))
                    let rhs = try XCTUnwrap(interiorFragment(text, native: native, offset: offset, length: expected,
                                                             index: 0, y: 0, width: width, multiplier: 1))
                    try compareFragment(lhs, rhs, text: text, includePixels: true)
                    if offset <= run.location || offset >= run.upperBound - 2 {
                        XCTAssertEqual(layout.clusterCount, 0)
                    }
                }
            }
        }
    }

    func testLateUnsupportedContentAndAttributesFallBack() throws {
        let payload = String(repeating: "a", count: 4_200)
        var fixtures = ["{\"p\":\"" + payload + "\"}",
                        "  \"" + payload + " ", "  \"" + payload + "\r",
                        payload + "\",\t", payload + "\", more", payload + "\\",
                        "  \"" + payload + "\\", " " + payload + "\"",
                        "let value_09 = " + payload + "; next_word 09",
                        "short words " + payload + " tail words", "_" + payload + "_",
                        "{\"p\":\"short\",\"n\":12}" + String(repeating: " small words", count: 450),
                        String(repeating: "short words ", count: 450),
                        String(repeating: "_", count: 65) + payload,
                        "  \"" + payload + "é\"}",
                        "  \"" + payload + "e\u{301}\"}",
                        "  \"" + payload + "👩‍💻\"}",
                        "  \"" + payload + "\t\"}",
                        "  \"" + payload + "\nmore\"}",
                        "  \"" + payload + "\u{0000}\"}",
                        "  \"" + payload + "\r\"}",
                        "  \"" + payload + String(repeating: " words", count: 800) + "\"}"]
            .map { interiorText($0) }
        for (key, value) in [(NSAttributedString.Key.kern, 0.25 as Any), (.ligature, 1 as Any),
                             (.baselineOffset, 2 as Any), (.backgroundColor, UIColor.yellow as Any),
                             (.font, UIFont.systemFont(ofSize: 17) as Any)] {
            let text = interiorText("  \"" + payload + "\",")
            text.addAttribute(key, value: value, range: NSRange(location: text.length - 4, length: 1))
            fixtures.append(text)
        }
        for text in fixtures {
            XCTAssertNil(InteriorRunGate.range(in: text))
            XCTAssertNil(UnbrokenLineBreakContext.make(for: text))
            let layout = InteriorRunLayout(text, width: 97.25)
            layout.typeset(to: text.length)
            XCTAssertEqual(layout.clusterCount, 0)
            XCTAssertGreaterThan(layout.nativeCount, 0)
            let expected = interiorFresh(text, width: 97.25)
            try compare(layout.fragments, with: expected, text: text, sparsePixels: true)
            let production = interiorPreparedProduction(text, width: 97.25)
            production.typesetLineFragments(toLocation: text.length)
            try compare(production.lineFragments, with: expected, text: text, sparsePixels: true)
        }
    }

    func testOwnedSnapshotsContinuationAppearanceAndEditRescoping() throws {
        let body = "  \"" + String(repeating: "AVoffice09", count: 500) + "\",  \r\n"
        let source = interiorText(body)
        let layout = InteriorRunLayout(source, width: 101.25)
        layout.typeset(to: 600)
        XCTAssertGreaterThan(layout.clusterCount, 0)
        source.replaceCharacters(in: NSRange(location: 10, length: 1), with: "é")
        layout.typeset(to: layout.text.length)
        try compare(layout.fragments, with: interiorFresh(interiorText(body), width: 101.25),
                    text: layout.text, sparsePixels: true)
        let edited = InteriorRunLayout(source, width: 101.25)
        XCTAssertNil(edited.run)
        edited.typeset(to: source.length)
        try compare(edited.fragments, with: interiorFresh(source, width: 101.25), text: source, sparsePixels: true)

        let colored = interiorText(body, color: .label)
        colored.addAttribute(.foregroundColor, value: UIColor.systemRed, range: NSRange(location: 150, length: 70))
        let partial = InteriorRunLayout(interiorText(body), width: 101.25)
        partial.typeset(to: 700)
        XCTAssertTrue(partial.refresh(colored, width: 101.25, multiplier: 1))
        var appearancePixels: [Data] = []
        for style in [UIUserInterfaceStyle.light, .dark] {
            var result: Result<Void, Error> = .success(())
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                result = Result {
                    XCTAssertTrue(partial.refresh(colored, width: 101.25, multiplier: 1))
                    partial.typeset(to: colored.length)
                    let expected = interiorFresh(colored, width: 101.25)
                    try compare(partial.fragments, with: expected, text: colored, sparsePixels: true)
                    appearancePixels.append(try pixels(XCTUnwrap(expected.first), text: colored))
                }
            }
            try result.get()
        }
        XCTAssertNotEqual(appearancePixels[0], appearancePixels[1], "The native control must exercise dynamic color.")
        XCTAssertFalse(partial.refresh(colored, width: 149.125, multiplier: 1.2))
        partial.typeset(to: colored.length)
        try compare(partial.fragments, with: interiorFresh(colored, width: 149.125, heightMultiplier: 1.2),
                    text: colored, sparsePixels: true)
        let fontChanged = interiorText(body, font: UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular))
        XCTAssertFalse(partial.refresh(fontChanged, width: 149.125, multiplier: 1.2))
        XCTAssertNotNil(partial.run)
        partial.typeset(to: fontChanged.length)
        try compare(partial.fragments, with: interiorFresh(fontChanged, width: 149.125, heightMultiplier: 1.2),
                    text: fontChanged, sparsePixels: true)
        let changed = interiorText("      " + body)
        XCTAssertFalse(partial.refresh(changed, width: 149.125, multiplier: 1.2))
        XCTAssertEqual(partial.run?.location, 6 + 3)
        partial.typeset(to: changed.length)
        try compare(partial.fragments, with: interiorFresh(changed, width: 149.125, heightMultiplier: 1.2),
                    text: changed, sparsePixels: true)
    }

    func testNarrowWidthsAndFailedSuggestionsRetainProductionProgress() throws {
        let text = interiorText("  \"" + String(repeating: "a", count: 4_200) + "\",\r\n")
        for width in [CGFloat(0.25), 31.5, 100.25] {
            let layout = InteriorRunLayout(text, width: width)
            layout.forceFailedCluster = width > 32
            layout.typeset(to: text.length)
            let production = LineTypesetter(lineID: "interior-experiment")
            production.constrainingWidth = width
            production.prepareToTypeset(text)
            production.typesetLineFragments(toLocation: text.length)
            XCTAssertEqual(layout.fragments.map(\.visibleRange), production.lineFragments.map(\.visibleRange))
            XCTAssertEqual(layout.fragments.map(\.hiddenLength), production.lineFragments.map(\.hiddenLength))
            XCTAssertEqual(layout.fragments.last?.range.upperBound, text.length)
            XCTAssertEqual(layout.clusterCount, 0)
        }
    }

    func testProductionQuotedRunAdmissionAndNativeParity() throws {
        let payload = String(repeating: "AVoffice09Zflffi123", count: 250)
        let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 10)),
                     try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 22)),
                     UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular), DefaultTheme.shared.font]
        let wrappers = [("  \"", "\","), ("\"", "\""), ("    \"", "\",   "), ("  \"", "\",")]
        for (index, font) in fonts.enumerated() {
            let wrapper = wrappers[index]
            for ending in ["", "\n", "\r\n"] {
                let text = interiorText(wrapper.0 + payload + wrapper.1 + ending, font: font,
                                        tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font))
                let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: text))
                let start = wrapper.0.utf16.count
                XCTAssertEqual(context.runRange, start ..< start + payload.utf16.count)
                XCTAssertEqual(context.bodyLength, text.length - ending.utf16.count)
                XCTAssertEqual(context.text, text)
                let native = CTTypesetterCreateWithAttributedString(text)
                let boundary = CGFloat(CTLineGetTypographicBounds(
                    CTTypesetterCreateLine(native, CFRange(location: start + 1, length: 17)), nil, nil, nil))
                let widths: [CGFloat] = [boundary - 1 / 1_024, boundary + 1 / 1_024, 320.25]
                for width in widths {
                    let production = interiorPreparedProduction(text, width: width, multiplier: 1.125)
                    production.typesetLineFragments(toLocation: text.length)
                    try compare(production.lineFragments, with: interiorFresh(text, width: width, heightMultiplier: 1.125),
                                text: text, sparsePixels: true)
                }
            }
        }
        let whole = interiorText(payload + "\r\n")
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: whole)).runRange, 0 ..< payload.utf16.count)
    }

    func testProductionQuotedContinuationAppearanceAndResetMatchNative() throws {
        let body = "  \"" + String(repeating: "officeAV09", count: 500) + "\",   \r\n"
        for style in [UIUserInterfaceStyle.light, .dark] {
            var result: Result<Void, Error> = .success(())
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                result = Result {
                    let initial = interiorText(body, color: .label)
                    XCTAssertNotNil(UnbrokenLineBreakContext.make(for: initial))
                    let production = interiorPreparedProduction(initial, width: 101.25)
                    production.typesetLineFragments(toLocation: 700)
                    let native = InteriorNativeOracle()
                    native.constrainingWidth = 101.25
                    native.prepareToTypeset(initial)
                    native.typesetLineFragments(toLocation: 700)
                    try compare(production.lineFragments, with: native.lineFragments, text: initial,
                                sparsePixels: true, complete: false)
                    let recolored = interiorText(body, color: .label)
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
                    try compare(production.lineFragments, with: recoloredPrefix, text: recolored, sparsePixels: true, complete: false)
                    let background = NSMutableAttributedString(attributedString: recolored)
                    background.addAttribute(.backgroundColor, value: UIColor.yellow, range: NSRange(location: 4_500, length: 20))
                    XCTAssertNil(UnbrokenLineBreakContext.make(for: background))
                    let prefix = production.lineFragments.map(\.visibleRange)
                    _ = production.refreshAppearance(background)
                    XCTAssertEqual(production.lineFragments.map(\.visibleRange), prefix)
                    production.typesetLineFragments(toLocation: background.length)
                    try compare(production.lineFragments, with: interiorFresh(background, width: 101.25),
                                text: background, sparsePixels: true)
                    production.reset()
                    production.constrainingWidth = 149.125
                    production.lineFragmentHeightMultiplier = 1.2
                    let newFont = interiorText(body, font: UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular))
                    XCTAssertNotNil(UnbrokenLineBreakContext.make(for: newFont))
                    production.prepareToTypeset(newFont)
                    production.typesetLineFragments(toLocation: newFont.length)
                    try compare(production.lineFragments, with: interiorFresh(newFont, width: 149.125, heightMultiplier: 1.2),
                                text: newFont, sparsePixels: true)
                }
            }
            try result.get()
        }
    }

    func testProductionQuotedSnapshotAndChangedRunScopeMatchNative() throws {
        let body = "  \"" + String(repeating: "officeAV09", count: 500) + "\",\n"
        let source = interiorText(body)
        let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: source))
        let production = interiorPreparedProduction(source, width: 101.25)
        production.typesetLineFragments(toLocation: 600)
        source.replaceCharacters(in: NSRange(location: 10, length: 1), with: "é")
        production.typesetLineFragments(toLocation: context.text.length)
        XCTAssertEqual(context.text.string, body)
        try compare(production.lineFragments, with: interiorFresh(context.text, width: 101.25),
                    text: context.text, sparsePixels: true)
        XCTAssertNil(UnbrokenLineBreakContext.make(for: source))
        production.reset()
        production.prepareToTypeset(source)
        production.typesetLineFragments(toLocation: source.length)
        try compare(production.lineFragments, with: interiorFresh(source, width: 101.25), text: source, sparsePixels: true)

        let rescope = interiorText("      " + body)
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: rescope)).runRange, 9 ..< 5_009)
        _ = production.reprepareToTypeset(rescope, previous: source, prefixLimit: 0)
        production.typesetLineFragments(toLocation: rescope.length)
        try compare(production.lineFragments, with: interiorFresh(rescope, width: 101.25), text: rescope, sparsePixels: true)
        let tailEdit = NSMutableAttributedString(attributedString: rescope)
        tailEdit.replaceCharacters(in: NSRange(location: tailEdit.length - 4, length: 1), with: "Z9")
        XCTAssertEqual(try XCTUnwrap(UnbrokenLineBreakContext.make(for: tailEdit)).runRange, 9 ..< 5_010)
        _ = production.reprepareToTypeset(tailEdit, previous: rescope, prefixLimit: tailEdit.length - 4)
        production.typesetLineFragments(toLocation: tailEdit.length)
        try compare(production.lineFragments, with: interiorFresh(tailEdit, width: 101.25), text: tailEdit, sparsePixels: true)
    }

    func testSplitDerivedPartialWrappersMatchPrototypeAndProductionNative() throws {
        let payload = String(repeating: "AVoffice09Zflffi123", count: 250)
        let fonts = [try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 13)),
                     UIFont.monospacedSystemFont(ofSize: 19.5, weight: .regular)]
        for font in fonts {
            for wrapper in [("  \"", ""), ("", "\",   ")] {
                for ending in ["", "\n", "\r\n"] {
                    let text = interiorText(wrapper.0 + payload + wrapper.1 + ending, font: font)
                    let run = try XCTUnwrap(InteriorRunGate.range(in: text))
                    let context = try XCTUnwrap(UnbrokenLineBreakContext.make(for: text))
                    XCTAssertEqual(run, NSRange(location: wrapper.0.utf16.count, length: payload.utf16.count))
                    XCTAssertEqual(context.runRange, run.location ..< run.upperBound)
                    XCTAssertFalse(context.run.allowsInitialOffset)
                    let native = CTTypesetterCreateWithAttributedString(text)
                    let boundary = CGFloat(CTLineGetTypographicBounds(
                        CTTypesetterCreateLine(native, CFRange(location: run.location + 1, length: 17)), nil, nil, nil))
                    let widths: [CGFloat] = [boundary - 1 / 1_024, boundary + 1 / 1_024, 320.25]
                    for width in widths {
                        let prototype = InteriorRunLayout(text, width: width)
                        _ = prototype.suggestion(at: run.location)
                        XCTAssertEqual(prototype.clusterCount, 0, "A partial wrapper's entry must stay native.")
                        prototype.typeset(to: text.length)
                        XCTAssertGreaterThan(prototype.clusterCount, 0)
                        XCTAssertGreaterThan(prototype.nativeCount, 0)
                        XCTAssertTrue(prototype.clusterRanges.allSatisfy { range in
                            range.location > run.location && range.upperBound < run.upperBound
                        })
                        let expected = interiorFresh(text, width: width)
                        try compare(prototype.fragments, with: expected, text: text, sparsePixels: true)
                        let production = interiorPreparedProduction(text, width: width)
                        production.typesetLineFragments(toLocation: text.length)
                        try compare(production.lineFragments, with: expected, text: text, sparsePixels: true)
                    }
                }
            }
        }
        let whole = interiorText(payload + "\r\n")
        XCTAssertTrue(try XCTUnwrap(UnbrokenLineBreakContext.make(for: whole)).run.allowsInitialOffset)
        let prototype = InteriorRunLayout(whole, width: 101.25)
        _ = prototype.suggestion(at: 0)
        XCTAssertEqual(prototype.clusterCount, 1, "Whole alphanumeric paragraphs retain offset-zero acceleration.")
    }

    // Opt-in paired timings include fresh gate, ownership and full CoreText shaping.
    // Keep balanced full/viewport timing and separate admission cost reporting together.
    // swiftlint:disable:next function_body_length
    func testPairedFullViewportAndAdmissionPerformance() throws {
        guard ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1" else {
            throw XCTSkip("Set RUNESTONE_PERFORMANCE=1 for paired timings")
        }
        let payload = String(repeating: "officeAV09", count: 6_000)
        let admitted = interiorText("  \"" + payload + "\",\n")
        let words = interiorText(String(repeating: "short words ", count: 5_000))
        let shortJSON = interiorText(String(repeating: "{\"p\":\"short\"}, ", count: 4_000))
        let unicode = interiorText("  \"" + payload + "é\",")
        let lateAttribute = interiorText(admitted.string)
        lateAttribute.addAttribute(.kern, value: 0.25, range: NSRange(location: lateAttribute.length - 2, length: 1))
        for (name, text) in [("admitted", admitted), ("words", words), ("shortJSON", shortJSON),
                             ("lateUnicode", unicode), ("lateAttribute", lateAttribute)] {
            for viewport in [true, false] {
                for iteration in 0 ..< 4 {
                    var samples: [String: Double] = [:]
                    for candidate in (iteration.isMultiple(of: 2) ? [true, false] : [false, true]) {
                        let start = CACurrentMediaTime()
                        if candidate {
                            let layout = InteriorRunLayout(text, width: 320.25)
                            if viewport {
                                layout.typeset(in: CGRect(x: 0, y: 0, width: 320.25, height: 600))
                            } else {
                                layout.typeset(to: text.length)
                            }
                            XCTAssertEqual(layout.run != nil, name == "admitted")
                            withExtendedLifetime(layout) {}
                        } else {
                            let native = InteriorNativeOracle()
                            native.constrainingWidth = 320.25
                            native.prepareToTypeset(text)
                            if viewport {
                                native.typesetLineFragments(in: CGRect(x: 0, y: 0, width: 320.25, height: 600))
                            } else {
                                native.typesetLineFragments(toLocation: text.length)
                            }
                            withExtendedLifetime(native) {}
                        }
                        samples[candidate ? "prototype" : "native"] = (CACurrentMediaTime() - start) * 1_000
                    }
                    print("INTERIOR_PAIRED fixture=\(name) viewport=\(viewport) iteration=\(iteration) ms=\(samples)")
                }
            }
            for iteration in 0 ..< 4 {
                let start = CACurrentMediaTime()
                let range = InteriorRunGate.range(in: text)
                let gated = CACurrentMediaTime()
                let owned = range == nil ? nil : interiorOwned(text)
                let copied = CACurrentMediaTime()
                print("INTERIOR_ADMISSION fixture=\(name) iteration=\(iteration) gate_ms=\((gated - start) * 1_000) "
                      + "snapshot_ms=\((copied - gated) * 1_000) admitted=\(range != nil)")
                withExtendedLifetime(owned) {}
            }
        }
    }
}

/// Probe <=64 prefix units plus 128 consecutive token units, before attribute
/// construction or a full scan. Only one dominant run is supported: >=4096 units,
/// starting <=64 units from the start and occupying >=90% of the body.
private enum InteriorRunGate {
    // A single admission pass keeps rejection order visible for cost review.
    // swiftlint:disable:next cyclomatic_complexity
    static func range(in input: NSAttributedString) -> NSRange? {
        guard input.length >= 4_096,
              let string = CFAttributedStringGetString(input),
              let bytes = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) else { return nil }
        var start = 0
        var candidate: Int?
        for index in 0 ..< min(input.length, 64 + 128) {
            if alphanumeric(bytes[index]) {
                if index - start + 1 >= 128 { candidate = start; break }
            } else {
                guard (32 ... 126).contains(bytes[index]) else {
                    return nil
                }
                start = index + 1
                if start > 64 {
                    return nil
                }
            }
        }
        guard let candidate, candidate <= 64 else {
            return nil
        }
        let first = input.attributes(at: 0, effectiveRange: nil)
        guard let font = first[.font] as? UIFont, (10 ... 22).contains(font.pointSize),
              font == UIFont(name: "Menlo-Regular", size: font.pointSize)
                || font == UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular),
              let paragraph = first[.paragraphStyle] as? NSParagraphStyle,
              paragraph.defaultTabInterval.isFinite, paragraph.defaultTabInterval > 0 else { return nil }
        var expected = interiorText("a", font: font, tabWidth: paragraph.defaultTabInterval).attributes(at: 0, effectiveRange: nil)
        expected.removeValue(forKey: .foregroundColor)
        guard supported(first, expected: expected) else {
            return nil
        }
        let terminal = bytes[input.length - 1] == 10 ? (bytes[input.length - 2] == 13 ? 2 : 1) : 0
        let bodyEnd = input.length - terminal
        var runEnd = candidate
        while runEnd < bodyEnd && alphanumeric(bytes[runEnd]) { runEnd += 1 }
        guard runEnd - candidate >= 4_096, runEnd - candidate >= bodyEnd - bodyEnd / 10,
              benchmarkWrapper(bytes, start: candidate, end: runEnd, bodyEnd: bodyEnd) else {
            return nil
        }
        // Prefix already passed the probe; validate the whole explicit length to
        // reject late Unicode, NUL, tabs, internal newlines and bare terminal CR.
        for index in 0 ..< bodyEnd where !(32 ... 126).contains(bytes[index]) { return nil }
        var accepted = true
        input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, _, stop in
            if !supported(attributes, expected: expected) { accepted = false; stop.pointee = true }
        }
        return accepted ? NSRange(location: candidate, length: runEnd - candidate) : nil
    }

    /// Benchmark wrapper or either one-sided wrapper produced by splitting it.
    /// ASCII spaces/opening quote and closing quote/comma/spaces are optional sides.
    /// JSON keys, code identifiers, underscores and adjacent words remain native.
    private static func benchmarkWrapper(_ bytes: UnsafePointer<CChar>, start: Int, end: Int, bodyEnd: Int) -> Bool {
        if start > 0 {
            guard bytes[start - 1] == 34 else {
                return false
            }
            for index in 0 ..< start - 1 where bytes[index] != 32 { return false }
        }
        if end == bodyEnd {
            return true
        }
        guard bytes[end] == 34 else {
            return false
        }
        var next = end + 1
        if next < bodyEnd, bytes[next] == 44 { next += 1 }
        while next < bodyEnd && bytes[next] == 32 { next += 1 }
        return next == bodyEnd
    }

    private static func alphanumeric(_ unit: CChar) -> Bool {
        (48 ... 57).contains(unit) || (65 ... 90).contains(unit) || (97 ... 122).contains(unit)
    }

    private static func supported(_ attributes: [NSAttributedString.Key: Any], expected: [NSAttributedString.Key: Any]) -> Bool {
        var actual = attributes
        guard actual.removeValue(forKey: .foregroundColor) is UIColor else {
            return false
        }
        if let ligature = actual.removeValue(forKey: .ligature) {
            guard let value = ligature as? NSNumber, value.doubleValue == 0 else {
                return false
            }
        }
        return (actual as NSDictionary).isEqual(to: expected)
    }
}

private func interiorAllowsInitialOffset(_ run: NSRange?, text: NSAttributedString) -> Bool {
    guard let run, run.location == 0 else {
        return false
    }
    let string = CFAttributedStringGetString(text)
    var bodyEnd = text.length
    if CFStringGetCharacterAtIndex(string, bodyEnd - 1) == 10 {
        bodyEnd -= CFStringGetCharacterAtIndex(string, bodyEnd - 2) == 13 ? 2 : 1
    }
    return run.upperBound == bodyEnd
}

private func interiorOwned(_ input: NSAttributedString) -> NSAttributedString {
    let copy = NSMutableAttributedString(string: input.string)
    input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, range, _ in
        var owned = attributes
        if let paragraph = owned[.paragraphStyle] as? NSParagraphStyle { owned[.paragraphStyle] = paragraph.copy() }
        copy.setAttributes(owned, range: range)
    }
    return NSAttributedString(attributedString: copy)
}

/// Full original paragraph is always shaped; only break suggestion changes.
/// Failed admission borrows production lifetime rules and performs no snapshot.
private final class InteriorRunLayout {
    private(set) var text: NSAttributedString
    private(set) var run: NSRange?
    private(set) var fragments: [LineFragment] = []
    private(set) var clusterCount = 0
    private(set) var nativeCount = 0
    private(set) var clusterRanges: [NSRange] = []
    var forceFailedCluster = false
    private var allowsInitialOffset: Bool
    private var native: CTTypesetter
    private var width: CGFloat
    private var multiplier: CGFloat
    private var production: LineTypesetter?

    init(_ input: NSAttributedString, width: CGFloat, multiplier: CGFloat = 1) {
        run = InteriorRunGate.range(in: input)
        allowsInitialOffset = interiorAllowsInitialOffset(run, text: input)
        text = run == nil ? input : interiorOwned(input)
        native = CTTypesetterCreateWithAttributedString(interiorDrawingText(text))
        self.width = width
        self.multiplier = multiplier
    }

    func suggestion(at offset: Int) -> Int {
        if let run, allowsInitialOffset || offset > run.location, offset < run.upperBound,
           width.isFinite, width >= 32, multiplier.isFinite, multiplier > 0 {
            let length = forceFailedCluster ? 0 : CTTypesetterSuggestClusterBreak(native, offset, Double(width))
            if length > 0, length < run.upperBound - offset {
                clusterCount += 1
                clusterRanges.append(NSRange(location: offset, length: length))
                return length
            }
            if length <= 0 { self.run = nil }
        }
        nativeCount += 1
        return interiorNativeWordBreak(text, native: native, offset: offset, width: width)
    }

    func typeset(in rect: CGRect) {
        while (fragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0) < rect.maxY {
            let offset = fragments.last?.range.upperBound ?? 0
            guard offset < text.length else {
                return
            }
            typeset(to: offset + 1)
            guard (fragments.last?.range.upperBound ?? 0) > offset else {
                return
            }
        }
    }

    func typeset(to target: Int) {
        if production != nil {
            continueProduction(to: target)
            return
        }
        guard width.isFinite, width >= 32, multiplier.isFinite, multiplier > 0 else {
            resetToProduction(to: target)
            return
        }
        var offset = fragments.last?.range.upperBound ?? 0
        var y = fragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        while offset < min(target, text.length) {
            let length = suggestion(at: offset)
            guard let fragment = interiorFragment(text, native: native, offset: offset, length: length,
                                                  index: fragments.count, y: y, width: width, multiplier: multiplier) else {
                resetToProduction(to: target)
                return
            }
            fragments.append(fragment)
            offset = fragment.range.upperBound
            y += fragment.scaledSize.height
        }
    }

    /// Appearance reuse requires exact text and all layout attributes to match.
    /// A fresh gate runs once per replacement, never once per fragment.
    func refresh(_ input: NSAttributedString, width: CGFloat, multiplier: CGFloat) -> Bool {
        let retain = width == self.width && multiplier == self.multiplier
            && Self.layoutText(input).isEqual(to: Self.layoutText(text))
        run = InteriorRunGate.range(in: input)
        allowsInitialOffset = interiorAllowsInitialOffset(run, text: input)
        text = run == nil ? input : interiorOwned(input)
        native = CTTypesetterCreateWithAttributedString(interiorDrawingText(text))
        self.width = width
        self.multiplier = multiplier
        production = nil
        clusterCount = 0
        nativeCount = 0
        clusterRanges = []
        if retain {
            fragments = fragments.map { fragment in
                let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
                return fragment.withLine(CTTypesetterCreateLine(native, range))
            }
        } else {
            fragments = []
        }
        return retain
    }

    private static func layoutText(_ input: NSAttributedString) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: input)
        copy.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: copy.length))
        return copy
    }

    private func resetToProduction(to target: Int) {
        let production = LineTypesetter(lineID: "interior-experiment")
        production.constrainingWidth = width
        production.lineFragmentHeightMultiplier = multiplier
        production.prepareToTypeset(text)
        self.production = production
        clusterCount = 0
        clusterRanges = []
        continueProduction(to: target)
    }

    private func continueProduction(to target: Int) {
        production?.typesetLineFragments(toLocation: target)
        fragments = production?.lineFragments ?? []
    }
}

/// Match production background extraction. The baseline independently shapes and
/// breaks these drawing attributes without entering production LineTypesetter.
private func interiorDrawingText(_ text: NSAttributedString) -> NSAttributedString {
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

private func interiorText(_ string: String, font: UIFont? = nil, explicitLigature: Bool = false,
                          color: UIColor = .black, tabWidth: CGFloat = 40) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(string: string)
    DefaultStringAttributes(textColor: color, font: font ?? UIFont(name: "Menlo-Regular", size: 17)!,
                            kern: 0, tabWidth: tabWidth).apply(to: result)
    if explicitLigature {
        result.addAttribute(.ligature, value: 0, range: NSRange(location: 0, length: result.length))
    }
    return result
}

private func interiorPreparedProduction(_ text: NSAttributedString, width: CGFloat, multiplier: CGFloat = 1) -> LineTypesetter {
    let production = LineTypesetter(lineID: "interior-experiment")
    production.constrainingWidth = width
    production.lineFragmentHeightMultiplier = multiplier
    production.prepareToTypeset(text)
    return production
}

private func interiorFresh(_ text: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1) -> [LineFragment] {
    let native = InteriorNativeOracle()
    native.constrainingWidth = width
    native.lineFragmentHeightMultiplier = heightMultiplier
    native.prepareToTypeset(text)
    native.typesetLineFragments(toLocation: text.length)
    return native.lineFragments
}

/// Frozen native baseline: no production LineTypesetter/LineBreakSuggester and no
/// cluster fast path. Only ordinary-width cases use this legacy truncation oracle;
/// pathological progress behavior has separate contract tests, never a hanging baseline.
private final class InteriorNativeOracle {
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
        native = CTTypesetterCreateWithAttributedString(interiorDrawingText(text))
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
            let length = interiorNativeWordBreak(text, native: native, offset: offset, width: constrainingWidth)
            guard let fragment = interiorFragment(text, native: native, offset: offset, length: length,
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
private func interiorNativeWordBreak(_ text: NSAttributedString, native: CTTypesetter,
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
private func interiorFragment(_ text: NSAttributedString, native: CTTypesetter, offset: Int, length: Int,
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
            let fragment = LineFragment(id: LineFragmentID(lineId: "interior-experiment", lineFragmentIndex: index),
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

extension InteriorASCIIRunExperimentTests {
    private func compare(_ actual: [LineFragment], with expected: [LineFragment], text: NSAttributedString,
                         sparsePixels: Bool = false, complete: Bool = true) throws {
        XCTAssertEqual(actual.count, expected.count)
        guard actual.count == expected.count else { throw InteriorMismatch.fragmentCount }
        if complete {
            XCTAssertEqual(actual.last?.range.upperBound ?? 0, text.length)
        } else {
            XCTAssertLessThanOrEqual(actual.last?.range.upperBound ?? 0, text.length)
        }
        for (index, pair) in zip(actual, expected).enumerated() {
            try compareFragment(pair.0, pair.1, text: text,
                                includePixels: !sparsePixels || index <= 1 || index == actual.count / 2 || index >= actual.count - 2)
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
            throw InteriorMismatch.fragmentRange
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
        let delegate = InteriorFragmentText(text.attributedSubstring(from: fragment.visibleRange).string)
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

private final class InteriorFragmentText: LineFragmentRendererDelegate {
    let contents: String
    init(_ contents: String) { self.contents = contents }
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? { contents }
}

private enum InteriorMismatch: Error {
    case invalidJSONEncoding
    case fragmentCount
    case fragmentRange
}
