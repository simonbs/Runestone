// swiftlint:disable file_length
import Combine
import Foundation

protocol TextViewControllerDelegate: AnyObject {
    func textViewControllerDidChangeText(_ textViewController: TextViewController)
    func textViewController(_ textViewController: TextViewController, didChangeSelectedRange selectedRange: NSRange?)
}

extension TextViewControllerDelegate {
    func textViewController(_ textViewController: TextViewController, didChangeSelectedRange selectedRange: NSRange?) {}
}

// swiftlint:disable:next type_body_length
final class TextViewController {
    weak var delegate: TextViewControllerDelegate?

    // Content
    let stringView: StringView
    let lineManager: LineManager
    var text: String {
        get {
            stringView.string as String
        }
        set {
            let nsString = newValue as NSString
            if nsString != stringView.string {
                stringView.string = nsString
                languageMode.value.parse(nsString)
                lineControllerStorage.removeAllLineControllers()
                lineManager.rebuild()
                if let oldSelectedRange = selectedRange {
                    #if os(iOS)
                    textView.inputDelegate?.selectionWillChange(textView)
                    #endif
                    selectedRange = oldSelectedRange.capped(to: stringView.string.length)
                    #if os(iOS)
                    textView.inputDelegate?.selectionDidChange(textView)
                    #endif
                }
//                contentSizeService.reset()
//                gutterWidthService.invalidateLineNumberWidth()
                highlightedRangeService.invalidateHighlightedRangeFragments()
                invalidateLines()
                lineFragmentLayouter.setNeedsLayout()
                lineFragmentLayouter.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    timedUndoManager.removeAllActions()
                }
            }
        }
    }

    // Visible content
//    var viewport: CGRect {
//        get {
//            lineFragmentLayouter.viewport
//        }
//        set {
//            if newValue != lineFragmentLayouter.viewport {
////                contentSizeService.containerSize = newValue.size
//
//                if isLineWrappingEnabled && newValue.width != lineFragmentLayouter.viewport.width  {
//                    widestLineTracker.reset()
//                    for lineController in lineControllerStorage {
//                        lineController.invalidateTypesetting()
//                    }
//                }
//                lineFragmentLayouter.viewport = newValue
//                textView.setNeedsLayout()
//            }
//        }
//    }

    // Editing
    var selectedRange: NSRange? {
        get {
            _selectedRange
        }
        set {
            if newValue != _selectedRange {
                _selectedRange = newValue
                delegate?.textViewController(self, didChangeSelectedRange: newValue)
            }
        }
    }
    var _selectedRange: NSRange? {
        didSet {
            if _selectedRange != oldValue {
                #if os(macOS)
                caretLayouter.caretLocation = _selectedRange?.upperBound ?? 0
                textSelectionLayouter.selectedRange = _selectedRange
                #endif
                lineSelectionLayouter.selectedRange = _selectedRange
                highlightedRangeNavigationController.selectedRange = _selectedRange
                textView.setNeedsLayout()
            }
        }
    }
    var markedRange: NSRange?
    var isEditing = false
    var isEditable = true {
        didSet {
            if isEditable != oldValue && !isEditable && isEditing {
                textView.resignFirstResponder()
                isEditing = false
                textView.editorDelegate?.textViewDidEndEditing(textView)
            }
        }
    }
    var isSelectable = true {
        didSet {
            if isSelectable != oldValue && !isSelectable && isEditing {
                textView.resignFirstResponder()
                selectedRange = nil
                isEditing = false
                textView.editorDelegate?.textViewDidEndEditing(textView)
            }
        }
    }
    var preserveUndoStackWhenSettingString = false
    var lineEndings: LineEnding = .lf
