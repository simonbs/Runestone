#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class TextFinderPresentationColorsTests: XCTestCase {
    func testReadableResultsAcrossLightDarkAndColoredThemesInEitherSystemAppearance() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            appearance.performAsCurrentDrawingAppearance {
                for red in stride(from: 0.0, through: 1.0, by: 0.2) {
                    for green in stride(from: 0.0, through: 1.0, by: 0.2) {
                        for blue in stride(from: 0.0, through: 1.0, by: 0.2) {
                            let background = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
                            let colors = TextFinderPresentationColors(editorBackground: background)
                            XCTAssertGreaterThanOrEqual(contrast(colors.matchForeground, colors.matchBackground), 4.5)
                            XCTAssertGreaterThanOrEqual(contrast(colors.selectedForeground, colors.selectedBackground), 4.5)
                            XCTAssertNotEqual(colors.matchBackground, colors.selectedBackground)
                            XCTAssertEqual(colors.matchBackground.alphaComponent, 1)
                        }
                    }
                }
            }
        }
    }

    func testResultFillFollowsThemeRatherThanSystemAppearance() {
        let light = TextFinderPresentationColors(editorBackground: .white)
        let dark = TextFinderPresentationColors(editorBackground: .black)
        let colored = TextFinderPresentationColors(editorBackground: NSColor(srgbRed: 0.1, green: 0.15, blue: 0.35, alpha: 1))
        XCTAssertEqual(light.matchForeground, .black)
        XCTAssertEqual(dark.matchForeground, .white)
        XCTAssertNotEqual(light.matchBackground, dark.matchBackground)
        XCTAssertNotEqual(colored.matchBackground, dark.matchBackground)
        for alpha in [0.0, 0.5, 1.0] {
            let transparent = TextFinderPresentationColors(editorBackground: NSColor(srgbRed: 0.5, green: 0.1, blue: 0.7, alpha: alpha))
            XCTAssertEqual(transparent.matchBackground.alphaComponent, 1)
            XCTAssertGreaterThanOrEqual(contrast(transparent.matchForeground, transparent.matchBackground), 4.5)
        }
    }

    private func contrast(_ first: NSColor, _ second: NSColor) -> CGFloat {
        func luminance(_ color: NSColor) -> CGFloat {
            let color = color.usingColorSpace(.sRGB)!
            let channels = [color.redComponent, color.greenComponent, color.blueComponent].map {
                $0 > 0.04045 ? pow(($0 + 0.055) / 1.055, 2.4) : $0 / 12.92
            }
            return zip(channels, [CGFloat(0.2126), 0.7152, 0.0722]).map(*).reduce(0, +)
        }
        let values = [luminance(first), luminance(second)]
        return (values.max()! + 0.05) / (values.min()! + 0.05)
    }
}
#endif
