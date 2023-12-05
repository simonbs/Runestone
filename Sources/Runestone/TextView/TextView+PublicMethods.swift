import Foundation

public extension TextView {
    /// Sets the current _state_ of the editor. The state contains the text to be displayed by the editor and
    /// various additional information about the text that the editor needs to show the text.
    ///
    /// It is safe to create an instance of <code>TextViewState</code> in the background, and as such it can be
    /// created before presenting the editor to the user, e.g. when opening the document from an instance of
    /// <code>UIDocumentBrowserViewController</code>.
    ///
    /// This is the preferred way to initially set the text, language and theme on the <code>TextView</code>.
    /// - Parameter state: The new state to be used by the editor.
    /// - Parameter addUndoAction: Whether the state change can be undone. Defaults to false.
//    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
//        textViewStateSetter.setState(state, addUndoAction: addUndoAction)
//    }

    /// Returns the row and column at the specified location in the text.
    /// Common usages of this includes showing the line and column that the caret is currently located at.
    /// - Parameter location: The location is relative to the first index in the string.
    /// - Returns: The text location if the input location could be found in the string, otherwise nil.
    func textLocation(at location: Int) -> TextLocation? {
//        textLocationConverter.textLocation(at: location)
        return nil
    }

    /// Returns the character location at the specified row and column.
    /// - Parameter textLocation: The row and column in the text.
    /// - Returns: The location if the input row and column could be found in the text, otherwise nil.
    func location(at textLocation: TextLocation) -> Int? {
//        textLocationConverter.location(at: textLocation)
        return nil
    }

    /// Sets the language mode on a background thread.
    ///
    /// - Parameters:
    ///   - languageMode: The new language mode to be used by the editor.
    ///   - completion: Called when the content have been parsed or when parsing fails.
    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
//        languageModeSetter.setLanguageMode(languageMode, completion: completion)
    }

    /// Replaces the text in the specified matches.
    /// - Parameters:
    ///   - batchReplaceSet: Set of ranges to replace with a text.
    func replaceText(in batchReplaceSet: BatchReplaceSet) {
//        batchReplacer.replaceText(in: batchReplaceSet)
    }

    /// Returns the syntax node at the specified location in the document.
    ///
    /// This can be used with character pairs to determine if a pair should be inserted or not.
    /// For example, a character pair consisting of two quotes (") to surround a string, should probably not be
    /// inserted when the quote is typed while the caret is already inside a string.
    ///
    /// This requires a language to be set on the editor.
    /// - Parameter location: A location in the document.
    /// - Returns: The syntax node at the location.
    func syntaxNode(at location: Int) -> SyntaxNode? {
//        syntaxNodeRaycaster.syntaxNode(at: location)
        return nil
    }

    /// Checks if the specified locations is within the indentation of the line.
    ///
    /// - Parameter location: A location in the document.
    /// - Returns: True if the location is within the indentation of the line, otherwise false.
    func isIndentation(at location: Int) -> Bool {
//        indentationChecker.isIndentation(at: location)
        return false
    }

    /// Decreases the indentation level of the selected lines.
    func shiftLeft() {
//        textShifter.shiftLeft()
    }

    /// Increases the indentation level of the selected lines.
    func shiftRight() {
//        textShifter.shiftRight()
    }

    /// Moves the selected lines up by one line.
    ///
    /// Calling this function has no effect when the selected lines include the first line in the text view.
    func moveSelectedLinesUp() {
//        lineMover.moveSelectedLinesUp()
    }

    /// Moves the selected lines down by one line.
    ///
    /// Calling this function has no effect when the selected lines include the last line in the text view.
    func moveSelectedLinesDown() {
//        lineMover.moveSelectedLinesDown()
    }

    /// Attempts to detect the indent strategy used in the document. This may return an unknown strategy even
    /// when the document contains indentation.
    func detectIndentStrategy() -> DetectedIndentStrategy {
//        languageMode.detectIndentStrategy()
        return .space(length: 2)
    }

    /// Go to the beginning of the line at the specified index.
    ///
    /// - Parameter lineIndex: Index of line to navigate to.
    /// - Parameter selection: The placement of the caret on the line.
    /// - Returns: True if the text view could navigate to the specified line index, otherwise false.
    @discardableResult
    func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
