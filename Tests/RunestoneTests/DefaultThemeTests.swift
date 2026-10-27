@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

final class DefaultThemeTests: XCTestCase {
    // Preserve the original asset mapping and keep colors dynamic when a theme
    // created in one appearance is used in another.
    func testTokenPalettePreservesAssetsFallbacksAndFontTraits() throws {
        let palette = [
            ("comment", "comment"),
            ("constant.builtin", "constant_builtin"),
            ("constant.character", "constant_character"),
            ("constructor", "constructor"),
            ("function", "function"),
            ("keyword", "keyword"),
            ("number", "number"),
            ("operator", "operator"),
            ("property", "property"),
            ("punctuation", "punctuation"),
            ("string", "string"),
            ("type", "type"),
            ("variable.builtin", "variable_builtin")
        ]
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for (name, asset) in palette {
            let expected = try XCTUnwrap(UIColor(named: "theme_" + asset, in: .module, compatibleWith: nil))
            for creationTraits in [light, dark] {
                creationTraits.performAsCurrent {
                    let theme = DefaultTheme()
                    // Dotted descendants inherit their nearest supported ancestor;
                    // empty path components are ignored by the existing name parser.
                    for capture in [name, name + ".specialized.deep", "." + name + "..specialized."] {
                        guard let actual = theme.textColor(for: capture) else {
                            XCTFail("Missing color for \(capture)")
                            continue
                        }
                        XCTAssertEqual(theme.fontTraits(for: capture), name == "keyword" ? .bold : [], capture)
                        XCTAssertNil(theme.font(for: capture), capture)
                        for style in [light, dark] {
                            for contrast in [UIAccessibilityContrast.normal, .high] {
                                let traits: UITraitCollection
                                if #available(iOS 17.0, *) {
                                    traits = UITraitCollection { traits in
                                        traits.userInterfaceStyle = style.userInterfaceStyle
                                        traits.accessibilityContrast = contrast
                                    }
                                } else {
                                    traits = UITraitCollection(traitsFrom: [
                                        style, UITraitCollection(accessibilityContrast: contrast)
                                    ])
                                }
                                XCTAssertEqual(actual.resolvedColor(with: traits), expected.resolvedColor(with: traits), capture)
                            }
                        }
                    }
                }
            }
        }
    }

    func testUnsupportedAndUnstyledTokenNamesRemainUnstyled() {
        let theme = DefaultTheme()
        for name in ["", ".", "unknown", "unknown.keyword", "constant", "constant.unknown", "Keyword",
                     "variable", "variable.member", "variable.unknown.deep"] {
            XCTAssertNil(theme.textColor(for: name), name)
            XCTAssertNil(theme.font(for: name), name)
            XCTAssertEqual(theme.fontTraits(for: name), [], name)
        }
    }

    func testDefaultTextViewAppearanceAndThemeChanges() throws {
        let view = TextView()
        let inputView = try XCTUnwrap(descendants(of: view).compactMap { $0 as? TextInputView }.first)
        let gutter = try XCTUnwrap(descendants(of: view).compactMap { $0 as? GutterBackgroundView }.first)
        assertAppearance(of: inputView, gutter: gutter, theme: DefaultTheme.shared)

        let customTheme = CustomTheme()
        view.theme = customTheme
        assertAppearance(of: inputView, gutter: gutter, theme: customTheme)

        view.theme = DefaultTheme.shared
        assertAppearance(of: inputView, gutter: gutter, theme: DefaultTheme.shared)
    }

    func testLayoutManagerInitializesInvisibleCharactersAndUpdatesTheirTheme() {
        let stringView = StringView(string: "hello")
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let configuration = InvisibleCharacterConfiguration()
        let highlights = HighlightService(lineManager: lineManager)
        let factory = LineControllerFactory(stringView: stringView, highlightService: highlights,
                                            invisibleCharacterConfiguration: configuration)
        let storage = LineControllerStorage(stringView: stringView, lineControllerFactory: factory)
        let gutterWidth = GutterWidthService(lineManager: lineManager)
        let contentSize = ContentSizeService(lineManager: lineManager, lineControllerStorage: storage,
                                             gutterWidthService: gutterWidth, invisibleCharacterConfiguration: configuration)
        let caretRects = CaretRectService(stringView: stringView, lineManager: lineManager,
                                          lineControllerStorage: storage, gutterWidthService: gutterWidth)
        let selectionRects = SelectionRectService(lineManager: lineManager, contentSizeService: contentSize,
                                                  gutterWidthService: gutterWidth, caretRectService: caretRects)
        let manager = LayoutManager(lineManager: lineManager, languageMode: PlainTextInternalLanguageMode(),
                                    stringView: stringView, lineControllerStorage: storage, contentSizeService: contentSize,
                                    gutterWidthService: gutterWidth, caretRectService: caretRects,
                                    selectionRectService: selectionRects, highlightService: highlights,
                                    invisibleCharacterConfiguration: configuration)
        XCTAssertEqual(configuration.font, DefaultTheme.shared.font)
        XCTAssertEqual(configuration.textColor, DefaultTheme.shared.invisibleCharactersColor)

        let customTheme = CustomTheme()
        manager.theme = customTheme
        XCTAssertEqual(configuration.font, customTheme.font)
        XCTAssertEqual(configuration.textColor, customTheme.invisibleCharactersColor)
        manager.theme = DefaultTheme.shared
        XCTAssertEqual(configuration.font, DefaultTheme.shared.font)
        XCTAssertEqual(configuration.textColor, DefaultTheme.shared.invisibleCharactersColor)
    }

    func testBackgroundDefaultHighlightingPreservesDynamicColors() {
        let completed = expectation(description: "Background highlighting")
        DispatchQueue.global(qos: .userInitiated).async {
            let light = UITraitCollection(userInterfaceStyle: .light)
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            light.performAsCurrent {
                let language = TreeSitterLanguage(tree_sitter_javascript(),
                                                  highlightsQuery: .init(string: "(identifier) @keyword"))
                let state = TextViewState(text: "value;", language: language)
                let highlighter = StringSyntaxHighlighter(theme: state.theme, language: language)
                let highlighted = highlighter.syntaxHighlight("value;")
                guard let color = highlighted.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor,
                      let tokenColor = highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                      let expectedTokenColor = UIColor(named: "theme_keyword", in: .module, compatibleWith: nil),
                      let tokenFont = highlighted.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
                    XCTFail("Default highlighting must provide a foreground color")
                    completed.fulfill()
                    return
                }
                let independentTheme = DefaultTheme()
                XCTAssertEqual(color.resolvedColor(with: light), independentTheme.textColor.resolvedColor(with: light))
                XCTAssertEqual(color.resolvedColor(with: dark), independentTheme.textColor.resolvedColor(with: dark))
                XCTAssertNotEqual(color.resolvedColor(with: light), color.resolvedColor(with: dark))
                XCTAssertEqual(tokenColor.resolvedColor(with: light), expectedTokenColor.resolvedColor(with: light))
                XCTAssertEqual(tokenColor.resolvedColor(with: dark), expectedTokenColor.resolvedColor(with: dark))
                XCTAssertNotEqual(tokenColor.resolvedColor(with: light), tokenColor.resolvedColor(with: dark))
                XCTAssertTrue(tokenFont.fontDescriptor.symbolicTraits.contains(.traitBold))
                XCTAssertEqual(tokenFont.pointSize, independentTheme.font.pointSize)
            }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 10)
    }

    private func assertAppearance(of inputView: TextInputView, gutter: GutterBackgroundView, theme: Theme,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(gutter.backgroundColor, theme.gutterBackgroundColor, file: file, line: line)
        XCTAssertEqual(gutter.hairlineColor, theme.gutterHairlineColor, file: file, line: line)
        XCTAssertEqual(gutter.hairlineWidth, theme.gutterHairlineWidth, file: file, line: line)
        XCTAssertTrue(inputView.subviews.contains { $0.backgroundColor == theme.selectedLineBackgroundColor }, file: file, line: line)
        XCTAssertTrue(gutter.superview?.subviews.contains { $0.backgroundColor == theme.selectedLinesGutterBackgroundColor } == true,
                      file: file, line: line)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

private final class CustomTheme: Theme {
    let font: UIFont = .systemFont(ofSize: 23)
    let textColor: UIColor = .brown
    let gutterBackgroundColor: UIColor = .cyan
    let gutterHairlineColor: UIColor = .magenta
    let gutterHairlineWidth: CGFloat = 3
    let lineNumberColor: UIColor = .blue
    let lineNumberFont: UIFont = .systemFont(ofSize: 19)
    let selectedLineBackgroundColor: UIColor = .orange
    let selectedLinesLineNumberColor: UIColor = .red
    let selectedLinesGutterBackgroundColor: UIColor = .purple
    let invisibleCharactersColor: UIColor = .green
    let pageGuideHairlineColor: UIColor = .gray
    let pageGuideBackgroundColor: UIColor = .lightGray
    let markedTextBackgroundColor: UIColor = .yellow

    func textColor(for highlightName: String) -> UIColor? {
        nil
    }
}