//    var kern: CGFloat = 0 {
//        didSet {
//            if kern != oldValue {
//                invalidateLines()
//                PageGuideLayouter.kern = kern
////                contentSizeService.invalidateContentSize()
//                lineFragmentLayouter.setNeedsLayout()
//                textView.setNeedsLayout()
//            }
//        }
//    }

    // View hierarchy
    var textView: TextView {
        if let textView = _textView {
            return textView
        } else {
            fatalError("The text view has been deallocated or has not been assigned")
        }
    }
    weak var scrollView: MultiPlatformScrollView? {
        didSet {
            if scrollView !== oldValue {
                contentSizeService.scrollView = scrollView
            }
        }
    }
    private weak var _textView: TextView?

    let textContainer: TextContainer
    let typesetSettings: TypesetSettings
    let invisibleCharacterSettings: InvisibleCharacterSettings
    let themeSettings = ThemeSettings()
    private let estimatedLineHeight: EstimatedLineHeight
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let contentAreaProvider: ContentAreaProvider
    let contentSizeService: ContentSizeService
    let caretRectProvider: CaretRectProvider
    let lineControllerStorage: LineControllerStorage
    let navigationService: NavigationService
    let lineFragmentLayouter: LineFragmentLayouter
    let lineSelectionLayouter: LineSelectionLayouter
    let pageGuideLayouter: PageGuideLayouter
    let indentController: IndentController
    #if os(macOS)
    let textSelectionLayouter: TextSelectionLayouter
    let caretLayouter: CaretLayouter
    let selectionService: SelectionService
    #endif

//    var safeAreaInsets: MultiPlatformEdgeInsets = .zero {
//        didSet {
//            if safeAreaInsets != oldValue {
//                lineFragmentLayouter.safeAreaInsets = safeAreaInsets
//            }
//        }
//    }
//    var textContainerInset: MultiPlatformEdgeInsets = .zero {
//        didSet {
//            if textContainerInset != lineFragmentLayouter.textContainerInset {
////                contentSizeService.textContainerInset = textContainerInset
//                lineSelectionLayouter.textContainerInset = textContainerInset
//                lineFragmentLayouter.textContainerInset = textContainerInset
//                #if os(macOS)
//                textSelectionLayouter.textContainerInset = textContainerInset
//                #endif
//                textView.setNeedsLayout()
//            }
//        }
//    }


    // Indentation
//    var indentStrategy: IndentStrategy = .tab(length: 2) {
//        didSet {
//            if indentStrategy != oldValue {
//                indentController.indentStrategy = indentStrategy
//                textView.setNeedsLayout()
//                textView.layoutIfNeeded()
//            }
//        }
//    }

    // Gutter
//    var gutterLeadingPadding: CGFloat = 3 {
//        didSet {
//            if gutterLeadingPadding != oldValue {
//                gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
//                textView.setNeedsLayout()
//            }
//        }
//    }
//    var gutterTrailingPadding: CGFloat = 3 {
//        didSet {
//            if gutterTrailingPadding != oldValue {
//                gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
//                textView.setNeedsLayout()
//            }
//        }
//    }
//    var gutterMinimumCharacterCount: Int = 1 {
//        didSet {
//            if gutterMinimumCharacterCount != oldValue {
//                gutterWidthService.gutterMinimumCharacterCount = gutterMinimumCharacterCount
//                textView.setNeedsLayout()
//            }
//        }
//    }
//    let gutterWidthService: GutterWidthService
//    var showLineNumbers = false {
//        didSet {
//            if showLineNumbers != oldValue {
//                #if os(iOS)
//                textView.inputDelegate?.selectionWillChange(textView)
//                #endif
//                gutterWidthService.showLineNumbers = showLineNumbers
//                lineFragmentLayouter.setNeedsLayout()
//                textView.setNeedsLayout()
//                #if os(iOS)
//                textView.inputDelegate?.selectionDidChange(textView)
//                #endif
//            }
//        }
//    }

    var characterPairs: [CharacterPair] = [] {
        didSet {
            maximumLeadingCharacterPairComponentLength = characterPairs.map(\.leading.utf16.count).max() ?? 0
        }
    }
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    private(set) var maximumLeadingCharacterPairComponentLength = 0