//        goToLineNavigator.goToLine(lineIndex, select: selection)
        return false
    }

    /// Search for the specified query.
    ///
    /// The code below shows how a ``SearchQuery`` can be constructed and passed to ``search(for:)``.
    ///
    /// ```swift
    /// let query = SearchQuery(text: "foo", matchMethod: .contains, isCaseSensitive: false)
    /// let results = textView.search(for: query)
    /// ```
    ///
    /// - Parameter query: Query to find matches for.
    /// - Returns: Results matching the query.
    func search(for query: SearchQuery) -> [SearchResult] {
//        searchService.search(for: query)
        return []
    }

    /// Search for the specified query and return results that take a replacement string into account.
    ///
    /// When searching for a regular expression this function will perform pattern matching and take the matched groups into account in the returned results.
    ///
    /// The code below shows how a ``SearchQuery`` can be constructed and passed to ``search(for:replacingMatchesWith:)`` and how the returned search results can be used to perform a replace operation.
    ///
    /// ```swift
    /// let query = SearchQuery(text: "foo", matchMethod: .contains, isCaseSensitive: false)
    /// let results = textView.search(for: query, replacingMatchesWith: "bar")
    /// let replacements = results.map { BatchReplaceSet.Replacement(range: $0.range, text: $0.replacementText) }
    /// let batchReplaceSet = BatchReplaceSet(replacements: replacements)
    /// textView.replaceText(in: batchReplaceSet)
    /// ```
    ///
    /// - Parameters:
    ///   - query: Query to find matches for.
    ///   - replacementString: String to replace matches with. Can refer to groups in a regular expression using $0, $1, $2 etc.
    /// - Returns: Results matching the query.
    func search(for query: SearchQuery, replacingMatchesWith replacementString: String) -> [SearchReplaceResult] {
//        searchService.search(for: query, replacingMatchesWith: replacementString)
        return []
    }

    /// Returns a peek into the text view's underlying attributed string.
    /// - Parameter range: Range of text to include in text view. The returned result may span a larger range than the one specified.
    /// - Returns: Text preview containing the specified range.
    func textPreview(containing range: NSRange) -> TextPreview? {
//        textPreviewFactory.textPreview(containing: range)
        return nil
    }

    /// Selects a highlighted range behind the selected range if possible.
    func selectPreviousHighlightedRange() {
//        highlightedRangeNavigator.selectPreviousRange()
    }

    /// Selects a highlighted range after the selected range if possible.
    func selectNextHighlightedRange() {
//        highlightedRangeNavigator.selectNextRange()
    }

    /// Selects the highlighed range at the specified index.
    /// - Parameter index: Index of highlighted range to select.
    func selectHighlightedRange(at index: Int) {
//        highlightedRangeNavigator.selectRange(at: index)
    }

    /// Synchronously displays the visible lines.
    ///
    /// This can be used to immediately update the visible lines after setting the theme.
    ///
    /// Use with caution as redisplaying the visible lines can be a costly operation.
//    func redisplayVisibleLines() {
//        redisplayVisibleLines()
//    }

    /// Scrolls the text view to reveal the text in the specified range.
    ///
    /// The function will scroll the text view as little as possible while revealing as much as possible of the specified range. It is not guaranteed that the entire range is visible after performing the scroll.
    ///
    /// - Parameters:
    ///   - range: The range of text to scroll into view.
    func scrollRangeToVisible(_ range: NSRange) {
//        viewportScroller.scroll(toVisibleRange: range)
    }

    /// Replaces the text that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in the document.
    ///   - text: A string to replace the text in range.
    func replace(_ range: NSRange, withText text: String) {
//        textReplacer.replaceText(in: range, with: text)
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    func text(in range: NSRange) -> String? {
//        stringView.substring(in: range)
        return nil
    }
}
