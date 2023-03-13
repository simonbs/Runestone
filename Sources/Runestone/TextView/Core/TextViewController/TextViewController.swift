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

    private let keyWindowObserver: KeyWindowObserver
    let isFirstResponder: CurrentValueSubject<Bool, Never>

    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    var text: String {
        get {
            stringView.value.string as String
        }
        set {
            let nsString = newValue as NSString
            if nsString != stringView.value.string {
                stringView.value.string = nsString
                languageMode.value.parse(nsString)
                lineControllerStorage.removeAllLineControllers()
                lineManager.value.rebuild()
//                if let oldSelectedRange = selectedRange {
//                    #if os(iOS)
//                    textView.inputDelegate?.selectionWillChange(textView)
//                    #endif
//                    selectedRange = oldSelectedRange.capped(to: stringView.value.string.length)
//                    #if os(iOS)
//                    textView.inputDelegate?.selectionDidChange(textView)
//                    #endif
//                }
//                contentSizeService.reset()
//                gutterWidthService.invalidateLineNumberWidth()
//                highlightedRangeService.invalidateHighlightedRangeFragments()
//                invalidateLines()
//                lineFragmentLayouter.setNeedsLayout()
//                lineFragmentLayouter.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    timedUndoManager.removeAllActions()
                }
            }
        }
    }
    let selectedRange: CurrentValueSubject<NSRange, Never>

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
                isEditing = false
                textView.editorDelegate?.textViewDidEndEditing(textView)
            }
        }
    }
    var preserveUndoStackWhenSettingString = false
    var lineEndings: LineEnding = .lf

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
    let themeSettings: ThemeSettings
    private let estimatedLineHeight: EstimatedLineHeight
    private let widestLineTracker: WidestLineTracker
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let contentArea: ContentArea
    let contentSizeService: ContentSizeService
    let caret: Caret
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

    var characterPairs: [CharacterPair] = [] {
        didSet {
            maximumLeadingCharacterPairComponentLength = characterPairs.map(\.leading.utf16.count).max() ?? 0
        }
    }
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    private(set) var maximumLeadingCharacterPairComponentLength = 0

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

    // swiftlint:disable:next function_body_length
    init(textView: TextView) {
        let compositionRoot = CompositionRoot(textView: textView)
        _textView = textView
        keyWindowObserver = compositionRoot.keyWindowObserver
        isFirstResponder = compositionRoot.isFirstResponder
        selectedRange = compositionRoot.selectedRange
        textContainer = compositionRoot.textContainer
        typesetSettings = compositionRoot.typesetSettings
        invisibleCharacterSettings = compositionRoot.invisibleCharacterSettings
        themeSettings = compositionRoot.themeSettings
        contentArea = compositionRoot.contentArea
        stringView = compositionRoot.stringView
        lineManager = compositionRoot.lineManager
        languageMode = compositionRoot.languageMode
        estimatedLineHeight = compositionRoot.estimatedLineHeight
        caret = compositionRoot.caret
        highlightedRangeService = compositionRoot.highlightedRangeService
        lineControllerStorage = compositionRoot.lineControllerStorage
//        gutterWidthService = GutterWidthService(lineManager: lineManager)
        widestLineTracker = compositionRoot.widestLineTracker
        contentSizeService = compositionRoot.contentSizeService
        navigationService = compositionRoot.navigationService
        indentController = compositionRoot.indentController
        lineFragmentLayouter = compositionRoot.lineFragmentLayouter
        lineSelectionLayouter = compositionRoot.lineSelectionLayouter
        pageGuideLayouter = compositionRoot.pageGuideLayouter
        #if os(macOS)
        selectionService = compositionRoot.selectionService
        textSelectionLayouter = compositionRoot.textSelectionLayouter
        caretLayouter = compositionRoot.caretLayouter
        #endif
        lineFragmentLayouter.delegate = self
        indentController.delegate = self
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
        let oldText = stringView.value.string
        let newText = state.stringView.string
        state.lineManager.estimatedLineHeight = estimatedLineHeight.rawValue
        stringView.value = state.stringView
        lineManager.value = state.lineManager
        themeSettings.theme.value = state.theme
        languageMode.value = InternalLanguageModeFactory.internalLanguageMode(
            from: state.languageModeState,
            stringView: stringView,
            lineManager: lineManager
        )
        lineControllerStorage.removeAllLineControllers()
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
        #if os(iOS)
        textView.inputDelegate?.selectionWillChange(textView)
        selectedRange.value = oldSelectedRange.capped(to: stringView.string.length)
        textView.inputDelegate?.selectionDidChange(textView)
        #endif
    }

    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        self.languageMode.value = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager
        )
        self.languageMode.value.parse(stringView.value.string) { [weak self] finished in
            if let self = self, finished {
//                self.invalidateLines()
//                self.lineFragmentLayouter.setNeedsLayout()
//                self.lineFragmentLayouter.layoutIfNeeded()
            }
            completion?(finished)
        }
    }

    func highlightedRange(for range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == selectedRange.value }
    }
}

private extension TextViewController {
    private func setupTextViewNeedsLayoutObserver() {
        Publishers.CombineLatest(
            stringView,
            textContainer.viewport.removeDuplicates()
        ).sink { [weak self] _ in
            self?.textView.setNeedsLayout()
        }.store(in: &cancellables)
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

// MARK: - IndentControllerDelegate
extension TextViewController: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        replaceText(in: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        #if os(iOS)
        textView.inputDelegate?.selectionWillChange(textView)
        selectedRange.value = range
        textView.inputDelegate?.selectionDidChange(textView)
        #else
        selectedRange.value = range
        #endif
    }

    func indentControllerDidUpdateTabWidth(_ controller: IndentController) {
//        invalidateLines()
    }
}
