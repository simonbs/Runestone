#if canImport(AppKit)
import AppKit

/// Internal first-responder experiment. It is not a public editor surface.
/// The document attachment owns the adapter and connection; this view holds
/// both weakly so retaining a view cannot keep its document alive.
final class PreparedInputResponderView: ReadOnlyDocumentView,
                                        PreparedInputContextConnection.ReadyObserver,
                                        PreparedInputContextConnection.CommandHandler,
                                        NSDraggingSource,
                                        NSUserInterfaceValidations {
    private final class InsertionIndicator: NSTextInsertionIndicator {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private let blockCaret = AppKitBlockCaretView(frame: .zero)
    private let insertionIndicator = InsertionIndicator(frame: .zero)
    private weak var inputAdapter: PreparedInputEventAdapter?
    private weak var inputConnection: PreparedInputContextConnection?
    private var focusGeneration = UUID()
    private var keyObservers: [NSObjectProtocol] = []
    private var interpretingKeyEvents = false
    private var commandGeneration = UUID()
    private var disarmed = false
    private(set) var isReadOnly = false
    private var focusRequested = false
    private var dragSelection: PreparedInputDragSelection?
    private var pendingTextDrag: (text: String, range: NSRange)?
    /// Invalidated whenever a pointer gesture ends, even if the next gesture
    /// recreates the same range and revisions while a timer callback is active.
    private var pointerGestureGeneration = UUID()
    private var pointerAutoscrollClock: PreparedInputAutoscrollClock?
    // A gesture has a single finite budget even if it re-enters the viewport.
    private var pointerAutoscrollStarted = false
    var inputViewportClock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    // The default is AppKit’s shared pasteboard; tests can provide an isolated named one.
    var inputPasteboardProvider: () -> NSPasteboard = { .general }
    var fileDropHandler: (([URL]) -> Bool)?
    private final class SelectionLocation: NSObject, NSTextLocation {
        let offset: Int

        init(_ offset: Int) { self.offset = offset }

        func compare(_ location: NSTextLocation) -> ComparisonResult {
            guard let location = location as? SelectionLocation else { return .orderedSame }
            if offset < location.offset { return .orderedAscending }
            if offset > location.offset { return .orderedDescending }
            return .orderedSame
        }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? SelectionLocation)?.offset == offset
        }

        override var hash: Int { offset.hashValue }
    }

    private struct VerticalPreference {
        let textSelection: NSTextSelection
        let selection: NSRange
        let selectionRevision: UUID
        let contentRevision: UUID
        let layoutRevision: UUID
    }
    private var verticalPreference: VerticalPreference?

    private func verticalAnchorScreenX(for selection: NSRange) -> CGFloat? {
        guard let anchor = verticalPreference, let window,
              anchor.selection == selection, anchor.selectionRevision == inputSelectionRevision,
              anchor.contentRevision == contentRevision, anchor.layoutRevision == inputLayoutRevision else { return nil }
        let point = CGPoint(x: horizontalTextInset + anchor.textSelection.anchorPositionOffset, y: 0)
        return window.convertPoint(toScreen: convert(point, to: nil)).x
    }

    init(snapshot: NSAttributedString) {
        super.init(snapshot: snapshot, fallbackHeight: 16)
        insertionIndicator.displayMode = .hidden
        blockCaret.isHidden = true
        insertionIndicator.setAccessibilityElement(false)
        addSubview(insertionIndicator)
        addSubview(blockCaret)
    }

    required init?(coder: NSCoder) { nil }

    func attach(adapter: PreparedInputEventAdapter, connection: PreparedInputContextConnection) {
        precondition(Thread.isMainThread && !disarmed && inputConnection == nil && inputAdapter == nil)
        inputAdapter = adapter
        inputConnection = connection
        connection.readyObserver = self
        connection.commandHandler = self
        registerForDraggedTypes([.string, .fileURL])
        scheduleFocusCheck()
    }

    /// Immediately stop accepting new responder and accessibility work. The
    /// attachment owns deferred context retirement and gate cleanup.
    func disarmForDetachment() {
        precondition(Thread.isMainThread)
        guard !disarmed else { return }
        disarmed = true
        insertionIndicator.displayMode = .hidden
        blockCaret.isHidden = true
        endPointerSelection()
        verticalPreference = nil
        PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
        focusRequested = false
        focusGeneration = UUID()
        inputAdapter = nil
        inputConnection = nil
        unregisterDraggedTypes()
    }

    /// Suspends or resumes mutation without retiring this view or its document
    /// connection. Entering read-only mode first relinquishes first responder,
    /// which gives the ordinary focus-loss path ownership of composition
    /// cancellation and context retirement. The adapter keeps its canonical
    /// selection so a later explicit focus request can resume from that range.
    @discardableResult
    func setReadOnly(_ value: Bool) -> Bool {
        precondition(Thread.isMainThread)
        guard !disarmed, !isRetired else { return false }
        guard value != isReadOnly else { return true }
        if value {
            if let window, window.firstResponder === self,
               !window.makeFirstResponder(nil) { return false }
            suppressFocus()
            isReadOnly = true
        } else {
            isReadOnly = false
        }
        scheduleAccessibilityValueChanged()
        scheduleAccessibilitySelectionChanged()
        needsDisplay = true
        return true
    }

    /// Only the explicit public focus request may arm first-responder status.
    @discardableResult
    func requestFocusEligibility() -> Bool {
        precondition(Thread.isMainThread)
        guard !disarmed, !isReadOnly, !isRetired,
              inputConnection?.isConnectedForEditing == true else { return false }
        focusRequested = true
        return true
    }

    func revokeFocusEligibility() {
        precondition(Thread.isMainThread)
        endPointerSelection()
        focusRequested = false
        focusGeneration = UUID()
        insertionIndicator.displayMode = .hidden
        blockCaret.isHidden = true
        inputConnection?.suspendForFocusLoss()
    }

    private var ownsKeyFocus: Bool {
        guard !isRetired, let window = window else { return false }
        return window.isKeyWindow && window.firstResponder === self
    }

    override func accessibilityTextState() -> AccessibilityTextState? {
        if disarmed || isReadOnly { return super.accessibilityTextState() }
        return inputConnection?.accessibilityTextState()
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        guard !isRetired else { return nil }
        guard !disarmed, !isReadOnly,
              inputConnection?.accessibilityTextState() != nil else { return .staticText }
        return .textArea
    }

    override func isAccessibilitySelectorAllowed(_ selector: Selector) -> Bool {
        let setters = ["setAccessibilityValue:", "setAccessibilitySelectedText:",
                       "setAccessibilitySelectedTextRange:"]
        if setters.contains(NSStringFromSelector(selector)) {
            guard !disarmed, !isReadOnly, inputConnection?.accessibilityTextState() != nil,
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
        !disarmed && !isReadOnly && focusRequested && !isRetired &&
            inputConnection?.isConnectedForEditing == true
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

    private weak var observedInputScrollView: NSScrollView?
    private weak var liveScrollInputContext: NSTextInputContext?
    private var liveScrollDepth = 0

    private func observeInputScrolling() {
        let center = NotificationCenter.default
        if let scroll = observedInputScrollView {
            for name in [NSScrollView.willStartLiveScrollNotification, NSScrollView.didEndLiveScrollNotification,
                         NSScrollView.willStartLiveMagnifyNotification, NSScrollView.didEndLiveMagnifyNotification] {
                center.removeObserver(self, name: name, object: scroll)
            }
        }
        finishInputScrolling()
        observedInputScrollView = window == nil ? nil : enclosingScrollView
        guard let scroll = observedInputScrollView else { return }
        for name in [NSScrollView.willStartLiveScrollNotification, NSScrollView.willStartLiveMagnifyNotification] {
            center.addObserver(self, selector: #selector(inputScrollDidStart(_:)), name: name, object: scroll)
        }
        for name in [NSScrollView.didEndLiveScrollNotification, NSScrollView.didEndLiveMagnifyNotification] {
            center.addObserver(self, selector: #selector(inputScrollDidEnd(_:)), name: name, object: scroll)
        }
    }

    @objc private func inputScrollDidStart(_ notification: Notification) {
        guard let context = inputContext else { return }
        liveScrollDepth += 1
        guard liveScrollDepth == 1 else { return }
        liveScrollInputContext = context
        context.textInputClientWillStartScrollingOrZooming()
    }

    @objc private func inputScrollDidEnd(_ notification: Notification) {
        guard liveScrollDepth > 0 else { return }
        liveScrollDepth -= 1
        if liveScrollDepth == 0 { finishInputScrolling() }
    }

    private func finishInputScrolling() {
        let context = liveScrollInputContext
        liveScrollInputContext = nil
        liveScrollDepth = 0
        context?.textInputClientDidEndScrollingOrZooming()
    }

    override func viewDidMoveToWindow() {
        keyObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyObservers.removeAll()
        super.viewDidMoveToWindow()
        observeInputScrolling()
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
        finishInputScrolling()
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

    var inputConnectionDidBecomeReady: (() -> Void)?

    func preparedInputContextConnectionDidBecomeReady(_ connection: PreparedInputContextConnection) {
        guard inputConnection === connection else { return }
        scheduleFocusCheck()
        inputConnectionDidBecomeReady?()
    }

    override func keyDown(with event: NSEvent) {
        endPointerSelection()
        guard !disarmed, !isReadOnly else { return }
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

    @objc(checkSpelling:)
    private func checkSpelling(_ sender: Any?) { inputConnection?.nativeTextCheckingController?.checkSpelling(sender) }

    @objc(showGuessPanel:)
    private func showGuessPanel(_ sender: Any?) { inputConnection?.nativeTextCheckingController?.showGuessPanel(sender) }

    @objc(changeSpelling:)
    private func changeSpelling(_ sender: Any?) { inputConnection?.nativeTextCheckingController?.changeSpelling(sender) }

    @objc(orderFrontSubstitutionsPanel:)
    private func orderFrontSubstitutionsPanel(_ sender: Any?) {
        inputConnection?.nativeTextCheckingController?.orderFrontSubstitutionsPanel(sender)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !disarmed, let connection = inputConnection,
              let snapshot = connection.textFinderSnapshot(), let window,
              event.window === window else { return super.menu(for: event) }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        guard let index = InputScreenRangeGeometry.characterIndexForPointer(for: point, in: self),
              index >= 0, index <= (snapshot.text as NSString).length else { return super.menu(for: event) }
        let clicked = NSLocationInRange(index, snapshot.selection) ||
            (snapshot.selection.length == 0 && index == snapshot.selection.location)
        var effective = snapshot.selection
        return connection.nativeTextCheckingController?.menu(at: index, clickedOnSelection: clicked,
                                                              effectiveRange: &effective) ?? super.menu(for: event)
    }

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
    override func insertBacktab(_ sender: Any?) { performStandardCommand("insertBacktab:") }
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

    override func scrollPageUp(_ sender: Any?) { performStandardCommand("scrollPageUp:") }
    override func scrollPageDown(_ sender: Any?) { performStandardCommand("scrollPageDown:") }
    override func scrollToBeginningOfDocument(_ sender: Any?) { performStandardCommand("scrollToBeginningOfDocument:") }
    override func scrollToEndOfDocument(_ sender: Any?) { performStandardCommand("scrollToEndOfDocument:") }
    override func centerSelectionInVisibleArea(_ sender: Any?) { performStandardCommand("centerSelectionInVisibleArea:") }

    /// AppKit calls this before enabling an edit menu item. Actual execution
    /// repeats all revision, composition and gate checks.
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard !disarmed, ownsKeyFocus, let action = item.action, let connection = inputConnection,
              let adapter = inputAdapter, connection.accessibilityTextState() != nil else { return false }
        let allowed = canPerformEditingAction(action, connection: connection, adapter: adapter,
            pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: self.inputPasteboardProvider()))
        return allowed && ownsKeyFocus && inputConnection === connection && connection.isActiveForInput
    }

    /// Headless seam for menu validation; the public responder additionally
    /// requires active window focus before calling this method.
    func canPerformEditingAction(_ selector: Selector, connection: PreparedInputContextConnection,
                                 adapter: PreparedInputEventAdapter,
                                 pasteboard: PreparedInputClipboardCommand.Pasteboard) -> Bool {
        guard !disarmed, !isReadOnly, inputConnection === connection, inputAdapter === adapter,
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
        case "checkSpelling:", "showGuessPanel:", "orderFrontSubstitutionsPanel:":
            guard let state = adapter.inputStateForHost(), !state.hasComposition else { return false }
            return connection.nativeTextCheckingController != nil
        case "changeSpelling:":
            guard let state = adapter.inputStateForHost(), !state.hasComposition else { return false }
            return state.selection.length > 0 && connection.nativeTextCheckingController != nil
        default:
            guard let state = adapter.inputStateForHost(), !state.hasComposition else { return false }
            let text = self.manager.stringView.string
            guard PreparedInputCommandInterpreter.isValidSelectionRange(state.selection, in: text) else { return false }
            if isVisualMovement(name) {
                if visualDestination(name, selection: state.selection) != nil { return true }
                if let target = offscreenMovementOrigin(name, selection: state.selection),
                   offscreenMovementLine(for: target) != nil { return true }
                guard name.hasPrefix("moveUp") || name.hasPrefix("moveDown") else { return false }
                let up = name.hasPrefix("moveUp")
                let origin = PreparedInputCommandInterpreter.movementOrigin(selection: state.selection,
                    extending: name.contains("AndModifySelection:"), direction: up ? .backward : .forward, view: self)
                let affinity = presentedSelectionState.flatMap {
                    $0.range == state.selection && $0.activeLocation == origin ? $0.affinity : nil
                }
                return PreparedInputVisualMovement.verticalNeedsViewportStep(
                    from: InputCaretTarget(location: origin, affinity: affinity),
                    direction: up ? .up : .down, in: self)
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
                pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: self.inputPasteboardProvider()),
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
        case "scrollPageUp:", "scrollPageDown:", "scrollToBeginningOfDocument:", "scrollToEndOfDocument:",
             "centerSelectionInVisibleArea:":
            scrollForKeyboardCommand(name, adapter: adapter, isAvailable: isAvailable)
            return
        case "copy:", "cut:", "paste:":
            let operation: PreparedInputClipboardCommand.Operation
            switch NSStringFromSelector(selector) {
            case "copy:": operation = .copy
            case "cut:": operation = .cut
            default: operation = .paste
            }
            routeClipboard(operation, on: connection,
                pasteboard: PreparedInputClipboardCommand.SystemPasteboard(board: self.inputPasteboardProvider()),
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
            if attempt.outcome != .processed {
                connection.requestReset()
            } else if name.hasPrefix("move"),
                      let selection = adapter.selectionStateForHost(),
                      let check = movementViewportCheck(selection: selection.range, adapter: adapter, isAvailable: isAvailable) {
                let target = InputCaretTarget(location: selection.activeLocation, affinity: selection.affinity)
                _ = revealOffscreenMovementCaret(target, clock: inputViewportClock, revealFullCaret: selection.range.length == 0,
                                               isCurrent: check)
            }
        }
    }

    private func scrollForKeyboardCommand(_ name: String, adapter: PreparedInputEventAdapter,
                                          isAvailable: @escaping () -> Bool) {
        guard isAvailable(), let scroll = enclosingScrollView, scroll.documentView === self else { return }
        let clip = scroll.contentView
        var proposed = clip.bounds
        switch name {
        case "scrollPageUp:", "scrollPageDown:":
            let page = max(1, unobscuredContentViewport(proposed).height - scroll.verticalPageScroll)
            proposed.origin.y += name == "scrollPageUp:" ? -page : page
        case "scrollToBeginningOfDocument:":
            proposed.origin.y = bounds.minY - scroll.contentInsets.top
        case "scrollToEndOfDocument:":
            proposed.origin.y = bounds.maxY - proposed.height + scroll.contentInsets.bottom
        default:
            guard let state = adapter.selectionStateForHost(),
                  let check = movementViewportCheck(selection: state.range, adapter: adapter, isAvailable: isAvailable)
            else { return }
            let target = InputCaretTarget(location: state.activeLocation, affinity: state.affinity)
            if InputCaretAffinityGeometry.documentRect(for: target, in: self) == nil {
                guard revealOffscreenMovementCaret(target, clock: inputViewportClock, isCurrent: check) == .progressed,
                      check() else { return }
            }
            guard let rect = InputCaretAffinityGeometry.documentRect(for: target, in: self) else { return }
            proposed = clip.bounds
            proposed.origin.y = rect.midY - proposed.height / 2
            if !displayConfiguration.isLineWrappingEnabled,
               rect.minX < proposed.minX || rect.maxX > proposed.maxX {
                proposed.origin.x = rect.midX - proposed.width / 2
            }
        }
        let origin = clip.constrainBoundsRect(proposed).origin
        guard isAvailable(), enclosingScrollView === scroll, scroll.documentView === self else { return }
        clip.scroll(to: origin)
        if isAvailable(), enclosingScrollView === scroll, scroll.documentView === self {
            scroll.reflectScrolledClipView(clip)
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
        let target: InputCaretTarget
        let direction: PreparedInputCommandInterpreter.Direction
        let extending: Bool
        let verticalAnchorOffset: CGFloat?
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
            guard let window else { return nil }
            func endpoint(at location: Int) -> NSRect? {
                if let rect = InputScreenCaretGeometry.rect(at: location, in: self) {
                    return convert(window.convertFromScreen(rect), from: nil)
                }
                guard !displayConfiguration.isLineWrappingEnabled,
                      let clip = enclosingScrollView?.contentView, let layout = visibleLayout,
                      layout.isComplete, layout.viewport == clip.bounds else { return nil }
                return InputCaretAffinityGeometry.documentRect(for: .init(location: location, affinity: nil), in: self)
            }
            guard let first = endpoint(at: selection.location),
                  let last = endpoint(at: selection.upperBound) else { return nil }
            let firstBefore = abs(first.midY - last.midY) > 0.5 ? first.midY < last.midY : first.midX < last.midX
            guard abs(first.midY - last.midY) > 0.5 || abs(first.midX - last.midX) > 0.01 else { return nil }
            let chosen = (backward == firstBefore) ? selection.location : selection.upperBound
            direction = chosen == selection.location ? .backward : .forward
            if !extending { collapseTarget = chosen }
        }
        let origin = PreparedInputCommandInterpreter.movementOrigin(selection: selection, extending: extending,
                                                                     direction: direction, view: self)
        let originTarget: InputCaretTarget = {
            guard let state = presentedSelectionState, state.range == selection,
                  state.activeLocation == origin else { return InputCaretTarget(location: origin, affinity: nil) }
            return InputCaretTarget(location: origin, affinity: state.affinity)
        }()
        var verticalAnchorOffset: CGFloat?
        let target: InputCaretTarget?
        if let collapseTarget = collapseTarget {
            let affinity = presentedSelectionState.flatMap { state in
                state.range == selection && state.activeLocation == collapseTarget ? state.affinity : nil
            }
            target = InputCaretTarget(location: collapseTarget, affinity: affinity)
        } else if isVertical {
            let value = PreparedInputVisualMovement.vertical(from: originTarget, direction: backward ? .up : .down,
                                                              preferredScreenX: verticalAnchorScreenX(for: selection), in: self)
            if let value, let window {
                target = value.target
                let point = window.convertPoint(fromScreen: CGPoint(x: value.preferredScreenX, y: 0))
                verticalAnchorOffset = convert(point, from: nil).x - horizontalTextInset
            } else if (backward && origin == 0) || (!backward && origin == text.length) {
                target = InputCaretTarget(location: origin, affinity: originTarget.affinity)
            }
            else { target = nil }
        } else if isHorizontal {
            let horizontalDirection: PreparedInputVisualMovement.HorizontalDirection = backward ? .left : .right
            if isWord, let location = PreparedInputVisualMovement.unwrappedWordDestination(
                from: origin, direction: horizontalDirection, in: self) {
                target = InputCaretTarget(location: location, affinity: nil)
            } else if isWord {
                switch PreparedInputVisualWordMovement.destination(from: origin, direction: horizontalDirection, in: self) {
                case let .moved(location): target = InputCaretTarget(location: location, affinity: nil)
                case .boundary: target = originTarget
                case .unavailable: target = nil
                }
            } else {
                switch PreparedInputVisualMovement.horizontal(from: originTarget, direction: horizontalDirection, in: self) {
                case let .moved(value): target = value
                case .boundary: target = originTarget
                case .unavailable: target = nil
                }
            }
        } else {
            let edge: PreparedInputVisualMovement.Edge = backward ? .beginning : .end
            if name.contains("LeftEnd") || name.contains("RightEnd") {
                target = PreparedInputVisualMovement.lineEdge(from: origin, edge: edge, in: self)
                    .map { InputCaretTarget(location: $0, affinity: nil) }
            } else {
                target = PreparedInputVisualMovement.logicalLineEdge(from: origin, edge: edge, in: self)
                    .map { InputCaretTarget(location: $0, affinity: nil) }
            }
        }
        guard let target = target else { return nil }
        return VisualDestination(target: target, direction: direction, extending: extending, verticalAnchorOffset: verticalAnchorOffset)
    }

    private func offscreenMovementOrigin(_ name: String, selection: NSRange) -> InputCaretTarget? {
        let vertical = name.hasPrefix("moveUp") || name.hasPrefix("moveDown")
        // Horizontal collapse of an extended range needs both visible edges.
        guard selection.length == 0 || vertical else { return nil }
        let backward = name.contains("Left") || name.contains("Beginning") || name.hasPrefix("moveUp")
        let origin = PreparedInputCommandInterpreter.movementOrigin(
            selection: selection, extending: name.contains("AndModifySelection:"),
            direction: backward ? .backward : .forward, view: self
        )
        let affinity = presentedSelectionState.flatMap {
            $0.range == selection && $0.activeLocation == origin ? $0.affinity : nil
        }
        return InputCaretTarget(location: origin, affinity: affinity)
    }

    private func movementViewportCheck(selection: NSRange, adapter: PreparedInputEventAdapter,
                                       isAvailable: @escaping () -> Bool) -> (() -> Bool)? {
        guard let window, let clip = enclosingScrollView?.contentView,
              let documentRevision = adapter.installedRevisionForDispatch else { return nil }
        let content = contentRevision
        let selectionRevision = inputSelectionRevision
        return {
            guard isAvailable(), !self.isRetired, self.window === window,
                  self.enclosingScrollView?.contentView === clip,
                  self.contentRevision == content, self.inputSelectionRevision == selectionRevision,
                  adapter.installedRevisionForDispatch == documentRevision,
                  let current = adapter.inputStateForHost(), !current.hasComposition,
                  current.selection == selection else { return false }
            return isAvailable() && self.contentRevision == content && self.inputSelectionRevision == selectionRevision
        }
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
              let check = movementViewportCheck(selection: selection, adapter: adapter, isAvailable: isAvailable)
        else { return nil }
        let up = name.hasPrefix("moveUp")
        let extending = name.contains("AndModifySelection:")
        let direction: PreparedInputCommandInterpreter.Direction = up ? .backward : .forward
        let origin = PreparedInputCommandInterpreter.movementOrigin(selection: selection, extending: extending,
                                                                     direction: direction, view: self)
        let affinity = presentedSelectionState.flatMap {
            $0.range == selection && $0.activeLocation == origin ? $0.affinity : nil
        }
        let originTarget = InputCaretTarget(location: origin, affinity: affinity)
        guard PreparedInputVisualMovement.verticalNeedsViewportStep(
                from: originTarget, direction: up ? .up : .down, in: self),
              let caret = affinity == nil
                ? InputScreenCaretGeometry.rect(at: origin, in: self)
                : InputScreenCaretGeometry.rect(for: originTarget, in: self) else { return nil }
        let documentCaret = self.convert(window.convertFromScreen(caret), from: nil)
        let bounds = clip.bounds
        // Keep the source caret inside the viewport so the next row can be
        // resolved from actual geometry rather than from an estimated offset.
        let room = up ? bounds.maxY - documentCaret.maxY : documentCaret.minY - bounds.minY
        let rowHeight = documentCaret.height * displayConfiguration.lineHeightMultiplier
        let amount = min(PreparedInputViewportStep.maximumDelta, rowHeight, max(0, room - 1))
        guard amount.isFinite, amount >= 1 else { return .boundary }
        return PreparedInputViewportStep.perform(in: self, dx: 0, dy: up ? -amount : amount,
                                                 clock: inputViewportClock, isCurrent: check)
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
        let isVertical = name.hasPrefix("moveUp") || name.hasPrefix("moveDown")
        var destination = visualDestination(name, selection: state.selection)
        var verticalProbeOrigin: NSRect?
        var viewportMayHaveChanged = false
        if destination == nil {
            let offscreenStep: PreparedInputViewportStep.Outcome?
            if let origin = offscreenMovementOrigin(name, selection: state.selection),
               let check = movementViewportCheck(selection: state.selection, adapter: adapter, isAvailable: isAvailable) {
                offscreenStep = revealOffscreenMovementCaret(origin, clock: inputViewportClock, isCurrent: check)
            } else { offscreenStep = nil }
            let viewportBeforeProbe = visibleLayout?.viewport
            let step = offscreenStep ?? scrollForVerticalMovement(name, selection: state.selection,
                                                                  adapter: adapter, isAvailable: isAvailable)
            switch step {
            case .progressed:
                viewportMayHaveChanged = true
                if offscreenStep == nil && isVertical { verticalProbeOrigin = viewportBeforeProbe }
                destination = visualDestination(name, selection: state.selection)
            case .unavailable, .viewportChanged:
                viewportMayHaveChanged = true
            case .refusedBeforeScroll:
                viewportMayHaveChanged = offscreenStep == nil
            case .boundary, nil:
                break
            }
        }
        guard let destination = destination else {
            verticalPreference = nil
            connection.recordInputFailure(operation: .command,
                failure: .init(reason: .unavailable, effect: viewportMayHaveChanged ? .mayHaveApplied : .notApplied))
            return
        }
        if let viewport = visibleLayout?.viewport,
           horizontallyClippedMovementRect(for: destination.target, viewport: viewport, revealFullCaret: !destination.extending) != nil ||
                (isVertical && verticalMovementReveal(for: destination.target, from: verticalProbeOrigin ?? viewport) != nil),
           let check = movementViewportCheck(selection: state.selection, adapter: adapter, isAvailable: isAvailable) {
            let step = revealOffscreenMovementCaret(destination.target, clock: inputViewportClock,
                                                   revealFullCaret: !destination.extending,
                                                   verticalReference: isVertical ? verticalProbeOrigin ?? viewport : nil,
                                                   isCurrent: check)
            guard step == .progressed, check() else {
                verticalPreference = nil
                connection.recordInputFailure(operation: .command,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            }
        }
        switch PreparedInputCommandInterpreter.moveSelection(target: destination.target, selection: state.selection,
            extending: destination.extending, direction: destination.direction, adapter: adapter, view: self,
            isAvailable: isAvailable) {
        case let .handled(attempt):
            if let failure = attempt.failure { connection.recordInputFailure(operation: .command, failure: failure) }
            if attempt.outcome != .processed { connection.requestReset(); verticalPreference = nil }
            else if let offset = destination.verticalAnchorOffset, let current = adapter.inputStateForHost() {
                let start = SelectionLocation(current.selection.location)
                let end = SelectionLocation(current.selection.upperBound)
                guard let range = NSTextRange(location: start, end: end) else {
                    verticalPreference = nil
                    return
                }
                let selection = NSTextSelection(range: range, affinity: .downstream, granularity: .character)
                selection.anchorPositionOffset = offset
                verticalPreference = VerticalPreference(textSelection: selection, selection: current.selection,
                                                        selectionRevision: inputSelectionRevision,
                                                        contentRevision: contentRevision, layoutRevision: inputLayoutRevision)
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
        if handleSyntaxFoldingClick(event) { return }
        guard focusRequested, !disarmed, !isReadOnly,
              let connection = inputConnection else { return }
        if event.clickCount == 1, event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty,
           connection.showSpellingReversion(at: convert(event.locationInWindow, from: nil)) { return }
        connection.dismissSpellingCorrection()
        if event.clickCount == 1, !event.modifierFlags.contains(.shift), let window,
           let snapshot = connection.selectionSnapshot(), snapshot.state.range.length > 0 {
            let point = window.convertPoint(toScreen: event.locationInWindow)
            if let index = InputScreenRangeGeometry.characterIndexForPointer(for: point, in: self),
               NSLocationInRange(index, snapshot.state.range) {
                pendingTextDrag = (snapshot.text, snapshot.state.range)
                return
            }
        }
        pendingTextDrag = nil
        _ = connection.performCoordinatedInput { self.routeMouseDown(event, connection: connection) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty, let fileDropHandler { return fileDropHandler(urls) }
        guard canAcceptTextDrop(sender), let connection = inputConnection,
              let string = sender.draggingPasteboard.string(forType: .string), let window else { return false }
        let point = window.convertPoint(toScreen: sender.draggingLocation)
        guard let offset = InputScreenRangeGeometry.characterIndexForPointerDrag(for: point, in: self) else { return false }
        return connection.replaceForTextFinder(NSRange(location: offset, length: 0), with: string)
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        if fileDropHandler != nil,
           sender.draggingPasteboard.availableType(from: [.fileURL]) == .fileURL { return .copy }
        return canAcceptTextDrop(sender) ? .copy : []
    }

    private func canAcceptTextDrop(_ sender: NSDraggingInfo) -> Bool {
        guard !disarmed, !isReadOnly, !isRetired, inputConnection?.isConnectedForEditing == true else { return false }
        return sender.draggingPasteboard.availableType(from: [.string]) == .string
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
                              extending: event.modifierFlags.contains(.shift), clickCount: event.clickCount,
                              connection: connection, hasFocus: { self.ownsKeyFocus })
    }

    private func multipleClickRange(at offset: Int, clickCount: Int, in text: NSString) -> NSRange? {
        guard let line = manager.line(containingCharacterAt: offset), line.data.totalLength > 0 else { return nil }
        if clickCount >= 3 {
            return text.paragraphRange(for: NSRange(location: offset, length: 0))
        }
        guard line.data.length > 0 else { return nil }
        let source = text.substring(with: NSRange(location: line.location, length: line.data.length))
        let local = min(offset - line.location, line.data.length - 1)
        let word = NSAttributedString(string: source).doubleClick(at: local)
        guard word.location != NSNotFound else { return nil }
        return NSRange(location: line.location + word.location, length: word.length)
    }

    /// Caller holds the outer dispatch scope; the focus predicate is checked
    /// around geometry callouts and is injectable for headless tests.
    func beginPointerSelection(at screenPoint: NSPoint, extending: Bool, clickCount: Int = 1,
                               connection: PreparedInputContextConnection, hasFocus: @escaping () -> Bool) {
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
                  let target = InputScreenRangeGeometry.caretTargetForPointer(for: screenPoint, in: self),
                  isCurrent(), canUse() else { report(.unavailable); reported = true; return }
            let offset = target.location
            let currentSelection = adapter.selectedRangeForInput()
            let text = self.manager.stringView.string
            guard PreparedInputCommandInterpreter.isValidSelectionRange(currentSelection, in: text),
                  PreparedInputCommandInterpreter.isValidBoundary(offset, in: text), isCurrent(), canUse() else {
                report(.invalidSelection); reported = true; return
            }
            let anchor: Int
            let state: InputSelectionState
            let dragClickCount: Int
            if !extending, clickCount > 1,
               let unit = self.multipleClickRange(at: offset, clickCount: clickCount, in: text) {
                anchor = unit.location
                state = .rangeOnly(unit)
                dragClickCount = clickCount
            } else {
                dragClickCount = 1
                if extending {
                    anchor = PreparedInputCommandInterpreter.selectionAnchor(for: currentSelection, in: self) ??
                        (offset < currentSelection.location ? currentSelection.upperBound : currentSelection.location)
                } else {
                    anchor = offset
                }
                let selection = NSRange(location: min(anchor, offset), length: abs(offset - anchor))
                let endpoint: InputSelectionState.Endpoint = selection.length == 0 ? .caret :
                    (offset == selection.location ? .lowerBound : .upperBound)
                state = InputSelectionState(range: selection, activeEndpoint: endpoint, affinity: target.affinity)
            }
            PreparedInputCommandInterpreter.resetSelectionExtension(in: self)
            let attempt = adapter.setSelectionReporting(state, isAvailable: { isCurrent() && canUse() })
            if let failure = attempt.failure {
                connection.recordInputFailure(operation: .setSelection, failure: failure)
                reported = true
            }
            if attempt.outcome != .processed { connection.requestReset() }
            else {
                applied = true
                dragSelection = PreparedInputDragSelection(anchor: anchor, selection: state.range,
                    contentRevision: contentRevision, selectionRevision: inputSelectionRevision, clickCount: dragClickCount)
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
        if let pendingTextDrag {
            self.pendingTextDrag = nil
            let item = NSDraggingItem(pasteboardWriter: pendingTextDrag.text as NSString)
            let local = convert(event.locationInWindow, from: nil)
            item.setDraggingFrame(NSRect(origin: local, size: NSSize(width: 1, height: 1)), contents: nil)
            beginDraggingSession(with: [item], event: event, source: self)
            return
        }
        guard focusRequested, !disarmed, !isReadOnly, dragSelection != nil,
              let connection = inputConnection else { return }
        if !connection.performCoordinatedInput({ self.routeMouseDragged(event, connection: connection) }) {
            endPointerSelection()
        }
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

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
                  let target = InputScreenRangeGeometry.caretTargetForPointerDrag(for: screenPoint, in: self),
                  let offset = Optional(target.location),
                  PreparedInputCommandInterpreter.isValidBoundary(offset, in: self.manager.stringView.string),
                  isCurrent(), canUse(),
                  let selection = drag.selection(to: offset,
                                                 unit: drag.clickCount > 1 ? self.multipleClickRange(
                                                    at: offset, clickCount: drag.clickCount, in: self.manager.stringView.string) : nil,
                                                 current: adapter.selectedRangeForInput(),
                                                 contentRevision: self.contentRevision,
                                                 selectionRevision: self.inputSelectionRevision) else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .notApplied))
                reported = true
                self.endPointerSelection()
                return
            }
            let endpoint: InputSelectionState.Endpoint = selection.length == 0 ? .caret :
                (offset < drag.anchor ? .lowerBound : .upperBound)
            let state = InputSelectionState(range: selection, activeEndpoint: endpoint,
                                            affinity: drag.clickCount == 1 ? target.affinity : nil)
            let attempt = adapter.setSelectionReporting(state, isAvailable: { isCurrent() && canUse() })
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

    override func mouseUp(with event: NSEvent) {
        let shouldCollapseSelection = pendingTextDrag != nil
        pendingTextDrag = nil
        if shouldCollapseSelection, let connection = inputConnection {
            _ = connection.performCoordinatedInput { self.routeMouseDown(event, connection: connection) }
        }
        endPointerSelection()
    }

    private func endPointerSelection() {
        let endingGeneration = UUID()
        pointerGestureGeneration = endingGeneration
        pointerAutoscrollClock?.stop()
        // Cancellation can call out. Do not clear a newer gesture installed
        // while the previous timer was being invalidated.
        if pointerGestureGeneration == endingGeneration { dragSelection = nil }
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
        let gestureGeneration = pointerGestureGeneration
        guard let connection = inputConnection, let adapter = inputAdapter,
              let drag = dragSelection, let delta = pointerScrollDelta(at: screenPoint),
              delta.x != 0 || delta.y != 0 else {
            if pointerGestureGeneration == gestureGeneration { endPointerSelection() }
            return false
        }
        var advanced = false
        let admitted = connection.performCoordinatedInput {
            guard let documentRevision = adapter.installedRevisionForDispatch else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            }
            let isCurrent = {
                guard !self.disarmed, !self.isRetired, self.inputConnection === connection,
                      self.inputAdapter === adapter, connection.isActiveForInput, hasFocus(),
                      self.pointerGestureGeneration == gestureGeneration,
                      adapter.installedRevisionForDispatch == documentRevision,
                      let currentDrag = self.dragSelection, currentDrag.anchor == drag.anchor,
                      currentDrag.contentRevision == drag.contentRevision,
                      currentDrag.selectionRevision == drag.selectionRevision,
                      currentDrag.expectedSelection == drag.expectedSelection,
                      self.contentRevision == drag.contentRevision,
                      self.inputSelectionRevision == drag.selectionRevision,
                      let state = adapter.inputStateForHost(), !state.hasComposition,
                      state.selection == drag.expectedSelection else { return false }
                // Querying the host and focus are callouts. Check their effects
                // before treating a refused step as a clean no-op.
                return !self.disarmed && !self.isRetired && self.inputConnection === connection &&
                    self.inputAdapter === adapter && connection.isActiveForInput && hasFocus() &&
                    self.pointerGestureGeneration == gestureGeneration &&
                    adapter.installedRevisionForDispatch == documentRevision &&
                    self.contentRevision == drag.contentRevision && self.inputSelectionRevision == drag.selectionRevision &&
                    self.dragSelection?.anchor == drag.anchor &&
                    self.dragSelection?.contentRevision == drag.contentRevision &&
                    self.dragSelection?.selectionRevision == drag.selectionRevision &&
                    self.dragSelection?.expectedSelection == drag.expectedSelection
            }
            guard isCurrent() else {
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            }
            let step = PreparedInputViewportStep.perform(in: self, dx: delta.x, dy: delta.y,
                                                         clock: self.inputViewportClock,
                                                         allowRefusalBeforeScroll: true, isCurrent: isCurrent)
            switch step {
            case .boundary, .refusedBeforeScroll:
                guard isCurrent() else {
                    connection.recordInputFailure(operation: .setSelection,
                        failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                    return
                }
                return
            case .unavailable:
                connection.recordInputFailure(operation: .setSelection,
                    failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                return
            case .viewportChanged:
                // Scrolling is view state, and this tick has not attempted a
                // selection operation. Stop cleanly when the captured input
                // state is still current; a reentrant input change remains
                // uncertain and must enter recovery.
                guard isCurrent() else {
                    connection.recordInputFailure(operation: .setSelection,
                        failure: .init(reason: .unavailable, effect: .mayHaveApplied))
                    return
                }
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
        guard admitted && advanced else {
            // A reentrant callback can begin a new gesture while this tick is
            // unwinding. The old tick must not cancel the new gesture or clock.
            if pointerGestureGeneration == gestureGeneration { endPointerSelection() }
            return false
        }
        return true
    }

    override func noteInputCoordinatesChanged() {
        super.noteInputCoordinatesChanged()
        needsDisplay = true
    }

    override func presentationAttributedSubstring(from range: NSRange) -> NSAttributedString {
        let content = super.presentationAttributedSubstring(from: range)
        guard let prediction = inputConnection?.inlinePredictionRange else { return content }
        let intersection = NSIntersectionRange(range, prediction)
        guard intersection.length > 0 else { return content }
        let result = NSMutableAttributedString(attributedString: content)
        let local = NSRange(location: intersection.location - range.location, length: intersection.length)
        // Use the theme's foreground at reduced opacity, preserving its contrast
        // on independently chosen editor backgrounds and its syntax font metrics.
        let foreground = result.attribute(.foregroundColor, at: local.location, effectiveRange: nil) as? NSColor ?? .textColor
        result.addAttributes([.foregroundColor: foreground.withAlphaComponent(0.5), .underlineStyle: 0], range: local)
        return result
    }

    override func drawSelectionBackground(_ dirtyRect: NSRect) {
        guard ownsKeyFocus, !disarmed, !isReadOnly, let connection = inputConnection else { return }
        connection.performResponderActivity { adapter, isCurrent in
            guard let selection = adapter.selectionStateForHost(),
                  selection.range.location != NSNotFound, isCurrent(), ownsKeyFocus,
                  !adapter.needsInputReset,
                  let geometry = InputSelectionGeometry.geometry(selection: selection, marked: nil, in: self, fillsLineBackground: true),
                  isCurrent(), ownsKeyFocus else { return }
            (displayConfiguration.selectionColor ?? NSColor.selectedTextBackgroundColor).setFill()
            // Fill once so overlapping bidi segments and line tails keep a
            // translucent selection color uniform.
            let path = NSBezierPath()
            for rect in geometry.selectionRects where rect.intersects(dirtyRect) {
                path.appendRect(rect)
            }
            path.fill()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        var caret: NSRect?
        var blockPlacement: LogicalLineLayoutController.Placement?
        defer {
            if displayConfiguration.usesBlockCaret {
                insertionIndicator.displayMode = .hidden
                if let caret, ownsKeyFocus, !disarmed, !isReadOnly {
                    blockCaret.update(frame: caret, placement: blockPlacement,
                                      color: displayConfiguration.caretColor ?? .textInsertionPointColor)
                } else {
                    blockCaret.isHidden = true
                }
            } else {
                blockCaret.isHidden = true
                updateInsertionIndicator(caret)
            }
        }
        guard !isWaitingForInitialSyntaxPaint, ownsKeyFocus, !disarmed, !isReadOnly, let connection = inputConnection else { return }
        NSColor.systemRed.setStroke()
        for rect in connection.spellingAnnotationRects where rect.intersects(dirtyRect) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 1))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 1))
            path.lineWidth = 1
            path.lineCapStyle = .round
            path.setLineDash([0, 3], count: 2, phase: 0)
            path.stroke()
        }
        NSColor.controlAccentColor.withAlphaComponent(0.45).setFill()
        for rect in connection.spellingCorrectionRects where rect.intersects(dirtyRect) {
            NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2),
                         xRadius: 1, yRadius: 1).fill()
        }
        connection.performResponderActivity { adapter, isCurrent in
            guard let selection = adapter.selectionStateForHost(),
                  selection.range.location != NSNotFound, isCurrent(), ownsKeyFocus else { return }
            let marked = adapter.markedRangeForInput()
            guard !adapter.needsInputReset, isCurrent(), ownsKeyFocus,
                  let geometry = InputSelectionGeometry.geometry(selection: selection,
                      marked: marked.location == NSNotFound ? nil : marked, in: self),
                  isCurrent(), ownsKeyFocus else { return }
            NSColor.textColor.setFill()
            if !connection.isPresentingInlinePrediction {
                for rect in geometry.markedRects where rect.intersects(dirtyRect) {
                    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1)).fill()
                }
            }
            caret = geometry.caretRect
            if displayConfiguration.usesBlockCaret, let bar = caret {
                (caret, blockPlacement) = blockCaretGeometry(at: selection.range.location, bar: bar)
            }
        }
    }

    private func updateInsertionIndicator(_ caret: NSRect?) {
        guard let caret, ownsKeyFocus, !disarmed, !isReadOnly else {
            if insertionIndicator.displayMode != .hidden { insertionIndicator.displayMode = .hidden }
            return
        }
        let color = displayConfiguration.caretColor ?? .textInsertionPointColor
        if insertionIndicator.color != color { insertionIndicator.color = color }
        // AppKit restarts its blink delay when the frame is set.
        if insertionIndicator.frame != caret { insertionIndicator.frame = caret }
        if insertionIndicator.displayMode != .automatic { insertionIndicator.displayMode = .automatic }
    }

    deinit { keyObservers.forEach { NotificationCenter.default.removeObserver($0) } }
}
#endif
