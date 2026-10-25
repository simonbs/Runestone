@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

final class DefaultThemeTests: XCTestCase {
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
                let language = TreeSitterLanguage(tree_sitter_javascript())
                let state = TextViewState(text: "value", language: language)
                let highlighter = StringSyntaxHighlighter(theme: state.theme, language: language)
                let highlighted = highlighter.syntaxHighlight("value")
                guard let color = highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor else {
                    XCTFail("Default highlighting must provide a foreground color")
                    completed.fulfill()
                    return
                }
                let independentTheme = DefaultTheme()
                XCTAssertEqual(color.resolvedColor(with: light), independentTheme.textColor.resolvedColor(with: light))
                XCTAssertEqual(color.resolvedColor(with: dark), independentTheme.textColor.resolvedColor(with: dark))
                XCTAssertNotEqual(color.resolvedColor(with: light), color.resolvedColor(with: dark))
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
