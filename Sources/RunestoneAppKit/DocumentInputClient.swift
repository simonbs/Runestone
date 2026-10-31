#if canImport(AppKit)
import AppKit

/// Internal protocol adapter only. A real view must own focus, event handling,
/// selection and marked-text rendering, input-context invalidation and undo.
/// The host must provide screen-coordinate geometry and must not expose this as
/// an interactive editor until those contracts are implemented and verified.
///
/// Plain input receives the host's typing attributes; attributed input retains
/// its runs, including marked attributes. A host must decide which transient IME
/// decorations belong in presentation rather than persisted document content.
/// The injected providers must be synchronous and must not mutate the document.
final class DocumentInputClient: NSObject, NSTextInputClient {
    typealias RangeGeometry = (rect: NSRect, actualRange: NSRange)

    let session: DocumentInputSession
    private let view: ReadOnlyDocumentView
    private let typingAttributes: () -> [NSAttributedString.Key: Any]
    private let commandHandler: (Selector) -> Void
    private let rectProvider: (NSRange) -> RangeGeometry?
    private let indexProvider: (NSPoint) -> Int?
    private let markedAttributes: [NSAttributedString.Key]

    init(view: ReadOnlyDocumentView,
         typingAttributes: @escaping () -> [NSAttributedString.Key: Any],
         commandHandler: @escaping (Selector) -> Void,
         rectProvider: @escaping (NSRange) -> RangeGeometry?,
         indexProvider: @escaping (NSPoint) -> Int?,
         markedAttributes: [NSAttributedString.Key] = []) {
        self.view = view
        self.session = DocumentInputSession(view: view)
        self.typingAttributes = typingAttributes
        self.commandHandler = commandHandler
        self.rectProvider = rectProvider
        self.indexProvider = indexProvider
        self.markedAttributes = markedAttributes
        super.init()
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard let content = attributedInput(string) else { return }
        _ = session.insertText(content, replacementRange: replacementRange)
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard let content = attributedInput(string) else { return }
        _ = session.setMarkedText(content, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    func unmarkText() { _ = session.unmarkText() }
    func selectedRange() -> NSRange { session.selectedRange }
    func markedRange() -> NSRange { session.markedRange ?? NSRange(location: NSNotFound, length: 0) }
    func hasMarkedText() -> Bool { session.markedRange != nil }
    func doCommand(by selector: Selector) { commandHandler(selector) }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { markedAttributes }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        guard !session.isStale, isValid(range) else { return nil }
        let content = view.attributedContent(in: range)
        actualRange?.pointee = range
        return content
    }

    /// Providers return screen coordinates. A missing or invalid result returns
    /// an empty rect with an NSNotFound actual range, never fabricated geometry.
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        guard !session.isStale, isValid(range), let result = rectProvider(range), !session.isStale,
              isValid(result.actualRange), result.rect.origin.x.isFinite, result.rect.origin.y.isFinite,
              result.rect.size.width.isFinite, result.rect.size.height.isFinite else { return .zero }
        actualRange?.pointee = result.actualRange
        return result.rect
    }

    /// Providers receive screen coordinates. NSNotFound denotes no valid hit.
    func characterIndex(for point: NSPoint) -> Int {
        guard !session.isStale, point.x.isFinite, point.y.isFinite,
              let index = indexProvider(point), !session.isStale,
              isValid(NSRange(location: index, length: 0)) else { return NSNotFound }
        return index
    }

    private func attributedInput(_ value: Any) -> NSAttributedString? {
        if let attributed = value as? NSAttributedString { return NSAttributedString(attributedString: attributed) }
        if let string = value as? String { return NSAttributedString(string: string, attributes: typingAttributes()) }
        return nil
    }

    private func isValid(_ range: NSRange) -> Bool {
        let text = view.manager.stringView.string
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        return isScalarBoundary(range.location, in: text) && isScalarBoundary(range.location + range.length, in: text)
    }

    private func isScalarBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset > 0 && offset < text.length else { return true }
        return !(0xD800...0xDBFF).contains(text.character(at: offset - 1)) ||
               !(0xDC00...0xDFFF).contains(text.character(at: offset))
    }
}
#endif
