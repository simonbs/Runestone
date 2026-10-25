import UIKit

/// Kept independent of the SDK so existing clients can build with older Xcode releases.
protocol WritingToolsControlling: AnyObject {
    func stop()
    func layoutDidChange()
}

enum WritingToolsRange {
    static func isValid(_ range: NSRange, in string: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= string.length,
              range.length <= string.length - range.location else {
                  return false
              }
        // UTF-16 offsets may separate composed characters, but must never split a surrogate pair.
        for offset in [range.location, range.location + range.length] where offset > 0 && offset < string.length {
            let previous = string.character(at: offset - 1)
            let next = string.character(at: offset)
            if (0xD800...0xDBFF).contains(previous) && (0xDC00...0xDFFF).contains(next) {
                return false
            }
        }
        return true
    }
}

// Xcode 16.2 includes Swift 6.0.3 and the iOS 18.2 coordinator APIs.
// Earlier toolchains retain UIKit's existing panel-based UITextInput experience.
#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
final class WritingToolsInteraction: NSObject, WritingToolsControlling, UIWritingToolsCoordinator.Delegate {
    private weak var textInputView: TextInputView?
    private var contextIdentifier: UUID?
    private var expectedText: NSString?
    private var expectedMutationVersion: UInt?
    private var hiddenText: [HiddenText] = []
    private var isUpdatingLayout = false
    private var isStopping = false
    private var previousLayout: [CGRect] = []

    lazy var coordinator: UIWritingToolsCoordinator = {
        let coordinator = UIWritingToolsCoordinator(delegate: self)
        coordinator.preferredBehavior = .complete
        coordinator.preferredResultOptions = .plainText
        return coordinator
    }()

    private struct HiddenText {
        let animation: UIWritingToolsCoordinator.TextAnimation
        let originalRange: NSRange
        var range: NSRange
    }

    init(textInputView: TextInputView) {
        self.textInputView = textInputView
        super.init()
    }

    func stop() {
        guard !isStopping else {
            return
        }
        isStopping = true
        clearContext()
        if coordinator.state != .inactive { coordinator.stopWritingTools() }
        textInputView?.setWritingToolsActive(false)
        isStopping = false
    }

