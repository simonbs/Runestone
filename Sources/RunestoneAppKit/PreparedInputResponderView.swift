#if canImport(AppKit)
import AppKit

/// Internal first-responder experiment. It is not a public editor surface.
/// The document attachment owns the adapter and connection; this view holds
/// both weakly so retaining a view cannot keep its document alive.
final class PreparedInputResponderView: ReadOnlyDocumentView,
                                        PreparedInputContextConnection.ReadyObserver,
                                        PreparedInputContextConnection.CommandHandler {
    private weak var inputAdapter: PreparedInputEventAdapter?
    private weak var inputConnection: PreparedInputContextConnection?
    private var focusGeneration = UUID()
    private var keyObservers: [NSObjectProtocol] = []
    private var interpretingKeyEvents = false
    private var commandGeneration = UUID()
    private var disarmed = false
    private var focusRequested = false

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

    /// Menu actions can arrive independently of key interpretation. Each
    /// enters a dispatch scope and is deferred until that scope has closed.
    @objc(undo:)
    private func requestUndo(_ sender: Any?) { requestHistory(.undo) }

    @objc(redo:)
    private func requestRedo(_ sender: Any?) { requestHistory(.redo) }

    private func requestHistory(_ operation: RunestoneInputHistoryOperation) {
        guard !disarmed, ownsKeyFocus, let connection = inputConnection else { return }
        _ = connection.performCoordinatedInput { connection.requestHistory(operation) }
    }

    func preparedInputContextConnection(_ connection: PreparedInputContextConnection, doCommand selector: Selector) {
        guard inputConnection === connection, ownsKeyFocus else {
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        routeCommand(selector, on: connection) { [weak self] selector in
            guard let self = self else { return false }
            return self.nextResponder?.tryToPerform(selector, with: self) ?? false
        }
    }

    /// The window-ownership check is performed by the responder callback; this
    /// internal seam also allows deterministic command-routing verification.
    func routeCommand(_ selector: Selector, on connection: PreparedInputContextConnection,
                      forward: (Selector) -> Bool) {
        commandGeneration = UUID()
        guard inputConnection === connection, let adapter = inputAdapter else {
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        switch NSStringFromSelector(selector) {
        case "undo:": connection.requestHistory(.undo); return
        case "redo:": connection.requestHistory(.redo); return
        default: break
        }
        switch PreparedInputCommandInterpreter.performReporting(selector, adapter: adapter, view: self) {
        case .unsupported:
            if !forward(selector) {
                // The responder chain has already been invoked; it may have
                // performed work even if it reports that it did not handle it.
                connection.recordInputFailure(operation: .command,
                    failure: .init(reason: .unsupported, effect: .mayHaveApplied))
            }
        case let .blocked(failure):
            connection.recordInputFailure(operation: .command, failure: failure)
        case let .handled(attempt):
            if let failure = attempt.failure { connection.recordInputFailure(operation: .command, failure: failure) }
            if attempt.outcome != .processed { connection.requestReset() }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard focusRequested, !disarmed, let connection = inputConnection else { return }
        _ = connection.performCoordinatedInput { self.routeMouseDown(event, connection: connection) }
    }

    private func routeMouseDown(_ event: NSEvent, connection: PreparedInputContextConnection) {
        func report(_ reason: PreparedInputEventAdapter.InputFailure.Reason,
                    _ effect: PreparedInputEventAdapter.InputFailure.Effect = .notApplied) {
            connection.recordInputFailure(operation: .setSelection, failure: .init(reason: reason, effect: effect))
        }
        guard !isRetired, let window = window,
              window.makeFirstResponder(self), ownsKeyFocus,
              connection.resumeForFocus(), ownsKeyFocus else { report(.unavailable); return }
        var entered = false
        var reported = false
        var applied = false
        let remainedCurrent = connection.performResponderActivity { adapter, isCurrent in
            entered = true
            guard let provisional = adapter.hasProvisionalCompositionForInput() else {
                report(.unavailable); reported = true; return
            }
            guard !provisional else { report(.compositionActive); reported = true; return }
            guard !adapter.needsInputReset, isCurrent(), ownsKeyFocus else {
                report(.unavailable); reported = true; return
            }
            let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
            guard isCurrent(), ownsKeyFocus,
                  let offset = InputScreenRangeGeometry.characterIndex(for: screenPoint, in: self),
                  isCurrent(), ownsKeyFocus else { report(.unavailable); reported = true; return }
            let attempt = adapter.setSelectionReporting(NSRange(location: offset, length: 0))
            if let failure = attempt.failure {
                connection.recordInputFailure(operation: .setSelection, failure: failure)
                reported = true
            }
            if attempt.outcome != .processed { connection.requestReset() }
            else { applied = true }
            needsDisplay = true
        }
        if !remainedCurrent && !reported {
            report(applied ? .admittedFailure : .unavailable, applied ? .mayHaveApplied : .notApplied)
        } else if !entered && !reported {
            report(.unavailable)
        }
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