//        didSet {
//            if languageMode !== oldValue {
//                indentController.languageMode = languageMode
//                if let treeSitterLanguageMode = languageMode as? TreeSitterInternalLanguageMode {
//                    treeSitterLanguageMode.delegate = self
//                }
//            }
//        }
//    }

    // Highlighted ranges
    var highlightedRanges: [HighlightedRange] {
        get {
            highlightedRangeService.highlightedRanges
        }
        set {
            if newValue != highlightedRangeService.highlightedRanges {
                highlightedRangeService.highlightedRanges = newValue
                highlightedRangeNavigationController.highlightedRanges = newValue
            }
        }
    }
    private let highlightedRangeService: HighlightedRangeService
    var highlightedRangeLoopingMode: HighlightedRangeLoopingMode {
        get {
            if highlightedRangeNavigationController.loopRanges {
                return .enabled
            } else {
                return .disabled
            }
        }
        set {
            switch newValue {
            case .enabled:
                highlightedRangeNavigationController.loopRanges = true
            case .disabled:
                highlightedRangeNavigationController.loopRanges = false
            }
        }
    }
    let highlightedRangeNavigationController = HighlightedRangeNavigationController()

    let timedUndoManager = CoalescingUndoManager()
    var isAutomaticScrollEnabled = true
    private var cancellables: Set<AnyCancellable> = []



    private let widestLineTracker: WidestLineTracker

    // swiftlint:disable:next function_body_length
    init(textView: TextView) {
        let compositionRoot = CompositionRoot(textView: textView)
        _textView = textView
        textContainer = compositionRoot.textContainer
        typesetSettings = compositionRoot.typesetSettings
        invisibleCharacterSettings = compositionRoot.invisibleCharacterSettings
        contentAreaProvider = compositionRoot.contentAreaProvider
        stringView = compositionRoot.stringView
        lineManager = compositionRoot.lineManager
        languageMode = compositionRoot.languageMode
        caretRectProvider = compositionRoot.caretRectProvider
        highlightedRangeService = compositionRoot.highlightedRangeService
        lineControllerStorage = compositionRoot.lineControllerStorage
//        gutterWidthService = GutterWidthService(lineManager: lineManager)
        widestLineTracker = compositionRoot.widestLineTracker
        contentSizeService = compositionRoot.contentSizeService
        navigationService = compositionRoot.navigationService
        #if os(macOS)
        selectionService = compositionRoot.selectionService
        #endif
        indentController = compositionRoot.indentController
        lineFragmentLayouter = compositionRoot.lineFragmentLayouter
        lineSelectionLayouter = compositionRoot.lineSelectionLayouter
        #if os(macOS)
        textSelectionLayouter = compositionRoot.textSelectionLayouter
        caretLayouter = CaretLayouter(caretRectProvider: caretRectProvider, containerView: textView)
        #endif
        lineFragmentLayouter.delegate = self
        indentController.delegate = self
        lineControllerStorage.delegate = self
//        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
//        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
//        setupContentSizeObserver()
//        setupGutterWidthObserver()
        setupTextViewNeedsLayoutObserver()
        #if os(iOS)
        subscribeToMemoryWarningNotification()
        #endif
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldText = stringView.string
        let newText = state.stringView.string
        stringView.string = newText
        themeSettings.theme.value = state.theme
        languageMode.value = state.languageMode
        lineControllerStorage.removeAllLineControllers()
        lineManager.copy(from: state.lineManager)
//        contentSizeService.reset()
//        gutterWidthService.invalidateLineNumberWidth()
        highlightedRangeService.invalidateHighlightedRangeFragments()
        if addUndoAction {
            if newText != oldText {
                let newRange = NSRange(location: 0, length: newText.length)
                timedUndoManager.endUndoGrouping()
                timedUndoManager.beginUndoGrouping()
                addUndoOperation(replacing: newRange, withText: oldText as String)
                timedUndoManager.endUndoGrouping()
            }
        } else {
            timedUndoManager.removeAllActions()
        }
        if let oldSelectedRange = selectedRange {
            #if os(iOS)
            textView.inputDelegate?.selectionWillChange(textView)
            selectedRange = oldSelectedRange.capped(to: stringView.string.length)
            textView.inputDelegate?.selectionDidChange(textView)
            #endif
        }
    }

    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        self.languageMode.value = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager
        )
        self.languageMode.value.parse(stringView.string) { [weak self] finished in
            if let self = self, finished {
                self.invalidateLines()
                self.lineFragmentLayouter.setNeedsLayout()
                self.lineFragmentLayouter.layoutIfNeeded()
            }
            completion?(finished)
        }
    }

    func highlightedRange(for range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == selectedRange }
    }
}

