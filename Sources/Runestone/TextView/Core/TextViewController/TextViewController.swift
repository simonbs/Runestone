// swiftlint:disable file_length
import Byte
import Combine
import Foundation
import LineManager
import MultiPlatform
import RangeHelpers
import StringView
import TreeSitter

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
    var textView: TextView {
        if let textView = _textView {
            return textView
        } else {
            fatalError("The text view has been deallocated or has not been assigned")
        }
    }
    weak var scrollView: MultiPlatformScrollView?
    private weak var _textView: TextView?
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
                caretLayoutManager.caretLocation = _selectedRange?.upperBound ?? 0
                textSelectionLayoutManager.selectedRange = _selectedRange
                #endif
                lineSelectionLayoutManager.selectedRange = _selectedRange
                highlightNavigationController.selectedRange = _selectedRange
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
    var viewport: CGRect {
        get {
            lineFragmentLayoutManager.viewport
        }
        set {
            if newValue != lineFragmentLayoutManager.viewport {
                contentSizeService.containerSize = newValue.size
                if isLineWrappingEnabled && newValue.width != lineFragmentLayoutManager.viewport.width  {
                    for lineController in lineControllerStorage {
                        lineController.invalidateTypesetting()
                    }
                }
                lineFragmentLayoutManager.viewport = newValue
                textView.setNeedsLayout()
            }
        }
    }
    var text: String {
        get {
            stringView.string as String
        }
        set {
            let nsString = newValue as NSString
            if nsString != stringView.string {
                stringView.string = nsString
                languageMode.parse(nsString)
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
                contentSizeService.invalidateContentSize()
                gutterWidthService.invalidateLineNumberWidth()
                invalidateLines()
                lineFragmentLayoutManager.setNeedsLayout()
                lineFragmentLayoutManager.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    timedUndoManager.removeAllActions()
                }
            }
        }
    }
    var hasPendingContentSizeUpdate = false
    var safeAreaInsets: MultiPlatformEdgeInsets = .zero {
        didSet {
            if safeAreaInsets != oldValue {
                lineFragmentLayoutManager.safeAreaInsets = safeAreaInsets
            }
        }
    }

    private(set) var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                lineManager.stringView = stringView
                lineControllerFactory.stringView = stringView
                lineControllerStorage.stringView = stringView
                lineFragmentLayoutManager.stringView = stringView
                lineSelectionLayoutManager.stringView = stringView
                indentController.stringView = stringView
                navigationService.stringView = stringView
                #if os(macOS)
                selectionService.stringView = stringView
                textSelectionLayoutManager.stringView = stringView
                caretLayoutManager.stringView = stringView
                #endif
            }
        }
    }
    let invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    private(set) var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                lineFragmentLayoutManager.lineManager = lineManager
                lineSelectionLayoutManager.lineManager = lineManager
                indentController.lineManager = lineManager
                gutterWidthService.lineManager = lineManager
                contentSizeService.lineManager = lineManager
                highlightService.lineManager = lineManager
                navigationService.lineManager = lineManager
                #if os(macOS)
                selectionService.lineManager = lineManager
                textSelectionLayoutManager.lineManager = lineManager
                caretLayoutManager.lineManager = lineManager
                #endif
            }
        }
    }
    let highlightService: HighlightService
    let lineControllerFactory: LineControllerFactory
    let lineControllerStorage: LineControllerStorage
    let gutterWidthService: GutterWidthService
    let contentSizeService: ContentSizeService
    let navigationService: NavigationService
    #if os(macOS)
    let selectionService: SelectionService
    #endif
    let indentController: IndentController
    let pageGuideController = PageGuideController()
    let highlightNavigationController = HighlightNavigationController()
    let timedUndoManager = TimedUndoManager()
    let lineFragmentLayoutManager: LineFragmentLayoutManager
    let lineSelectionLayoutManager: LineSelectionLayoutManager
    #if os(macOS)
    let textSelectionLayoutManager: TextSelectionLayoutManager
    let caretLayoutManager: CaretLayoutManager
    #endif

    var languageMode: InternalLanguageMode = PlainTextInternalLanguageMode() {
        didSet {
            if languageMode !== oldValue {
                indentController.languageMode = languageMode
                if let treeSitterLanguageMode = languageMode as? TreeSitterInternalLanguageMode {
                    treeSitterLanguageMode.delegate = self
                }
            }
        }
    }
    var lineEndings: LineEnding = .lf
    var theme: Theme = DefaultTheme() {
        didSet {
            applyThemeToChildren()
        }
    }
    var characterPairs: [CharacterPair] = [] {
        didSet {
            maximumLeadingCharacterPairComponentLength = characterPairs.map(\.leading.utf16.count).max() ?? 0
        }
    }
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
                #if os(iOS)
                textView.inputDelegate?.selectionWillChange(textView)
                #endif
                gutterWidthService.showLineNumbers = showLineNumbers
                lineFragmentLayoutManager.setNeedsLayout()
                textView.setNeedsLayout()
                #if os(iOS)
                textView.inputDelegate?.selectionDidChange(textView)
                #endif
            }
        }
    }
    var lineSelectionDisplayType: LineSelectionDisplayType = .disabled {
        didSet {
            if lineSelectionDisplayType != oldValue {
                lineSelectionLayoutManager.showLineSelection = lineSelectionDisplayType != .disabled
                lineSelectionLayoutManager.selectEntireLine = lineSelectionDisplayType == .line
            }
        }
    }
    var showTabs: Bool {
        get {
            invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != invisibleCharacterConfiguration.showTabs {
                invisibleCharacterConfiguration.showTabs = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var showSpaces: Bool {
        get {
            invisibleCharacterConfiguration.showSpaces
        }
        set {
            if newValue != invisibleCharacterConfiguration.showSpaces {
                invisibleCharacterConfiguration.showSpaces = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var showNonBreakingSpaces: Bool {
        get {
            invisibleCharacterConfiguration.showNonBreakingSpaces
        }
        set {
            if newValue != invisibleCharacterConfiguration.showNonBreakingSpaces {
                invisibleCharacterConfiguration.showNonBreakingSpaces = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var showLineBreaks: Bool {
        get {
            invisibleCharacterConfiguration.showLineBreaks
        }
        set {
            if newValue != invisibleCharacterConfiguration.showLineBreaks {
                invisibleCharacterConfiguration.showLineBreaks = newValue
                invalidateLines()
                lineFragmentLayoutManager.setNeedsLayout()
                setNeedsDisplayOnLines()
                textView.setNeedsLayout()
            }
        }
    }
    var showSoftLineBreaks: Bool {
        get {
            invisibleCharacterConfiguration.showSoftLineBreaks
        }
        set {
            if newValue != invisibleCharacterConfiguration.showSoftLineBreaks {
                invisibleCharacterConfiguration.showSoftLineBreaks = newValue
                invalidateLines()
                lineFragmentLayoutManager.setNeedsLayout()
                setNeedsDisplayOnLines()
                textView.setNeedsLayout()
            }
        }
    }
    var tabSymbol: String {
        get {
            invisibleCharacterConfiguration.tabSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.tabSymbol {
                invisibleCharacterConfiguration.tabSymbol = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var spaceSymbol: String {
        get {
            invisibleCharacterConfiguration.spaceSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.spaceSymbol {
                invisibleCharacterConfiguration.spaceSymbol = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var nonBreakingSpaceSymbol: String {
        get {
            invisibleCharacterConfiguration.nonBreakingSpaceSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.nonBreakingSpaceSymbol {
                invisibleCharacterConfiguration.nonBreakingSpaceSymbol = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var lineBreakSymbol: String {
        get {
            invisibleCharacterConfiguration.lineBreakSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.lineBreakSymbol {
                invisibleCharacterConfiguration.lineBreakSymbol = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var softLineBreakSymbol: String {
        get {
            invisibleCharacterConfiguration.softLineBreakSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.softLineBreakSymbol {
                invisibleCharacterConfiguration.softLineBreakSymbol = newValue
                setNeedsDisplayOnLines()
            }
        }
    }
    var indentStrategy: IndentStrategy = .tab(length: 2) {
        didSet {
            if indentStrategy != oldValue {
                indentController.indentStrategy = indentStrategy
                textView.setNeedsLayout()
                textView.layoutIfNeeded()
            }
        }
    }
    var gutterLeadingPadding: CGFloat = 3 {
        didSet {
            if gutterLeadingPadding != oldValue {
                gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
                textView.setNeedsLayout()
            }
        }
    }
    var gutterTrailingPadding: CGFloat = 3 {
        didSet {
            if gutterTrailingPadding != oldValue {
                gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
                textView.setNeedsLayout()
            }
        }
    }
    var gutterMinimumCharacterCount: Int = 1 {
        didSet {
            if gutterMinimumCharacterCount != oldValue {
                gutterWidthService.gutterMinimumCharacterCount = gutterMinimumCharacterCount
                textView.setNeedsLayout()
            }
        }
    }
    var textContainerInset: MultiPlatformEdgeInsets = .zero {
        didSet {
            if textContainerInset != lineFragmentLayoutManager.textContainerInset {
                contentSizeService.textContainerInset = textContainerInset
                lineSelectionLayoutManager.textContainerInset = textContainerInset
                lineFragmentLayoutManager.textContainerInset = textContainerInset
                #if os(macOS)
                textSelectionLayoutManager.textContainerInset = textContainerInset
                caretLayoutManager.textContainerInset = textContainerInset
                #endif
                textView.setNeedsLayout()
            }
        }
    }
    var isLineWrappingEnabled: Bool {
        get {
            lineFragmentLayoutManager.isLineWrappingEnabled
        }
        set {
            if newValue != lineFragmentLayoutManager.isLineWrappingEnabled {
                contentSizeService.isLineWrappingEnabled = newValue
                lineFragmentLayoutManager.isLineWrappingEnabled = newValue
                invalidateLines()
                lineFragmentLayoutManager.layoutIfNeeded()
            }
        }
    }
    var lineBreakMode: LineBreakMode = .byWordWrapping {
        didSet {
            if lineBreakMode != oldValue {
                invalidateLines()
                contentSizeService.invalidateContentSize()
                lineFragmentLayoutManager.setNeedsLayout()
                lineFragmentLayoutManager.layoutIfNeeded()
            }
        }
    }
    var gutterWidth: CGFloat {
        gutterWidthService.gutterWidth
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                invalidateLines()
                lineManager.estimatedLineHeight = estimatedLineHeight
                lineSelectionLayoutManager.lineHeightMultiplier = lineHeightMultiplier
                #if os(macOS)
                textSelectionLayoutManager.lineHeightMultiplier = lineHeightMultiplier
                #endif
                lineFragmentLayoutManager.setNeedsLayout()
                textView.setNeedsLayout()
            }
        }
    }
    var kern: CGFloat = 0 {
        didSet {
            if kern != oldValue {
                invalidateLines()
                pageGuideController.kern = kern
                contentSizeService.invalidateContentSize()
                lineFragmentLayoutManager.setNeedsLayout()
                textView.setNeedsLayout()
            }
        }
    }
    var showPageGuide = false {
        didSet {
            if showPageGuide != oldValue {
                if showPageGuide {
                    #if os(iOS)
                    textView.addSubview(pageGuideController.guideView)
                    textView.sendSubviewToBack(pageGuideController.guideView)
                    #else
                    textView.addSubview(pageGuideController.guideView, positioned: .below, relativeTo: nil)
                    #endif
                    textView.setNeedsLayout()
                } else {
                    pageGuideController.guideView.removeFromSuperview()
                    textView.setNeedsLayout()
                }
            }
        }
    }
    var pageGuideColumn: Int {
        get {
            pageGuideController.column
        }
        set {
            if newValue != pageGuideController.column {
                pageGuideController.column = newValue
                textView.setNeedsLayout()
            }
        }
    }
    var verticalOverscrollFactor: CGFloat {
        get {
            contentSizeService.verticalOverscrollFactor
        }
        set {
            if newValue != contentSizeService.verticalOverscrollFactor {
                contentSizeService.verticalOverscrollFactor = newValue
                invalidateContentSizeIfNeeded()
            }
        }
    }
    var horizontalOverscrollFactor: CGFloat {
        get {
            contentSizeService.horizontalOverscrollFactor
        }
        set {
            if newValue != contentSizeService.horizontalOverscrollFactor {
                contentSizeService.horizontalOverscrollFactor = newValue
                invalidateContentSizeIfNeeded()
            }
        }
    }
    var lengthOfInitallyLongestLine: Int? {
        lineManager.initialLongestLine?.data.totalLength
    }
    var highlightedRanges: [HighlightedRange] {
        get {
            highlightService.highlightedRanges
        }
        set {
            if newValue != highlightService.highlightedRanges {
                highlightService.highlightedRanges = newValue
                highlightNavigationController.highlightedRanges = newValue
            }
        }
    }
    var highlightedRangeLoopingMode: HighlightedRangeLoopingMode {
        get {
            if highlightNavigationController.loopRanges {
                return .enabled
            } else {
                return .disabled
            }
        }
        set {
            switch newValue {
            case .enabled:
                highlightNavigationController.loopRanges = true
            case .disabled:
                highlightNavigationController.loopRanges = false
            }
        }
    }
    var isAutomaticScrollEnabled = true
    var hasPendingFullLayout = false
    var preserveUndoStackWhenSettingString = false
    private(set) var maximumLeadingCharacterPairComponentLength = 0

    private var estimatedLineHeight: CGFloat {
        theme.font.totalLineHeight * lineHeightMultiplier
    }
    private var cancellables: Set<AnyCancellable> = []

    // swiftlint:disable:next function_body_length
    init(textView: TextView) {
        _textView = textView
        lineManager = LineManager(stringView: stringView)
        highlightService = HighlightService(lineManager: lineManager)
        lineControllerFactory = LineControllerFactory(
            stringView: stringView,
            highlightService: highlightService,
            invisibleCharacterConfiguration: invisibleCharacterConfiguration
        )
        lineControllerStorage = LineControllerStorage(
            stringView: stringView,
            lineControllerFactory: lineControllerFactory
        )
        gutterWidthService = GutterWidthService(lineManager: lineManager)
        contentSizeService = ContentSizeService(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            gutterWidthService: gutterWidthService,
            invisibleCharacterConfiguration: invisibleCharacterConfiguration
        )
        navigationService = NavigationService(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
        #if os(macOS)
        selectionService = SelectionService(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
        #endif
        indentController = IndentController(
            stringView: stringView,
            lineManager: lineManager,
            languageMode: languageMode,
            indentStrategy: indentStrategy,
            indentFont: theme.font
        )
        lineFragmentLayoutManager = LineFragmentLayoutManager(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            contentSizeService: contentSizeService,
            containerView: textView
        )
        lineSelectionLayoutManager = LineSelectionLayoutManager(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            containerView: textView
        )
        #if os(macOS)
        textSelectionLayoutManager = TextSelectionLayoutManager(
            stringView: stringView,
            lineManager: lineManager,
            textContainerInset: textContainerInset,
            lineControllerStorage: lineControllerStorage,
            contentSizeService: contentSizeService,
            containerView: textView
        )
        caretLayoutManager = CaretLayoutManager(
            stringView: stringView,
            lineManager: lineManager,
            textContainerInset: textContainerInset,
            lineControllerStorage: lineControllerStorage,
            containerView: textView
        )
        #endif
        lineFragmentLayoutManager.delegate = self
        applyThemeToChildren()
        indentController.delegate = self
        lineControllerStorage.delegate = self
        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
        setupContentSizeObserver()
        setupGutterWidthObserver()
        #if os(iOS)
        subscribeToMemoryWarningNotification()
        #endif
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldText = stringView.string
        let newText = state.stringView.string
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineControllerStorage.removeAllLineControllers()
        lineManager = state.lineManager
        lineManager.estimatedLineHeight = estimatedLineHeight
        contentSizeService.invalidateContentSize()
        gutterWidthService.invalidateLineNumberWidth()
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
        let internalLanguageMode = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager
        )
        self.languageMode = internalLanguageMode
        internalLanguageMode.parse(stringView.string) { [weak self] finished in
            if let self = self, finished {
                self.invalidateLines()
                self.lineFragmentLayoutManager.setNeedsLayout()
                self.lineFragmentLayoutManager.layoutIfNeeded()
            }
            completion?(finished)
        }
    }

    func highlightedRange(for range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == selectedRange }
    }
}

private extension TextViewController {
    private func applyThemeToChildren() {
        gutterWidthService.font = theme.lineNumberFont
        lineManager.estimatedLineHeight = estimatedLineHeight
        indentController.indentFont = theme.font
        pageGuideController.font = theme.font
        pageGuideController.guideView.hairlineWidth = theme.pageGuideHairlineWidth
        pageGuideController.guideView.hairlineColor = theme.pageGuideHairlineColor
        pageGuideController.guideView.backgroundColor = theme.pageGuideBackgroundColor
        invisibleCharacterConfiguration.font = theme.font
        invisibleCharacterConfiguration.textColor = theme.invisibleCharactersColor
        lineSelectionLayoutManager.backgroundColor = theme.selectedLineBackgroundColor
        for lineController in lineControllerStorage {
            lineController.theme = theme
            lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
            lineController.invalidateSyntaxHighlighting()
        }
    }

    private func setupContentSizeObserver() {
        contentSizeService.$isContentSizeInvalid.filter { $0 }.sink { [weak self] _ in
            if self?._textView != nil {
                self?.invalidateContentSizeIfNeeded()
            }
        }.store(in: &cancellables)
    }

    private func setupGutterWidthObserver() {
        gutterWidthService.didUpdateGutterWidth.sink { [weak self] in
            if let self = self, let textView = self._textView, self.showLineNumbers {
                // Typeset lines again when the line number width changes since changing line number width may increase or reduce the number of line fragments in a line.
                textView.setNeedsLayout()
                self.invalidateLines()
                self.lineFragmentLayoutManager.setNeedsLayout()
                textView.editorDelegate?.textViewDidChangeGutterWidth(self.textView)
            }
        }.store(in: &cancellables)
    }
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

// MARK: - LineFragmentLayoutManagerDelegate
extension TextViewController: LineFragmentLayoutManagerDelegate {
    func lineFragmentLayoutManager(_ lineFragmentLayoutManager: LineFragmentLayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
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
//        lineController.constrainingWidth = lineFragmentLayoutManager.constrainingLineWidth
        lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
        lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
        lineController.tabWidth = indentController.tabWidth
        lineController.theme = theme
        lineController.lineBreakMode = lineBreakMode
    }
}

// MARK: - LineControllerDelegate
extension TextViewController: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        let syntaxHighlighter = languageMode.createLineSyntaxHighlighter()
        syntaxHighlighter.kern = kern
        return syntaxHighlighter
    }

    func lineControllerDidInvalidateSize(_ lineController: LineController) {
        lineFragmentLayoutManager.setNeedsLayout()
        lineSelectionLayoutManager.setNeedsLayout()
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
