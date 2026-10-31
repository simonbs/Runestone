// swiftlint:disable file_length
import Combine
import RunestoneEngine
import UIKit

protocol TextInputViewDelegate: AnyObject {
    func textInputViewWritingToolsWillPresent(_ view: TextInputView)
    func textInputViewWritingToolsDidDismiss(_ view: TextInputView)
    func textInputViewWritingToolsWillBegin(_ view: TextInputView)
    func textInputViewWritingToolsDidEnd(_ view: TextInputView)
    func textInputViewWillBeginEditing(_ view: TextInputView)
    func textInputViewDidBeginEditing(_ view: TextInputView)
    func textInputViewDidEndEditing(_ view: TextInputView)
    func textInputViewDidCancelBeginEditing(_ view: TextInputView)
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputView(_ view: TextInputView, shouldCheckSpellingIn range: NSRange) -> Bool
    func textInputViewWillBeginFoldingTransition(_ view: TextInputView)
    func textInputViewDidFinishFoldingTransition(_ view: TextInputView, animated: Bool)
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func textInputViewDidChangeGutterWidth(_ view: TextInputView)
    func textInputViewDidBeginFloatingCursor(_ view: TextInputView)
    func textInputViewDidEndFloatingCursor(_ view: TextInputView)
    func textInputViewDidUpdateMarkedRange(_ view: TextInputView)
    func textInputView(_ view: TextInputView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool
    func textInputView(_ view: TextInputView, replaceTextIn highlightedRange: HighlightedRange)
}

// MARK: - Code Folding
extension TextInputView {
    func refreshCodeFolding(synchronously: Bool = false) {
        guard isCodeFoldingEnabled else {
            return
        }
        foldingRevision &+= 1
        let revision = foldingRevision
        let mode = languageMode
        let apply: ([TreeSitterFoldingRange]) -> Void = { [weak self, weak mode] ranges in
            guard let self = self, let mode = mode, self.isCodeFoldingEnabled,
                  self.foldingRevision == revision, self.languageMode === mode else { return }
            self.foldingController.update(ranges, lineCount: self.lineManager.lineCount)
            self.applyFoldingProjection()
        }
        if synchronously { apply(mode.foldingRanges()) } else { mode.foldingRanges(completion: apply) }
    }

    func toggleFold(atRow row: Int, animated: Bool = true) {
        guard isCodeFoldingEnabled, !isWritingToolsActive,
              let range = foldingController.rangesByRow[row], !lineManager.isLineHidden(row) else { return }
        let firstHidden = lineManager.line(atRow: range.hiddenStartRow)
        let lastHidden = lineManager.line(atRow: range.endRow)
        let hiddenRange = NSRange(location: firstHidden.location,
                                  length: lastHidden.location + lastHidden.data.totalLength - firstHidden.location)
        if let markedRange = markedRange, NSIntersectionRange(markedRange, hiddenRange).length > 0 {
            return
        }
        let mutationVersion = textMutationVersion
        let originalLineManager = lineManager
        let isCollapsing = !foldingController.collapsedRanges.contains(range)
        if isCollapsing, let selection = selectedRange,
           hiddenRange.contains(selection.lowerBound) || hiddenRange.contains(selection.upperBound) {
            let anchor = lineManager.line(atRow: row)
            selectedRange = NSRange(location: anchor.location + anchor.data.length, length: 0)
        }
        guard textMutationVersion == mutationVersion, lineManager === originalLineManager,
              isCodeFoldingEnabled, foldingController.rangesByRow[row] == range else { return }
        layoutManager.cancelFoldingAnimation()
        delegate?.textInputViewWillBeginFoldingTransition(self)
        layoutManager.animateFoldingChange(atRow: row, animated: animated, changes: {
            _ = self.foldingController.toggle(at: row)
            if animated, self.window != nil {
                let feedback = isCollapsing ? self.collapseFeedback : self.expandFeedback
                feedback.impactOccurred(intensity: 0.5)
            }
            self.applyFoldingProjection()
            self.layoutManager.layoutIfNeeded()
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }, completion: { [weak self] animated in
            guard let self = self else {
                return
            }
            self.delegate?.textInputViewDidFinishFoldingTransition(self, animated: animated)
        })
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }

    private func resetCodeFolding() {
        foldingRevision &+= 1
        layoutManager.cancelFoldingAnimation()
        delegate?.textInputViewDidFinishFoldingTransition(self, animated: false)
        foldingController.reset()
        lineManager.setCollapsedLineRanges([])
        layoutManager.foldingRanges = [:]
        layoutManager.collapsedFoldRows = []
    }

    private func applyFoldingProjection() {
        lineManager.setCollapsedLineRanges(isCodeFoldingEnabled ? foldingController.hiddenLineRanges : [])
        layoutManager.foldingRanges = isCodeFoldingEnabled ? foldingController.rangesByRow : [:]
        layoutManager.collapsedFoldRows = Set(foldingController.collapsedRanges.map(\.startRow))
        contentSizeService.invalidateContentSize()
        layoutManager.setNeedsLayout()
        layoutManager.setNeedsLayoutLineSelection()
        setNeedsLayout()
    }

    private func finishFoldingEdit(_ change: TextChange) {
        guard isCodeFoldingEnabled else {
            isApplyingFoldingEdit = false
            return
        }
        foldingController.apply(change)
        applyFoldingProjection()
        isApplyingFoldingEdit = false
        refreshCodeFolding()
    }

    private func revealFoldedRange(_ range: NSRange) {
        guard isCodeFoldingEnabled, !foldingController.collapsedRanges.isEmpty else {
            return
        }
        var changed = false
        for location in [range.lowerBound, range.upperBound] {
            if let line = lineManager.line(containingCharacterAt: location) {
                if foldingController.reveal(row: line.index) { changed = true }
            }
        }
        if changed {
            layoutManager.cancelFoldingAnimation()
            applyFoldingProjection()
        }
    }
}

extension TextInputViewDelegate {
    func textInputView(_ view: TextInputView, shouldCheckSpellingIn range: NSRange) -> Bool {
        true
    }
    func textInputViewWritingToolsWillPresent(_ view: TextInputView) {}
    func textInputViewWritingToolsDidDismiss(_ view: TextInputView) {}
    func textInputViewWritingToolsWillBegin(_ view: TextInputView) {}
    func textInputViewWritingToolsDidEnd(_ view: TextInputView) {}
}

// swiftlint:disable:next type_body_length
final class TextInputView: UIView, UITextInput {
    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = _selectedRange {
                return IndexedRange(range)
            } else {
                return nil
            }
        }
        set {
            // We should not use this setter. It's intended for UIKit to use. It'll invoke the setter in various scenarios, for example when navigating the text using the keyboard.
            // On the iOS 16 beta, UIKit may pass an NSRange with a negatives length (e.g. {4, -2}) when double tapping to select text. This will cause a crash when UIKit later attempts to use the selected range with NSString's -substringWithRange:. This can be tested with a string containing the following three lines:
            //    A
            //
            //    A
            // Placing the character on the second line, which is empty, and double tapping several times on the empty line to select text will cause the editor to crash. To work around this we take the non-negative value of the selected range. Last tested on August 30th, 2022.
            let newRange = (newValue as? IndexedRange)?.range.nonNegativeLength
            if newRange != _selectedRange {
                notifyDelegateAboutSelectionChangeInLayoutSubviews = true
                // The logic for determining whether or not to notify the input delegate is based on advice provided by Alexander Blach, developer of Textastic.
                var shouldNotifyInputDelegate = false
                if didCallPositionFromPositionInDirectionWithOffset {
                    shouldNotifyInputDelegate = true
                    didCallPositionFromPositionInDirectionWithOffset = false
                }
                // This is a consequence of our workaround that ensures multi-stage input, such as when entering Korean,
                // works correctly. The workaround causes bugs when selecting words using Shift + Option + Arrow Keys
                // followed by Shift + Arrow Keys if we do not treat it as a special case.
                // The consequence of not having this workaround is that Shift + Arrow Keys may adjust the wrong end of
                // the selected text when followed by navigating between word boundaries usign Shift + Option + Arrow Keys.
                if customTokenizer.didCallPositionFromPositionToWordBoundary && !didCallDeleteBackward {
                    shouldNotifyInputDelegate = true
                    customTokenizer.didCallPositionFromPositionToWordBoundary = false
                }
                didCallDeleteBackward = false
                notifyInputDelegateAboutSelectionChangeInLayoutSubviews = !shouldNotifyInputDelegate
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionWillChange(self)
                }
                _selectedRange = newRange
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionDidChange(self)
                }
            }
        }
    }
    private(set) var markedTextRange: UITextRange? {
        get {
            if let markedRange = markedRange {
                return IndexedRange(markedRange)
            } else {
                return nil
            }
        }
        set {
            markedRange = (newValue as? IndexedRange)?.range.nonNegativeLength
        }
    }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition {
        IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        IndexedPosition(index: string.length)
    }
    weak var inputDelegate: UITextInputDelegate?
    var hasText: Bool {
        string.length > 0
    }
    var tokenizer: UITextInputTokenizer {
        customTokenizer
    }
    private lazy var customTokenizer = TextInputStringTokenizer(textInput: self,
                                                                stringView: stringView,
                                                                lineManager: lineManager,
                                                                lineControllerStorage: lineControllerStorage)
    var autocorrectionType: UITextAutocorrectionType = .default {
        didSet { invalidateSpellChecking() }
    }
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var smartQuotesType: UITextSmartQuotesType = .default
    var smartDashesType: UITextSmartDashesType = .default
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    // Runestone owns spelling decorations and actions. UIKit's built-in correction popup uses a private replacement object.
    // Keep that popup disabled independently of the public spelling preference and keyboard autocorrection.
    var spellCheckingType: UITextSpellCheckingType = .no
    var preferredSpellCheckingType: UITextSpellCheckingType = .default {
        didSet { invalidateSpellChecking() }
    }
    var showIgnoreSpellingAction = false {
        didSet { invalidateSpellChecking() }
    }
    var showLearnSpellingAction = false {
        didSet { invalidateSpellChecking() }
    }
    var showUnlearnSpellingAction = false {
        didSet { invalidateSpellChecking() }
    }
    var spellCheckingLanguage: String? {
        didSet { invalidateSpellChecking() }
    }
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
#if compiler(>=6.0) && (!os(visionOS) || compiler(>=6.1))
    // Runestone only accepts plain text, even when Writing Tools generates replacements.
    @available(iOS 18.0, visionOS 2.4, *)
    var allowedWritingToolsResultOptions: UIWritingToolsResultOptions {
        get {
            if let rawValue = writingToolsResultOptionsRawValue {
                return UIWritingToolsResultOptions(rawValue: rawValue)
            }
            return .plainText
        }
        set {
            writingToolsResultOptionsRawValue = newValue.rawValue
        }
    }
    private var writingToolsResultOptionsRawValue: UInt?
