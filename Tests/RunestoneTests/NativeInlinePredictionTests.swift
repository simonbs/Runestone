import CoreText
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class NativeInlinePredictionTests: XCTestCase {
    func testPredictionTraitFollowsSettingWithoutChangingAccentComposition() throws {
        let pair = try Pair()
        XCTAssertEqual(pair.input.inlinePredictionType, .no)
        XCTAssertEqual((pair.input as UITextInput).inlinePredictionType, .no)
        pair.editor.isInlinePredictionEnabled = true
        XCTAssertEqual(pair.input.inlinePredictionType, .default)
        pair.input.setMarkedText("¨", selectedRange: NSRange(location: 1, length: 0))
        pair.editor.isInlinePredictionEnabled = false
        XCTAssertEqual(pair.input.inlinePredictionType, .no)
        XCTAssertEqual(pair.editor.text, "¨")
        XCTAssertNotNil(pair.editor.markedTextRange)
        pair.input.insertText("ü")
        XCTAssertEqual(pair.editor.text, "ü")
        XCTAssertNil(pair.editor.markedTextRange)
    }

    func testWordAndSentenceAttributedCallbacksMatchNativeTextAndSelection() throws {
        for size in [CGFloat(13), 23] {
            for color in [UIColor.black, .white, .systemPurple] {
                let pair = try Pair(font: .monospacedSystemFont(ofSize: size, weight: .regular), color: color)
                for suggestion in ["doing", "doing today? I hope you are well.", "doing 😀\nA new paragraph."] {
                    pair.reset("Hello ")
                    let supplied = NSMutableAttributedString(string: suggestion)
                    supplied.addAttributes([.foregroundColor: UIColor.systemGray, .backgroundColor: UIColor.clear],
                                           range: NSRange(location: 1, length: supplied.length - 1))
                    pair.native.setAttributedMarkedText(supplied, selectedRange: NSRange(location: 1, length: 0))
                    pair.input.setAttributedMarkedText(supplied, selectedRange: NSRange(location: 1, length: 0))
                    pair.assertState()
                    let full = IndexedRange(location: 0, length: pair.editor.text.utf16.count)
                    let attributes = pair.input.attributedText(in: full)
                    XCTAssertEqual(attributes.attribute(.font, at: 7, effectiveRange: nil) as? UIFont, pair.font)
                    XCTAssertEqual(attributes.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? UIColor, color)
                    XCTAssertEqual(attributes.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor, .systemGray)
                    XCTAssertEqual(attributes.attribute(.backgroundColor, at: 7, effectiveRange: nil) as? UIColor, .clear)
                    pair.native.insertText(suggestion)
                    pair.input.insertText(suggestion)
                    pair.assertState()
                    XCTAssertNil(pair.editor.markedTextRange)
                    let committed = pair.input.attributedText(in: IndexedRange(location: 0, length: pair.editor.text.utf16.count))
                    XCTAssertEqual(committed.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor, color)
                    XCTAssertNil(committed.attribute(.backgroundColor, at: 7, effectiveRange: nil))
                }
            }
        }
    }

    func testDeadKeyAndMultistageIMECallbacksMatchNativeTextView() throws {
        let pair = try Pair()
        for stages in [["¨", "ü"], ["に", "日本", "日本語"], ["ㅎ", "하", "한"], ["e\u{301}"]] {
            pair.reset("prefix ")
            for stage in stages {
                let selection = NSRange(location: stage.utf16.count, length: 0)
                pair.native.setMarkedText(stage, selectedRange: selection)
                pair.input.setMarkedText(stage, selectedRange: selection)
                pair.assertState()
                let styled = pair.input.attributedText(in: IndexedRange(location: 7, length: stage.utf16.count))
                XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, pair.color)
                XCTAssertNil(styled.attribute(.backgroundColor, at: 0, effectiveRange: nil))
            }
            pair.native.unmarkText()
            pair.input.unmarkText()
            pair.assertState()
        }
    }

    func testAttributedIMEStylesAreHonoredWithoutGuessingPredictionColors() throws {
        let pair = try Pair()
        pair.reset("test ")
        let marked = NSAttributedString(string: "日本語", attributes: [
            .foregroundColor: UIColor.systemRed, .backgroundColor: UIColor.systemYellow, .underlineStyle: 1
        ])
        pair.native.setAttributedMarkedText(marked, selectedRange: NSRange(location: 1, length: 1))
        pair.input.setAttributedMarkedText(marked, selectedRange: NSRange(location: 1, length: 1))
        pair.assertState()
        let styled = pair.input.attributedText(in: IndexedRange(location: 5, length: 3))
        XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .systemRed)
        XCTAssertEqual(styled.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor, .systemYellow)
        XCTAssertEqual(styled.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, 1)
    }

    func testPlainCompositionFollowingAttributedPredictionRestoresTheme() throws {
        let pair = try Pair()
        pair.reset("a ")
        let suggestion = NSAttributedString(string: "wonderful day", attributes: [.foregroundColor: UIColor.systemGray, .backgroundColor: UIColor.clear])
        pair.input.setAttributedMarkedText(suggestion, selectedRange: NSRange(location: 0, length: 0))
        pair.native.setAttributedMarkedText(suggestion, selectedRange: NSRange(location: 0, length: 0))
        pair.input.setMarkedText("¨", selectedRange: NSRange(location: 1, length: 0))
        pair.native.setMarkedText("¨", selectedRange: NSRange(location: 1, length: 0))
        pair.assertState()
        let styled = pair.input.attributedText(in: IndexedRange(location: 2, length: 1))
        XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, pair.color)
        XCTAssertNil(styled.attribute(.backgroundColor, at: 0, effectiveRange: nil))
        pair.input.insertText("ü")
        pair.native.insertText("ü")
        pair.assertState()
    }

    func testClearingAttributedMarkedTextMatchesNativeAndRemovesDecorations() throws {
        let pair = try Pair()
        pair.reset("before after")
        pair.editor.selectedRange = NSRange(location: 7, length: 5)
        pair.native.selectedRange = NSRange(location: 7, length: 5)
        let marked = NSAttributedString(string: "replacement", attributes: [.foregroundColor: UIColor.systemGray, .backgroundColor: UIColor.clear])
        pair.input.setAttributedMarkedText(marked, selectedRange: NSRange(location: 3, length: 0))
        pair.native.setAttributedMarkedText(marked, selectedRange: NSRange(location: 3, length: 0))
        pair.assertState()
        pair.input.setAttributedMarkedText(nil, selectedRange: NSRange(location: 0, length: 0))
        pair.native.setAttributedMarkedText(NSAttributedString(string: ""), selectedRange: NSRange(location: 0, length: 0))
        pair.assertState()
    }

    func testRenderedPredictionFragmentsDoNotAcquireIMEBackground() throws {
        let pair = try Pair()
        let controller = UIViewController()
        controller.view.addSubview(pair.editor)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        pair.reset("Hello ")
        let supplied = NSAttributedString(string: "doing today? I hope you are well.", attributes: [
            .foregroundColor: UIColor.systemGray, .backgroundColor: UIColor.clear
        ])
        pair.input.setAttributedMarkedText(supplied, selectedRange: NSRange(location: 0, length: 0))
        pair.editor.layoutIfNeeded()
        pair.input.layoutLines(toLocation: pair.editor.text.utf16.count)
        pair.input.layoutIfNeeded()
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let renderers = descendants(pair.input).compactMap { ($0 as? LineFragmentView)?.renderer }
        XCTAssertFalse(renderers.isEmpty)
        for renderer in renderers {
            XCTAssertNil(renderer.markedRange, "Attributed marked text owns its background; theme IME highlighting must not leak in")
        }
        let hasGhostRun = renderers.flatMap { CTLineGetGlyphRuns($0.lineFragment.line) as? [CTRun] ?? [] }.contains { run in
            (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.foregroundColor] as? UIColor == .systemGray
        }
        XCTAssertTrue(hasGhostRun, "The rendered Core Text lines must preserve UIKit's ghost foreground")
    }

    func testThemeChangesDuringMarkedInputPreserveGhostAndRefreshTypingDefaults() throws {
        let pair = try Pair()
        pair.reset("")
        let supplied = NSMutableAttributedString(string: "doing")
        supplied.addAttributes([.font: pair.font, .foregroundColor: pair.color], range: NSRange(location: 0, length: 1))
        supplied.addAttributes([.font: pair.font, .foregroundColor: UIColor.systemGray, .backgroundColor: UIColor.clear],
                               range: NSRange(location: 1, length: 4))
        pair.input.setAttributedMarkedText(supplied, selectedRange: NSRange(location: 1, length: 0))
        let font = UIFont.systemFont(ofSize: 25, weight: .medium)
        pair.editor.theme = PredictionTheme(font: font, textColor: .white)
        let text = pair.input.attributedText(in: IndexedRange(location: 0, length: 5))
        XCTAssertEqual(text.attribute(.font, at: 1, effectiveRange: nil) as? UIFont, font)
        XCTAssertEqual(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .white)
        XCTAssertEqual(text.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, .systemGray)
    }

    func testReplacingDocumentTextClearsMarkedPresentationLikeUIKit() throws {
        let pair = try Pair()
        pair.reset("prefix ")
        let marked = NSAttributedString(string: "predicted phrase", attributes: [.foregroundColor: UIColor.systemGray])
        pair.native.setAttributedMarkedText(marked, selectedRange: NSRange(location: 0, length: 0))
        pair.input.setAttributedMarkedText(marked, selectedRange: NSRange(location: 0, length: 0))
        pair.native.text = "new document"
        pair.editor.text = "new document"
        XCTAssertEqual(pair.editor.text, pair.native.text)
        XCTAssertNil(pair.editor.markedTextRange)
        XCTAssertNil(pair.native.markedTextRange)
        let styled = pair.input.attributedText(in: IndexedRange(location: 0, length: 12))
        XCTAssertEqual(styled.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor, pair.color)
    }

    private final class Pair {
        let editor: TextView
        let input: TextInputView
        let native: UITextView
        let font: UIFont
        let color: UIColor

        init(font: UIFont = .monospacedSystemFont(ofSize: 17, weight: .regular), color: UIColor = .black) throws {
            self.font = font
            self.color = color
            editor = TextView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
            editor.theme = PredictionTheme(font: font, textColor: color)
            editor.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            input = try XCTUnwrap(editor.subviews.compactMap { $0 as? TextInputView }.first)
            native = UITextView(frame: editor.frame)
            native.font = font
            native.textColor = color
            native.textContainerInset = editor.textContainerInset
            native.textContainer.lineFragmentPadding = 0
            native.inlinePredictionType = .no
            native.autocorrectionType = .no
            reset("")
        }

        func reset(_ text: String) {
            input.unmarkText()
            native.unmarkText()
            editor.text = text
            native.text = text
            native.font = font
            native.textColor = color
            editor.selectedRange = NSRange(location: text.utf16.count, length: 0)
            native.selectedRange = editor.selectedRange
        }

        func assertState(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(editor.text, native.text, file: file, line: line)
            XCTAssertEqual(editor.selectedRange, native.selectedRange, file: file, line: line)
            let nativeMarked = native.markedTextRange.map {
                NSRange(location: native.offset(from: native.beginningOfDocument, to: $0.start),
                        length: native.offset(from: $0.start, to: $0.end))
            }
            XCTAssertEqual((editor.markedTextRange as? IndexedRange)?.range, nativeMarked, file: file, line: line)
        }
    }
}

private final class PredictionTheme: Theme {
    let font: UIFont
    let textColor: UIColor
    init(font: UIFont, textColor: UIColor) { self.font = font; self.textColor = textColor }
    let gutterBackgroundColor = UIColor.clear
    let gutterHairlineColor = UIColor.gray
    let lineNumberColor = UIColor.gray
    var lineNumberFont: UIFont { font }
    let selectedLineBackgroundColor = UIColor.clear
    let selectedLinesLineNumberColor = UIColor.gray
    let selectedLinesGutterBackgroundColor = UIColor.clear
    let invisibleCharactersColor = UIColor.gray
    let pageGuideHairlineColor = UIColor.gray
    let pageGuideBackgroundColor = UIColor.clear
    let markedTextBackgroundColor = UIColor.systemYellow
    func textColor(for highlightName: String) -> UIColor? { nil }
}
