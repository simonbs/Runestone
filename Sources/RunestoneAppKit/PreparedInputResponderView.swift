#if canImport(AppKit)
import AppKit

/// Internal first-responder experiment. It is not a public editor surface.
/// The document attachment owns the adapter and connection; this view holds
/// both weakly so retaining a view cannot keep its document alive.
final class PreparedInputResponderView: ReadOnlyDocumentView,
                                        PreparedInputContextConnection.ReadyObserver,
                                        PreparedInputContextConnection.CommandHandler,
                                        NSUserInterfaceValidations {
    private weak var inputAdapter: PreparedInputEventAdapter?
    private weak var inputConnection: PreparedInputContextConnection?
    private var focusGeneration = UUID()
    private var keyObservers: [NSObjectProtocol] = []
    private var interpretingKeyEvents = false
    private var commandGeneration = UUID()
    private var disarmed = false
    private var focusRequested = false
    private var dragSelection: PreparedInputDragSelection?
    private var pointerAutoscrollClock: PreparedInputAutoscrollClock?
    // A gesture has a single finite budget even if it re-enters the viewport.
    private var pointerAutoscrollStarted = false
    var inputViewportClock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private struct VerticalPreference {
        let x: CGFloat
        let selection: NSRange
        let selectionRevision: UUID
        let contentRevision: UUID
        let geometryRevision: UUID
    }
    private var verticalPreference: VerticalPreference?

    init(snapshot: NSAttributedString) {
        super.init(snapshot: snapshot, fallbackHeight: 16)
    }

    required init?(coder: NSCoder) { nil }

    func attach(adapter: PreparedInputEventAdapter, connection: PreparedInputContextConnection) {
        precondition(Thread.isMainThread && !disarmed && inputConnection == nil && inputAdapter == nil)
        inputAdapter = adapter
        inputConnection = connection
        connection.readyObserver = self
        connection.commandHandler = self
        scheduleFocusCheck()
    }

    /// Immediately stop accepting new responder and accessibility work. The
    /// attachment owns deferred context retirement and gate cleanup.
    func disarmForDetachment() {
        precondition(Thread.isMainThread)
        guard !disarmed else { return }
        disarmed = true
        endPointerSelection()
        verticalPreference = nil
        PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
        focusRequested = false
        focusGeneration = UUID()
        inputAdapter = nil
        inputConnection = nil
    }

    /// Only the explicit public focus request may arm first-responder status.
    @discardableResult
    func requestFocusEligibility() -> Bool {
        precondition(Thread.isMainThread)
        guard !disarmed, !isRetired, inputConnection?.isConnectedForEditing == true else { return false }
        focusRequested = true
        return true
    }

    func revokeFocusEligibility() {
        precondition(Thread.isMainThread)
        endPointerSelection()
        focusRequested = false
        focusGeneration = UUID()
        inputConnection?.suspendForFocusLoss()
    }

    private var ownsKeyFocus: Bool {
        guard !isRetired, let window = window else { return false }
        return window.isKeyWindow && window.firstResponder === self
    }

    override func accessibilityTextState() -> AccessibilityTextState? {
        if disarmed { return super.accessibilityTextState() }
        return inputConnection?.accessibilityTextState()
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        guard !isRetired else { return nil }
        guard !disarmed, inputConnection?.accessibilityTextState() != nil else { return .staticText }
        return .textArea
    }

    override func isAccessibilitySelectorAllowed(_ selector: Selector) -> Bool {
        let setters = ["setAccessibilityValue:", "setAccessibilitySelectedText:",
                       "setAccessibilitySelectedTextRange:"]
        if setters.contains(NSStringFromSelector(selector)) {
            guard !disarmed, inputConnection?.accessibilityTextState() != nil,
                  inputAdapter?.hasProvisionalCompositionForInput() == false else { return false }
            return true
        }
        return super.isAccessibilitySelectorAllowed(selector)
    }

    override func setAccessibilityValue(_ value: Any?) {
        performAccessibilityMutation(operation: .insertText) { adapter in
            guard let text = value as? String, let state = adapter.accessibilityTextStateForInput() else { return nil }
            return adapter.insertTextReporting(text, replacementRange: NSRange(location: 0, length: (state.text as NSString).length))
        }
    }

    override func setAccessibilitySelectedText(_ value: String?) {
        performAccessibilityMutation(operation: .insertText) { adapter in
            guard let text = value else { return nil }
            let range = adapter.selectedRangeForInput()
            guard range.location != NSNotFound else { return nil }
            return adapter.insertTextReporting(text, replacementRange: range)
        }
    }

    override func setAccessibilitySelectedTextRange(_ range: NSRange) {
        performAccessibilityMutation(operation: .setSelection) { adapter in
            adapter.setSelectionReporting(range)
        }
    }

    /// AX setters are synchronous but can be called out of band. They enter
    /// the same dispatch lease as keyboard input and are rejected while a
    /// marked composition is provisional; they never replay a failed change.
    private func performAccessibilityMutation(operation: PreparedInputContextConnection.InputOperation,
                                              _ body: (PreparedInputEventAdapter) -> PreparedInputEventAdapter.InputAttempt?) {
        guard !disarmed, let connection = inputConnection,
              connection.accessibilityTextState() != nil else { return }
        endPointerSelection()
        verticalPreference = nil
        PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
        _ = connection.performCoordinatedInput {
            var reported = false
            var applied = false
            let current = connection.performResponderActivity { adapter, isCurrent in
                guard isCurrent(), !self.disarmed else { return }
                guard let marked = adapter.hasProvisionalCompositionForInput() else {
                    connection.recordInputFailure(operation: operation,
                        failure: .init(reason: .unavailable, effect: .notApplied))
                    reported = true
                    return
                }
                guard !marked else {
                    connection.recordInputFailure(operation: operation,
                        failure: .init(reason: .compositionActive, effect: .notApplied))
                    reported = true
                    return
                }
                guard isCurrent(), !self.disarmed, let attempt = body(adapter) else {
                    connection.recordInputFailure(operation: operation,
                        failure: .init(reason: .unavailable, effect: .notApplied))
                    reported = true
                    return
                }
                if let failure = attempt.failure {
                    connection.recordInputFailure(operation: operation, failure: failure)
                    reported = true
                }
                if attempt.outcome != .processed { connection.requestReset() }
                else { applied = true }
            }
            if !current && !reported {
                connection.recordInputFailure(operation: operation,
                    failure: .init(reason: applied ? .admittedFailure : .unavailable,
                                   effect: applied ? .mayHaveApplied : .notApplied))
            }
        }
    }

    override var acceptsFirstResponder: Bool {
        !disarmed && focusRequested && !isRetired && inputConnection?.isConnectedForEditing == true
    }

    override var inputContext: NSTextInputContext? {
        guard ownsKeyFocus else { return nil }
        return inputConnection?.currentInputContext
    }

    override func becomeFirstResponder() -> Bool {
        guard acceptsFirstResponder, super.becomeFirstResponder() else { return false }
        scheduleFocusCheck()
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        suppressFocus()
        let accepted = super.resignFirstResponder()
        if !accepted { scheduleFocusCheck() }
        needsDisplay = true
        return accepted
    }

    override func viewDidMoveToWindow() {
        keyObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyObservers.removeAll()
        super.viewDidMoveToWindow()
        guard let window = window, !isRetired else { suppressFocus(); return }
        keyObservers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification,
                                                                     object: window, queue: .main) { [weak self] _ in
            self?.scheduleFocusCheck()
        })
        keyObservers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                                     object: window, queue: .main) { [weak self] _ in
            self?.suppressFocus()
        })
        if ownsKeyFocus { scheduleFocusCheck() } else { suppressFocus() }
    }

    private func suppressFocus() {
        endPointerSelection()
        verticalPreference = nil
        PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
        revokeFocusEligibility()
        needsDisplay = true
    }

    private func scheduleFocusCheck() {
        let generation = UUID()
        focusGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.focusRequested, self.focusGeneration == generation,
                  self.ownsKeyFocus, let connection = self.inputConnection else { return }
            _ = connection.resumeForFocus()
            guard self.focusGeneration == generation, self.ownsKeyFocus else {
                connection.suspendForFocusLoss()
                return
            }
            self.needsDisplay = true
        }
    }

    func preparedInputContextConnectionDidBecomeReady(_ connection: PreparedInputContextConnection) {
        guard inputConnection === connection else { return }
        scheduleFocusCheck()
    }

    override func keyDown(with event: NSEvent) {
        endPointerSelection()
        guard !disarmed else { return }
        guard let connection = inputConnection else { super.keyDown(with: event); return }
        _ = connection.performCoordinatedInput { self.routeKeyDown(event, connection: connection) }
    }

    private func routeKeyDown(_ event: NSEvent, connection: PreparedInputContextConnection) {
        guard ownsKeyFocus else {
            connection.recordInputFailure(operation: .undispatchedKey,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        let beforeCommands = commandGeneration
        let beforeContent = contentRevision
        let beforeGeometry = inputGeometryRevision
        switch connection.dispatchKey(event) {
        case .handled, .unavailable:
            return
        case .declined:
            break
        }
        // The input context has already seen this event. If focus was lost,
        // its effects are uncertain and the event must never be replayed.
        guard ownsKeyFocus, inputConnection === connection, !isRetired else {
            connection.recordInputFailure(operation: .keyBindingFallback,
                failure: .init(reason: .unavailable, effect: .mayHaveApplied))
            return
        }
        if commandGeneration != beforeCommands || contentRevision != beforeContent ||
            inputGeometryRevision != beforeGeometry {
            connection.recordInputFailure(operation: .keyBindingFallback,
                failure: .init(reason: .unavailable, effect: .mayHaveApplied))
            return
        }
        // The connection reports a failed fallback guard itself, once, with
        // mayHaveApplied because AppKit has already handled the driver call.
        _ = connection.performKeyBindingFallback {
            guard ownsKeyFocus, inputConnection === connection, !interpretingKeyEvents else {
                connection.recordInputFailure(operation: .keyBindingFallback,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            }
            interpretingKeyEvents = true
            defer { interpretingKeyEvents = false }
            interpretKeyEvents([event])
        }
    }

    @objc(insertText:)
    func insertTextFromKeyBinding(_ value: Any) {
        guard let connection = inputConnection else { return }
        guard interpretingKeyEvents, ownsKeyFocus else {
            connection.recordInputFailure(operation: .insertText,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        connection.insertTextFromKeyBinding(value, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    @objc(doCommandBySelector:)
    func doCommandFromKeyBinding(_ selector: Selector) {
        guard let connection = inputConnection else { return }
        guard interpretingKeyEvents, ownsKeyFocus else {
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        connection.doCommandFromKeyBinding(selector)
    }

    @objc(copy:)
    private func copyText(_ sender: Any?) { performClipboardMenuAction(.copy) }

    @objc(cut:)
    private func cutText(_ sender: Any?) { performClipboardMenuAction(.cut) }

    @objc(paste:)
    private func pasteText(_ sender: Any?) { performClipboardMenuAction(.paste) }

    override func selectAll(_ sender: Any?) { performStandardCommand("selectAll:") }

    /// Menu actions and key-binding methods share the same admitted event.
    /// When AppKit invokes a selector during interpretation, do not nest a
    /// second reservation around it.
    private func performStandardCommand(_ name: String) {
        guard let connection = inputConnection else { return }
        performStandardCommand(name, on: connection, hasFocus: { self.ownsKeyFocus })
    }

    /// Headless seam for AppKit's direct selector path. A live action supplies
    /// the window-focus check; tests can exercise scope ordering without a key window.
    func performStandardCommand(_ name: String, on connection: PreparedInputContextConnection,
                                hasFocus: @escaping () -> Bool) {
        guard !disarmed, inputConnection === connection, connection.isActiveForInput, hasFocus() else { return }
        let perform = { self.routeCommand(NSSelectorFromString(name), on: connection, hasFocus: hasFocus) { _ in false } }
        if connection.dispatchCoordinator?.isActive == true { perform() }
        else { _ = connection.performCoordinatedInput(perform) }
    }

    override func insertTab(_ sender: Any?) { performStandardCommand("insertTab:") }
    override func insertNewline(_ sender: Any?) { performStandardCommand("insertNewline:") }
    override func insertLineBreak(_ sender: Any?) { performStandardCommand("insertLineBreak:") }
    override func deleteBackward(_ sender: Any?) { performStandardCommand("deleteBackward:") }
    override func deleteForward(_ sender: Any?) { performStandardCommand("deleteForward:") }
    override func deleteWordBackward(_ sender: Any?) { performStandardCommand("deleteWordBackward:") }
    override func deleteWordForward(_ sender: Any?) { performStandardCommand("deleteWordForward:") }
    override func moveLeft(_ sender: Any?) { performStandardCommand("moveLeft:") }
    override func moveRight(_ sender: Any?) { performStandardCommand("moveRight:") }
    override func moveBackward(_ sender: Any?) { performStandardCommand("moveBackward:") }
    override func moveForward(_ sender: Any?) { performStandardCommand("moveForward:") }
    override func moveLeftAndModifySelection(_ sender: Any?) { performStandardCommand("moveLeftAndModifySelection:") }
    override func moveRightAndModifySelection(_ sender: Any?) { performStandardCommand("moveRightAndModifySelection:") }
    override func moveBackwardAndModifySelection(_ sender: Any?) { performStandardCommand("moveBackwardAndModifySelection:") }
    override func moveForwardAndModifySelection(_ sender: Any?) { performStandardCommand("moveForwardAndModifySelection:") }
    override func moveWordLeft(_ sender: Any?) { performStandardCommand("moveWordLeft:") }
    override func moveWordRight(_ sender: Any?) { performStandardCommand("moveWordRight:") }
    override func moveWordBackward(_ sender: Any?) { performStandardCommand("moveWordBackward:") }
    override func moveWordForward(_ sender: Any?) { performStandardCommand("moveWordForward:") }
    override func moveWordLeftAndModifySelection(_ sender: Any?) { performStandardCommand("moveWordLeftAndModifySelection:") }
    override func moveWordRightAndModifySelection(_ sender: Any?) { performStandardCommand("moveWordRightAndModifySelection:") }
    override func moveWordBackwardAndModifySelection(_ sender: Any?) { performStandardCommand("moveWordBackwardAndModifySelection:") }
    override func moveWordForwardAndModifySelection(_ sender: Any?) { performStandardCommand("moveWordForwardAndModifySelection:") }
    override func moveUp(_ sender: Any?) { performStandardCommand("moveUp:") }
    override func moveDown(_ sender: Any?) { performStandardCommand("moveDown:") }
    override func moveUpAndModifySelection(_ sender: Any?) { performStandardCommand("moveUpAndModifySelection:") }
    override func moveDownAndModifySelection(_ sender: Any?) { performStandardCommand("moveDownAndModifySelection:") }
    override func moveToBeginningOfLine(_ sender: Any?) { performStandardCommand("moveToBeginningOfLine:") }
    override func moveToEndOfLine(_ sender: Any?) { performStandardCommand("moveToEndOfLine:") }
    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) { performStandardCommand("moveToBeginningOfLineAndModifySelection:") }
    override func moveToEndOfLineAndModifySelection(_ sender: Any?) { performStandardCommand("moveToEndOfLineAndModifySelection:") }
    override func moveToLeftEndOfLine(_ sender: Any?) { performStandardCommand("moveToLeftEndOfLine:") }
    override func moveToRightEndOfLine(_ sender: Any?) { performStandardCommand("moveToRightEndOfLine:") }
    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) { performStandardCommand("moveToLeftEndOfLineAndModifySelection:") }
    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) { performStandardCommand("moveToRightEndOfLineAndModifySelection:") }
    override func moveToBeginningOfParagraph(_ sender: Any?) { performStandardCommand("moveToBeginningOfParagraph:") }
    override func moveToEndOfParagraph(_ sender: Any?) { performStandardCommand("moveToEndOfParagraph:") }
    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) { performStandardCommand("moveToBeginningOfParagraphAndModifySelection:") }
    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) { performStandardCommand("moveToEndOfParagraphAndModifySelection:") }
    override func moveToBeginningOfDocument(_ sender: Any?) { performStandardCommand("moveToBeginningOfDocument:") }
    override func moveToEndOfDocument(_ sender: Any?) { performStandardCommand("moveToEndOfDocument:") }
    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) { performStandardCommand("moveToBeginningOfDocumentAndModifySelection:") }
    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) { performStandardCommand("moveToEndOfDocumentAndModifySelection:") }

    /// AppKit calls this before enabling an edit menu item. Actual execution
    /// repeats all revision, composition and gate checks.
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard !disarmed, ownsKeyFocus, let action = item.action, let connection = inputConnection,
              let adapter = inputAdapter, connection.accessibilityTextState() != nil else { return false }
        let allowed = canPerformEditingAction(action, connection: connection, adapter: adapter,
            pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: .general))
        return allowed && ownsKeyFocus && inputConnection === connection && connection.isActiveForInput
    }

    /// Headless seam for menu validation; the public responder additionally
    /// requires active window focus before calling this method.
    func canPerformEditingAction(_ selector: Selector, connection: PreparedInputContextConnection,
                                 adapter: PreparedInputEventAdapter,
                                 pasteboard: PreparedInputClipboardCommand.Pasteboard) -> Bool {
        guard !disarmed, inputConnection === connection, inputAdapter === adapter,
              connection.isActiveForInput, connection.accessibilityTextState() != nil else { return false }
        let name = NSStringFromSelector(selector)
        switch name {
        case "copy:": return PreparedInputClipboardCommand.canPerform(.copy, adapter: adapter, view: self, pasteboard: pasteboard)
        case "cut:": return PreparedInputClipboardCommand.canPerform(.cut, adapter: adapter, view: self, pasteboard: pasteboard)
        case "paste:": return PreparedInputClipboardCommand.canPerform(.paste, adapter: adapter, view: self, pasteboard: pasteboard)
        case "undo:": return connection.canPerformHistory(.undo)
        case "redo:": return connection.canPerformHistory(.redo)
        case "selectAll:":
            guard let state = adapter.inputStateForHost(), !state.hasComposition else { return false }
            return self.manager.stringView.string.length > 0
        default:
            guard let state = adapter.inputStateForHost(), !state.hasComposition else { return false }
            let text = self.manager.stringView.string
            guard PreparedInputCommandInterpreter.isValidSelectionRange(state.selection, in: text) else { return false }
            if isVisualMovement(name) {
                if visualDestination(name, selection: state.selection) != nil { return true }
                guard name.hasPrefix("moveUp") || name.hasPrefix("moveDown") else { return false }
                let up = name.hasPrefix("moveUp")
                let origin = PreparedInputCommandInterpreter.movementOrigin(selection: state.selection,
                    extending: name.contains("AndModifySelection:"), direction: up ? .backward : .forward, view: self)
                return PreparedInputVisualMovement.verticalNeedsViewportStep(from: origin, direction: up ? .up : .down, in: self)
            }
            guard PreparedInputCommandInterpreter.supports(name) else { return false }
            if name == "deleteBackward:" || name == "deleteWordBackward:" {
                return state.selection.length > 0 || state.selection.location > 0
            }
            if name == "deleteForward:" || name == "deleteWordForward:" {
                return state.selection.length > 0 || state.selection.upperBound < text.length
            }
            return true
        }
    }

    private func performClipboardMenuAction(_ operation: PreparedInputClipboardCommand.Operation) {
        guard !disarmed, ownsKeyFocus, let connection = inputConnection else { return }
        let perform = {
            self.routeClipboard(operation, on: connection,
                pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: .general),
                hasFocus: { self.ownsKeyFocus })
        }
        if connection.dispatchCoordinator?.isActive == true { perform() }
        else { _ = connection.performCoordinatedInput(perform) }
    }

    /// Called only inside an admitted dispatch. No input or pasteboard payload
    /// is retained after this synchronous action returns.
    func routeClipboard(_ operation: PreparedInputClipboardCommand.Operation,
                        on connection: PreparedInputContextConnection,
                        pasteboard: PreparedInputClipboardCommand.Pasteboard,
                        hasFocus: () -> Bool = { true }) {
        guard !disarmed, inputConnection === connection, let adapter = inputAdapter else {
            connection.recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        endPointerSelection()
        verticalPreference = nil
        if operation != .copy { PreparedInputCommandInterpreter.resetSelectionExtension(in: self) }
        let category: PreparedInputContextConnection.InputOperation = operation == .copy ? .command : .insertText
        switch PreparedInputClipboardCommand.perform(operation, adapter: adapter, view: self, pasteboard: pasteboard,
            isAvailable: { !self.disarmed && self.inputConnection === connection && connection.isActiveForInput && hasFocus() }) {
        case .processed: break
        case let .failed(failure, needsReset):
            connection.recordInputFailure(operation: category, failure: failure)
            if needsReset { connection.requestReset() }
        }
    }

    /// Menu actions can arrive independently of key interpretation. Each
    /// enters a dispatch scope and is deferred until that scope has closed.
    @objc(undo:)
    private func requestUndo(_ sender: Any?) { requestHistory(.undo) }

    @objc(redo:)
    private func requestRedo(_ sender: Any?) { requestHistory(.redo) }

    private func requestHistory(_ operation: RunestoneInputHistoryOperation) {
        guard !disarmed, ownsKeyFocus, let connection = inputConnection else { return }
        if connection.dispatchCoordinator?.isActive == true { connection.requestHistory(operation) }
        else { _ = connection.performCoordinatedInput { connection.requestHistory(operation) } }
    }

    func preparedInputContextConnection(_ connection: PreparedInputContextConnection, doCommand selector: Selector) {
        guard inputConnection === connection, ownsKeyFocus else {
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        routeCommand(selector, on: connection, hasFocus: { self.ownsKeyFocus }) { [weak self] selector in
            guard let self = self else { return false }
            return self.nextResponder?.tryToPerform(selector, with: self) ?? false
        }
    }

    /// The window-ownership check is performed by the responder callback; this
    /// internal seam also allows deterministic command-routing verification.
    func routeCommand(_ selector: Selector, on connection: PreparedInputContextConnection,
                      hasFocus: @escaping () -> Bool = { true }, forward: (Selector) -> Bool) {
        commandGeneration = UUID()
        guard inputConnection === connection, let adapter = inputAdapter else {
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        let isAvailable = { !self.disarmed && self.inputConnection === connection && connection.isActiveForInput && hasFocus() }
        let name = NSStringFromSelector(selector)
        if isVisualMovement(name) {
            routeVisualMovement(name, adapter: adapter, connection: connection, isAvailable: isAvailable)
            return
        }
        verticalPreference = nil
        switch name {
        case "copy:", "cut:", "paste:":
            let operation: PreparedInputClipboardCommand.Operation
            switch NSStringFromSelector(selector) {
            case "copy:": operation = .copy
            case "cut:": operation = .cut
            default: operation = .paste
            }
            routeClipboard(operation, on: connection,
                pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: .general),
                hasFocus: { self.ownsKeyFocus })
            return
        case "undo:": connection.requestHistory(.undo); return
        case "redo:": connection.requestHistory(.redo); return
        default: break
        }
        switch PreparedInputCommandInterpreter.performReporting(selector, adapter: adapter, view: self, isAvailable: isAvailable) {
        case .unsupported:
            // Unsupported editing selectors are not routed to another owner
            // while this document's input reservation is held.
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unsupported, effect: .notApplied))
        case let .blocked(failure):
            connection.recordInputFailure(operation: .command, failure: failure)
        case let .handled(attempt):
            if let failure = attempt.failure { connection.recordInputFailure(operation: .command, failure: failure) }
            if attempt.outcome != .processed { connection.requestReset() }
        }
    }

    private func isVisualMovement(_ name: String) -> Bool {
        let names: Set<String> = ["moveLeft:", "moveRight:", "moveLeftAndModifySelection:",
            "moveRightAndModifySelection:", "moveWordLeft:", "moveWordRight:",
            "moveWordLeftAndModifySelection:", "moveWordRightAndModifySelection:", "moveUp:", "moveDown:",
            "moveUpAndModifySelection:", "moveDownAndModifySelection:",
            "moveToBeginningOfLine:", "moveToEndOfLine:",
            "moveToBeginningOfLineAndModifySelection:", "moveToEndOfLineAndModifySelection:",
            "moveToLeftEndOfLine:", "moveToRightEndOfLine:",
            "moveToLeftEndOfLineAndModifySelection:", "moveToRightEndOfLineAndModifySelection:"]
        return names.contains(name)
    }

    private struct VisualDestination {
        let target: Int
        let direction: PreparedInputCommandInterpreter.Direction
        let extending: Bool
        let preferredX: CGFloat?
    }

    /// Compute without mutation so menu validation can use the same geometry
    /// and reject unavailable/ambiguous commands before enabling the item.
    private func visualDestination(_ name: String, selection: NSRange) -> VisualDestination? {
        let text = manager.stringView.string
        guard PreparedInputCommandInterpreter.isValidSelectionRange(selection, in: text) else { return nil }
        let extending = name.contains("AndModifySelection:")
        let isVertical = name.hasPrefix("moveUp") || name.hasPrefix("moveDown")
        let isWord = name.hasPrefix("moveWordLeft") || name.hasPrefix("moveWordRight")
        let isHorizontal = isWord || name == "moveLeft:" || name == "moveRight:" ||
            name == "moveLeftAndModifySelection:" || name == "moveRightAndModifySelection:"
        let backward = name.contains("Left") || name.contains("Beginning") || name.hasPrefix("moveUp")
        var direction: PreparedInputCommandInterpreter.Direction = backward ? .backward : .forward
        var collapseTarget: Int?
        if isHorizontal && selection.length > 0 {
            // Pick the visually nearer endpoint rather than assuming that an
            // RTL run's logical order is its left-to-right order.
            guard let a = InputScreenCaretGeometry.rect(at: selection.location, in: self),
                  let b = InputScreenCaretGeometry.rect(at: selection.upperBound, in: self),
                  let window = window else { return nil }
            let first = self.convert(window.convertFromScreen(a), from: nil)
            let last = self.convert(window.convertFromScreen(b), from: nil)
            let firstBefore = abs(first.midY - last.midY) > 0.5 ? first.midY < last.midY : first.midX < last.midX
            guard abs(first.midY - last.midY) > 0.5 || abs(first.midX - last.midX) > 0.01 else { return nil }
            let chosen = (backward == firstBefore) ? selection.location : selection.upperBound
            direction = chosen == selection.location ? .backward : .forward
            if !extending { collapseTarget = chosen }
        }
        let origin = PreparedInputCommandInterpreter.movementOrigin(selection: selection, extending: extending,
                                                                     direction: direction, view: self)
        var preferredX: CGFloat?
        let target: Int?
        if let collapseTarget = collapseTarget {
            target = collapseTarget
        } else if isVertical {
            let preference = verticalPreference
            let x = preference.flatMap { previous in
                previous.selection == selection && previous.selectionRevision == inputSelectionRevision &&
                previous.contentRevision == contentRevision && previous.geometryRevision == inputGeometryRevision ? previous.x : nil
            }
            let value = PreparedInputVisualMovement.vertical(from: origin, direction: backward ? .up : .down,
                                                            preferredScreenX: x, in: self)
            if let value = value { target = value.location; preferredX = value.preferredScreenX }
            else if (backward && origin == 0) || (!backward && origin == text.length) { target = origin }
            else { target = nil }
        } else if isHorizontal {
            let horizontalDirection: PreparedInputVisualMovement.HorizontalDirection = backward ? .left : .right
            let result = isWord
                ? PreparedInputVisualWordMovement.destination(from: origin, direction: horizontalDirection, in: self)
                : PreparedInputVisualMovement.horizontal(from: origin, direction: horizontalDirection, in: self)
            switch result {
            case let .moved(location): target = location
            case .boundary: target = origin
            case .unavailable: target = nil
            }
        } else {
            let edge: PreparedInputVisualMovement.Edge = backward ? .beginning : .end
            if name.contains("LeftEnd") || name.contains("RightEnd") {
                target = PreparedInputVisualMovement.lineEdge(from: origin, edge: edge, in: self)
            } else {
                target = PreparedInputVisualMovement.logicalLineEdge(from: origin, edge: edge, in: self)
            }
        }
        guard let target = target else { return nil }
        return VisualDestination(target: target, direction: direction, extending: extending, preferredX: preferredX)
    }

    /// Make at most one short, bounded viewport step for a vertical command.
    /// The original input event is not retained: the same admitted scope
    /// recomputes geometry only after revision and selection revalidation.
    private func scrollForVerticalMovement(_ name: String, selection: NSRange,
                                           adapter: PreparedInputEventAdapter,
                                           isAvailable: @escaping () -> Bool) -> PreparedInputViewportStep.Outcome? {
        guard name.hasPrefix("moveUp") || name.hasPrefix("moveDown"),
              let window = window, let clip = enclosingScrollView?.contentView,
              let layout = visibleLayout, layout.isComplete, layout.viewport == clip.bounds,
              let documentRevision = adapter.installedRevisionForDispatch else { return nil }
        let up = name.hasPrefix("moveUp")
        let extending = name.contains("AndModifySelection:")
        let direction: PreparedInputCommandInterpreter.Direction = up ? .backward : .forward
        let origin = PreparedInputCommandInterpreter.movementOrigin(selection: selection, extending: extending,
                                                                     direction: direction, view: self)
        guard PreparedInputVisualMovement.verticalNeedsViewportStep(from: origin, direction: up ? .up : .down, in: self),
              let caret = InputScreenCaretGeometry.rect(at: origin, in: self) else { return nil }
        let documentCaret = self.convert(window.convertFromScreen(caret), from: nil)
        let bounds = clip.bounds
        // Keep the source caret inside the viewport so the next row can be
        // resolved from actual geometry rather than from an estimated offset.
        let room = up ? bounds.maxY - documentCaret.maxY : documentCaret.minY - bounds.minY
        let amount = min(PreparedInputViewportStep.maximumDelta, bounds.height * 0.25, max(0, room - 1))
        guard amount.isFinite, amount >= 1 else { return .boundary }
        let content = contentRevision
        let selectionRevision = inputSelectionRevision
        let geometry = inputGeometryRevision
        let priorX = verticalPreference.flatMap { value in
            value.selection == selection && value.selectionRevision == selectionRevision &&
            value.contentRevision == content && value.geometryRevision == geometry ? value.x : nil
        } ?? caret.midX
        let check = {
            guard isAvailable(), !self.isRetired, self.window === window,
                  self.enclosingScrollView?.contentView === clip,
                  self.contentRevision == content, self.inputSelectionRevision == selectionRevision,
                  adapter.installedRevisionForDispatch == documentRevision,
                  let current = adapter.inputStateForHost(), !current.hasComposition,
                  current.selection == selection else { return false }
            return isAvailable() && self.contentRevision == content && self.inputSelectionRevision == selectionRevision
        }
        let result = PreparedInputViewportStep.perform(in: self, dx: 0, dy: up ? -amount : amount, clock: inputViewportClock, isCurrent: check)
        if result == .progressed && check() {
            verticalPreference = VerticalPreference(x: priorX, selection: selection, selectionRevision: selectionRevision,
                                                    contentRevision: content, geometryRevision: inputGeometryRevision)
        }
        return result
    }

    /// Apply a current Core Text destination through the document reservation.
    private func routeVisualMovement(_ name: String, adapter: PreparedInputEventAdapter,
                                     connection: PreparedInputContextConnection, isAvailable: @escaping () -> Bool) {
        guard let state = adapter.inputStateForHost() else {
            verticalPreference = nil
            connection.recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        guard !state.hasComposition else {
            verticalPreference = nil
            connection.recordInputFailure(operation: .command, failure: .init(reason: .compositionActive, effect: .notApplied))
            return
        }
        var destination = visualDestination(name, selection: state.selection)
        var viewportMayHaveChanged = false
        if destination == nil, let step = scrollForVerticalMovement(name, selection: state.selection,
                                                                     adapter: adapter, isAvailable: isAvailable) {
            switch step {
            case .progressed:
                viewportMayHaveChanged = true
                destination = visualDestination(name, selection: state.selection)
            case .boundary:
                break
            case .unavailable:
                viewportMayHaveChanged = true
            }
        }
        guard let destination = destination else {
            verticalPreference = nil
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: viewportMayHaveChanged ? .mayHaveApplied : .notApplied))
            return
        }
        switch PreparedInputCommandInterpreter.moveSelection(target: destination.target, selection: state.selection,
            extending: destination.extending, direction: destination.direction, adapter: adapter, view: self,
            isAvailable: isAvailable) {
        case let .handled(attempt):
            if let failure = attempt.failure { connection.recordInputFailure(operation: .command, failure: failure) }
            if attempt.outcome != .processed { connection.requestReset(); verticalPreference = nil }
            else if let x = destination.preferredX, let current = adapter.inputStateForHost() {
                verticalPreference = VerticalPreference(x: x, selection: current.selection, selectionRevision: inputSelectionRevision,
                                                        contentRevision: contentRevision, geometryRevision: inputGeometryRevision)
            } else { verticalPreference = nil }
        case let .blocked(failure):
            verticalPreference = nil
            connection.recordInputFailure(operation: .command, failure: failure)
        case .unsupported:
            verticalPreference = nil
            connection.recordInputFailure(operation: .command, failure: .init(reason: .unsupported, effect: .notApplied))
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard focusRequested, !disarmed, let connection = inputConnection else { return }
        _ = connection.performCoordinatedInput { self.routeMouseDown(event, connection: connection) }
    }

    private func routeMouseDown(_ event: NSEvent, connection: PreparedInputContextConnection) {
        guard !isRetired, let window = window, event.window === window,
              window.makeFirstResponder(self), ownsKeyFocus,
              connection.resumeForFocus(), ownsKeyFocus else {
            endPointerSelection()
            connection.recordInputFailure(operation: .setSelection,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        beginPointerSelection(at: window.convertPoint(toScreen: event.locationInWindow),
                              extending: event.modifierFlags.contains(.shift), connection: connection,
                              hasFocus: { self.ownsKeyFocus })
    }

    /// Caller holds the outer dispatch scope; the focus predicate is checked
    /// around geometry callouts and is injectable for headless tests.
    func beginPointerSelection(at screenPoint: NSPoint, extending: Bool, connection: PreparedInputContextConnection,
                               hasFocus: @escaping () -> Bool) {
        endPointerSelection()
        pointerAutoscrollStarted = false
        verticalPreference = nil
        let canUse = { !self.disarmed && self.inputConnection === connection && hasFocus() }
        func report(_ reason: PreparedInputEventAdapter.InputFailure.Reason,
                    _ effect: PreparedInputEventAdapter.InputFailure.Effect = .notApplied) {
            connection.recordInputFailure(operation: .setSelection, failure: .init(reason: reason, effect: effect))
        }
        var entered = false
        var reported = false
        var applied = false
        let remainedCurrent = connection.performResponderActivity { adapter, isCurrent in
            entered = true
            guard let provisional = adapter.hasProvisionalCompositionForInput() else {
                report(.unavailable); reported = true; return
            }
            guard !provisional else { report(.compositionActive); reported = true; return }
            guard !adapter.needsInputReset, isCurrent(), canUse() else {
                report(.unavailable); reported = true; return
            }
            guard isCurrent(), canUse(),
                  let offset = InputScreenRangeGeometry.characterIndexForPointer(for: screenPoint, in: self),
                  isCurrent(), canUse() else { report(.unavailable); reported = true; return }
            let currentSelection = adapter.selectedRangeForInput()
            let text = self.manager.stringView.string
            guard PreparedInputCommandInterpreter.isValidSelectionRange(currentSelection, in: text),
                  PreparedInputCommandInterpreter.isValidBoundary(offset, in: text), isCurrent(), canUse() else {
                report(.invalidSelection); reported = true; return
            }
            let anchor: Int
            if extending {
                anchor = PreparedInputCommandInterpreter.selectionAnchor(for: currentSelection, in: self) ??
                    (offset < currentSelection.location ? currentSelection.upperBound : currentSelection.location)
            } else {
                anchor = offset
            }
            PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
            let selection = NSRange(location: min(anchor, offset), length: max(anchor, offset) - min(anchor, offset))
            let attempt = adapter.setSelectionReporting(selection, isAvailable: { isCurrent() && canUse() })
            if let failure = attempt.failure {
                connection.recordInputFailure(operation: .setSelection, failure: failure)
                reported = true
            }
            if attempt.outcome != .processed { connection.requestReset() }
            else {
                applied = true
                dragSelection = PreparedInputDragSelection(anchor: anchor, selection: selection,
                    contentRevision: contentRevision, selectionRevision: inputSelectionRevision)
            }
            needsDisplay = true
        }
        if !remainedCurrent && !reported {
            report(applied ? .admittedFailure : .unavailable, applied ? .mayHaveApplied : .notApplied)
        } else if !entered && !reported {
            report(.unavailable)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard focusRequested, !disarmed, dragSelection != nil, let connection = inputConnection else { return }
        if !connection.performCoordinatedInput({ self.routeMouseDragged(event, connection: connection) }) {
            endPointerSelection()
        }
    }

    private func routeMouseDragged(_ event: NSEvent, connection: PreparedInputContextConnection) {
        guard let window = window, event.window === window, ownsKeyFocus, !isRetired else {
            endPointerSelection()
            connection.recordInputFailure(operation: .setSelection,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        continuePointerSelection(at: window.convertPoint(toScreen: event.locationInWindow),
                                 connection: connection, hasFocus: { self.ownsKeyFocus })
    }

    /// One drag event, scoped and revision checked independently of prior events.
    @discardableResult
    func continuePointerSelection(at screenPoint: NSPoint, connection: PreparedInputContextConnection,
                                  hasFocus: @escaping () -> Bool) -> Bool {
        guard var drag = dragSelection, !isRetired else {
            connection.recordInputFailure(operation: .setSelection,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return false
        }
        let canUse = { !self.disarmed && self.inputConnection === connection && hasFocus() }
        var reported = false
        var applied = false
        let current = connection.performResponderActivity { adapter, isCurrent in
            guard isCurrent(), canUse(),
                  adapter.hasProvisionalCompositionForInput() == false,
                  self.contentRevision == drag.contentRevision else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .notApplied))
                reported = true
                self.endPointerSelection()
                return
            }
            guard isCurrent(), canUse(),
                  let offset = InputScreenRangeGeometry.characterIndexForPointerDrag(for: screenPoint, in: self),
                  PreparedInputCommandInterpreter.isValidBoundary(offset, in: self.manager.stringView.string),
                  isCurrent(), canUse(),
                  let selection = drag.selection(to: offset, current: adapter.selectedRangeForInput(),
                                                 contentRevision: self.contentRevision,
                                                 selectionRevision: self.inputSelectionRevision) else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .notApplied))
                reported = true
                self.endPointerSelection()
                return
            }
            let attempt = adapter.setSelectionReporting(selection, isAvailable: { isCurrent() && canUse() })
            if let failure = attempt.failure {
                connection.recordInputFailure(operation: .setSelection, failure: failure)
                reported = true
            }
            if attempt.outcome != .processed {
                self.endPointerSelection()
                connection.requestReset()
            } else {
                applied = true
                drag.didApply(selectionRevision: self.inputSelectionRevision)
                self.dragSelection = drag
                self.needsDisplay = true
            }
        }
        if !current && !reported {
            endPointerSelection()
            connection.recordInputFailure(operation: .setSelection,
                failure: .init(reason: applied ? .admittedFailure : .unavailable,
                               effect: applied ? .mayHaveApplied : .notApplied))
        }
        guard current, applied, !reported, dragSelection != nil else {
            endPointerSelection()
            return false
        }
        trackPointerAutoscroll(at: screenPoint)
        return true
    }

    override func mouseUp(with event: NSEvent) { endPointerSelection() }

    private func endPointerSelection() {
        pointerAutoscrollClock?.stop()
        dragSelection = nil
    }

    /// Test injection is done before a gesture and uses the same clock and
    /// step path as the production timer.
    func installPointerAutoscrollClock(_ clock: PreparedInputAutoscrollClock) {
        precondition(Thread.isMainThread && dragSelection == nil)
        pointerAutoscrollClock?.stop()
        pointerAutoscrollClock = clock
    }

    private func trackPointerAutoscroll(at screenPoint: NSPoint) {
        guard let delta = pointerScrollDelta(at: screenPoint) else {
            endPointerSelection()
            return
        }
        guard delta.x != 0 || delta.y != 0 else {
            pointerAutoscrollClock?.stop()
            return
        }
        if pointerAutoscrollStarted {
            pointerAutoscrollClock?.update(screenPoint)
            return
        }
        pointerAutoscrollStarted = true
        if pointerAutoscrollClock == nil {
            pointerAutoscrollClock = PreparedInputAutoscrollClock { [weak self] point in
                guard let self = self else { return false }
                return self.performPointerAutoscrollStep(at: point, hasFocus: { [weak self] in
                    self?.ownsKeyFocus == true
                })
            }
        }
        _ = pointerAutoscrollClock?.begin(at: screenPoint)
    }

    private func pointerScrollDelta(at screenPoint: NSPoint) -> NSPoint? {
        guard screenPoint.x.isFinite, screenPoint.y.isFinite, !isRetired,
              let window = window, let scroll = enclosingScrollView,
              scroll.documentView === self else { return nil }
        let bounds = scroll.contentView.bounds
        let point = convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        guard point.x.isFinite, point.y.isFinite, bounds.minX.isFinite, bounds.maxX.isFinite,
              bounds.minY.isFinite, bounds.maxY.isFinite, bounds.width > 0, bounds.height > 0 else { return nil }
        func component(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            if value < lower { return -min(PreparedInputViewportStep.maximumDelta, max(1, lower - value)) }
            if value > upper { return min(PreparedInputViewportStep.maximumDelta, max(1, value - upper)) }
            return 0
        }
        return NSPoint(x: component(point.x, bounds.minX, bounds.maxX),
                       y: component(point.y, bounds.minY, bounds.maxY))
    }

    /// Called on a later run-loop turn with only a screen point. Every tick
    /// obtains a fresh dispatch lease and rejects stale selection or content.
    func performPointerAutoscrollStep(at screenPoint: NSPoint, hasFocus: @escaping () -> Bool) -> Bool {
        guard let connection = inputConnection, let adapter = inputAdapter,
              let drag = dragSelection, let delta = pointerScrollDelta(at: screenPoint),
              delta.x != 0 || delta.y != 0 else { endPointerSelection(); return false }
        var advanced = false
        let admitted = connection.performCoordinatedInput {
            let isCurrent = {
                guard !self.disarmed, !self.isRetired, self.inputConnection === connection,
                      self.inputAdapter === adapter, connection.isActiveForInput, hasFocus(),
                      let currentDrag = self.dragSelection,
                      currentDrag.contentRevision == drag.contentRevision,
                      currentDrag.selectionRevision == drag.selectionRevision,
                      currentDrag.expectedSelection == drag.expectedSelection,
                      self.contentRevision == drag.contentRevision,
                      self.inputSelectionRevision == drag.selectionRevision,
                      let state = adapter.inputStateForHost(), !state.hasComposition,
                      state.selection == drag.expectedSelection else { return false }
                return true
            }
            guard isCurrent() else { return }
            let step = PreparedInputViewportStep.perform(in: self, dx: delta.x, dy: delta.y,
                                                         clock: self.inputViewportClock, isCurrent: isCurrent)
            switch step {
            case .boundary: return
            case .unavailable:
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            case .progressed: break
            }
            guard isCurrent() else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            }
            advanced = self.continuePointerSelection(at: screenPoint, connection: connection, hasFocus: hasFocus)
            if !advanced {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .admittedFailure, effect: .mayHaveApplied))
            }
        }
        guard admitted && advanced else { endPointerSelection(); return false }
        return true
    }

    override func noteInputCoordinatesChanged() {
        super.noteInputCoordinatesChanged()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard ownsKeyFocus, let connection = inputConnection else { return }
        connection.performResponderActivity { adapter, isCurrent in
            let selection = adapter.selectedRangeForInput()
            guard selection.location != NSNotFound, isCurrent(), ownsKeyFocus else { return }
            let marked = adapter.markedRangeForInput()
            guard !adapter.needsInputReset, isCurrent(), ownsKeyFocus,
                  let geometry = InputSelectionGeometry.geometry(selection: selection,
                      marked: marked.location == NSNotFound ? nil : marked, in: self),
                  isCurrent(), ownsKeyFocus else { return }
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35).setFill()
            for rect in geometry.selectionRects where rect.intersects(dirtyRect) { NSBezierPath(rect: rect).fill() }
            NSColor.textColor.setFill()
            for rect in geometry.markedRects where rect.intersects(dirtyRect) {
                NSBezierPath(rect: NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1)).fill()
            }
            if let caret = geometry.caretRect, caret.intersects(dirtyRect) { NSBezierPath(rect: caret).fill() }
        }
    }

    deinit { keyObservers.forEach { NotificationCenter.default.removeObserver($0) } }
}
#endif