    func layoutDidChange() {
        guard !isUpdatingLayout, let contextIdentifier, let view = textInputView, !view.isApplyingWritingToolsReplacement else {
            return
        }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }
        let rects = view.writingToolsTextRects(in: NSRange(location: 0, length: view.string.length))
        if rects != previousLayout {
            previousLayout = rects
            coordinator.updateForReflowedTextInContextWithIdentifier(contextIdentifier)
        }
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 requestsContextsFor scope: UIWritingToolsCoordinator.ContextScope,
                                 completion: @escaping ([UIWritingToolsCoordinator.Context]) -> Void) {
        guard let view = textInputView, view.markedTextRange == nil,
              view.isUserInteractionEnabled else {
                  completion([])
                  return
              }
        clearContext()
        let text = view.string
        let wholeDocument = NSRange(location: 0, length: text.length)
        var range = wholeDocument
        if scope == .userSelection, let selection = view.selectedRange, WritingToolsRange.isValid(selection, in: text) {
            range = selection.length > 0 ? selection : text.paragraphRange(for: selection)
        } else if scope == .visibleArea,
                  let start = view.closestPosition(to: view.viewport.origin) as? IndexedPosition,
                  let end = view.closestPosition(to: CGPoint(x: view.viewport.maxX, y: view.viewport.maxY)) as? IndexedPosition {
            let visibleRange = NSRange(location: min(start.index, end.index), length: abs(end.index - start.index))
            if WritingToolsRange.isValid(visibleRange, in: text) { range = text.paragraphRange(for: visibleRange) }
        }
        // A single full-document context keeps subsequent UTF-16 replacements unambiguous,
        // including edits that insert paragraphs before another proofreading suggestion.
        let attributedText = NSAttributedString(string: text as String, attributes: [.font: view.theme.font])
        let context = UIWritingToolsCoordinator.Context(attributedString: attributedText, range: range)
        contextIdentifier = context.identifier
        expectedText = text.copy() as? NSString
        expectedMutationVersion = view.textMutationVersion
        completion([context])
    }

    // swiftlint:disable:next function_parameter_count
    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 replace range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 proposedText replacementText: NSAttributedString,
                                 reason: UIWritingToolsCoordinator.TextReplacementReason,
                                 animationParameters: UIWritingToolsCoordinator.AnimationParameters?,
                                 completion: @escaping (NSAttributedString?) -> Void) {
        guard let view = validView(for: range, in: context), view.isEditableForWritingTools,
              let insertedText = view.replaceTextForWritingTools(in: range, with: replacementText.string),
              contextIdentifier == context.identifier else {
                  completion(nil)
                  return
              }
        expectedText = view.string.copy() as? NSString
        expectedMutationVersion = view.textMutationVersion
        adjustHiddenRanges(replacing: range, withLength: (insertedText as NSString).length)
        view.layoutIfNeeded()
        layoutDidChange()
        completion(NSAttributedString(string: insertedText, attributes: [.font: view.theme.font]))
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 select ranges: [NSValue],
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping () -> Void) {
        defer { completion() }
        // Runestone has one contiguous selection. Keep the first system-requested selection.
        guard let range = ranges.first?.rangeValue, let view = validView(for: range, in: context) else {
            return
        }
        view.inputDelegate?.selectionWillChange(view)
        view.selectedRange = range
        view.inputDelegate?.selectionDidChange(view)
        view.delegate?.textInputViewDidChangeSelection(view)
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 requestsBoundingBezierPathsFor range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping ([UIBezierPath]) -> Void) {
        let rects = validView(for: range, in: context)?.writingToolsTextRects(in: range) ?? []
        completion(rects.map { UIBezierPath(rect: $0) })
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 requestsUnderlinePathsFor range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping ([UIBezierPath]) -> Void) {
        guard let view = validView(for: range, in: context) else {
            completion([])
            return
        }
        completion(view.writingToolsTextRects(in: range).map { rect in
            let path = UIBezierPath()
            let baseline = rect.midY + view.theme.font.lineHeight / 2 + view.theme.font.descender
            let y = min(rect.maxY, baseline + 2)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            return path
        })
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 prepareFor textAnimation: UIWritingToolsCoordinator.TextAnimation,
                                 for range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping () -> Void) {
        if validView(for: range, in: context) != nil {
            hiddenText.append(HiddenText(animation: textAnimation, originalRange: range, range: range))
            updateHiddenText()
        }
        completion()
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 requestsPreviewFor textAnimation: UIWritingToolsCoordinator.TextAnimation,
                                 of range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping (UITargetedPreview?) -> Void) {
        guard let view = validView(for: range, in: context), view.window != nil else {
            completion(nil)
            return
        }
        let rects = view.writingToolsTextRects(in: range).map { $0.intersection(view.viewport) }.filter { !$0.isEmpty && !$0.isNull }
        guard !rects.isEmpty else {
            completion(nil)
            return
        }
        let frame = rects.reduce(CGRect.null) { $0.union($1) }
        // Draw only the glyphs, with the same Core Text line renderer as the editor.
        // Limit the image to the viewport so large documents cannot allocate huge bitmaps.
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: frame.size, format: format).image { renderer in
            let cg = renderer.cgContext
            cg.translateBy(x: -frame.minX, y: -frame.minY)
            cg.clip(to: rects)
            view.drawWritingToolsText(in: cg)
        }
        let imageView = UIImageView(image: image)
        imageView.frame = frame
        let localRects = rects.map { NSValue(cgRect: $0.offsetBy(dx: -frame.minX, dy: -frame.minY)) }
        let parameters = UIPreviewParameters(textLineRects: localRects)
        parameters.backgroundColor = .clear
        let target = UIPreviewTarget(container: view, center: CGPoint(x: frame.midX, y: frame.midY))
        completion(UITargetedPreview(view: imageView, parameters: parameters, target: target))
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 finish textAnimation: UIWritingToolsCoordinator.TextAnimation,
                                 for range: NSRange,
                                 in context: UIWritingToolsCoordinator.Context,
                                 completion: @escaping () -> Void) {
        if contextIdentifier == context.identifier,
           let index = hiddenText.firstIndex(where: { $0.animation == textAnimation && $0.originalRange == range }) {
            hiddenText.remove(at: index)
            updateHiddenText()
        }
        completion()
    }

    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 willChangeTo newState: UIWritingToolsCoordinator.State,
                                 completion: @escaping () -> Void) {
        if newState == .inactive { clearContext() }
        textInputView?.setWritingToolsActive(newState != .inactive)
        completion()
    }

    // iOS 18.2 and 18.3 ask the delegate to map proofreading taps back into its context.
    func writingToolsCoordinator(_ writingToolsCoordinator: UIWritingToolsCoordinator,
                                 requestsRangeInContextWithIdentifierFor point: CGPoint,
                                 completion: @escaping (NSRange, UUID) -> Void) {
        guard let identifier = contextIdentifier, let view = textInputView,
              let range = view.characterRange(at: point) as? IndexedRange else {
            completion(NSRange(location: NSNotFound, length: 0), contextIdentifier ?? UUID())
            return
        }
        completion(range.range, identifier)
    }

    private func validView(for range: NSRange, in context: UIWritingToolsCoordinator.Context) -> TextInputView? {
        guard contextIdentifier == context.identifier, let view = textInputView,
              view.textMutationVersion == expectedMutationVersion, view.string == expectedText,
              WritingToolsRange.isValid(range, in: view.string) else {
                  return nil
              }
        return view
    }

    private func clearContext() {
        textInputView?.invalidateWritingToolsContext()
        contextIdentifier = nil
        expectedText = nil
        expectedMutationVersion = nil
        hiddenText.removeAll()
        previousLayout.removeAll()
        textInputView?.setWritingToolsHiddenRanges([])
    }

    private func adjustHiddenRanges(replacing range: NSRange, withLength length: Int) {
        let delta = length - range.length
        for index in hiddenText.indices {
            let hidden = hiddenText[index].range
            if hidden.location >= NSMaxRange(range) {
                hiddenText[index].range.location += delta
            } else if NSMaxRange(hidden) > range.location {
                let start = min(hidden.location, range.location)
                let end = max(range.location + length, NSMaxRange(hidden) + delta)
                hiddenText[index].range = NSRange(location: start, length: end - start)
            }
        }
        updateHiddenText()
    }

    private func updateHiddenText() {
        var merged: [NSRange] = []
        for range in hiddenText.map(\.range).filter({ $0.length > 0 }).sorted(by: { $0.location < $1.location }) {
            if let previous = merged.last, NSMaxRange(previous) >= range.location {
                merged[merged.count - 1] = NSUnionRange(previous, range)
            } else {
                merged.append(range)
            }
        }
        textInputView?.setWritingToolsHiddenRanges(merged)
    }
}
#endif