#endif
#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
    @available(iOS 18.0, visionOS 2.4, *)
    var writingToolsBehavior: UIWritingToolsBehavior {
        get { UIWritingToolsBehavior(rawValue: preferredWritingToolsBehavior) ?? .complete }
        set {
            stopWritingTools()
            preferredWritingToolsBehavior = newValue.rawValue
            if #available(iOS 18.2, visionOS 2.4, *) {
                (writingToolsController as? WritingToolsInteraction)?.coordinator.preferredBehavior = newValue
            }
        }
    }
#endif
    private var preferredWritingToolsBehavior = 1
    var writingToolsExcludedRangesProvider: ((String) -> [NSRange])? {
        didSet { stopWritingTools() }
    }
    func writingToolsExcludedRanges() -> [NSRange] {
        let text = string
        return WritingToolsExclusions.normalizedRanges(writingToolsExcludedRangesProvider?(text as String) ?? [], in: text)
    }
    private func allowsWritingToolsReplacement(in range: NSRange, with text: String) -> Bool {
        WritingToolsExclusions.allowsReplacement(in: range, with: text, in: string, excluding: writingToolsExcludedRanges())
    }

    var isEditableForSystemTextReplacement = true
    var writingToolsController: WritingToolsControlling?
    private(set) var isWritingToolsActive = false
    private(set) var isWritingToolsPresented = false

    // Explicit Objective-C exposure also preserves the selectors when building with an older SDK.
    @objc func willPresentWritingTools() {
        guard !isWritingToolsPresented else {
            return
        }
        isWritingToolsPresented = true
        delegate?.textInputViewWritingToolsWillPresent(self)
    }

    @objc func didDismissWritingTools() {
        guard isWritingToolsPresented else {
            return
        }
        isWritingToolsPresented = false
        delegate?.textInputViewWritingToolsDidDismiss(self)
    }

    private(set) var isApplyingSystemTextReplacement = false
    private(set) var textMutationVersion: UInt = 0
    private(set) var writingToolsContextVersion: UInt = 0
    private var textBeforeWritingTools: NSString?
    private var selectionBeforeWritingTools: NSRange?

    func stopWritingTools() {
        invalidateWritingToolsContext()
        writingToolsController?.stop()
    }

    func invalidateWritingToolsContext() {
        writingToolsContextVersion &+= 1
    }

    private func stopWritingToolsBeforeEditing() -> Bool {
        let originalVersion = textMutationVersion
        stopWritingTools()
        return textMutationVersion == originalVersion
    }

    func setWritingToolsActive(_ active: Bool) {
        guard active != isWritingToolsActive else {
            return
        }
        invalidateSpellChecking()
        if active {
            timedUndoManager.endUndoGrouping()
            textBeforeWritingTools = string.copy() as? NSString
            selectionBeforeWritingTools = selectedRange
            isWritingToolsActive = true
            delegate?.textInputViewWritingToolsWillBegin(self)
        } else {
            checkpointWritingToolsUndo()
            textBeforeWritingTools = nil
            selectionBeforeWritingTools = nil
            isWritingToolsActive = false
            delegate?.textInputViewWritingToolsDidEnd(self)
        }
    }

    /// Commit suggestions before a user edit, keeping their undo history separate from typing.
    /// A session may contain several checkpoints, but no-op/reverted suggestions add no undo step.
    private func checkpointWritingToolsUndo() {
        guard isWritingToolsActive, let original = textBeforeWritingTools else {
            return
        }
        if let change = WritingToolsRange.change(from: string, to: original) {
            timedUndoManager.endUndoGrouping()
            addUndoOperation(replacing: change.range, withText: change.text,
                             selectedRangeAfterUndo: selectionBeforeWritingTools)
            timedUndoManager.endUndoGrouping()
        }
        resetWritingToolsUndoBaseline()
    }

    private func resetWritingToolsUndoBaseline() {
        guard isWritingToolsActive else {
            return
        }
        textBeforeWritingTools = string.copy() as? NSString
        selectionBeforeWritingTools = selectedRange
    }

    @objc var insertionPointColor: UIColor = .label {
        didSet {
            if insertionPointColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionBarColor: UIColor = .label {
        didSet {
            if selectionBarColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionHighlightColor: UIColor = .label.withAlphaComponent(0.2) {
        didSet {
            if selectionHighlightColor != oldValue {
                updateCaretColor()
            }
        }
    }
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                layoutManager.isEditing = isEditing
                setNeedsLayout()
            }
        }
    }
    override var undoManager: UndoManager? {
        timedUndoManager
    }

    // MARK: - Appearance
    var theme: Theme {
        didSet {
            applyThemeToChildren()
        }
    }
    var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
                caretRectService.showLineNumbers = showLineNumbers
                gutterWidthService.showLineNumbers = showLineNumbers
                layoutManager.showLineNumbers = showLineNumbers
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var isCodeFoldingEnabled = false {
        didSet {
            guard isCodeFoldingEnabled != oldValue else {
                return
            }
            resetCodeFolding()
            layoutManager.isCodeFoldingEnabled = isCodeFoldingEnabled
            gutterWidthService.isCodeFoldingEnabled = isCodeFoldingEnabled
            applyFoldingProjection()
            if isCodeFoldingEnabled { refreshCodeFolding() }
        }
    }
    let foldingController = CodeFoldingController()
    private lazy var collapseFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var expandFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var foldingRevision: UInt = 0
    private var isApplyingFoldingEdit = false
    var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            layoutManager.lineSelectionDisplayType
        }
        set {
            layoutManager.lineSelectionDisplayType = newValue
        }
    }
    var showTabs: Bool {
        get {
            invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != invisibleCharacterConfiguration.showTabs {
                invisibleCharacterConfiguration.showTabs = newValue
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
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
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
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
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var indentStrategy: IndentStrategy = .tab(length: 2) {
        didSet {
            if indentStrategy != oldValue {
                indentController.indentStrategy = indentStrategy
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
    }
    var gutterLeadingPadding: CGFloat = 3 {
        didSet {
            if gutterLeadingPadding != oldValue {
                gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var gutterTrailingPadding: CGFloat = 3 {
        didSet {
            if gutterTrailingPadding != oldValue {
                gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var gutterMinimumCharacterCount: Int = 1 {
        didSet {
            if gutterMinimumCharacterCount != oldValue {
                gutterWidthService.gutterMinimumCharacterCount = gutterMinimumCharacterCount
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var textContainerInset: UIEdgeInsets {
        get {
            layoutManager.textContainerInset
        }
        set {
            if newValue != layoutManager.textContainerInset {
                let textInsets = TextInsets(top: newValue.top, left: newValue.left,
                                            bottom: newValue.bottom, right: newValue.right)
                caretRectService.textContainerInset = textInsets
                selectionRectService.textContainerInset = textInsets
                contentSizeService.textContainerInset = textInsets
                layoutManager.textContainerInset = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var isLineWrappingEnabled: Bool {
        get {
            layoutManager.isLineWrappingEnabled
        }
        set {
            if newValue != layoutManager.isLineWrappingEnabled {
                contentSizeService.isLineWrappingEnabled = newValue
                layoutManager.isLineWrappingEnabled = newValue
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }
    var lineBreakMode: LineBreakMode = .byWordWrapping {
        didSet {
            if lineBreakMode != oldValue {
                invalidateLines()
                contentSizeService.invalidateContentSize()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }
    var gutterWidth: CGFloat {
        gutterWidthService.gutterWidth
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                selectionRectService.lineHeightMultiplier = lineHeightMultiplier
                layoutManager.lineHeightMultiplier = lineHeightMultiplier
                invalidateLines()
                lineManager.estimatedLineHeight = estimatedLineHeight
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var kern: CGFloat = 0 {
        didSet {
            if kern != oldValue {
                invalidateLines()
                pageGuideController.kern = kern
                contentSizeService.invalidateContentSize()
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var characterPairs: [CharacterPair] = [] {
        didSet {
            maximumLeadingCharacterPairComponentLength = characterPairs.map(\.leading.utf16.count).max() ?? 0
        }
    }
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var showPageGuide = false {
        didSet {
            if showPageGuide != oldValue {
                if showPageGuide {
                    addSubview(pageGuideController.guideView)
                    sendSubviewToBack(pageGuideController.guideView)
                    setNeedsLayout()
                } else {
                    pageGuideController.guideView.removeFromSuperview()
                    setNeedsLayout()
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
                setNeedsLayout()
            }
        }
    }
    private var estimatedLineHeight: CGFloat {
        theme.font.totalLineHeight * lineHeightMultiplier
    }
    var highlightedRanges: [HighlightedRange] {
        get {
            highlightService.highlightedRanges
        }
        set {
            if newValue != highlightService.highlightedRanges {
                highlightService.highlightedRanges = newValue
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSString {
        get {
            stringView.string
        }
        set {
            if newValue != stringView.string {
                stopWritingTools()
                resetCodeFolding()
                textMutationVersion &+= 1
                invalidateSpellChecking()
                stringView.string = newValue
                languageMode.parse(newValue)
                // Rebuilding creates new line IDs. Release controllers and pending highlighting for the old lines.
                lineControllerStorage.removeAllLineControllers()
                lineManager.rebuild()
                refreshCodeFolding()
                if let oldSelectedRange = selectedRange {
                    inputDelegate?.selectionWillChange(self)
                    selectedRange = safeSelectionRange(from: oldSelectedRange)
                    inputDelegate?.selectionDidChange(self)
                }
                contentSizeService.invalidateContentSize()
                gutterWidthService.invalidateLineNumberWidth()
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    undoManager?.removeAllActions()
                }
            }
        }
    }
    var viewport: CGRect {
        get {
            layoutManager.viewport
        }
        set {
            if newValue != layoutManager.viewport {
                layoutManager.cancelFoldingAnimation()
                layoutManager.viewport = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var scrollViewWidth: CGFloat = 0 {
        didSet {
            if scrollViewWidth != oldValue {
                contentSizeService.scrollViewWidth = scrollViewWidth
                layoutManager.scrollViewWidth = scrollViewWidth
                if isLineWrappingEnabled {
                    invalidateLines()
                }
            }
        }
    }
    var contentSize: CGSize {
        contentSizeService.contentSize
    }
    var selectedRange: NSRange? {
        get {
            _selectedRange
        }
        set {
            if newValue != _selectedRange {
                _selectedRange = newValue
                delegate?.textInputViewDidChangeSelection(self)
            }
        }
    }
    private var _selectedRange: NSRange? {
        didSet {
            if _selectedRange != oldValue {
                if !isApplyingFoldingEdit, let range = _selectedRange { revealFoldedRange(range) }
                layoutManager.selectedRange = _selectedRange
                layoutManager.setNeedsLayoutLineSelection()
                setNeedsLayout()
            }
        }
    }
    override var canBecomeFirstResponder: Bool {
        true
    }
    weak var gutterParentView: UIView? {
        get {
            layoutManager.gutterParentView
        }
        set {
            layoutManager.gutterParentView = newValue
        }
    }
    var scrollViewSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            if scrollViewSafeAreaInsets != oldValue {
                layoutManager.safeAreaInsets = scrollViewSafeAreaInsets
            }
        }
    }
    var gutterContainerView: UIView {
        layoutManager.gutterContainerView
    }
    private(set) var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                caretRectService.stringView = stringView
                lineManager.stringView = stringView
                lineControllerFactory.stringView = stringView
                lineControllerStorage.stringView = stringView
                layoutManager.stringView = stringView
                indentController.stringView = stringView
                lineMovementController.stringView = stringView
                customTokenizer.stringView = stringView
            }
        }
    }
    private(set) var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                indentController.lineManager = lineManager
                lineMovementController.lineManager = lineManager
                gutterWidthService.lineManager = lineManager
                contentSizeService.lineManager = lineManager
                caretRectService.lineManager = lineManager
                selectionRectService.lineManager = lineManager
                highlightService.lineManager = lineManager
                customTokenizer.lineManager = lineManager
            }
        }
    }
    var viewHierarchyContainsCaret: Bool {
        textSelectionView?.subviews.count == 1
    }
    var lineEndings: LineEnding = .lf
    private(set) var isRestoringPreviouslyDeletedText = false
    private(set) var isUpdatingMarkedText = false

    // MARK: - Private
    private var languageMode: InternalLanguageMode = PlainTextInternalLanguageMode() {
        didSet {
            if languageMode !== oldValue {
                indentController.languageMode = languageMode
                if let treeSitterLanguageMode = languageMode as? TreeSitterInternalLanguageMode {
                    treeSitterLanguageMode.delegate = self
                }
            }
        }
    }
    private let lineControllerFactory: LineControllerFactory
    private let lineControllerStorage: LineControllerStorage
    private let layoutManager: LayoutManager
    private let timedUndoManager = TimedUndoManager()
    private let indentController: IndentController
    private let lineMovementController: LineMovementController
    private let pageGuideController = PageGuideController()
    private let gutterWidthService: GutterWidthService
    private let contentSizeService: ContentSizeService
    private let caretRectService: CaretRectService
    private let selectionRectService: SelectionRectService
    private let highlightService: HighlightService
    private let invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    private var markedRange: NSRange? {
        get {
            layoutManager.markedRange
        }
        set {
            if layoutManager.markedRange != newValue {
                invalidateSpellChecking()
            }
            layoutManager.markedRange = newValue
        }
    }
    private var floatingCaretView: FloatingCaretView?
    private var insertionPointColorBeforeFloatingBegan: UIColor = .label
    private var maximumLeadingCharacterPairComponentLength = 0
    private var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            return subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }
    private var hasPendingFullLayout = false
    private let editMenuController = EditMenuController()
    private let spellCheckingService = SpellCheckingService()
    private var spellingRevision: UInt = 0
    private var lastSpellingRequest: SpellingRequest?
    private var lastLegacySpellingRequest: LegacySpellingRequest?
    private var notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
    private var notifyDelegateAboutSelectionChangeInLayoutSubviews = false
    private var didCallPositionFromPositionInDirectionWithOffset = false
    private var didCallDeleteBackward = false
    private var hasDeletedTextWithPendingLayoutSubviews = false
    private var preserveUndoStackWhenSettingString = false
    private var cancellables: [AnyCancellable] = []

    // MARK: - Lifecycle
    // swiftlint:disable:next function_body_length
    init(theme: Theme) {
        self.theme = theme
        lineManager = LineManager(stringView: stringView)
        highlightService = HighlightService(lineManager: lineManager)
        lineControllerFactory = LineControllerFactory(stringView: stringView,
                                                      highlightService: highlightService,
                                                      invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        lineControllerStorage = LineControllerStorage(stringView: stringView, lineControllerFactory: lineControllerFactory)
        gutterWidthService = GutterWidthService(lineManager: lineManager)
        contentSizeService = ContentSizeService(lineManager: lineManager,
                                                lineControllerStorage: lineControllerStorage,
                                                gutterWidthService: gutterWidthService,
                                                invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        caretRectService = CaretRectService(stringView: stringView,
                                            lineManager: lineManager,
                                            lineControllerStorage: lineControllerStorage,
                                            gutterWidthService: gutterWidthService)
        selectionRectService = SelectionRectService(lineManager: lineManager,
                                                    contentSizeService: contentSizeService,
                                                    gutterWidthService: gutterWidthService,
                                                    caretRectService: caretRectService)
        layoutManager = LayoutManager(lineManager: lineManager,
                                      languageMode: languageMode,
                                      stringView: stringView,
                                      lineControllerStorage: lineControllerStorage,
                                      contentSizeService: contentSizeService,
                                      gutterWidthService: gutterWidthService,
                                      caretRectService: caretRectService,
                                      selectionRectService: selectionRectService,
                                      highlightService: highlightService,
                                      invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        indentController = IndentController(stringView: stringView,
                                            lineManager: lineManager,
                                            languageMode: languageMode,
                                            indentStrategy: indentStrategy,
                                            indentFont: theme.font)
        lineMovementController = LineMovementController(lineManager: lineManager,
                                                        stringView: stringView,
                                                        lineControllerStorage: lineControllerStorage)
        super.init(frame: .zero)
        applyThemeToChildren()
        indentController.delegate = self
        lineControllerStorage.delegate = self
        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
        layoutManager.delegate = self
        layoutManager.textInputView = self
        editMenuController.delegate = self
        editMenuController.setupEditMenu(in: self)
        observeSpellingLanguage()
        setupContentSizeObserver()
        setupGutterWidthObserver()
        setupWritingTools()
        layoutManager.onToggleFold = { [weak self] row in self?.toggleFold(atRow: row) }
    }

    private func setupWritingTools() {
        timedUndoManager.willUndoOrRedo = { [weak self] in self?.checkpointWritingToolsUndo() }
#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
        if #available(iOS 18.2, visionOS 2.4, *) {
            let interaction = WritingToolsInteraction(textInputView: self)
            writingToolsController = interaction
            addInteraction(interaction.coordinator)
        }
#endif
    }

    override func becomeFirstResponder() -> Bool {
        if canBecomeFirstResponder {
            delegate?.textInputViewWillBeginEditing(self)
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            invalidateSpellChecking()
            delegate?.textInputViewDidBeginEditing(self)
        } else {
            // This is called in the case where:
            // 1. The view is the first responder.
            // 2. A view is presented modally on top of the editor.
            // 3. The modally presented view is dismissed.
            // 4. The responder chain attempts to make the text view first responder again but super.becomeFirstResponder() returns false.
            delegate?.textInputViewDidCancelBeginEditing(self)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            delegate?.textInputViewDidEndEditing(self)
        }
        return didResignFirstResponder
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hasDeletedTextWithPendingLayoutSubviews = false
        layoutManager.layoutIfNeeded()
        layoutManager.layoutLineSelectionIfNeeded()
        layoutPageGuideIfNeeded()
        checkVisibleSpellingIfNeeded()
        updateLegacySpellingMenuIfNeeded()
        writingToolsController?.layoutDidChange()
        // We notify the input delegate about selection changes in layoutSubviews so we have a chance of disabling notifying the input delegate during an editing operation.
        // We will sometimes disable notifying the input delegate when the user enters Korean text.
        // This workaround is inspired by a dialog with Alexander Blach (@lextar), developer of Textastic.
        if notifyInputDelegateAboutSelectionChangeInLayoutSubviews {
            inputDelegate?.selectionWillChange(self)
            inputDelegate?.selectionDidChange(self)
        }
        if notifyDelegateAboutSelectionChangeInLayoutSubviews {
            notifyDelegateAboutSelectionChangeInLayoutSubviews = false
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    override func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    override func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: string)
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func cut(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: "")
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func selectAll(_ sender: Any?) {
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        selectedRange = NSRange(location: 0, length: string.length)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
            return selectedTextRange.map { !$0.isEmpty } ?? false
        } else if action == #selector(cut(_:)) {
            if let selectedTextRange = selectedTextRange {
                return isEditing && !selectedTextRange.isEmpty
            } else {
                return false
            }
        } else if action == #selector(paste(_:)) {
            return isEditing && UIPasteboard.general.hasStrings
        } else if action == #selector(selectAll(_:)) {
            return true
        } else if action == NSSelectorFromString("replace:") {
            // UIKit's legacy replacement object is private. Our spelling actions carry their own public data.
            return false
        } else if let index = EditMenuController.spellingActionSelectors.firstIndex(of: action) {
            return isEditing && editMenuController.hasLegacySpellingSuggestion(at: index)
        } else if let kind = SpellingWordAction.Kind.allCases.first(where: { $0.selector == action }) {
            return isEditing && isEditableForSystemTextReplacement && editMenuController.hasLegacySpellingWordAction(kind)
        } else if action == NSSelectorFromString("replaceTextInSelectedHighlightedRange") {
            if let selectedRange = selectedRange, let highlightedRange = highlightedRange(for: selectedRange) {
                return delegate?.textInputView(self, canReplaceTextIn: highlightedRange) ?? false
            } else {
                return false
            }
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        lineManager.linePosition(at: location)
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        stopWritingTools()
        resetCodeFolding()
        textMutationVersion &+= 1
        invalidateSpellChecking()
        let oldText = stringView.string
        let newText = state.stringView.string
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineControllerStorage.removeAllLineControllers()
        lineManager = state.lineManager
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.languageMode = state.languageMode
        layoutManager.lineManager = state.lineManager
        applyFoldingProjection()
        refreshCodeFolding()
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
            inputDelegate?.selectionWillChange(self)
            selectedRange = safeSelectionRange(from: oldSelectedRange)
            inputDelegate?.selectionDidChange(self)
        }
        if window != nil {
            performFullLayout()
        } else {
            hasPendingFullLayout = true
        }
    }

    func clearSelection() {
        selectedRange = nil
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            selectedRange = NSRange(location: index, length: 0)
        }
    }

    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        resetCodeFolding()
        applyFoldingProjection()
        let internalLanguageMode = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager)
        self.languageMode = internalLanguageMode
        layoutManager.languageMode = internalLanguageMode
        internalLanguageMode.parse(string) { [weak self] finished in
            if let self = self, finished {
                self.refreshCodeFolding()
                self.invalidateLines()
                self.layoutManager.setNeedsLayout()
                self.layoutManager.layoutIfNeeded()
                self.invalidateSpellChecking()
            }
            completion?(finished)
        }
    }

    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.linePosition(at: location) {
            return languageMode.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevel = languageMode.currentIndentLevel(of: line, using: indentStrategy)
        let indentString = indentStrategy.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        languageMode.detectIndentStrategy()
    }

    func textPreview(containing range: NSRange) -> TextPreview? {
        layoutManager.textPreview(containing: range)
    }

    func layoutLines(toLocation location: Int) {
        revealFoldedRange(NSRange(location: location, length: 0))
        layoutManager.layoutLines(toLocation: location)
    }

    func redisplayVisibleLines() {
        layoutManager.redisplayVisibleLines()
    }

    override func didMoveToWindow() {
        if window == nil {
            stopWritingTools()
            didDismissWritingTools()
        }
        super.didMoveToWindow()
        if hasPendingFullLayout && window != nil {
            hasPendingFullLayout = false
            performFullLayout()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // We end our current undo group when the user touches the view.
        let result = super.hitTest(point, with: event)
        if result === self {
            timedUndoManager.endUndoGrouping()
        }
        return result
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            invalidateLines()
            layoutManager.setNeedsLayout()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if let keyCode = presses.first?.key?.keyCode, presses.count == 1 {
            if markedRange != nil {
                handleKeyPressDuringMultistageTextInput(keyCode: keyCode)
            }
        }
    }
}

// MARK: - Theming
private extension TextInputView {
    private func applyThemeToChildren() {
        gutterWidthService.font = theme.lineNumberFont
        lineManager.estimatedLineHeight = estimatedLineHeight
        indentController.indentFont = theme.font
        pageGuideController.font = theme.font
        pageGuideController.guideView.hairlineWidth = theme.pageGuideHairlineWidth
        pageGuideController.guideView.hairlineColor = theme.pageGuideHairlineColor
        pageGuideController.guideView.backgroundColor = theme.pageGuideBackgroundColor
        layoutManager.theme = theme
    }
}

// MARK: - Navigation
private extension TextInputView {
    private func handleKeyPressDuringMultistageTextInput(keyCode: UIKeyboardHIDUsage) {
        // When editing multistage text input (that is, we have a marked text) we let the user unmark the text
        // by pressing the arrow keys or Escape. This isn't common in iOS apps but it's the default behavior
        // on macOS and I think that works quite well for plain text editors on iOS too.
        guard let markedRange = markedRange, let markedText = stringView.substring(in: markedRange) else {
            return
        }
        // We only unmark the text if the marked text contains specific characters only.
        // Some languages use multistage text input extensively and for those iOS presents a UI when
        // navigating with the arrow keys. We do not want to interfere with that interaction.
        let characterSet = CharacterSet(charactersIn: "`´^¨")
        guard markedText.rangeOfCharacter(from: characterSet.inverted) == nil else {
            return
        }
        switch keyCode {
        case .keyboardUpArrow:
            navigate(in: .up, offset: 1)
            unmarkText()
        case .keyboardRightArrow:
            navigate(in: .right, offset: 1)
            unmarkText()
        case .keyboardDownArrow:
            navigate(in: .down, offset: 1)
            unmarkText()
        case .keyboardLeftArrow:
            navigate(in: .left, offset: 1)
            unmarkText()
        case .keyboardEscape:
            unmarkText()
        default:
            break
        }
    }

    private func navigate(in direction: UITextLayoutDirection, offset: Int) {
        if let selectedRange = selectedRange {
            if let location = lineMovementController.location(from: selectedRange.location, in: direction, offset: offset) {
                self.selectedRange = NSRange(location: location, length: 0)
            }
        }
    }
}

// MARK: - Layout
private extension TextInputView {
    private func layoutPageGuideIfNeeded() {
        if showPageGuide {
            // The width extension is used to make the page guide look "attached" to the right hand side, even when the scroll view bouncing on the right side.
            let maxContentOffsetX = contentSizeService.contentWidth - viewport.width
            let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
            let xPosition = gutterWidthService.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
            let width = max(bounds.width - xPosition + widthExtension, 0)
            let orrigin = CGPoint(x: xPosition, y: viewport.minY)
            let pageGuideSize = CGSize(width: width, height: viewport.height)
            pageGuideController.guideView.frame = CGRect(origin: orrigin, size: pageGuideSize)
        }
    }

    private func performFullLayout() {
        invalidateLines()
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    private func invalidateLines() {
        for lineController in lineControllerStorage {
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = indentController.tabWidth
            lineController.kern = kern
            lineController.lineBreakMode = lineBreakMode
            lineController.invalidateSyntaxHighlighting()
        }
    }

    private func setupContentSizeObserver() {
        contentSizeService.$isContentSizeInvalid.filter { $0 }.sink { [weak self] _ in
            if let self = self {
                self.delegate?.textInputViewDidInvalidateContentSize(self)
            }
        }.store(in: &cancellables)
    }

    private func setupGutterWidthObserver() {
        gutterWidthService.didUpdateGutterWidth.sink { [weak self] in
            if let self = self {
                // Typeset lines again when the line number width changes since changing line number width may increase or reduce the number of line fragments in a line.
                self.setNeedsLayout()
                self.invalidateLines()
                self.layoutManager.setNeedsLayout()
                self.delegate?.textInputViewDidChangeGutterWidth(self)
            }
        }.store(in: &cancellables)
    }
}

// MARK: - Floating Caret
extension TextInputView {
    func beginFloatingCursor(at point: CGPoint) {
        if floatingCaretView == nil, let position = closestPosition(to: point) {
            insertionPointColorBeforeFloatingBegan = insertionPointColor
            insertionPointColor = insertionPointColorBeforeFloatingBegan.withAlphaComponent(0.5)
            updateCaretColor()
            let caretRect = self.caretRect(for: position)
            let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
            let floatingCaretView = FloatingCaretView()
            floatingCaretView.backgroundColor = insertionPointColorBeforeFloatingBegan
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
            addSubview(floatingCaretView)
            self.floatingCaretView = floatingCaretView
            delegate?.textInputViewDidBeginFloatingCursor(self)
        }
    }

    func updateFloatingCursor(at point: CGPoint) {
        if let floatingCaretView = floatingCaretView {
            let caretSize = floatingCaretView.frame.size
            let caretOrigin = CGPoint(x: point.x - caretSize.width / 2, y: point.y - caretSize.height / 2)
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretSize)
        }
    }

    func endFloatingCursor() {
        insertionPointColor = insertionPointColorBeforeFloatingBegan
        updateCaretColor()
        floatingCaretView?.removeFromSuperview()
        floatingCaretView = nil
        delegate?.textInputViewDidEndFloatingCursor(self)
    }

    private func updateCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView = textSelectionView {
            textSelectionView.removeFromSuperview()
            addSubview(textSelectionView)
        }
    }
}

// MARK: - Rects
extension TextInputView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? IndexedPosition else {
            fatalError("Expected position to be of type \(IndexedPosition.self)")
        }
        return caretRectService.caretRect(at: indexedPosition.index, allowMovingCaretToNextLineFragment: true)
    }

    func caretRect(at location: Int) -> CGRect {
        caretRectService.caretRect(at: location, allowMovingCaretToNextLineFragment: true)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        return layoutManager.firstRect(for: indexedRange.range)
    }
}

// MARK: - Editing
extension TextInputView {
    func insertText(_ text: String) {
        // A typed tab follows the indentation strategy. Replacement and pasted text retain literal tabs.
        let preparedText = text == "\t" ? indentStrategy.string(indentLevel: 1) : text
        isRestoringPreviouslyDeletedText = hasDeletedTextWithPendingLayoutSubviews
        hasDeletedTextWithPendingLayoutSubviews = false
        defer {
            isRestoringPreviouslyDeletedText = false
        }
        // If there is no marked range or selected range then we fallback to appending text to the end of our string.
        let selectedRange = markedRange ?? selectedRange ?? NSRange(location: stringView.string.length, length: 0)
        guard shouldChangeText(in: selectedRange, replacementText: preparedText) else {
            isRestoringPreviouslyDeletedText = false
            return
        }
        // If we're inserting text then we can't have a marked range. However, UITextInput doesn't always clear the marked range
        // before calling -insertText(_:), so we do it manually. This issue can be tested by entering a backtick (`) in an empty
        // document, then pressing any arrow key (up, right, down or left) followed by the return key.
        // The backtick will remain marked unless we manually clear the marked range.
        markedRange = nil
        replaceText(in: selectedRange, with: preparedText)
        layoutIfNeeded()
        delegate?.textInputViewDidChangeSelection(self)
    }

    /// Used only when the input source identifies a logical newline command.
    /// Generic UITextInput insertion is ambiguous and remains literal.
    @discardableResult
    func insertLogicalNewline() -> Bool {
        guard markedRange == nil, let selectedRange = selectedRange,
              let symbol = RunestoneLineEndingPolicy.newline(in: string, replacing: selectedRange),
              shouldChangeText(in: selectedRange, replacementText: symbol) else { return false }
        let previousVersion = textMutationVersion
        if let ending = LineEnding(symbol: symbol) {
            indentController.insertLineBreak(in: selectedRange, using: ending)
        } else {
            // Unicode separators cannot be represented by the legacy iOS
            // LineEnding enum, but must still be inserted without conversion.
            _ = replaceText(in: selectedRange, with: symbol)
        }
        guard textMutationVersion != previousVersion else { return false }
        layoutIfNeeded()
        delegate?.textInputViewDidChangeSelection(self)
        return true
    }

    func deleteBackward() {
        didCallDeleteBackward = true
        guard let selectedRange = markedRange ?? selectedRange, selectedRange.length > 0 else {
            return
        }
        let deleteRange = rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == markedRange {
            markedRange = nil
        }
        guard shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        // Set a flag indicating that we have deleted text. This is reset in -layoutSubviews() but if this has not been reset before insertText() is called, then UIKit deleted characters prior to inserting combined characters. This happens when UIKit turns Korean characters into a single character. E.g. when typing ㅇ followed by ㅓ UIKit will perform the following operations:
        // 1. Delete ㅇ.
        // 2. Delete the character before ㅇ. I'm unsure why this is needed.
        // 3. Insert the character that was previously before ㅇ.
        // 4. Insert the ㅇ and ㅓ but combined into the single character delete ㅇ and then insert 어.
        // We can detect this case in insertText() by checking if this variable is true.
        hasDeletedTextWithPendingLayoutSubviews = true
        // Disable notifying delegate in layout subviews to prevent sending the selected range with length > 0 when deleting text. This aligns with the behavior of UITextView and was introduced to resolve issue #158: https://github.com/simonbs/Runestone/issues/158
        notifyDelegateAboutSelectionChangeInLayoutSubviews = false
        // Disable notifying input delegate in layout subviews to prevent issues when entering Korean text. This workaround is inspired by a dialog with Alexander Black (@lextar), developer of Textastic.
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
        // Just before calling deleteBackward(), UIKit will set the selected range to a range of length 1, if the selected range has a length of 0.
        // In that case we want to undo to a selected range of length 0, so we construct our range here and pass it all the way to the undo operation.
        let selectedRangeAfterUndo: NSRange
        if deleteRange.length == 1 {
            selectedRangeAfterUndo = NSRange(location: selectedRange.upperBound, length: 0)
        } else {
            selectedRangeAfterUndo = selectedRange
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            timedUndoManager.endUndoGrouping()
            timedUndoManager.beginUndoGrouping()
        }
        replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRangeAfterUndo)
        // Sending selection changed without calling the input delegate directly. This ensures that both inputting Korean letters and deleting entire words with Option+Backspace works properly.
        sendSelectionChangedToTextSelectionView()
        if isDeletingMultipleCharacters {
            timedUndoManager.endUndoGrouping()
        }
        delegate?.textInputViewDidChangeSelection(self)
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range.nonNegativeLength, replacementText: text) {
            replaceText(in: indexedRange.range.nonNegativeLength, with: text)
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard stopWritingToolsBeforeEditing() else {
            return
        }
        guard !batchReplaceSet.replacements.isEmpty else {
            return
        }
        var oldLinePosition: LinePosition?
        if let oldSelectedRange = selectedRange {
            oldLinePosition = lineManager.linePosition(at: oldSelectedRange.location)
        }
        let textEditHelper = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: lineEndings)
        let newString = textEditHelper.string(byApplying: batchReplaceSet)
        setStringWithUndoAction(newString)
        if let oldLinePosition = oldLinePosition {
            // By restoring the selected range using the old line position we can better preserve the old selected language.
            moveCaret(to: oldLinePosition)
        }
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            let range = indexedRange.range.nonNegativeLength
            // UIKit can request an empty range, including the new paragraph after a trailing newline.
            if range.length == 0 && range.location >= 0 && range.location <= stringView.string.length {
                return ""
            }
            return text(in: range)
        } else {
            return nil
        }
    }

    func text(in range: NSRange) -> String? {
        stringView.substring(in: range)
    }

    private func setStringWithUndoAction(_ newString: NSString) {
        guard stopWritingToolsBeforeEditing() else {
            return
        }
        guard newString != string else {
            return
        }
        guard let oldString = stringView.string.copy() as? NSString else {
            return
        }
        // UndoManager owns the inverse group while undoing or redoing.
        let shouldManageUndoGroup = !timedUndoManager.isUndoing && !timedUndoManager.isRedoing
        if shouldManageUndoGroup {
            timedUndoManager.endUndoGrouping()
        }
        let oldSelectedRange = selectedRange
        preserveUndoStackWhenSettingString = true
        string = newString
        preserveUndoStackWhenSettingString = false
        if shouldManageUndoGroup {
            timedUndoManager.beginUndoGrouping()
        }
        timedUndoManager.setActionName(L10n.Undo.ActionName.replaceAll)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            textInputView.setStringWithUndoAction(oldString)
        }
        if shouldManageUndoGroup {
            timedUndoManager.endUndoGrouping()
        }
        delegate?.textInputViewDidChange(self)
        if let oldSelectedRange = oldSelectedRange {
            selectedRange = safeSelectionRange(from: oldSelectedRange)
        }
    }

    /// Applies a plain-text Writing Tools replacement through the normal editing pipeline.
    /// The returned string is the actual inserted text, preserving its line endings.
    func replaceTextForWritingTools(in range: NSRange, with text: String) -> String? {
        replaceTextFromSystem(in: range, with: text, isWritingToolsReplacement: true)
    }

    /// Shares validation, literal insertion, notifications, and undo boundaries between system editing features.
    private func replaceTextFromSystem(in range: NSRange, with text: String,
                                       isWritingToolsReplacement: Bool,
                                       isStillValid: () -> Bool = { true }) -> String? {
        guard isEditableForSystemTextReplacement, WritingToolsRange.isValid(range, in: string), markedTextRange == nil else {
            return nil
        }
        let originalVersion = textMutationVersion
        let originalContextVersion = writingToolsContextVersion
        let preparedText = text
        guard !isWritingToolsReplacement || allowsWritingToolsReplacement(in: range, with: preparedText),
              textMutationVersion == originalVersion, writingToolsContextVersion == originalContextVersion else {
            return nil
        }
        isApplyingSystemTextReplacement = true
        defer { isApplyingSystemTextReplacement = false }
        guard shouldChangeText(in: range, replacementText: preparedText), isStillValid() else {
            return nil
        }
        // A delegate may synchronously change the document while deciding whether to allow an edit.
        guard !isWritingToolsReplacement || allowsWritingToolsReplacement(in: range, with: preparedText),
              isEditableForSystemTextReplacement, markedTextRange == nil,
              writingToolsContextVersion == originalContextVersion,
              textMutationVersion == originalVersion, WritingToolsRange.isValid(range, in: string) else {
            return nil
        }
        timedUndoManager.endUndoGrouping()
        inputDelegate?.textWillChange(self)
        inputDelegate?.selectionWillChange(self)
        let canReplace = (!isWritingToolsReplacement || allowsWritingToolsReplacement(in: range, with: preparedText))
            && isEditableForSystemTextReplacement && markedTextRange == nil
            && writingToolsContextVersion == originalContextVersion && textMutationVersion == originalVersion && isStillValid()
        let didReplace = canReplace && replaceText(in: range, with: preparedText, selectedRangeAfterUndo: selectedRange,
                                                   isWritingToolsReplacement: isWritingToolsReplacement)
        timedUndoManager.endUndoGrouping()
        inputDelegate?.textDidChange(self)
        inputDelegate?.selectionDidChange(self)
        if didReplace {
            delegate?.textInputViewDidChangeSelection(self)
        }
        return didReplace ? preparedText : nil
    }

    func writingToolsTextRects(in range: NSRange) -> [CGRect] {
        layoutIfNeeded()
        return layoutManager.writingToolsTextRects(in: range)
    }

    func setWritingToolsHiddenRanges(_ ranges: [NSRange]) {
        layoutManager.writingToolsHiddenRanges = ranges
    }

    func drawWritingToolsText(in context: CGContext) {
        layoutManager.drawWritingToolsText(in: context)
    }

    private func rangeForDeletingText(in range: NSRange) -> NSRange {
        var resultingRange = range
        if range.length == 1, let indentRange = indentController.indentRangeInFrontOfLocation(range.upperBound) {
            resultingRange = indentRange
        } else {
            resultingRange = string.customRangeOfComposedCharacterSequences(for: range)
        }
        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
        if characterPairTrailingComponentDeletionMode == .immediatelyFollowingLeadingComponent
            && maximumLeadingCharacterPairComponentLength > 0
            && resultingRange.length <= maximumLeadingCharacterPairComponentLength {
            let stringToDelete = stringView.substring(in: resultingRange)
            if let characterPair = characterPairs.first(where: { $0.leading == stringToDelete }) {
                let trailingComponentLength = characterPair.trailing.utf16.count
                let trailingComponentRange = NSRange(location: resultingRange.upperBound, length: trailingComponentLength)
                if stringView.substring(in: trailingComponentRange) == characterPair.trailing {
                    let deleteRange = trailingComponentRange.upperBound - resultingRange.lowerBound
                    resultingRange = NSRange(location: resultingRange.lowerBound, length: deleteRange)
                }
            }
        }
        return resultingRange
    }

    @discardableResult
    private func replaceText(in range: NSRange,
                             with newString: String,
                             selectedRangeAfterUndo: NSRange? = nil,
                             undoActionName: String = L10n.Undo.ActionName.typing,
                             isWritingToolsReplacement: Bool = false) -> Bool {
        guard WritingToolsRange.isValid(range, in: string) else {
            return false
        }
        layoutManager.cancelFoldingAnimation()
        revealFoldedRange(range)
        lineManager.setCollapsedLineRanges([])
        if !isWritingToolsReplacement { checkpointWritingToolsUndo() }
        let previousText = writingToolsController?.hasContext == true ? string.copy() as? NSString : nil
        let previousVersion = textMutationVersion
        textMutationVersion &+= 1
        invalidateSpellChecking()
        let nsNewString = newString as NSString
        let currentText = text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsNewString.length)
        if !isWritingToolsActive || !isWritingToolsReplacement {
            addUndoOperation(replacing: newRange, withText: currentText, selectedRangeAfterUndo: selectedRangeAfterUndo, actionName: undoActionName)
        }
        isApplyingFoldingEdit = true
        defer { isApplyingFoldingEdit = false }
        _selectedRange = NSRange(location: newRange.upperBound, length: 0)
        let textEditHelper = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: lineEndings)
        let textEditResult = textEditHelper.replaceText(in: range, with: newString)
        let textChange = textEditResult.textChange
        let lineChangeSet = textEditResult.lineChangeSet
        let languageModeLineChangeSet = languageMode.textDidChange(textChange)
        finishFoldingEdit(textChange)
        lineChangeSet.union(with: languageModeLineChangeSet)
        applyLineChangesToLayoutManager(lineChangeSet)
        let updatedTextEditResult = TextEditResult(textChange: textChange, lineChangeSet: lineChangeSet)
        if !isWritingToolsReplacement {
            // Set the baseline before notifying UIKit: updateRange may synchronously end the session.
            resetWritingToolsUndoBaseline()
            if let previousText {
                writingToolsController?.textDidChange(in: range, replacementText: newString,
                                                      previousText: previousText, previousVersion: previousVersion,
                                                      isUndoOrRedo: timedUndoManager.isUndoing || timedUndoManager.isRedoing)
            }
            // A coordinator callback can synchronously switch documents. Do not emit an old edit for it.
            guard textMutationVersion == previousVersion &+ 1 else {
                return false
            }
        }
        delegate?.textInputViewDidChange(self)
        guard textMutationVersion == previousVersion &+ 1 else {
            return false
        }
        if updatedTextEditResult.didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
        return true
    }

    private func applyLineChangesToLayoutManager(_ lineChangeSet: LineChangeSet) {
        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            contentSizeService.invalidateContentSize()
            for removedLine in lineChangeSet.removedLines {
                lineControllerStorage.removeLineController(withID: removedLine.id)
                contentSizeService.removeLine(withID: removedLine.id)
            }
        }
        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
        layoutManager.redisplayLines(withIDs: editedLineIDs, allowingPrefixReuse: true)
        if didAddOrRemoveLines {
            gutterWidthService.invalidateLineNumberWidth()
        }
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        let version = textMutationVersion
        let contextVersion = writingToolsContextVersion
        let allowed = delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        return allowed && version == textMutationVersion && contextVersion == writingToolsContextVersion
    }

    private func addUndoOperation(replacing range: NSRange,
                                  withText text: String,
                                  selectedRangeAfterUndo: NSRange? = nil,
                                  actionName: String = L10n.Undo.ActionName.typing) {
        let oldSelectedRange = selectedRangeAfterUndo ?? selectedRange
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(actionName)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            let version = textInputView.textMutationVersion
            textInputView.inputDelegate?.selectionWillChange(textInputView)
            if textInputView.textMutationVersion == version, textInputView.replaceText(in: range, with: text) {
                textInputView.selectedRange = oldSelectedRange
                textInputView.resetWritingToolsUndoBaseline()
            }
            textInputView.inputDelegate?.selectionDidChange(textInputView)
        }
    }

}

// MARK: - Selection
extension TextInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? IndexedRange {
            return selectionRectService.selectionRects(in: indexedRange.range.nonNegativeLength).map(TextSelectionRect.init)
        } else {
            return []
        }
    }

    private func safeSelectionRange(from range: NSRange) -> NSRange {
        let stringLength = stringView.string.length
        let cappedLocation = min(max(range.location, 0), stringLength)
        let cappedLength = min(max(range.length, 0), stringLength - cappedLocation)
        return NSRange(location: cappedLocation, length: cappedLength)
    }

    private func moveCaret(to linePosition: LinePosition) {
        if linePosition.row < lineManager.lineCount {
            let line = lineManager.line(atRow: linePosition.row)
            let location = line.location + min(linePosition.column, line.data.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = nil
        }
    }

    private func sendSelectionChangedToTextSelectionView() {
        // The only way I've found to get the selection change to be reflected properly while still supporting Korean, Chinese, and deleting words with Option+Backspace is to call a private API in some cases. However, as pointed out by Alexander Blach in the following PR, there is another workaround to the issue.
        // When passing nil to the input delete, the text selection is update but the text input ignores it.
        // Even the Swift Playgrounds app does not get this right for all languages in all cases, so there seems to be some workarounds needed to due bugs in internal classes in UIKit that communicate with instances of UITextInput.
        inputDelegate?.selectionDidChange(nil)
    }
}

// MARK: - Indent and Outdent
extension TextInputView {
    func shiftLeft() {
        if let selectedRange = selectedRange {
            inputDelegate?.textWillChange(self)
            indentController.shiftLeft(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }

    func shiftRight() {
        if let selectedRange = selectedRange {
            inputDelegate?.textWillChange(self)
            indentController.shiftRight(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }
}

// MARK: - Move Lines
extension TextInputView {
    func moveSelectedLinesUp() {
        moveSelectedLine(byOffset: -1, undoActionName: L10n.Undo.ActionName.moveLinesUp)
    }

    func moveSelectedLinesDown() {
        moveSelectedLine(byOffset: 1, undoActionName: L10n.Undo.ActionName.moveLinesDown)
    }

    private func moveSelectedLine(byOffset lineOffset: Int, undoActionName: String) {
        guard stopWritingToolsBeforeEditing() else {
            return
        }
        guard let oldSelectedRange = selectedRange else {
            return
        }
        let moveLinesService = MoveLinesService(stringView: stringView, lineManager: lineManager, lineEndingSymbol: lineEndings.symbol)
        guard let operation = moveLinesService.operationForMovingLines(in: oldSelectedRange, byOffset: lineOffset) else {
            return
        }
        timedUndoManager.endUndoGrouping()
        timedUndoManager.beginUndoGrouping()
        defer { timedUndoManager.endUndoGrouping() }
        let versionBeforeRemoval = textMutationVersion
        guard replaceText(in: operation.removeRange, with: "", undoActionName: undoActionName),
              textMutationVersion == versionBeforeRemoval &+ 1 else {
            return
        }
        let versionBeforeInsertion = textMutationVersion
        guard replaceText(in: operation.replacementRange, with: operation.replacementString, undoActionName: undoActionName),
              textMutationVersion == versionBeforeInsertion &+ 1 else {
            return
        }
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        selectedRange = operation.selectedRange
    }
}

// MARK: - Marking
extension TextInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        guard stopWritingToolsBeforeEditing() else {
            return
        }
        guard let range = markedRange ?? self.selectedRange else {
            return
        }
        let markedText = markedText ?? ""
        isUpdatingMarkedText = true
        defer { isUpdatingMarkedText = false }
        guard shouldChangeText(in: range, replacementText: markedText) else {
            return
        }
        markedRange = markedText.isEmpty ? nil : NSRange(location: range.location, length: markedText.utf16.count)
        replaceText(in: range, with: markedText)
        // The selected range passed to setMarkedText(_:selectedRange:) is local to the marked range.
        let preferredSelectedRange = NSRange(location: range.location + selectedRange.location, length: selectedRange.length)
        inputDelegate?.selectionWillChange(self)
        _selectedRange = safeSelectionRange(from: preferredSelectedRange)
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidUpdateMarkedRange(self)
    }

    func unmarkText() {
        let hadMarkedText = markedRange != nil
        inputDelegate?.selectionWillChange(self)
        markedRange = nil
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidUpdateMarkedRange(self)
        if hadMarkedText {
            // Committing marked text changes its editing state even when its characters
            // stay the same. Match UITextView's final change notification.
            delegate?.textInputViewDidChange(self)
        }
    }
}

// MARK: - Ranges and Positions
extension TextInputView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        switch direction {
        case .left, .up:
            return IndexedPosition(index: indexedRange.range.lowerBound)
        case .right, .down:
            return IndexedPosition(index: indexedRange.range.upperBound)
        @unknown default:
            return nil
        }
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        didCallPositionFromPositionInDirectionWithOffset = true
        guard let newLocation = lineMovementController.location(from: indexedPosition.index, in: direction, offset: offset) else {
            return nil
        }
        return IndexedPosition(index: newLocation)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        switch direction {
        case .left, .up:
            let leftIndex = max(indexedPosition.index - 1, 0)
            return IndexedRange(location: leftIndex, length: indexedPosition.index - leftIndex)
        case .right, .down:
            let rightIndex = min(indexedPosition.index + 1, stringView.string.length)
            return IndexedRange(location: indexedPosition.index, length: rightIndex - indexedPosition.index)
        @unknown default:
            return nil
        }
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let index = layoutManager.closestIndex(to: point) else {
            return nil
        }
        let cappedIndex = max(index - 1, 0)
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: cappedIndex)
        return IndexedRange(range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = layoutManager.closestIndex(to: point) {
            return IndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        guard let index = layoutManager.closestIndex(to: point) else {
            return nil
        }
        let minimumIndex = indexedRange.range.lowerBound
        let maximumIndex = indexedRange.range.upperBound
        let cappedIndex = min(max(index, minimumIndex), maximumIndex)
        return IndexedPosition(index: cappedIndex)
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return IndexedRange(range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= string.length else {
            return nil
        }
        return IndexedPosition(index: newPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? IndexedPosition, let otherIndexedPosition = other as? IndexedPosition else {
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst may pass <uninitialized> to `position`. I'm not sure what the right way to deal with that is but returning .orderedSame seems to work.
            return .orderedSame
            #else
            fatalError("Positions must be of type \(IndexedPosition.self)")
            #endif
        }
        if indexedPosition.index < otherIndexedPosition.index {
            return .orderedAscending
        } else if indexedPosition.index > otherIndexedPosition.index {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }
}

// MARK: - Writing Direction
extension TextInputView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - UIEditMenuInteraction
extension TextInputView {
    func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        editMenuController.editMenu(for: textRange, suggestedActions: suggestedActions)
    }

    func presentEditMenuForText(in range: NSRange) {
        editMenuController.presentEditMenu(from: self, forTextIn: range)
    }

    @objc private func replaceTextInSelectedHighlightedRange() {
        if let selectedRange = selectedRange, let highlightedRange = highlightedRange(for: selectedRange) {
            delegate?.textInputView(self, replaceTextIn: highlightedRange)
        }
    }

    private func highlightedRange(for range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == range }
    }
}

// MARK: - TreeSitterLanguageModeDeleage
extension TextInputView: TreeSitterLanguageModeDelegate {
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

// MARK: - LineControllerStorageDelegate
extension TextInputView: LineControllerStorageDelegate {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController) {
        lineController.delegate = self
        lineController.constrainingWidth = layoutManager.constrainingLineWidth
        lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
        lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
        lineController.tabWidth = indentController.tabWidth
        lineController.theme = theme
        lineController.lineBreakMode = lineBreakMode
    }
}

// MARK: - LineControllerDelegate
extension TextInputView: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        languageMode.createLineSyntaxHighlighter()
    }

    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {
        setNeedsLayout()
        layoutManager.setNeedsLayout()
    }
}

// MARK: - LayoutManagerDelegate
extension TextInputView: LayoutManagerDelegate {
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        delegate?.textInputView(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
    }
}

// MARK: - IndentControllerDelegate
extension TextInputView: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) -> Bool {
        replaceText(in: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        let version = textMutationVersion
        inputDelegate?.selectionWillChange(self)
        if textMutationVersion == version { selectedRange = range }
        inputDelegate?.selectionDidChange(self)
        resetWritingToolsUndoBaseline()
    }

    func indentControllerDidUpdateTabWidth(_ controller: IndentController) {
        invalidateLines()
    }
}

// MARK: - EditMenuControllerDelegate
extension TextInputView: EditMenuControllerDelegate {
    func editMenuController(_ controller: EditMenuController, spellingSuggestionsFor range: NSRange) -> [SpellingSuggestion] {
        spellingSuggestions(in: range)
    }

    func editMenuController(_ controller: EditMenuController, spellingWordActionsFor range: NSRange) -> [SpellingWordAction] {
        spellingWordActions(in: range)
    }

    func editMenuController(_ controller: EditMenuController, perform action: SpellingWordAction) {
        performSpellingWordAction(action)
    }

    func editMenuController(_ controller: EditMenuController, replace suggestion: SpellingSuggestion) {
        replaceSpellingSuggestion(suggestion)
    }

    func editMenuController(_ controller: EditMenuController, caretRectAt location: Int) -> CGRect {
        caretRectService.caretRect(at: location, allowMovingCaretToNextLineFragment: false)
    }

    func editMenuControllerShouldReplaceText(_ controller: EditMenuController) {
        replaceTextInSelectedHighlightedRange()
    }

    func editMenuController(_ controller: EditMenuController, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        delegate?.textInputView(self, canReplaceTextIn: highlightedRange) ?? false
    }

    func editMenuController(_ controller: EditMenuController, highlightedRangeFor range: NSRange) -> HighlightedRange? {
        highlightedRange(for: range)
    }

    func selectedRange(for controller: EditMenuController) -> NSRange? {
        selectedRange
    }
}

// MARK: - Spelling
private struct SpellingRequest: Equatable {
    let visibleRanges: [NSRange]
    let language: String
    let excludedRanges: [NSRange]
}

private struct LegacySpellingRequest: Equatable {
    let selection: NSRange?
    let revision: UInt
}

extension TextInputView {
    private func observeSpellingLanguage() {
        for name in [UITextInputMode.currentInputModeDidChangeNotification, UIApplication.didBecomeActiveNotification,
                     SpellCheckingService.learnedWordsDidChangeNotification] {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] _ in self?.invalidateSpellChecking() }
                .store(in: &cancellables)
        }
    }

    func invalidateSpellChecking() {
        editMenuController.dismissSpellingMenu()
        spellingRevision &+= 1
        lastSpellingRequest = nil
        spellCheckingService.invalidate()
        layoutManager.misspelledRanges = []
        setNeedsLayout()
    }

    private var isSpellCheckingEnabled: Bool {
        !isWritingToolsActive && (preferredSpellCheckingType == .yes || (preferredSpellCheckingType == .default && autocorrectionType != .no))
    }

    private var resolvedSpellingLanguage: String? {
        let languages = UITextChecker.availableLanguages
        func match(_ preferred: String, allowsLanguageFallback: Bool) -> String? {
            let normalized = preferred.replacingOccurrences(of: "-", with: "_")
            if let exact = languages.first(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                return exact
            }
            guard allowsLanguageFallback, let base = normalized.split(separator: "_").first else {
                return nil
            }
            return languages.first { $0.split(separator: "_").first?.lowercased() == base.lowercased() }
        }
        if let language = spellCheckingLanguage {
            return match(language, allowsLanguageFallback: false)
        }
        let preferredLanguages = [textInputMode?.primaryLanguage].compactMap { $0 } + Locale.preferredLanguages
        return preferredLanguages.compactMap { match($0, allowsLanguageFallback: true) }.first ?? languages.first
    }

    private func checkVisibleSpellingIfNeeded() {
        guard isSpellCheckingEnabled, let language = resolvedSpellingLanguage,
              !layoutManager.visibleTextRanges.isEmpty else {
            if lastSpellingRequest != nil {
                spellCheckingService.invalidate()
                layoutManager.misspelledRanges = []
                lastSpellingRequest = nil
            }
            return
        }
        var excludedRanges = [markedRange].compactMap { $0 }
        if isEditing, let selection = selectedRange, selection.length == 0 {
            excludedRanges.append(selection)
        }
        let request = SpellingRequest(visibleRanges: layoutManager.visibleTextRanges, language: language, excludedRanges: excludedRanges)
        guard lastSpellingRequest != request else {
            return
        }
        lastSpellingRequest = request
        spellCheckingService.schedule(text: string, visibleRanges: request.visibleRanges, language: language,
                                      excludedRanges: excludedRanges, shouldCheck: { [weak self] range in
            guard let self = self else {
                return false
            }
            return self.delegate?.textInputView(self, shouldCheckSpellingIn: range) ?? true
        }, completion: { [weak self] ranges in
            self?.layoutManager.misspelledRanges = ranges
        })
    }

    private func updateLegacySpellingMenuIfNeeded() {
        if #available(iOS 16, *) {
            return
        }
        guard isFirstResponder else {
            lastLegacySpellingRequest = nil
            return
        }
        let request = LegacySpellingRequest(selection: selectedRange, revision: spellingRevision)
        guard request != lastLegacySpellingRequest else {
            return
        }
        lastLegacySpellingRequest = request
        editMenuController.updateLegacySpellingMenu()
    }

    func dismissSpellingMenu() {
        editMenuController.dismissSpellingMenu()
    }

    func presentSpellingMenu(at point: CGPoint) {
        guard isEditing, isEditableForSystemTextReplacement, isSpellCheckingEnabled, markedRange == nil,
              let selection = selectedRange, selection.length == 0,
              let position = closestPosition(to: point) else {
            return
        }
        // Probe both directions at character boundaries, then test actual rendered word geometry.
        for storageDirection in [UITextStorageDirection.backward, .forward] {
            let direction = UITextDirection(rawValue: storageDirection.rawValue)
            guard let word = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: direction) as? IndexedRange,
                  selection.location >= word.range.location, selection.location <= NSMaxRange(word.range),
                  let target = spellingTarget(in: word.range),
                  spellCheckingService.isMisspelled(for: word.range, in: string, language: target.language),
                  let rect = layoutManager.spellingRects(for: word.range).first(where: { $0.contains(point) }) else {
                continue
            }
            guard !spellingSuggestions(in: word.range).isEmpty || !spellingWordActions(in: word.range).isEmpty,
                  isCurrentSpellingSuggestion(target) else {
                return
            }
            selectedRange = word.range
            editMenuController.presentSpellingMenu(from: self, forTextIn: word.range, targetRect: rect)
            return
        }
    }

    var ignoredSpellingWords: [String] {
        spellCheckingService.ignoredWords
    }

    func ignoreSpellingWord(_ word: String) {
        spellCheckingService.ignoreWord(word)
        invalidateSpellChecking()
    }

    func resetIgnoredSpellingWords() {
        spellCheckingService.resetIgnoredWords()
        invalidateSpellChecking()
    }

    private func spellingTarget(in requestedRange: NSRange) -> SpellingSuggestion? {
        guard isEditing, isEditableForSystemTextReplacement, isSpellCheckingEnabled, markedRange == nil,
              WritingToolsRange.isValid(requestedRange, in: string), let language = resolvedSpellingLanguage else {
            return nil
        }
        var range = requestedRange
        if range.length == 0 {
            let position = IndexedPosition(index: range.location)
            let direction = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
            guard let word = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: direction) as? IndexedRange else {
                return nil
            }
            range = word.range
        }
        guard let original = spellCheckingService.word(for: range, in: string) else {
            return nil
        }
        let target = SpellingSuggestion(range: range, original: original, replacement: "", language: language,
                                        revision: spellingRevision, selection: selectedRange)
        guard delegate?.textInputView(self, shouldCheckSpellingIn: range) ?? true, isCurrentSpellingSuggestion(target) else {
            return nil
        }
        return target
    }

    func spellingSuggestions(in requestedRange: NSRange) -> [SpellingSuggestion] {
        guard let target = spellingTarget(in: requestedRange) else {
            return []
        }
        return spellCheckingService.suggestions(for: target.range, in: string, language: target.language).prefix(3).map { replacement in
            SpellingSuggestion(range: target.range, original: target.original, replacement: replacement, language: target.language,
                               revision: target.revision, selection: target.selection)
        }
    }

    func spellingWordActions(in requestedRange: NSRange) -> [SpellingWordAction] {
        guard let target = spellingTarget(in: requestedRange) else {
            return []
        }
        if SpellCheckingService.hasLearnedWord(target.original) {
            return showUnlearnSpellingAction ? [SpellingWordAction(kind: .unlearn, target: target)] : []
        }
        guard spellCheckingService.isMisspelled(for: target.range, in: string, language: target.language) else {
            return []
        }
        var actions: [SpellingWordAction] = []
        if showIgnoreSpellingAction {
            actions.append(SpellingWordAction(kind: .ignore, target: target))
        }
        if showLearnSpellingAction {
            actions.append(SpellingWordAction(kind: .learn, target: target))
        }
        return actions
    }

    func performSpellingWordAction(_ action: SpellingWordAction) {
        let target = action.target
        guard isCurrentSpellingSuggestion(target),
              delegate?.textInputView(self, shouldCheckSpellingIn: target.range) ?? true,
              isCurrentSpellingSuggestion(target) else {
            return
        }
        // Requery dictionary state even if another caller changed UITextChecker directly while the menu was open.
        let isLearned = SpellCheckingService.hasLearnedWord(target.original)
        if action.kind == .unlearn {
            guard isLearned else {
                return
            }
            SpellCheckingService.unlearnWord(target.original)
        } else {
            guard !isLearned, spellCheckingService.isMisspelled(for: target.range, in: string, language: target.language) else {
                return
            }
            switch action.kind {
            case .ignore:
                ignoreSpellingWord(target.original)
            case .learn:
                SpellCheckingService.learnWord(target.original)
            case .unlearn:
                break
            }
        }
    }

    func replaceSpellingSuggestion(_ suggestion: SpellingSuggestion) {
        guard isCurrentSpellingCorrection(suggestion),
              delegate?.textInputView(self, shouldCheckSpellingIn: suggestion.range) ?? true,
              isCurrentSpellingCorrection(suggestion) else {
            return
        }
        _ = replaceTextFromSystem(in: suggestion.range, with: suggestion.replacement, isWritingToolsReplacement: false) {
            self.isCurrentSpellingCorrection(suggestion)
        }
    }

    private func isCurrentSpellingCorrection(_ suggestion: SpellingSuggestion) -> Bool {
        isCurrentSpellingSuggestion(suggestion)
            && spellCheckingService.isMisspelled(for: suggestion.range, in: string, language: suggestion.language)
    }

    private func isCurrentSpellingSuggestion(_ suggestion: SpellingSuggestion) -> Bool {
        isEditing && isEditableForSystemTextReplacement && isSpellCheckingEnabled && markedRange == nil
            && suggestion.revision == spellingRevision && suggestion.language == resolvedSpellingLanguage
            && suggestion.selection == selectedRange && text(in: suggestion.range) == suggestion.original
    }

    @objc private func ignoreSelectedSpellingWord() {
        editMenuController.performLegacySpellingWordAction(.ignore)
    }

    @objc private func learnSelectedSpellingWord() {
        editMenuController.performLegacySpellingWordAction(.learn)
    }

    @objc private func unlearnSelectedSpellingWord() {
        editMenuController.performLegacySpellingWordAction(.unlearn)
    }

    @objc private func replaceWithFirstSpellingSuggestion() {
        editMenuController.replaceLegacySpellingSuggestion(at: 0)
    }

    @objc private func replaceWithSecondSpellingSuggestion() {
        editMenuController.replaceLegacySpellingSuggestion(at: 1)
    }

    @objc private func replaceWithThirdSpellingSuggestion() {
        editMenuController.replaceLegacySpellingSuggestion(at: 2)
    }
}