private extension TextViewController {
    private func setupTextViewNeedsLayoutObserver() {
        textContainer.viewport.removeDuplicates().sink { [weak self] _ in
            self?.textView.setNeedsLayout()
        }.store(in: &cancellables)
    }

//    private func setupGutterWidthObserver() {
//        gutterWidthService.didUpdateGutterWidth.sink { [weak self] in
//            if let self = self, let textView = self._textView, self.showLineNumbers {
//                // Typeset lines again when the line number width changes since changing line number width may increase or reduce the number of line fragments in a line.
//                textView.setNeedsLayout()
//                self.invalidateLines()
//                self.lineFragmentLayouter.setNeedsLayout()
//                textView.editorDelegate?.textViewDidChangeGutterWidth(self.textView)
//            }
//        }.store(in: &cancellables)
//    }
}

// MARK: - TreeSitterLanguageModeDelegate
extension TextViewController: TreeSitterLanguageModeDelegate {
    func treeSitterLanguageMode(_ languageMode: TreeSitterInternalLanguageMode, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        guard byteIndex.value >= 0 && byteIndex < stringView.string.byteCount else {
            return nil
        }
        let targetByteCount: ByteCount = 4 * 1_024
        let endByte = min(byteIndex + targetByteCount, stringView.string.byteCount)
        let byteRange = ByteRange(from: byteIndex, to: endByte)
        if let result = stringView.bytes(in: byteRange) {
            return TreeSitterTextProviderResult(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}

// MARK: - LineFragmentLayouterDelegate
extension TextViewController: LineFragmentLayouterDelegate {
    func lineFragmentLayouter(_ lineFragmentLayouter: LineFragmentLayouter, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        guard let scrollView else {
            return
        }
        let isScrolling = scrollView.isDragging || scrollView.isDecelerating
        if contentOffsetAdjustment != .zero && isScrolling {
            let newXOffset = scrollView.contentOffset.x + contentOffsetAdjustment.x
            let newYOffset = scrollView.contentOffset.y + contentOffsetAdjustment.y
            scrollView.contentOffset = CGPoint(x: newXOffset, y: newYOffset)
        }
    }
}

// MARK: - LineControllerStorageDelegate
extension TextViewController: LineControllerStorageDelegate {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController) {
        lineController.delegate = self
//        lineController.constrainingWidth = lineFragmentLayouter.constrainingLineWidth
    }
}

// MARK: - LineControllerDelegate
extension TextViewController: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        let syntaxHighlighter = languageMode.value.createLineSyntaxHighlighter()
        syntaxHighlighter.kern = typesetSettings.kern.value
        return syntaxHighlighter
    }

    func lineControllerDidInvalidateSize(_ lineController: LineController) {
        lineFragmentLayouter.setNeedsLayout()
        lineSelectionLayouter.setNeedsLayout()
        textView.setNeedsLayout()
    }
}

// MARK: - IndentControllerDelegate
extension TextViewController: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        replaceText(in: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        #if os(iOS)
        textView.inputDelegate?.selectionWillChange(textView)
        selectedRange = range
        textView.inputDelegate?.selectionDidChange(textView)
        #else
        selectedRange = range
        #endif
    }

    func indentControllerDidUpdateTabWidth(_ controller: IndentController) {
        invalidateLines()
    }
}
